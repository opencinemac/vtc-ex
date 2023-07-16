defmodule Vtc.Framestamp do
  @moduledoc """
  Represents a particular frame in a video clip.

  New Framestamp values are created with the `with_seconds/3` and `with_frames/2`, and
  other function prefaced by `with_*`.

  Vtc express a philosophy of working with Timecode that is defined by two major
  conceits:

  1. A frame identifier is incomplete without a framerate.
     [More here](Vtc.Framestamp.html#module-why-include-framerate).

  2. All frame identifiers commonly used in Video production boil down to being an
     expression of either the real-world seconds of a frame, OR a squential index
     number. [More here](Vtc.Framestamp.html#module-parsing-seconds-t-or-frames-t).

  ## What is a framestamp?

  Framestamps are an expression of Vtc's philosophy about working with timecode in
  application code. On a technical level, a framestamp is comprised of:

  - The real-world time that a frame occurred at, as represented by a rational value,
    measured in seconds since SMPTE timecode "midnight".

  - The framerate of the media the framestamp was generated for, as represented by a
    rational frames-per-second value.

  - Any associated metadata about the source representation the framestamp was parsed
    from, such as SMPTE NTSC non-drop timecode.

  So a fully-formed framestamp for `01:00:00:00` at `23.98 NTSC` would be
  `18018/5 @ 24000/1001 NTSC non-drop`.

  ### Why prefer seconds?

  SMPTE [timecode](history.html), shown above, is the canonical way we identify an
  individual frame in professional video workflows. As a human readable data type,
  timecode strings are great. You can easily locate, compare, and add timecode strings
  at a glance.

  Why then, does Vtc come up with a new representation?

  Well, SMPTE timecode strings are *not* as great for computers. Let's take a quick look
  at what we want from a good frame identifier:

  - Uniquely identify a frame in a specific video stream.

  - Sort by real-world occurrence.

  - Add / subtract values.

  - All of the above, in mixed-framerate contexts.

  The last point is key, timecode is great... *if* all of your media is running at the
  same framerate. For instance, when syncing footage and audio between two cameras --
  one running at 24fps, and one running at 48fps -- `01:00:00:13` and `01:00:00:26` are
  equivalent values, as they were captured at the same point in time, and should be
  synced together. Timecode is an expression of *frame index* more than *frame seconds*,
  and as such, cannot be lexically sorted in mixed-rate settings. Further,
  a computer cannot add "01:30:00:00" to "01:00:00:00" without converting it to some
  sort of numerical value.

  Many programs convert timecode directly to an integer frame number for arithamtic and
  comparison operations where each frame on the clock is issued a continuous index,
  zero `0` is `00:00:00:00`. Frame numbers, though, have the same issue with mixed-rate
  values as timecode; `26` at 48 frames-per-second represents the same real-world time
  as `13` at 24 frames-per-seconds, and preserving that equality is important for
  operations like jam-syncing.

  So that leaves us with real-world seconds. Convert timecode values -- even ones
  captured in mixed rates -- to seconds, then add and sort to your heart's content.

  ### Why rational numbers?

  We'll avoid a deep-dive over why we use a rational value over a float or decimal, but
  you can read more on that choice
  [here]([why we use rational values](the_rational_rationale.html).

  The short version is that many common SMPTE-specified framerates are defined as
  irrational numbers. For instance, `23.98 NTSC` is defined as `24000/1001`
  frames-per-second.

  In order to avoid off-by-one errors when using `seconds`, we need to avoid resolving
  values like `1001/24000` -- the value for frame `1` at `23.98 NTSC` -- into any sort
  of decimal representation, since `1001/24000` is an irrational value and cannot be
  cleanly represented as a decimal. It's digits ride off into the sunset.

  ### Why include framerate?

  SMPTE timecode does not include a framerate in it's specification for frame
  identifiers, i.e `01:00:00:00`. So why does `Vtc`?

  Lets say that we are working with a given video file, and you are handed the timecode
  `01:00:00:12`. What frame does that belong to?

  Without a framerate, you cannot know. If we are talking about `23.98 NTSC` media, it
  belongs to frame `86,400`, but if we are talking about `59.94 NTSC NDF`,  frame then
  it belongs to frame `216,000`, and if we are talking about `59.94 NTSC DF` media then
  it belongs to frame `215,784`.

  What about the other direction. We need to calculate the SMPTE timecode for frame
  `48`, which we previously parsed from a timecode. Well if it was originally parsed
  using `23.98 NTSC` footage, then it is TC `00:00:02:00`, but if it is `59.94 NTSC`
  then it is TC `00:00:00:48`. Framerate is implicitly required for a SMPTE timecode
  to be comprehensible.

  The story is the same with seconds. How many seconds does `01:00:00:00` represent?
  At `23.98 NTSC`, it represents `18018/5` seconds, but at `24fps true` it represents
  `3600/1` seconds.

  We cannot know what frame a seconds value represents, or what seconds value a frame
  represents, without knowing that scalar value's associated framerate. It's like having
  a timestamp without a timezone. Even in systems where all timestamps are converted to
  UTC, we often keep the timezone information around because it's just too useful in
  mixed-timezone settings, and you can't be *sure* what a given timezone represents
  in a vacuum if you don't have the associated timezone.

  Framerate -- especially in mixed rate settings, which Vtc considers a first-class use
  case -- is required to sensibly execute many operations, like casting in an out of
  SMPTE Timecode, adding two timecodes together, etc.

  For this reason we package the framerate of our media stream together with the scalar
  value that represents a frame in that stream, and take the onus of transporting these
  two values together off of the caller.

  ## Struct Fields

  - `seconds`: The real-world seconds elapsed since 'midnight' as a rational value.

  - `rate`: the [Framerate](`Vtc.Framerate`) of the `Framestamp`.

  ## Parsing: Seconds.t() or Frames.t()

  Parsing functions preappend `with_` to their name. When you give a value to a parsing
  function, it is the same value that would be returned by the euivalent unit
  conversion. So a value passed to [with_frames](`Vtc.Framestamp.with_frames/2`) is the
  same value [frames](`Vtc.Framestamp.frames/1`) would return:

  ```elixir
  iex> {:ok, framestamp} = Framestamp.with_frames(24, Rates.f23_98())
  iex> inspect(framestamp)
  "<00:00:01:00 <23.98 NTSC>>"
  iex> Framestamp.frames(framestamp)
  24
  ```

  The `Framestamp` module only has two basic construction / parsing methods:
  [with_seconds](`Vtc.Framestamp.with_seconds/2`) and
  [with_frames](`Vtc.Framestamp.with_frames/2`).

  At first blush, this may seem... odd. Where is `with_timecode/2`? Or
  `with_premiere_ticks/2`? We can render these formats, so why isn't there a parser for
  them? Well there is, sort of: the two functions above.

  Vtc's second major conceit is that all of the various ways of representing a
  video frame's timestamp boil down to EITHER:

  - a) A representation of an index number for that frame

  OR

  - b) A representation of the real-world seconds the frame occurred at.

  SMPTE timecode is really a human-readable way to represent a frame number. Same with
  film feet+frames.

  Premiere Ticks, on the other hand, represents a real-world seconds value, as broken
  down in `1/254_016_000_000ths` of a second.

  Instead of polluting the module's namespace with a range of constructors, Vtc declares
  a [Frames](`Vtc.Source.Frames`) protocol for types that represent a frame count, and a
  [Seconds](`Vtc.Source.Seconds`) protocol for types that represent a time-scalar.

  All framestamp representations eventually get funneled through one of these
  protocols. For instance, when the `String` implementation of the protocol detects a
  SMPTE timecode string, it wraps the value in a
  [SMPTETimecodeStr](`Vtc.Source.Frames.SMPTETimecodeStr`) struct which handles converting that
  string to a frame number thorough implementing the [Frames](`Vtc.Source.Frames`)
  protocol. That frame number is then taken by
  [with_frames](`Vtc.Framestamp.with_frames/2`) and converted to a rational seconds
  value.

  Going through protocols allows callers to define their own types that work with Vtc's
  parsing functions directly.

  ## Sorting Support

  [Framestamp](`Vtc.Framestamp`) implements `compare/2`, and as such, can be used wherever
  the standard library calls for a `Sorter` module. Let's see it in action:

  ```elixir
  iex> stamp_01 = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex> stamp_02 = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())
  iex>
  iex> sorted = Enum.sort([stamp_02, stamp_01], Framestamp)
  iex> inspect(sorted)
  "[<01:00:00:00 <23.98 NTSC>>, <02:00:00:00 <23.98 NTSC>>]"
  iex> sorted = Enum.sort([stamp_01, stamp_02], {:desc, Framestamp})
  iex> inspect(sorted)
  "[<02:00:00:00 <23.98 NTSC>>, <01:00:00:00 <23.98 NTSC>>]"
  iex> max = Enum.max([stamp_02, stamp_01], Framestamp)
  iex> inspect(max)
  "<02:00:00:00 <23.98 NTSC>>"
  iex> min = Enum.min([stamp_02, stamp_01], Framestamp)
  iex> inspect(min)
  "<01:00:00:00 <23.98 NTSC>>"
  iex> data_01 = %{id: 2, tc: stamp_01}
  iex> data_02 = %{id: 1, tc: stamp_02}
  iex> sorted = Enum.sort_by([data_02, data_01], & &1.tc, Framestamp)
  iex> inspect(sorted)
  "[%{id: 2, tc: <01:00:00:00 <23.98 NTSC>>}, %{id: 1, tc: <02:00:00:00 <23.98 NTSC>>}]"
  ```

  ## Arithmetic Autocasting

  For operators that take two `Framestamp` values, likt `add/3` or `compare/2`, as long
  as one argument is a [Framestamp](`Vtc.Framestamp`) value, `a` or `b` May be any value
  that implements the [Frames](`Vtc.Source.Frames`) protocol, such as a timecode string,
  and will be assumed to be the same framerate as the other.

  > #### Production code {: .tip}
  >
  > Autocasting exists to support quick scratch scripts and we suggest that it not be,
  > relied upon in production application code.

  If parsing the value fails during casting, the function raises a
  `Vtc.Framestamp.ParseError`.

  ## Using as an Ecto Type

  See [PgFramestamp](`Vtc.Ecto.Postgres.PgFramestamp`) for information on how to use
  `Framerate` in your postgres database as a native type.
  """
  use Vtc.Ecto.Postgres.Utils

  import Kernel, except: [div: 2, rem: 2, abs: 1]

  alias Vtc.Ecto.Postgres.PgFramestamp
  alias Vtc.FilmFormat
  alias Vtc.Framerate
  alias Vtc.Framestamp
  alias Vtc.Framestamp.Eval
  alias Vtc.Framestamp.MixedRateArithmaticError
  alias Vtc.Framestamp.ParseError
  alias Vtc.SMPTETimecode.Sections
  alias Vtc.Source.Frames
  alias Vtc.Source.Frames.FeetAndFrames
  alias Vtc.Source.Frames.SMPTETimecodeStr
  alias Vtc.Source.Seconds
  alias Vtc.Source.Seconds.PremiereTicks
  alias Vtc.Source.Seconds.RuntimeStr
  alias Vtc.Utils.DropFrame
  alias Vtc.Utils.Rational

  @enforce_keys [:seconds, :rate]
  defstruct [:seconds, :rate]

  @typedoc """
  [Framestamp](`Vtc.Framestamp`) type.
  """
  @type t() :: %__MODULE__{
          seconds: Ratio.t(),
          rate: Framerate.t()
        }

  @typedoc """
  Valid values for rounding options.

  - `:closest`: Round the to the closet whole frame. Rounds away from zero when
    value is equidistant from two whole-frames.

  - `:floor`: Always round down to the closest whole-frame. Negative numbers round away
     from zero

  - `:ciel`: Always round up to the closest whole-frame. Negative numbers round towards
     zero.

  - `:trunc`: Always round towards zero to the closest whole frame. Negative numbers
    round up and positive numbers round down.

  - `:off`: Do not round. Will always raise if result would represent a non-whole-frame
    value.
  """
  @type round() :: :closest | :floor | :ceil | :trunc | :off

  @typedoc """
  Describes which side to inherit the framerate from in mixed-rate arithmatic.
  """
  @type inherit_rate_opt() :: :left | :right | false

  @typedoc """
  Type returned by `with_seconds/3` and `with_frames/3`.
  """
  @type parse_result() :: {:ok, t()} | {:error, ParseError.t() | %ArgumentError{}}

  @doc section: :parse
  @doc """
  Returns a new [Framestamp](`Vtc.Framestamp`) with a `:seconds` field value equal to the
  `seconds` arg.

  ## Arguments

  - `seconds`: A value which can be represented as a number of real-world seconds.
    Must implement the [Seconds](`Vtc.Source.Seconds`) protocol.

  - `rate`: Frame-per-second playback value of the framestamp.

  ## Options

  - `round`: How to round the result with regards to whole-frames. If set to `:off`,
    will return an error if the provided `seconds` value does not exactly represent
    a whole-number frame count. Default: `:closest`.

  ## Examples

  Accetps runtime strings...

  ```elixir
  iex> result = Framestamp.with_seconds("01:00:00.5", Rates.f23_98())
  iex> inspect(result)
  "{:ok, <00:59:56:22 <23.98 NTSC>>}"
  ```

  ... floats...

  ```elixir
  iex> result = Framestamp.with_seconds(3600.5, Rates.f23_98())
  iex> inspect(result)
  "{:ok, <00:59:56:22 <23.98 NTSC>>}"
  ```

  ... integers...

  ```elixir
  iex> result = Framestamp.with_seconds(3600, Rates.f23_98())
  iex> inspect(result)
  "{:ok, <00:59:56:10 <23.98 NTSC>>}"
  ```

  ... integer Strings...

  ```elixir
  iex> result = Framestamp.with_seconds("3600", Rates.f23_98())
  iex> inspect(result)
  "{:ok, <00:59:56:10 <23.98 NTSC>>}"
  ```

  ... and float strings.

  ```elixir
  iex> result = Framestamp.with_seconds("3600.5", Rates.f23_98())
  iex> inspect(result)
  "{:ok, <00:59:56:22 <23.98 NTSC>>}"
  ```

  ## Premiere Ticks

  The `Vtc.Source.Seconds.PremiereTicks` struck implements the
  [Seconds](`Vtc.Source.Seconds`) protocol and can be used to parse the format. This
  struct is not a general-purpose Module for the unit, and only exists to hint to the
  parsing function how it should be processed:

  ```elixir
  iex> alias Vtc.Source.Seconds.PremiereTicks
  iex>
  iex> input = %PremiereTicks{in: 254_016_000_000}
  iex>
  iex> result = Framestamp.with_seconds!(input, Rates.f23_98())
  iex> inspect(result)
  "<00:00:01:00 <23.98 NTSC>>"
  ```
  """
  @spec with_seconds(
          Seconds.t(),
          Framerate.t(),
          opts :: [round: round() | :off]
        ) :: parse_result()
  def with_seconds(seconds, rate, opts \\ []) do
    round = Keyword.get(opts, :round, :closest)

    with {:ok, seconds} <- Seconds.seconds(seconds, rate),
         :ok <- validate_whole_frames(seconds, rate, round) do
      seconds = with_seconds_round_to_frame(seconds, rate, round)
      {:ok, %__MODULE__{seconds: seconds, rate: rate}}
    end
  end

  # Rounds seconds value to the nearest whole-frame.
  @spec with_seconds_round_to_frame(Ratio.t(), Framerate.t(), round() | :off) :: Ratio.t()
  defp with_seconds_round_to_frame(seconds, _, :off), do: seconds

  defp with_seconds_round_to_frame(seconds, rate, round) do
    rate.playback
    |> Ratio.mult(seconds)
    |> Rational.round(round)
    |> Ratio.new()
    |> Ratio.div(rate.playback)
  end

  # Validates that seconds is cleanly divisible by `rate.playback`.
  @spec validate_whole_frames(Ratio.t(), Framerate.t(), :off | round()) :: :ok | {:error, ParseError.t()}
  defp validate_whole_frames(seconds, rate, :off) do
    remainder = seconds |> Ratio.mult(rate.playback) |> Rational.rem(Ratio.new(1))

    if Ratio.eq?(remainder, Ratio.new(0)) do
      :ok
    else
      {:error, %ParseError{reason: :partial_frame}}
    end
  end

  defp validate_whole_frames(_, _, _), do: :ok

  @doc section: :parse
  @doc """
  As `with_seconds/3`, but raises on error.
  """
  @spec with_seconds!(
          Seconds.t(),
          Framerate.t(),
          opts :: [round: round() | :off]
        ) :: t()
  def with_seconds!(seconds, rate, opts \\ []) do
    seconds
    |> with_seconds(rate, opts)
    |> handle_raise_function()
  end

  @doc section: :parse
  @doc """
  Returns a new [Framestamp](`Vtc.Framestamp`) with a `frames/2` return value equal to the
  `frames` arg.

  ## Arguments

  - `frames`: A value which can be represented as a frame number / frame count. Must
    implement the [Frames](`Vtc.Source.Frames`) protocol.

  - `rate`: Frame-per-second playback value of the framestamp.

  ## Options

  - `round`: How to round the result with regards to whole-frames. Default: `:closest`.

  ## Examples

  Accepts SMPTE timecode strings...

  ```elixir
  iex> result = Framestamp.with_frames("01:00:00:00", Rates.f23_98())
  iex> inspect(result)
  "{:ok, <01:00:00:00 <23.98 NTSC>>}"
  ```

  ... feet+frames strings...

  ```elixir
  iex> result = Framestamp.with_frames("5400+00", Rates.f23_98())
  iex> inspect(result)
  "{:ok, <01:00:00:00 <23.98 NTSC>>}"
  ```

  By default, feet+frames is interpreted as 35mm, 4perf film. You can use the
  [FeetAndFrames](`Vtc.Source.Frames.FeetAndFrames`) struct to parse other film formats:

  ```elixir
  iex> alias Vtc.Source.Frames.FeetAndFrames
  iex>
  iex> {:ok, feet_and_frames} = FeetAndFrames.from_string("5400+00", film_format: :ff16mm)
  iex>
  iex> result = Framestamp.with_frames(feet_and_frames, Rates.f23_98())
  iex> inspect(result)
  "{:ok, <01:15:00:00 <23.98 NTSC>>}"
  ```

  ... integers...

  ```elixir
  iex> result = Framestamp.with_frames(86_400, Rates.f23_98())
  iex> inspect(result)
  "{:ok, <01:00:00:00 <23.98 NTSC>>}"
  ```

  ... and integer strings.

  ```elixir
  iex> result = Framestamp.with_frames("86400", Rates.f23_98())
  iex> inspect(result)
  "{:ok, <01:00:00:00 <23.98 NTSC>>}"
  ```
  """
  @spec with_frames(Frames.t(), Framerate.t()) :: parse_result()
  def with_frames(frames, rate) do
    with {:ok, frames} <- Frames.frames(frames, rate),
         :ok <- validate_drop_frame_number(frames, rate) do
      frames
      |> Ratio.new()
      |> Ratio.div(rate.playback)
      |> with_seconds(rate, round: :off)
    end
  end

  @doc section: :parse
  @doc """
  As `Framestamp.with_frames/3`, but raises on error.
  """
  @spec with_frames!(Frames.t(), Framerate.t()) :: t()
  def with_frames!(frames, rate) do
    frames
    |> with_frames(rate)
    |> handle_raise_function()
  end

  @spec validate_drop_frame_number(integer(), Framerate.t()) :: :ok | {:error, ParseError.t()}
  defp validate_drop_frame_number(frames, %{ntsc: :drop} = rate) do
    if Kernel.abs(frames) > DropFrame.max_frames(rate) do
      {:error, %ParseError{reason: :drop_frame_maximum_exceeded}}
    else
      :ok
    end
  end

  defp validate_drop_frame_number(_, _), do: :ok

  @doc section: :manipulate
  @doc """
  Rebases `framestamp` to a new framerate.

  The real-world seconds are recalculated using the same frame count as if they were
  being played back at `new_rate` instead of `framestamp.rate`.

  ## Examples

  ```elixir
  iex> framestamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex> {:ok, rebased} = Framestamp.rebase(framestamp, Rates.f47_95())
  iex> inspect(rebased)
  "<00:30:00:00 <47.95 NTSC>>"
  ```
  """
  @spec rebase(t(), Framerate.t()) :: parse_result()
  def rebase(%{rate: rate} = framestamp, rate), do: {:ok, framestamp}
  def rebase(framestamp, new_rate), do: framestamp |> frames() |> with_frames(new_rate)

  @doc section: :manipulate
  @doc """
  As `rebase/2`, but raises on error.
  """
  @spec rebase!(t(), Framerate.t()) :: t()
  def rebase!(framestamp, new_rate), do: framestamp |> rebase(new_rate) |> handle_raise_function()

  @doc section: :compare
  @doc """
  Comapare the values of `a` and `b`.

  Compatible with `Enum.sort/2`. For more on sorting non-builtin values, see
  [the Elixir ducumentation](https://hexdocs.pm/elixir/1.13/Enum.html#sort/2-sorting-structs).

  [auto-casts](#module-artithmatic-autocasting) [Frames](`Vtc.Source.Frames`) values.
  See `eq?/2` for more information on how equality is determined.

  ## Examples

  Using two framestamps parsed from SMPTE timecode, `01:00:00:00` NTSC is greater than
  `01:00:00:00` true because it represents more real-world time.

  ```elixir
  iex> a = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex> b = Framestamp.with_frames!("01:00:00:00", Rates.f24())
  iex> :gt = Framestamp.compare(a, b)
  ```

  Using a framestamp and a bare string:

  ```elixir
  iex> framestamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex> :eq = Framestamp.compare(framestamp, "01:00:00:00")
  ```
  """
  @spec compare(a :: t() | Frames.t(), b :: t() | Frames.t()) :: :lt | :eq | :gt
  def compare(a, b) do
    {a, b} = cast_op_args(a, b)
    Ratio.compare(a.seconds, b.seconds)
  end

  @doc section: :compare
  @doc """
  Returns `true` if `a` is eqaul to `b`.

  [auto-casts](#module-artithmatic-autocasting) [Frames](`Vtc.Source.Frames`) values.

  ## Examples

  ```elixir
  iex> a = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex> b = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex> true = Framestamp.eq?(a, b)
  ```

  Framestamps with the *same* string timecofe representation, but *different* real-world
  seconds values, are *not* equal:

  ```elixir
  iex> a = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex> b = Framestamp.with_frames!("01:00:00:00", Rates.f24())
  iex> false = Framestamp.eq?(a, b)
  ```

  But Framestamps with the *different* SMPTE timecode string representation, but the
  *same* real-world seconds values, *are* equal:

  ```elixir
  iex> a = Framestamp.with_frames!("01:00:00:12", Rates.f23_98())
  iex> b = Framestamp.with_frames!("01:00:00:24", Rates.f47_95())
  iex> true = Framestamp.eq?(a, b)
  ```
  """
  @spec eq?(a :: t() | Frames.t(), b :: t() | Frames.t()) :: boolean()
  def eq?(a, b), do: compare(a, b) == :eq

  @doc section: :compare
  @doc """
  Returns `true` if `a` is less than `b`.

  [auto-casts](#module-artithmatic-autocasting) [Frames](`Vtc.Source.Frames`) values.
  See `eq?/2` for more information on how equality is determined.

  ## Examples

  ```elixir
  iex> a = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex> b = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())
  iex> true = Framestamp.lt?(a, b)
  iex> false = Framestamp.lt?(b, a)
  ```
  """
  @spec lt?(a :: t() | Frames.t(), b :: t() | Frames.t()) :: boolean()
  def lt?(a, b), do: compare(a, b) == :lt

  @doc section: :compare
  @doc """
  Returns `true` if `a` is less than or equal to `b`.

  [auto-casts](#module-artithmatic-autocasting) [Frames](`Vtc.Source.Frames`) values.
  See `eq?/2` for more information on how equality is determined.
  """
  @spec lte?(a :: t() | Frames.t(), b :: t() | Frames.t()) :: boolean()
  def lte?(a, b), do: compare(a, b) in [:lt, :eq]

  @doc section: :compare
  @doc """
  Returns `true` if `a` is greater than `b`.

  [auto-casts](#module-artithmatic-autocasting) [Frames](`Vtc.Source.Frames`) values.
  See `eq?/2` for more information on how equality is determined.
  """
  @spec gt?(a :: t() | Frames.t(), b :: t() | Frames.t()) :: boolean()
  def gt?(a, b), do: compare(a, b) == :gt

  @doc section: :compare
  @doc """
  Returns `true` if `a` is greater than or eqaul to `b`.

  [auto-casts](#module-artithmatic-autocasting) [Frames](`Vtc.Source.Frames`) values.
  See `eq?/2` for more information on how equality is determined.
  """
  @spec gte?(a :: t() | Frames.t(), b :: t() | Frames.t()) :: boolean()
  def gte?(a, b), do: compare(a, b) in [:gt, :eq]

  @doc section: :arithmetic
  @doc """
  Add two framestamps.

  Uses the real-world seconds representation. When the rates of `a` and `b` are not
  equal, the result will inherit the framerate of `a` and be rounded to the seconds
  representation of the nearest whole-frame at that rate.

  [auto-casts](#module-artithmatic-autocasting) [Frames](`Vtc.Source.Frames`) values.

  ## Options

  - `inherit_rate`: Which side to inherit the framerate from in mixed-rate calculations.
    If `false`, this function will raise if `a.rate` does not match `b.rate`.
    Default: `false`.

  - `round`: How to round the result with respect to whole-frames when mixing
    framerates. Default: `:closest`.

  ## Examples

  Two framestamps running at the same rate:

  ```elixir
  iex> a = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex> b = Framestamp.with_frames!("01:30:21:17", Rates.f23_98())
  iex>
  iex> result = Framestamp.add(a, b)
  iex> inspect(result)
  "<02:30:21:17 <23.98 NTSC>>"
  ```

  Two framestamps running at different rates:

  iex> a = Framestamp.with_frames!("01:00:00:02", Rates.f23_98())
  iex> b = Framestamp.with_frames!("00:00:00:02", Rates.f47_95())
  iex>
  iex> result = Framestamp.add(a, b, inherit_rate: :left)
  iex> inspect(result)
  "<01:00:00:03 <23.98 NTSC>>"
  iex>
  iex> result = Framestamp.add(a, b, inherit_rate: :right)
  iex> inspect(result)
  "<01:00:00:06 <47.95 NTSC>>"

  If `:inherit_rate` is not set...

  ```elixir
  iex> a = Framestamp.with_frames!("01:00:00:02", Rates.f23_98())
  iex> b = Framestamp.with_frames!("00:00:00:02", Rates.f47_95())
  iex> Framestamp.add(a, b)
  ** (Vtc.Framestamp.MixedRateArithmaticError) attempted `Framestamp.add(a, b)` where `a.rate` does not match `b.rate`. try `:inherit_rate` option to `:left` or `:right`. alternatively, do your calculation in seconds, then cast back to `Framestamp` with the appropriate rate
  ```

  Using a framestamps and a bare string:

  ```elixir
  iex> a = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex>
  iex> result = Framestamp.add(a, "01:30:21:17")
  iex> inspect(result)
  "<02:30:21:17 <23.98 NTSC>>"
  ```
  """
  @spec add(
          a :: t() | Frames.t(),
          b :: t() | Frames.t(),
          opts :: [inherit_rate: inherit_rate_opt(), round: round()]
        ) :: t()
  def add(a, b, opts \\ []), do: do_arithmatic(a, b, :add, opts, &Ratio.add(&1, &2))

  @doc section: :arithmetic
  @doc """
  Subtract `b` from `a`.

  Uses their real-world seconds representation. When the rates of `a` and `b` are not
  equal, the result will inherit the framerate of `a` and be rounded to the seconds
  representation of the nearest whole-frame at that rate.

  [auto-casts](#module-artithmatic-autocasting) [Frames](`Vtc.Source.Frames`) values.

  ## Options

  - `inherit_rate`: Which side to inherit the framerate from in mixed-rate calculations.
    If `false`, this function will raise if `a.rate` does not match `b.rate`.
    Default: `false`.

  - `round`: How to round the result with respect to whole-frames when mixing
    framerates. Default: `:closest`.

  ## Examples

  Two framestamps running at the same rate:

  ```elixir
  iex> a = Framestamp.with_frames!("01:30:21:17", Rates.f23_98())
  iex> b = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex>
  iex> result = Framestamp.sub(a, b)
  iex> inspect(result)
  "<00:30:21:17 <23.98 NTSC>>"
  ```

  When `b` is greater than `a`, the result is negative:

  ```elixir
  iex> a = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex> b = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())
  iex>
  iex> result = Framestamp.sub(a, b)
  iex> inspect(result)
  "<-01:00:00:00 <23.98 NTSC>>"
  ```

  Two framestamps running at different rates:

  ```elixir
  iex> a = Framestamp.with_frames!("01:00:00:02", Rates.f23_98())
  iex> b = Framestamp.with_frames!("00:00:00:02", Rates.f47_95())
  iex>
  iex> result = Framestamp.sub(a, b, inherit_rate: :left)
  iex> inspect(result)
  "<01:00:00:01 <23.98 NTSC>>"
  iex>
  iex> result = Framestamp.sub(a, b, inherit_rate: :right)
  iex> inspect(result)
  "<01:00:00:02 <47.95 NTSC>>"
  ```

  If `:inherit_rate` is not set...

  ```elixir
  iex> a = Framestamp.with_frames!("01:00:00:02", Rates.f23_98())
  iex> b = Framestamp.with_frames!("00:00:00:02", Rates.f47_95())
  iex> Framestamp.sub(a, b)
  ** (Vtc.Framestamp.MixedRateArithmaticError) attempted `Framestamp.sub(a, b)` where `a.rate` does not match `b.rate`. try `:inherit_rate` option to `:left` or `:right`. alternatively, do your calculation in seconds, then cast back to `Framestamp` with the appropriate rate
  ```

  Using a framestamps and a bare string:

  ```elixir
  iex> a = Framestamp.with_frames!("01:30:21:17", Rates.f23_98())
  iex>
  iex> result = Framestamp.sub(a, "01:00:00:00")
  iex> inspect(result)
  "<00:30:21:17 <23.98 NTSC>>"
  ```
  """
  @spec sub(
          a :: t() | Frames.t(),
          b :: t() | Frames.t(),
          opts :: [inherit_rate: inherit_rate_opt(), round: round()]
        ) :: t()
  def sub(a, b, opts \\ []), do: do_arithmatic(a, b, :sub, opts, &Ratio.sub(&1, &2))

  # Runs a (Framestamp, Framestamp) arithamtic operation.
  @spec do_arithmatic(
          a :: t() | Frames.t(),
          b :: t() | Frames.t(),
          func_name :: :add | :sub,
          opts :: [inherit_rate: inherit_rate_opt(), round: round()],
          (Ratio.t(), Ratio.t() -> Ratio.t())
        ) :: t()
  defp do_arithmatic(a, b, func_name, opts, seconds_operation) do
    inherit_rate = Keyword.get(opts, :inherit_rate, false)

    case do_arithmatic_validate_rates(a, b, inherit_rate, func_name) do
      :ok ->
        {a, b} = cast_op_args(a, b)
        new_rate = if inherit_rate == :left, do: a.rate, else: b.rate

        a.seconds
        |> seconds_operation.(b.seconds)
        |> with_seconds!(new_rate, opts)

      {:error, error} ->
        raise error
    end
  end

  @spec do_arithmatic_validate_rates(t() | Frames.t(), t() | Frames.t(), inherit_rate_opt(), :add | :sub) ::
          :ok | {:error, MixedRateArithmaticError.t()}
  defp do_arithmatic_validate_rates(%Framestamp{rate: rate}, %Framestamp{rate: rate}, _, _), do: :ok
  defp do_arithmatic_validate_rates(_, _, :left, _), do: :ok
  defp do_arithmatic_validate_rates(_, _, :right, _), do: :ok
  defp do_arithmatic_validate_rates(_, b, _, _) when not is_struct(b, Framestamp), do: :ok
  defp do_arithmatic_validate_rates(a, _, _, _) when not is_struct(a, Framestamp), do: :ok

  defp do_arithmatic_validate_rates(a, b, _, func_name),
    do: {:error, %MixedRateArithmaticError{func_name: func_name, left_rate: a.rate, right_rate: b.rate}}

  # Casts args for ops with two values as long as at least one argument is a
  # `Framestamp`. The non-`Framestamp` argument inherents the `Framerate` of the
  # `Framestamp` argument.
  @spec cast_op_args(t() | Frames.t(), t() | Frames.t()) :: {t(), t()}
  defp cast_op_args(%__MODULE__{} = a, %__MODULE__{} = b), do: {a, b}
  defp cast_op_args(%__MODULE__{} = a, b), do: {a, with_frames!(b, a.rate)}
  defp cast_op_args(a, %__MODULE__{} = b), do: {with_frames!(a, b.rate), b}

  @doc section: :arithmetic
  @doc """
  Scales `a` by `b`.

  The result will inherit the framerate of `a` and be rounded to the seconds
  representation of the nearest whole-frame based on the `:round` option.

  ## Options

  - `round`: How to round the result with respect to whole-frame values. Defaults to
    `:closest`.

  ## Examples

  ```elixir
  iex> a = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex>
  iex> result = Framestamp.mult(a, 2)
  iex> inspect(result)
  "<02:00:00:00 <23.98 NTSC>>"

  iex> a = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex>
  iex> result = Framestamp.mult(a, 0.5)
  iex> inspect(result)
  "<00:30:00:00 <23.98 NTSC>>"
  ```
  """
  @spec mult(
          a :: t(),
          b :: Ratio.t() | number(),
          opts :: [round: round()]
        ) :: t()
  def mult(a, b, opts \\ []), do: a.seconds |> Ratio.mult(Ratio.new(b)) |> with_seconds!(a.rate, opts)

  @doc section: :arithmetic
  @doc """
  Divides `dividend` by `divisor`.

  The result will inherit the framerate of `dividend` and rounded to the nearest
  whole-frame based on the `:round` option.

  ## Options

  - `round`: How to round the result with respect to whole-frame values. Defaults to
    `:trunc` to match `divmod` and the expected meaning of `div` to mean integer
    division in elixir.

  ## Examples

  ```elixir
  iex> dividend = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex>
  iex> result = Framestamp.div(dividend, 2)
  iex> inspect(result)
  "<00:30:00:00 <23.98 NTSC>>"

  iex> dividend = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex>
  iex> result = Framestamp.div(dividend, 0.5)
  iex> inspect(result)
  "<02:00:00:00 <23.98 NTSC>>"
  ```
  """
  @spec div(
          dividend :: t(),
          divisor :: Ratio.t() | number(),
          opts :: [round: round()]
        ) :: t()
  def div(dividend, divisor, opts \\ []) do
    opts = Keyword.put_new(opts, :round, :trunc)
    dividend.seconds |> Ratio.div(Ratio.new(divisor)) |> with_seconds!(dividend.rate, opts)
  end

  @doc section: :arithmetic
  @doc """
  Divides the total frame count of `dividend` by `divisor` and returns both a quotient
  and a remainder.

  The quotient returned is equivalent to `Framestamp.div/3` with the `:round` option set
  to `:trunc`.

  ## Options

  - `round_frames`: How to round the frame count before doing the divrem operation.
    Default: `:closest`.

  - `round_remainder`: How to round the remainder frames when a non-whole frame would
    be the result. Default: `:closest`.

  ## Examples

  ```elixir
  iex> dividend = Framestamp.with_frames!("01:00:00:01", Rates.f23_98())
  iex>
  iex> result = Framestamp.divrem(dividend, 4)
  iex> inspect(result)
  "{<00:15:00:00 <23.98 NTSC>>, <00:00:00:01 <23.98 NTSC>>}"
  ```
  """
  @spec divrem(
          dividend :: t(),
          divisor :: Ratio.t() | number(),
          opts :: [round_frames: round(), round_remainder: round()]
        ) :: {t(), t()}
  def divrem(dividend, divisor, opts \\ []) do
    with {round_frames, round_remainder} <- validate_divrem_rounding(opts) do
      %{rate: rate} = dividend

      {quotient, remainder} =
        dividend
        |> frames(round: round_frames)
        |> Ratio.new()
        |> Rational.divrem(Ratio.new(divisor))

      remainder = Rational.round(remainder, round_remainder)

      {with_frames!(quotient, rate), with_frames!(remainder, rate)}
    end
  end

  @doc section: :arithmetic
  @doc """
  Devides the total frame count of `dividend` by `devisor`, and returns the remainder.

  The quotient is truncated before the remainder is calculated.

  ## Options

  - `round_frames`: How to round the frame count before doing the rem operation.
    Default: `:closest`.

  - `round_remainder`: How to round the remainder frames when a non-whole frame would
    be the result. Default: `:closest`.

  ## Examples

  ```elixir
  iex> dividend = Framestamp.with_frames!("01:00:00:01", Rates.f23_98())
  iex>
  iex> result = Framestamp.rem(dividend, 4)
  iex> inspect(result)
  "<00:00:00:01 <23.98 NTSC>>"
  ```
  """
  @spec rem(
          dividend :: t(),
          divisor :: Ratio.t() | number(),
          opts :: [round_frames: round(), round_remainder: round()]
        ) :: t()
  def rem(dividend, divisor, opts \\ []) do
    with {round_frames, round_remainder} <- validate_divrem_rounding(opts) do
      %{rate: rate} = dividend

      dividend
      |> frames(round: round_frames)
      |> Ratio.new()
      |> Rational.rem(Ratio.new(divisor))
      |> Rational.round(round_remainder)
      |> with_frames!(rate)
    end
  end

  # Validates the rounding options for `divrem` and `rem`.
  @spec validate_divrem_rounding(round_frames: round(), round_remainder: round()) :: {round(), round()}
  defp validate_divrem_rounding(opts) do
    with :ok <- ensure_round_enabled(opts, :round_frames),
         :ok <- ensure_round_enabled(opts, :round_remainder) do
      round_frames = Keyword.get(opts, :round_frames, :closest)
      round_remainder = Keyword.get(opts, :round_remainder, :closest)
      {round_frames, round_remainder}
    end
  end

  @doc section: :arithmetic
  @doc """
  As the kernel `-/1` function.

  - Makes a positive `tc` value negative.
  - Makes a negative `tc` value positive.

  ## Examples

  ```elixir
  iex> stamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex>
  iex> result = Framestamp.minus(stamp)
  iex> inspect(result)
  "<-01:00:00:00 <23.98 NTSC>>"
  ```

  ```elixir
  iex> stamp = Framestamp.with_frames!("-01:00:00:00", Rates.f23_98())
  iex>
  iex> result = Framestamp.minus(stamp)
  iex> inspect(result)
  "<01:00:00:00 <23.98 NTSC>>"
  ```
  """
  @spec minus(t()) :: t()
  def minus(framestamp), do: %{framestamp | seconds: Ratio.minus(framestamp.seconds)}

  @doc section: :arithmetic
  @doc """
  Returns the absolute value of `tc`.

  ## Examples

  ```elixir
  iex> stamp = Framestamp.with_frames!("-01:00:00:00", Rates.f23_98())
  iex>
  iex> result = Framestamp.abs(stamp)
  iex> inspect(result)
  "<01:00:00:00 <23.98 NTSC>>"
  ```

  ```elixir
  iex> stamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex>
  iex> result = Framestamp.abs(stamp)
  iex> inspect(result)
  "<01:00:00:00 <23.98 NTSC>>"
  ```
  """
  @spec abs(t()) :: t()
  def abs(framestamp), do: %{framestamp | seconds: Ratio.abs(framestamp.seconds)}

  @doc section: :arithmetic
  @doc """
  Evalutes [Framestamp](`Vtc.Framestamp`) mathematical expressions in a `do` block.

  Any code captured within this macro can use Kernel operators to work with
  [Framestamp](`Vtc.Framestamp`) values instead of module functions like `add/2`.

  ## Options

  - `at`: The Framerate to cast non-[Framestamp](`Vtc.Framestamp`) values to. If this
    value is not set, then at least one value in each operation must be a
    [Framestamp](`Vtc.Framestamp`). This value can be any value accepted by
    [Framerate.new/2](`Vtc.Framerate.new/2`).

  - `ntsc`: The `ntsc` value to use when creating a new Framerate with `at`. Not needed
    if `at` is a [Framerate](`Vtc.Framerate`) value.

  ## Examples

  Use eval to do some quick math. The block captures variables from the outer scope,
  but contains the expression within its own scope, just like an `if` or `with`
  statement.

  ```elixir
  iex> require Framestamp
  iex>
  iex> a = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex> b = Framestamp.with_frames!("00:30:00:00", Rates.f23_98())
  iex> c = Framestamp.with_frames!("00:15:00:00", Rates.f23_98())
  iex>
  iex> result =
  iex>   Framestamp.eval do
  iex>     a + b * 2 - c
  iex>   end
  iex>
  iex> inspect(result)
  "<01:45:00:00 <23.98 NTSC>>"
  ```

  Or if you want to do it in one line:

  ```elixir
  iex> require Framestamp
  iex>
  iex> a = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex> b = Framestamp.with_frames!("00:30:00:00", Rates.f23_98())
  iex> c = Framestamp.with_frames!("00:15:00:00", Rates.f23_98())
  iex>
  iex> result = Framestamp.eval(a + b * 2 - c)
  iex>
  iex> inspect(result)
  "<01:45:00:00 <23.98 NTSC>>"
  ```

  Just like the regular [Framestamp](`Vtc.Framestamp`) functions, only one value in an
  arithmetic expression needs to be a [Framestamp](`Vtc.Framestamp`) value. In the case
  above, since multiplication happens first, that's `b`:

  ```elixir
  iex> b = Framestamp.with_frames!("00:30:00:00", Rates.f23_98())
  iex>
  iex> result =
  iex>   Framestamp.eval do
  iex>     "01:00:00:00" + b * 2 - "00:15:00:00"
  iex>   end
  iex>
  iex> inspect(result)
  "<01:45:00:00 <23.98 NTSC>>"
  ```

  You can supply a default framerate if you just want to do some quick calculations.
  This framerate is inherited by every value that implements the
  [Frames](`Vtc.Source.Frames`) protocol in the block, including integers:

  ```elixir
  iex> result =
  iex>   Framestamp.eval at: Rates.f23_98() do
  iex>     "01:00:00:00" + "00:30:00:00" * 2 - "00:15:00:00"
  iex>   end
  iex>
  iex> inspect(result)
  "<01:45:00:00 <23.98 NTSC>>"
  ```

  You can use any value that can be parsed by `Framerate.new/2`.

  ```elixir
  iex> result =
  iex>   Framestamp.eval at: 23.98 do
  iex>     "01:00:00:00" + "00:30:00:00" * 2 - "00:15:00:00"
  iex>   end
  iex>
  iex> inspect(result)
  "<01:45:00:00 <23.98 NTSC>>"
  ```

  `ntsc: :non_drop, coerce_ntsc?: true` is assumed by default, but you can set a
  different value with the `:ntsc` option:

  ```elixir
  iex> result =
  iex>   Framestamp.eval at: 24, ntsc: nil do
  iex>     "01:00:00:00" + "00:30:00:00" * 2 - "00:15:00:00"
  iex>   end
  iex>
  iex> inspect(result)
  "<01:45:00:00 <24.0 fps>>"
  ```
  """
  @spec eval([at: Framerate.t() | number() | Ratio.t(), ntsc: Framerate.ntsc()], Macro.input()) :: Macro.t()
  defmacro eval(opts \\ [], body), do: Eval.eval(opts, body)

  @doc section: :convert
  @doc """
  Returns the number of frames that would have elapsed between `00:00:00:00` and
  [Framestamp](`Vtc.Framestamp`).

  ## Options

  - `round`: How to round the resulting frame number.

  ## What it is

  Frame number / frames count is the number of a frame if the SMPTE timecode started at
  00:00:00:00 and had been running until the current value. A SMPTE timecode of
  '00:00:00:10' has a frame number of 10. A SMPTE timecode of '01:00:00:00' has a frame
  number of 86400.

  ## Where you see it

  - Frame-sequence files: 'my_vfx_shot.0086400.exr'
  - FCP7XML cut lists:

      ```xml
      <timecode>
          <rate>
              <timebase>24</timebase>
              <ntsc>TRUE</ntsc>
          </rate>
          <string>01:00:00:00</string>
          <frame>86400</frame>  <!-- <====THIS LINE-->
          <displayformat>NDF</displayformat>
      </timecode>
      ```

  ## Examples

  ```elixir
  iex> framestamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex> Framestamp.frames(framestamp)
  86400
  ```
  """
  @spec frames(t(), opts :: [round: round()]) :: integer()
  def frames(framestamp, opts \\ []) do
    round = Keyword.get(opts, :round, :closest)

    framestamp.seconds
    |> Ratio.mult(framestamp.rate.playback)
    |> Rational.round(round)
  end

  @doc section: :convert
  @doc """
  The individual sections of a SMPTE timecode string as i64 values.

  ## Examples

  ```elixir
  iex> framestamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex>
  iex> result = Framestamp.smpte_timecode_sections(framestamp)
  iex> inspect(result)
  "%Vtc.SMPTETimecode.Sections{negative?: false, hours: 1, minutes: 0, seconds: 0, frames: 0}"
  ```
  """
  @spec smpte_timecode_sections(t(), opts :: [round: round()]) :: Sections.t()
  def smpte_timecode_sections(framestamp, opts \\ []), do: Sections.from_framestamp(framestamp, opts)

  @doc section: :convert
  @doc """
  Returns the the formatted SMPTE timecode for a [Framestamp](`Vtc.Framestamp`).

  Ex: `01:00:00:00`. Drop frame timecode will be rendered with a ';' sperator before the
  frames field.

  ## Options

  - `round`: How to round the resulting frames field.

  ## What it is

  Timecode is used as a human-readable way to represent the id of a given frame. It is
  formatted to give a rough sense of where to find a frame:
  `{HOURS}:{MINUTES}:{SECONDS}:{FRAME}`. For more on timecode, see Frame.io's
  [excellent post](https://blog.frame.io/2017/07/17/timecode-and-frame-rates/) on the
  subject.

  ## Where you see it

  Timecode is ubiquitous in video editing, a small sample of places you might see
  timecode:

  - Source and Playback monitors in your favorite NLE.
  - Burned into the footage for dailies.
  - Cut lists like an EDL.

  ## Examples

  ```elixir
  iex> framestamp = Framestamp.with_frames!(86_400, Rates.f23_98())
  iex> Framestamp.smpte_timecode(framestamp)
  "01:00:00:00"
  ```
  """
  @spec smpte_timecode(t(), opts :: [round: round()]) :: String.t()
  def smpte_timecode(framestamp, opts \\ []), do: framestamp |> SMPTETimecodeStr.from_framestamp(opts) |> then(& &1.in)

  @doc section: :convert
  @doc """
  Runtime Returns the true, real-world runtime of `framestamp` in `HH:MM:SS.FFFFFFFFF`
  format.

  Trailing zeroes are trimmed from the end of the return value. If the entire fractal
  seconds value would be trimmed, '.0' is used.

  ## Options

  - `precision`: The number of places to round to. Extra trailing 0's will still be
    trimmed. Default: `9`.

  - `trim_zeros?`: Whether to trim trailing zeroes. Default: `true`.

  ## What it is

  The human-readable version of `seconds`. It looks like timecode, but with a decimal
  seconds value instead of a frame number place.

  ## Where you see it

  • Anywhere real-world time is used.

  • FFMPEG commands:

    ```shell
    ffmpeg -ss 00:00:30.5 -i input.mov -t 00:00:10.25 output.mp4
    ```

  ## Note

  The true runtime will often diverge from the hours, minutes, and seconds
  value of the SMPTE timecode representation when dealing with non-whole-frame
  framerates. Even drop-frame timecode does not continuously adhere 1:1 to the
  actual runtime. For instance, <01:00:00;00 <29.97 NTSC DF>> has a true runtime of
  '00:59:59.9964', and <01:00:00:00 <23.98 NTSC>> has a true runtime of
  '01:00:03.6'

  ## Examples

  ```elixir
  iex> framestamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex> Framestamp.runtime(framestamp)
  "01:00:03.6"
  ```
  """
  @spec runtime(t(), precision: non_neg_integer(), trim_zeros?: boolean()) :: String.t()
  def runtime(framestamp, opts \\ []), do: framestamp |> RuntimeStr.from_framestamp(opts) |> then(& &1.in)

  @doc section: :convert
  @doc """
  Returns the number of elapsed ticks `framestamp` represents in Adobe Premiere Pro.

  ## Options

  - `round`: How to round the resulting ticks.

  ## What it is

  Internally, Adobe Premiere Pro uses ticks to divide up a second, and keep track of how
  far into that second we are. There are 254016000000 ticks in a second, regardless of
  framerate in Premiere.

  ## Where you see it

  - Premiere Pro Panel functions and scripts.

  - FCP7XML cutlists generated from Premiere:

    ```xml
    <clipitem id="clipitem-1">
    ...
    <in>158</in>
    <out>1102</out>
    <pproTicksIn>1673944272000</pproTicksIn>
    <pproTicksOut>11675231568000</pproTicksOut>
    ...
    </clipitem>
    ```

  ## Examples

  ```elixir
  iex> framestamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex> Framestamp.premiere_ticks(framestamp)
  915372057600000
  ```
  """
  @spec premiere_ticks(t(), opts :: [round: round()]) :: integer()
  def premiere_ticks(framestamp, opts \\ []) do
    with :ok <- ensure_round_enabled(opts) do
      framestamp |> PremiereTicks.from_framestamp(opts) |> then(& &1.in)
    end
  end

  @doc section: :convert
  @doc """
  Returns the number of physical film feet and frames `framestamp` represents if shot
  on film.

  Ex: '5400+13'.

  ## Options

  - `round`: How to round the internal frame count before conversion. Default: `:closest`.

  - `fiim_format`: The film format to use when doing the calculation. For more on film
    formats, see `Vtc.FilmFormat`. Default: `:ff35mm_4perf`, by far the most common
    format used to shoot Hollywood movies.

  ## What it is

  On physical film, each foot contains a certain number of frames. For 35mm, 4-perf film
  (the most common type on Hollywood movies), this number is 16 frames per foot.
  Feet-And-Frames was often used in place of Keycode to quickly reference a frame in the
  edit.

  ## Where you see it

  For the most part, feet + frames has died out as a reference, because digital media is
  not measured in feet. The most common place it is still used is Studio Sound
  Departments. Many Sound Mixers and Designers intuitively think in feet + frames, and
  it is often burned into the reference picture for them.

  - Telecine.
  - Sound turnover reference picture.
  - Sound turnover change lists.

  For more information on individual film formats, see the `Vtc.FilmFormat` module.

  ## Examples

  Defaults to 35mm, 4perf:

  ```elixir
  iex> framestamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex>
  iex> result = Framestamp.feet_and_frames(framestamp)
  iex> inspect(result)
  "<5400+00 :ff35mm_4perf>"
  ```

  Use `String.Chars` to convert the resulting struct to a traditional F=F string:

  ```elixir
  iex> alias Vtc.Source.Frames.FeetAndFrames
  iex>
  iex> framestamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex>
  iex> result = Framestamp.feet_and_frames(framestamp)
  iex> String.Chars.to_string(result)
  "5400+00"
  ```

  Outputting as a different film format:

  ## Examples

  ```elixir
  iex> framestamp = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex>
  iex> result = Framestamp.feet_and_frames(framestamp, film_format: :ff16mm)
  iex> inspect(result)
  "<4320+00 :ff16mm>"
  ```
  """
  @spec feet_and_frames(t(), opts :: [fiim_format: FilmFormat.t(), round: round()]) :: FeetAndFrames.t()
  def feet_and_frames(framestamp, opts \\ []) do
    with :ok <- ensure_round_enabled(opts) do
      FeetAndFrames.from_framestamp(framestamp, opts)
    end
  end

  # Ensures that rounding is enabled for functions that cannot meaningfully turn
  # rounding off, such as those that must return an integer.
  @spec ensure_round_enabled(Keyword.t(), atom()) :: :ok
  defp ensure_round_enabled(opts, opt \\ :round)

  defp ensure_round_enabled(opts, opt) do
    case Keyword.get(opts, opt, :closest) do
      :off -> raise(ArgumentError.exception("`:#{opt}` cannot be `:off`"))
      _ -> :ok
    end
  end

  @spec handle_raise_function({:ok, t()} | {:error, Exception.t()}) :: t()
  defp handle_raise_function({:ok, result}), do: result
  defp handle_raise_function({:error, error}), do: raise(error)

  when_pg_enabled do
    use Ecto.Type

    @impl Ecto.Type
    @spec type() :: atom()
    defdelegate type, to: PgFramestamp

    @impl Ecto.Type
    @spec cast(t() | %{String.t() => any()} | %{atom() => any()}) :: {:ok, t()} | :error
    defdelegate cast(value), to: PgFramestamp

    @impl Ecto.Type
    @spec load(PgFramestamp.db_record()) :: {:ok, t()} | :error
    defdelegate load(value), to: PgFramestamp

    @impl Ecto.Type
    @spec dump(t()) :: {:ok, PgFramestamp.db_record()} | :error
    defdelegate dump(value), to: PgFramestamp

    defdelegate validate_constraints(changeset, field, opts \\ []), to: PgFramestamp
  end
end

defimpl Inspect, for: Vtc.Framestamp do
  alias Vtc.Framestamp

  @spec inspect(Framestamp.t(), Elixir.Inspect.Opts.t()) :: String.t()
  def inspect(framestamp, _opts) do
    "<#{Framestamp.smpte_timecode(framestamp)} #{inspect(framestamp.rate)}>"
  end
end

defimpl String.Chars, for: Vtc.Framestamp do
  alias Vtc.Framestamp

  @spec to_string(Framestamp.t()) :: String.t()
  def to_string(framestamp), do: inspect(framestamp)
end
