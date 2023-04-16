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

A small preview of what `Vtc` has to offer:

```elixir
iex> Timecode.with_seconds!(1.5, Rates.f23_98())
"<00:05:23:04 <23.98 NTSC>>"

iex> tc = Timecode.with_frames!("17:23:13:02", Rates.f23_98())
"<17:23:00:02 <23.98 NTSC>>"

iex> Timecode.frames(tc)
1501922

iex> Timecode.feet_and_frames(tc)
"<93889+10 :ff35mm_4perf>"

iex> Timecode.compare(tc, "02:00:00:00")
:gt

iex> tc = Timecode.add(tc, "01:00:00:00")
"<18:23:13:02 <23.98 NTSC>>"

iex> Timecode.eval at: 23.98 do
iex>   tc + "00:30:00:00" * 2 - "00:15:00:00"
iex> end
"<19:08:13:02 <23.98 NTSC>>"

iex> a_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
iex> a = Range.new!(a_in, "02:00:00:00")
"<01:00:00:00 - 02:00:00:00 :exclusive <23.98 NTSC>>"
iex>
iex> b_in = Timecode.with_frames!("01:45:00:00", Rates.f23_98())
iex> b = Range.new!(b_in, "02:30:00:00")
"<01:45:00:00 - 02:30:00:00 :exclusive <23.98 NTSC>>"
iex>
iex> Range.intersection!(a, b)
"<01:45:00:00 - 02:00:00:00 :exclusive <23.98 NTSC>>"
```

Note that printing statements like `inspect/1` have been elided from the examples above.
For a more in depth look at the full capabilities of this library, check out the
[quickstart guide](https://hexdocs.pm/vtc/quickstart.html) or 
[API reference](https://hexdocs.pm/vtc/api-reference.html).

## Goals

- Offer a comprehensive set of tools for parsing, manipulating and rendering timecode
  in with all it's quirks and incarnations.

- Define an intuitive, idiomatic Elixir API.

- Do all calculations in Rational representation, so there is both no drift or rounding 
  errors when manipulating NTSC timecode, and we can represent time as finely as 
  possible rather than being limited to the granularity of frame numbers.

- Be approachable for newcomers to the timecode problem space. Each function and concept
  in the [API reference](https://hexdocs.pm/vtc/api-reference.html) includes a primer on
  what it is and where it is used in Film and Television workflow.

- Offer a flexible set of tools that support both rigorous, production-quality code and
  quick scratch scripts.

## Features

- SMPTE Conventions:
    - [X] NTSC
    - [X] Drop-Frame
    - [ ] Interlaced timecode
- Timecode Representations:
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
    - [X] Poorly formatted tc    | '1:13:4'
- [X] Built-in consts for common framerates.
- [X] Configurable rounding options.
- [X] Support for standard library sorting behavior.
- [X] Range type for working with and comparing frame ranges.
    - [X] Overlap between ranges
    - [X] Distance between ranges
    - [X] Inclusive and exclusive ranges

## Attributions

<div>Drop-frame calculations adapted from <a href="https://www.davidheidelberger.com/2010/06/10/drop-frame-timecode/">David Heidelberger's blog.</a></div>

<div>35mm, 2perf and 16mm format support based on <a href="https://github.com/opencinemac/vtc-rs/pull/8">Jamie Hardt's work for vtc-rs.</a></div>

<div>Logo made by <a href="" title="Freepik">Freepik</a> from <a href="https://www.flaticon.com/" title="Flaticon">www.flaticon.com</a></div>

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `vtc` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:vtc, "~> 0.7"}
  ]
end
```