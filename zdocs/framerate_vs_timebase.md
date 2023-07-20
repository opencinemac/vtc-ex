# NTSC: Framerate vs Timebase

To understand timecode, first we need to understand the difference between framerate,
the rate at which a piece of media is *actually* yielding frames, and timebase, the
rate at which we *pretend* that media is yielding frames when rendering a SMPTE timecode
value.

Timecode does not -- counterintuitively -- represent the TIME of a frame. Instead, it is 
a human-digestible INDEX of that frame in the sequence of all frames that make up a 
video clip, just like keycode before it. It's fields are NOT hours, minutes, seconds, 
and *milliseconds*, as you might expect from a time-based format; they are "hours", 
"minutes", "seconds", and *frames* (more on the airquotes later).

Timecode is more UUID than timestamp.

## (Not) fitting neatly into seconds

For true-frame video -- that is, video where frames never cross the boundary of a
given second -- this distinction doesn't matter. When recording at 24.0fps true, the
23rd frame recorded is `00:00:00:23` and the 24th frame recorded is `00:00:01:00`, 
SMPTE timecode, which lines up with `00:00:01.0` in real-world hours, minutes, and 
seconds.

Here is the catch -- because there is a catch -- the vast majority of video these days 
are *not* recorded in mathematically convenient framerates. They are recorded at 
framerates defined by the SMPTE NTSC standard. You can read a deep-dive on that 
standard [here](https://blog.frame.io/2017/07/17/timecode-and-frame-rates/), but the 
long and short of it is that cinema video is almost always recorded rates commonly
referred to as `23.98`, `29.97`, `59.84`, etc. that are fractionally slower than their
`24.0`, `30.0`, `60.0`, etc. counterparts.

When trying to figure out how to map NTSC frames to a frame-specific timestamp, 
attempting to conform to the real world becomes difficult. the 24th frame of 23.98, NTSC 
timecode actually occurs at `00:00:01.001`. If we want a discreet 'frames' place, do we 
then need to drop frames from some seconds to keep them in-line with a real world clock? 
Unsurprisingly, some timecode displays do exactly that. NTSC 
[drop-frame](https://en.wikipedia.org/wiki/SMPTE_timecode#Drop-frame_timecode) timecode
takes this approach, and is a nightmare to work with outside the very specific use case 
of measuring the length of an edit. 

Thankfully, drop-frame conventions are out of favor these days, and only defined for 
`29.97` and `59.94` framerates -- the framerates that were used for analogue video and 
older broadcast television.

## "Seconds" aren't Seconds

NTSC non-drop timecode is the favored convention today. Non-drop timecode, as the name
suggests, does *not* drop frames to keep it's "timestamp" in sync with the real-world 
clock. Instead, it chooses to believe a convenient lie that all 24 frames in a "second" 
actually fit in that second, and renders timecode accordingly, with each "second" 
starting at frame `00` and ending at frame `23`. Drift from the real-world clock is 
taken as a necessary sin in exchange for not having to manage drop frames. `01:00:00:00`
in `23.98 NTSC, non-drop`  timecode represents `01:00:03.6` in real-world hours, 
minutes, and seconds.

## Vtc Terminology

Vtc calls the true, real-world framerate of the media -- in this example `24000/1001` 
-- the `playback` rate of the timecode.

The rate at which timecode is calculated, -- in this example `24/1` -- is called the
`timebase`.

But wait -- why are we using fractions all of a sudden? That's because the common way we
refer to NTSC framerates -- i.e `23.98 NTSC` -- is actually rounded shorthand for it's 
actual specification: `24000/1001`.

We will examine the inherently rational nature of timecode calculations in the next
section.