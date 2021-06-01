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

Demo
----

Let's take a quick look at how we can use this library!
  
    # It's easy to make a new 23.98 NTSC timecode. We use the with_frames constructor here 
    # since timecode is really a human-readable way to represent frame count.
    iex> tc = Vtc.Timecode.with_frames!("17:23:13:02", Vtc.Rate.f23_98)
    <17:23:00:02 @ <23.98 NTSC NDF>>
    
    # We can get all sorts of ways to represent the timecode.
    iex> Vtc.Timecode.timecode(tc)
    "17:23:00:02"

    iex> Vtc.Timecode.frames(tc)
    1501922

    iex> tc.seconds
    751711961 <|> 12000

    iex> Vtc.Timecode.runtime(tc, 3)
    "17:24:15.676"

    iex> Vtc.Timecode.premiere_ticks(tc)
    15915544300656000

    iex(3)> Vtc.Timecode.feet_and_frames(tc)
    "93889+10"

    # We can inspect the framerate.
    iex> tc.rate.ntsc
    :NonDrop  
  
    iex> tc.rate.playback
    24000 <|> 1001

    iex> Vtc.Framerate.timebase(tc.rate)
    24

    # Parsing is flexible

    # Partial timecode:
    iex> Vtc.Timecode.with_frames!("3:12", Vtc.Rate.f23_98)
    <03:00:00:12 @ <23.98 NTSC NDF>>

    # Frame count:
    iex> Vtc.Timecode.with_frames!(24, Vtc.Rate.f23_98)    
    <00:00:01:00 @ <23.98 NTSC NDF>>

    # Seconds:
    iex> Vtc.Timecode.with_seconds!(1.5, Vtc.Rate.f23_98)
    <00:05:23:04 @ <23.98 NTSC NDF>>

    # Runtime:
    iex> Vtc.Timecode.with_seconds!("00:05:23.5", Vtc.Rate.f23_98)
    <00:00:01:12 @ <23.98 NTSC NDF>>

    # Premiere Ticks:
    iex> Vtc.Timecode.with_premiere_ticks!(254016000000, Vtc.Rate.f23_98)
    <00:00:01:00 @ <23.98 NTSC NDF>>

    # Feet and Frames:
    iex> Vtc.Timecode.with_frames!("1+08", Vtc.Rate.f23_98)
    <00:00:01:00 @ <23.98 NTSC NDF>>

    # We can make dropframe timecode for 29.97 or 59.94 using one of the pre-set 
    # framerates.
    iex> drop_frame = Vtc.Timecode.with_frames!(15000, Vtc.Rate.f29_97_Df)
    <00:08:20;18 @ <29.97 NTSC DF>>
    
    # We can make new timecodes with arbitrary framerates if we want:
    iex> rate = Vtc.Framerate.new!(240, :None)
    <240.0 fps>
    iex> Vtc.Timecode.with_frames!("01:00:00:00", rate)
    <01:00:00:00 @ <240.0 fps>>

    # We do the same thing NTSC framerates / timebases.
    iex> rate = Vtc.Framerate.new!(240, :NonDrop)
    <239.76 NTSC NDF>

Features
--------

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
        - [ ] 35mm, 4-perf
        - [ ] 35mm, 3-perf
        - [ ] 35mm, 2-perf
        - [ ] 16mm
    - [X] Premiere Ticks | 15240960000000
- Operations:
    - [ ] Comparisons (==, <, <=, >, >=)
    - [ ] Add
    - [ ] Subtract
    - [ ] Scale (multiply and divide)
    - [ ] Divmod
    - [ ] Modulo
    - [ ] Negative
    - [ ] Absolute
    - [ ] Rebase (recalculate frame count at new framerate)
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