# The Rational Rationale

Vtc uses rational (fraction) values to represent both timecode and framerate. Why? 
Rational values are not oft used in computer science, and less efficient than finding a 
way to represent your value as either a float or an integer scalar.

Video media programs have employed a variety of strategies to numerically representing
framerate and  timecode -- that is to say frame identifiers -- with varying success.

In this document, we will lay out some of the historical approaches, and then examine 
the reasoning behind Vtc's solution.

## Requirements

First, a brief distillation of Vtc's goals:

- Lossless casting in and out of timecode strings
- No rounding errors when adding or subtracting, or multiplying timecode values
- Math and comparisons must be frame-accurate in mixed rate contexts
- Comparisons between timecodes should be based on the real-world time a frame was 
  recorded assuming [jam-sync](https://www.robgwilson.com/news/2009/04/14/jam-sync-your-damn-cameras).

## NTSC and Digital Computing

`23.98 NTSC` timecode is specifified as running at `24000/1001` frames per second, with 
timecode caculated AS IF it were running at `24fps`.

`24000/1001` has the unfortunate propery of being an irrational number. It's digits
ride off into the sunset, never terminating:

```elixir
iex> 24_000 / 1001
23.976023976023978
```

This unfortunate mathematical reality has a number of unfortunate knock-on effects when
attempting to model frame-accurate timecode calculations.

## But wait...

If you look up the NTSC spec, you may notice that it ACTUALLY defines `23.98 NTSC` with
floats: `24000.0/1001.0`. So what gives? Why do we need more accuracy than the way video
equipment represents its frame identifiers internally?

When a camera or single-rate video editor is is producing frame timecodes, it is doing 
so from a frame number. Because those frame numbers are being generated sequentially, 
and ALWAYS in the context of a uniform frame rate, we can essentially ignore the small 
amount of real-world jitter that a video stream contains, and there will never be enough
precision loss that rounding to the nearest frame will be wrong.

But when trying to do theoretical calculation between in and out points, like when 
manipulating and EDL that *dense* data becomes *sparse* data, and we need to make sure 
we are doing our math in a way that does not lose a frame to precision issues, that 
can't misplace a frame when doing *math* between frames as *points*.

## Historical Approaches

Let's review how programs have historically attempted to grapple with timecode, and
how they fail to meet the requirements above.

**Frame integer**: One common approach to tacking timecode is to represent it as a frame
number with `0` standing for `00:00:00:00` and `24` standing for `00:00:01:00` (at
`23.98`). 

The problem with this approach is that in mixed-rate scenarios, these values
cannot be easily sorted by the real-world time that the frame was captured, and 
therefore are not suited to tasks like syncing multicams, or audio where cameras were
recording at multiple framerates. For instance, `00:00:00:23 @ 23.98` and 
`00:00:00:46 @ 47.95` both represent the same real-world time, but would be represented
as `23` and `46` respectively.

**Seconds float**: Another common technique is to do all arithmatic in floating point,
and represent the timecode as a seconds value. So `00:00:02:00` would be represented
as `48.0 frames / (24000.0/1001.0) fps = 2.002 seconds`. Most cameras calculate a their
Timecode values this way, and the official NTSC specification uses floats to define 
`24000.0/1001.0` as the `23.98 NTSC` framerate.

This works great when you are calculating each timecode frame-by-frame. You take each
frame numebr and after `23.976023976023978` seconds, you record the frame buffer and
generate a new Timecode for that frame's index. No frames are skipped. Likewise, when
casting in and out of timecode strings, there isn't enough precision loss for errors
to occur.

But when you start adding timecodes together... errors can happen. Let's take a timecode
of `00:00:00:23`. If we convert it to seconds, we get:

```elixir
iex> seconds = 23 / (24_000 / 1001)
0.9592916666666667
```

Now let's say we have five events that we want to get the total length of, each is 23
seconds long. At the end we cast back to frames so we can construct the timecode:

```elixir
iex> (seconds + seconds + seconds + seconds + seconds) * (24_000.0 / 1001.0)
115.00000000000001
```

We are just a *little* bit off. For this particular calculation, rounding gets us back
to the correct answer, but over the course of thousands of operations, say for summing
the duration of all events in an EDL, it adds up. We cannot cast back to frames to
make this correction after every operation in mixed frame contexts either.

Floats can also cause comparison errors in mixed framerate contexts. Let's imagine
we have one camera on set recording at `119.88 NTSC`, and one camera recording at
`23.98 NTSC`.

For both cameras, `23:13:13:00` should equal the same real-world time. But if we convert
the timecode stamps to real-world seconds as a float by calculating the frame number and 
dividing by the frame rate:

```elixir
iex> # 23.98 NTSC
iex> 2_006_232 / (24_000 / 1001)
83676.593
```

```elixir
iex> # 23.98 NTSC
iex> 10_031_160 / (120_000 / 1001)
83676.59300000001
```

Although these values SHOULD be equivalent, they are not. For applications that require
frame-accurate timeode comparisons, this appriach will not work, something video editors
have historically struggled with. Avid, for instance, disallowed mixed-rate timelines 
for years, focing users to transcode their media to a uniform rate before they could edit
it together.

**Quantized time**

Some programs attempt to define a minimum discreet time unit, such as a millisecond,
nanosecond, etc, and capture timecode as a scalar value of that unit. Premiere, for
instance, represents timecode as a "tick", which it defines as a `254_016_000_000th` of
a second. Video clip in, out, and duration values are all converted to a `tick` integer
value.

This approach can cause rounding issues when generating EDLs, FCP7 XMLs, AAFs and 
others. Although in recent times the program has gotten much bettern, Premiere 
originally had a number of off-by-one errors when it first started supporting
professional video workflows via interchange formats, ESPECIALLY when the framerate
of the media did not match the framerate of the edit sequence.

Again, 1 frame in `23.98` is equal to `0.04170833333333333` seconds. The digits value is
not easily representable as a discreet time value, and choosing an arbitraty quanta for
time means that the true frame time of a video clip of an arbitrary framearate may not
always neatly line up with the boundaries of your unit, cuasing gradual drift when you
start doing math.

## On Efficiency

Lastly, it is important to note that Vtc does NOT strive to be as efficient as possible.
Timecode manipulation -- when needed -- is not an operation that most programe needs to 
be done on the scale of millions of times per second, and will certainly not account for 
the majority of calculations that a program will be doing at any given step.

Therefore, we believe that the loss in efficiency is worth the gain in accuracy and
ease of use that Rational values provide. However, it is good to keep in mind that each
time a rational value is produces the operation will involve multiple sub-operations. 
In the case of addition: three multiplication, then recursive division to simplify the 
fraction.

## Conclusion

Vtc chose rational representation of timecode as a frame-accurate way to deal with
timecode values in mixed rate contexts. In short, we PUT OFF the step of casting to a
discreet value like a float, tick, millisecond, etc until AFTER we are done making 
calculations, convserving -- as accurately as possible -- a true, frame-accurate
time.