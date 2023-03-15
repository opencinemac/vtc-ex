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

Let's take a quick look at how we can use this library!
  
```elixir
alias Vtc.Framerate
alias Vtc.Rates
alias Vtc.Timecode

# It's easy to make a new 23.98 NTSC timecode. We use the with_frames constructor here 
# since timecode is really a human-readable way to represent frame count.
iex> tc = Timecode.with_frames!("17:23:13:02", Rates.f23_98) |> inspect()
"<17:23:00:02 @ <23.98 NTSC NDF>>"

# We can get all sorts of ways to represent the timecode.
iex> Timecode.timecode(tc)
"17:23:00:02"

iex> Timecode.frames(tc)
1501922

iex> tc.seconds |> inspect()
"751711961 <|> 12000"

iex> Timecode.runtime(tc, 3)
"17:24:15.676"

iex> Timecode.premiere_ticks(tc)
15915544300656000

iex> Timecode.feet_and_frames(tc)
"93889+10"

# We can inspect the framerate.
iex> tc.rate.ntsc
:non_drop  

iex> tc.rate.playback |> inspect()
"24000 <|> 1001"

iex> Framerate.timebase(tc.rate)
24

# Parsing is flexible

# Partial timecode:
iex> Timecode.with_frames!("3:12", Rates.f23_98) |> inspect()
"<03:00:00:12 @ <23.98 NTSC NDF>>"

# Frame count:
iex> Timecode.with_frames!(24, Rates.f23_98) |> inspect()
"<00:00:01:00 @ <23.98 NTSC NDF>>"

# Seconds:
iex> Timecode.with_seconds!(1.5, Rates.f23_98) |> inspect()
"<00:05:23:04 @ <23.98 NTSC NDF>>"

# Runtime:
iex> Timecode.with_seconds!("00:05:23.5", Rates.f23_98) |> inspect()
"<00:05:23:04 @ <23.98 NTSC NDF>>"

# Premiere Ticks:
iex> Timecode.with_premiere_ticks!(254_016_000_000, Rates.f23_98) |> inspect()
"<00:00:01:00 @ <23.98 NTSC NDF>>"

# Feet and Frames:
iex> Timecode.with_frames!("1+08", Rates.f23_98) |> inspect()
"<00:00:01:00 @ <23.98 NTSC NDF>>"

# We can add two timecodes:
iex> tc = Timecode.add(tc, Timecode.with_frames!("01:00:00:00", Rates.f23_98))
iex> inspect(tc)
"<18:23:13:02 @ <23.98 NTSC NDF>>"

# But if we want to do something quickly, we just use a timecode string instead.
iex> tc = Timecode.add(tc, "00:10:00:00")
iex> inspect(tc)
"<18:33:13:02 @ <23.98 NTSC NDF>>"

# Adding ints means adding frames.
iex> tc = Timecode.add(tc, 38)
iex> inspect(tc)
"<18:33:14:16 @ <23.98 NTSC NDF>>"

# We can subtract too.
iex> tc = Timecode.sub(tc, "01:00:00:00")
iex> inspect(tc)
"<17:33:14:16 @ <23.98 NTSC NDF>>"

# It's easy to compare two timecodes
iex> a = Timecode.with_frames!("01:00:00:00", Rates.f23_98)
iex> b = Timecode.with_frames!("02:00:00:00", Rates.f23_98)
iex> Timecode.compare(a, b)
:gt

# And even compare directly with a timecode string
iex> Timecode.compare(a, "00:59:00:00")
:lt

# We can multiply
iex> tc = Timecode.mult(tc, 2)
iex> inspect(tc)
"<35:06:29:08 @ <23.98 NTSC NDF>>"

# ... divide ...
iex> tc = Timecode.div(tc, 2)
iex> inspect(tc)
"<17:33:14:16 @ <23.98 NTSC NDF>>"

# ... and even get the remainder while dividing!
iex> {dividend, remainder} = Timecode.divmod(tc, 3)
iex> inspect(dividend)
"<05:51:04:21 @ <23.98 NTSC NDF>>"
iex> inspect(remainder)
"<00:00:00:01 @ <23.98 NTSC NDF>>"

# We can make dropframe timecode for 29.97 or 59.94 using one of the pre-set 
# framerates.
iex> drop_frame = Timecode.with_frames!(15000, Rates.f29_97_Df)
iex> inspect(drop_frame)
"<00:08:20;18 @ <29.97 NTSC DF>>"

# We can make new timecodes with arbitrary framerates if we want:
iex> Timecode.with_frames!("01:00:00:00", Framerate.new!(240, nil)) |> inspect()
"<01:00:00:00 @ <240.0 fps>>"

# Using `:non_drop` indicates this is an NTSC timecode, and will convert whole-number
# timebases to the correct speed.
iex> Timecode.with_frames!("01:00:00:00", Framerate.new!(48, :non_drop)) |> inspect()
"<01:00:00:00 @ <47.95 NTSC>>"

# We can also rebase the frames using a new framerate!
iex> Timecode.rebase(tc, Rates.f23_98) |> inspect()
"<02:00:00:00 @ <23.98 NTSC>>"
```

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
        - [ ] 35mm, 2-perf
        - [ ] 16mm
    - [X] Premiere Ticks | 15240960000000
- Operations:
    - [X] Comparisons (==, <, <=, >, >=)
    - [X] Add
    - [X] Subtract
    - [X] Scale (multiply and divide)
    - [ ] Divmod
    - [ ] Modulo
    - [ ] Negative
    - [ ] Absolute
    - [X] Rebase (recalculate frame count at new framerate)
- Flexible Parsing:
    - [X] Partial timecodes      | '1:12'
    - [X] Partial runtimes       | '1.5'
    - [X] Negative string values | '-1:12', '-3+00'
    - [X] Poorly formatted tc    | '1:13:4'
- [X] Built-in consts for common framerates.
- [ ] Range type for working with and comparing frame ranges.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `vtc` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:vtc, "~> 0.1"}
  ]
end
```