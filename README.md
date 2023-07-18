<h1 align="center">vtc-ex</h1>
<p align="center">
    <img height=150 class="heightSet" align="center" src="https://raw.githubusercontent.com/opencinemac/vtc-py/master/zdocs/source/_static/logo1.svg"/>
</p>
<p align="center">A SMPTE Timecode Library for Elixir</p>
<p align="center">
    <a href="https://dev.azure.com/peake100/Open%20Cinema%20Collective/_build?definitionId=19"><img src="https://dev.azure.com/peake100/Open%20Cinema%20Collective/_apis/build/status/vtc-ex?repoName=opencinemac%2Fvtc-ex&branchName=dev" alt="click to see build pipeline"></a>
    <a href="https://dev.azure.com/peake100/Open%20Cinema%20Collective/_build?definitionId=19"><img src="https://img.shields.io/azure-devops/tests/peake100/Open%20Cinema%20Collective/19/dev?compact_message" alt="click to see build pipeline"></a>
    <a href="https://dev.azure.com/peake100/Open%20Cinema%20Collective/_build?definitionId=19"><img src="https://img.shields.io/azure-devops/coverage/peake100/Open%20Cinema%20Collective/19/dev?compact_message" alt="click to see build pipeline"></a>
</p>
<p align="center">
    <a href="https://hex.pm/packages/vtc"><img src="https://img.shields.io/hexpm/v/vtc.svg" alt="PyPI version" height="18"></a>
    <a href="https://hexdocs.pm/vtc/readme.html"><img src="https://img.shields.io/badge/docs-hexdocs.pm-blue" alt="Documentation"></a>
</p>

## Demo

A small preview of what `Vtc` has to offer. Note that printing statements like 
`inspect/1` have been elided from the examples below.

`Vtc` represents specific frames in a video stream as [Framestamps](`Vtc.Framestamp`), 
which can [parsed](Vtc.Framestamp.html#parse) from a number of different formats, 
including SMPTE timecode, frame count, and physical film length measured in 
feet and frames:

```elixir
iex> Framestamp.with_seconds!(1.5, Rates.f23_98())
"<00:05:23:04 <23.98 NTSC>>"
iex> stamp = Framestamp.with_frames!("17:23:13:02", Rates.f23_98())
"<17:23:00:02 <23.98 NTSC>>"
```

Once in a [Framestamp](`Vtc.Framestamp`) struct, you 
[convert](Vtc.Framestamp.html#convert) to any of the supported formats:

```elixir
iex> Framestamp.smpte_timecode(stamp)
"00:05:23:04"
iex> Framestamp.frames(stamp)
1501922
iex> Framestamp.feet_and_frames(stamp)
"<93889+10 :ff35mm_4perf>"
```

[Comparisons](Vtc.Framestamp.html#compare) and 
[kernel sorting](Vtc.Framestamp.html#module-sorting-support) are supported, with many 
helper functions for specific comparisons:

```elixir
iex> Framestamp.compare(stamp, "02:00:00:00")
:gt
iex> Framestamp.gt?(stamp, "02:00:00:00")
true
iex> stamp_01 = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
iex> stamp_02 = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())
iex> data_01 = %{id: 2, tc: stamp_01}
iex> data_02 = %{id: 1, tc: stamp_02}
iex> [data_02, data_01] |> Enum.sort_by(& &1.tc, Framestamp) |> inspect()
"[%{id: 2, tc: <01:00:00:00 <23.98 NTSC>>}, %{id: 1, tc: <02:00:00:00 <23.98 NTSC>>}]"
```

All sensible [arithmetic](Vtc.Framestamp.html#arithmetic) operations are provided, such 
as addition, subtraction, and multiplication:

```elixir
iex> stamp = Framestamp.add(tc, "01:00:00:00")
"<18:23:13:02 <23.98 NTSC>>"
```

You can even use native operators within special [eval/2](Vtc.Framestamp.html#eval/2) 
blocks:

```elixir
iex> Framestamp.eval at: 23.98 do
iex>   stamp + "00:30:00:00" * 2 - "00:15:00:00"
iex> end
"<19:08:13:02 <23.98 NTSC>>"
```

[Ranges](`Vtc.Framestamp.Range`) let you operate on in/out points, for instance, finding the 
overlapping area between two ranges:

```elixir
iex> a_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
iex> a = Framestamp.Range.new!(a_in, "02:00:00:00")
"<01:00:00:00 - 02:00:00:00 :exclusive <23.98 NTSC>>"
iex> b_in = Framestamp.with_frames!("01:45:00:00", Rates.f23_98())
iex> b = Framestamp.Range.new!(b_in, "02:30:00:00")
"<01:45:00:00 - 02:30:00:00 :exclusive <23.98 NTSC>>"
iex> Framestamp.Range.intersection!(a, b)
"<01:45:00:00 - 02:00:00:00 :exclusive <23.98 NTSC>>"
```

## Ecto types

Vtx ships with optional ecto types that can be used to accelerate you timecode workflow
at the database level:

```elixir
## Migration file

defmodule MyApp.MySchema do
  @moduledoc false
  use Ecto.Migration

  alias Vtc.Ecto.Postgres.PgFramestamp
  alias Vtc.Framestamp

  def change do
    create table("my_table", primary_key: false) do
      add(:id, :uuid, primary_key: true, null: false)
      add(:a, Framestamp.type())
      add(:b, Framestamp.type())
    end
  end
end
```

```elixir
## Schema file

defmodule Vtc.Test.Support.FramestampSchema01 do
  @moduledoc false
  use Ecto.Schema

  alias Ecto.Changeset
  alias Vtc.Framestamp

  @type t() :: %__MODULE__{
          id: Ecto.UUID.t(),
          a: Framestamp.t(),
          b: Framestamp.t()
        }

  @primary_key {:id, Ecto.UUID, autogenerate: true}

  schema "my_table" do
    field(:a, Framestamp)
    field(:b, Framestamp)
  end

  @spec changeset(%__MODULE__{}, %{atom() => any()}) :: Changeset.t(%__MODULE__{})
  def changeset(schema, attrs), do: Changeset.cast(schema, attrs, [:id, :a, :b])
end
```

Values can be used in Ecto queries using the [type/2](`Ecto.Query.API.type/2`) function.
Vtc registers native operators for each type, so you can write queries like you would
expect to:

```elixir
iex> one_hour = Framestamp.with_frames("01:00:00:00", Rates.f23_98())
iex> 
iex> EdlEvents
iex> |> where([event], event.start > type(^one_hour, Framestamp))
iex> |> select([event], {event, event.end - event.in_framestamp})
```

The above query finds all events with a start time greater than `01:00:00:00` and
returns the record AND its calculated duration.

## Further Reading

Check out the [Quickstart Guide](quickstart.html) for a walkthrough of what `Vtc` 
offers for application-level code, and the [Ecto Quickstart Guide](ecto_quickstart.cheatmd)
for a deep-dive on working with Vtc's Postgres offertings.

The [API Reference](api-reference.html) offers a complete technical accounting of Vtc's 
capabilities.

## Goals

- Offer a comprehensive set of tools for parsing, manipulating and rendering timecode
  with all it's quirks and incarnations.

- Define an intuitive, idiomatic Elixir API.

- Do all calculations in Rational representation, so there is both no drift or rounding 
  errors when manipulating NTSC timecode, and we can represent time as finely as 
  possible rather than being limited to the granularity of frame numbers.

- Be approachable for newcomers to the timecode problem space. Each function and concept
  in the [API Reference](api-reference.html) includes a primer on what it is and where 
  it is used in Film and Television workflow.

- Offer a flexible set of tools that support both rigorous, production-quality code and
  quick scratch scripts.

## Features

- SMPTE Conventions:
    - [X] NTSC
    - [X] Drop-Frame
    - [ ] Interlaced timecode
- Timecode Representations:
    - [X] Framestamp  | 18018/5 seconds @ 24000/1001
    - [X] Timecode    | '01:00:00:00'
    - [X] Frames      | 86400
    - [X] Seconds     | 3600.0
    - [X] Runtime     | '01:00:00.0'
    - [X] Rational    | 18018/5
    - [X] Feet+Frames | '5400+00'
        - [X] 35mm, 4-perf
        - [ ] 35mm, 3-perf
        - [X] 35mm, 2-perf
        - [X] 16mm
    - [X] Premiere Ticks | 15240960000000
- Operations:
    - [X] Comparisons (==, <, <=, >, >=)
    - [X] Add
    - [X] Subtract
    - [X] Scale (multiply and divide)
    - [X] Divmod
    - [X] Modulo
    - [X] Negative
    - [X] Absolute
    - [X] Rebase (recalculate frame count at new framerate)
    - [X] Native Operator Evaluation
- Flexible Parsing:
    - [X] Partial timecodes      | '1:12'
    - [X] Partial runtimes       | '1.5'
    - [X] Negative string values | '-1:12', '-3+00'
    - [X] Poorly formatted SMPTE timecode    | '1:13:4'
- [X] Built-in consts for common framerates.
- [X] Configurable rounding options.
- [X] Support for standard library sorting behavior.
- [X] Range type for working with and comparing frame ranges.
    - [X] Overlap between ranges
    - [X] Distance between ranges
    - [X] Inclusive and exclusive ranges
- [X] Postgres Composite Types with Ecto and Postgrex:
    - Rational[X]
      - [X] Native comparison operators
      - [X] Native arithmetic operators
      - [X] Native BTree index support
    - Framerate[X]
      - [X] Native comparison operators
    - Framestamp[X]
      - [X] Native comparison operators
      - [X] Native arithmetic operators
      - [X] Native BTree index support
      - [X] Native inspection functions
    - Framestamp.Range
      - [X] Native GiST index support
      - [X] Native inspection functions

## Attributions

Drop-frame calculations adapted from 
[David Heidelberger's blog](https://www.davidheidelberger.com/2010/06/10/drop-frame-timecode/).

35mm, 2perf and 16mm format support based on 
[Jamie Hardt's work for vtc-rs](https://github.com/opencinemac/vtc-rs/pull/8).

Logo made by Freepik from [www.flaticon.com](https://www.flaticon.com/).

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `vtc` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:vtc, "~> 0.14"}
  ]
end
```