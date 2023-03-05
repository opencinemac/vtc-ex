defmodule Vtc.Timecode do
  @moduledoc """
  Represents the frame at a particular time in a video.

  New Timecode values are created with the `with_seconds/2` and `with_frames/2`, and
  other function prefaced by `with_*`.
  """

  use Ratio, comparison: true

  alias Vtc.Framerate
  alias Vtc.Private.Consts
  alias Vtc.Private.DropFrame
  alias Vtc.Utils.Rational
  alias Vtc.Source.Frames
  alias Vtc.Source.PremiereTicks
  alias Vtc.Source.Seconds

  @enforce_keys [:seconds, :rate]
  defstruct [:seconds, :rate]

  @typedoc """
  `Timecode` type.

  # Fields

  - **:seconds**: The real-world seconds elapsed since 01:00:00:00 as a rational value.
    (Note: The Ratio module automatically will coerce itself to an integer whenever
    possible, so this value may be an integer when exactly a whole-second value).

  - **:rate**: the Framerate of the timecode.
  """
  @type t :: %__MODULE__{
          seconds: Rational.t(),
          rate: Framerate.t()
        }

  defmodule Sections do
    @moduledoc """
    Holds the individual sections of a timecode for formatting / manipulation.
    """

    @enforce_keys [:negative?, :hours, :minutes, :seconds, :frames]
    defstruct [:negative?, :hours, :minutes, :seconds, :frames]

    @typedoc """
    Holds the individual sections of a timecode for formatting / manipulation.

    ## Fields

    - **negative**: Whether the timecode is less than 0.
    - **hours**: Hours place value.
    - **minutes**: Minutes place value.
    - **seconds**: Seconds place value.
    - **frames**: Frames place value.
    """
    @type t :: %__MODULE__{
            negative?: boolean(),
            hours: integer(),
            minutes: integer(),
            seconds: integer(),
            frames: integer()
          }
  end

  @doc """
  Returns the number of frames that would have elapsed between 00:00:00:00 and this
  timecode.

  # What it is

  Frame number / frames count is the number of a frame if the timecode started at
  00:00:00:00 and had been running until the current value. A timecode of '00:00:00:10'
  has a frame number of 10. A timecode of '01:00:00:00' has a frame number of 86400.

  # Where you see it

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
  """
  @spec frames(t()) :: integer()
  def frames(%__MODULE__{} = tc), do: Rational.round(tc.seconds * tc.rate.playback)

  @doc """
  The individual sections of a timecode string as i64 values.
  """
  @spec sections(t()) :: Sections.t()
  def sections(%__MODULE__{} = timecode) do
    rate = timecode.rate
    timebase = Framerate.timebase(rate)
    frames_per_minute = timebase * Consts.seconds_per_minute()
    frames_per_hour = timebase * Consts.seconds_per_hour()

    total_frames =
      timecode
      |> frames()
      |> abs()
      |> then(&if rate.ntsc == :drop, do: DropFrame.frame_num_adjustment(&1, rate), else: &1)

    {hours, remainder} = Rational.divmod(total_frames, frames_per_hour)
    {minutes, remainder} = Rational.divmod(remainder, frames_per_minute)
    {seconds, frames} = Rational.divmod(remainder, timebase)

    %Sections{
      negative?: timecode.seconds < 0,
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      frames: Rational.round(frames)
    }
  end

  @doc """
  Returns the the formatted SMPTE timecode: (ex: 01:00:00:00). Drop frame timecode will
  be rendered with a ';' sperator before the frames field.

  # What it is

  Timecode is used as a human-readable way to represent the id of a given frame. It is formatted
  to give a rough sense of where to find a frame: {HOURS}:{MINUTES}:{SECONDS}:{FRAME}. For more on
  timecode, see Frame.io's
  [excellent post](https://blog.frame.io/2017/07/17/timecode-and-frame-rates/) on the subject.

  # Where you see it

  Timecode is ubiquitous in video editing, a small sample of places you might see timecode:

  - Source and Playback monitors in your favorite NLE.
  - Burned into the footage for dailies.
  - Cut lists like an EDL.
  """
  @spec timecode(t()) :: String.t()
  def timecode(%__MODULE__{} = tc) do
    sections = sections(tc)

    sign = if tc.seconds < 0, do: "-", else: ""
    frame_sep = if tc.rate.ntsc == :drop, do: ";", else: ":"

    [
      sections.hours,
      sections.minutes,
      sections.seconds,
      sections.frames
    ]
    |> Enum.map(&render_tc_field/1)
    |> Enum.intersperse(":")
    |> then(&[sign | &1])
    |> List.replace_at(-2, frame_sep)
    |> List.to_string()
  end

  @spec render_tc_field(integer()) :: String.t()
  defp render_tc_field(value),
    do: value |> Integer.to_string() |> String.pad_leading(2, "0")

  @doc """
  Runtime Returns the true, real-world runtime of the timecode in HH:MM:SS.FFFFFFFFF
  format.

  Arguments

  - `precision`: The number of places to round to. Extra trailing 0's will still be
    trimmed.

  # What it is

  The formatted version of seconds. It looks like timecode, but with a decimal seconds
  value instead of a frame number place.

  # Where you see it

  • Anywhere real-world time is used.

  • FFMPEG commands:

    ```shell
    ffmpeg -ss 00:00:30.5 -i input.mov -t 00:00:10.25 output.mp4
    ```

  # Note

  The true runtime will often diverge from the hours, minutes, and seconds
  value of the timecode representation when dealing with non-whole-frame
  framerates. Even drop-frame timecode does not continuously adhere 1:1 to the
  actual runtime. For instance, <01:00:00;00 @ <29.97 NTSC DF>> has a true runtime of
  '00:59:59.9964', and <01:00:00:00 @ <23.98 NTSC NDF>> has a true runtime of
  '01:00:03.6'
  """
  @spec runtime(t(), integer()) :: String.t()
  def runtime(tc, precision) do
    {seconds, negative?} = if tc.seconds < 0, do: {-tc.seconds, true}, else: {tc.seconds, false}

    seconds = Decimal.div(Ratio.numerator(seconds), Ratio.denominator(seconds))

    {hours, seconds} = Decimal.div_rem(seconds, Consts.seconds_per_hour())
    {minutes, seconds} = Decimal.div_rem(seconds, Consts.seconds_per_minute())

    Decimal.Context
    seconds = Decimal.round(seconds, precision)
    seconds_floor = Decimal.round(seconds, 0, :down)
    fractal_seconds = Decimal.sub(seconds, seconds_floor)

    hours = hours |> Decimal.to_integer() |> Integer.to_string() |> String.pad_leading(2, "0")
    minutes = minutes |> Decimal.to_integer() |> Integer.to_string() |> String.pad_leading(2, "0")

    seconds_floor =
      seconds_floor |> Decimal.to_integer() |> Integer.to_string() |> String.pad_leading(2, "0")

    fractal_seconds = runtime_render_fractal_seconds(fractal_seconds)

    # We'll add a negative sign if the timecode is negative.
    sign = if negative?, do: "-", else: ""

    "#{sign}#{hours}:#{minutes}:#{seconds_floor}#{fractal_seconds}"
  end

  # Renders fractal seconds to a string.
  @spec runtime_render_fractal_seconds(Decimal.t()) :: String.t()
  defp runtime_render_fractal_seconds(seconds_fractal) do
    rendered =
      if Decimal.eq?(seconds_fractal, 0) do
        ""
      else
        Decimal.to_string(seconds_fractal)
        |> String.trim_leading("0")
        |> String.trim_trailing("0")
        |> String.trim_trailing(".")
      end

    if rendered == "", do: ".0", else: rendered
  end

  @doc """
  Returns the number of elapsed ticks this timecode represents in Adobe Premiere Pro.

  # What it is

  Internally, Adobe Premiere Pro uses ticks to divide up a second, and keep track of how
  far into that second we are. There are 254016000000 ticks in a second, regardless of
  framerate in Premiere.

  # Where you see it

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
  """
  @spec premiere_ticks(t()) :: integer()
  def premiere_ticks(%__MODULE__{} = tc),
    do: Rational.round(tc.seconds * Consts.ppro_tick_per_second())

  @doc """
  Returns the number of feet and frames this timecode represents if it were shot on 35mm
  4-perf film (16 frames per foot). ex: '5400+13'.

  # What it is

  On physical film, each foot contains a certain number of frames. For 35mm, 4-perf film
  (the most common type on Hollywood movies), this number is 16 frames per foot.
  Feet-And-Frames was often used in place of Keycode to quickly reference a frame in the
  edit.

  # Where you see it

  For the most part, feet + frames has died out as a reference, because digital media is
  not measured in feet. The most common place it is still used is Studio Sound
  Departments. Many Sound Mixers and Designers intuitively think in feet + frames, and it
  is often burned into the reference picture for them.

  - Telecine.

  - Sound turnover reference picture.

  - Sound turnover change lists.
  """
  @spec feet_and_frames(t()) :: String.t()
  def feet_and_frames(%__MODULE__{} = tc) do
    frames = tc |> frames() |> abs()

    # We need to call these functions from the kernel or we are going to get Ratio's
    # since we are using Ratio to overload these functions.
    feet = Kernel.div(frames, Consts.frames_per_foot())
    frames = Kernel.rem(frames, Consts.frames_per_foot())

    feet = Integer.to_string(feet)
    frames = frames |> Integer.to_string() |> String.pad_leading(2, "0")

    sign = if tc.seconds < 0, do: "-", else: ""

    "#{sign}#{feet}+#{frames}"
  end

  defmodule ParseError do
    @moduledoc """
    Exception returned when there is an error parsing a Timecode value.
    """
    defexception [:reason]

    @typedoc """
    Type of `Timecode.ParseError`

    # Fields

    - `:reason`: The reason the error occurred must be one of the following:

      - `:unrecognized_format`: Returned when a string value is not a recognized
        timecode, runtime, etc. format.
    """
    @type t :: %ParseError{reason: :unrecognized_format | :bad_drop_frames}

    @doc """
    Returns a message for the error reason.
    """
    @spec message(t()) :: String.t()
    def message(%__MODULE__{reason: :unrecognized_format}),
      do: "string format not recognized"

    def message(%__MODULE__{reason: :bad_drop_frames}),
      do: "frames value not allowed for drop-frame timecode. frame should have been dropped"
  end

  @typedoc """
  Type returned by `Timecode.with_seconds/2` and `Timecode.with_frames/2`.
  """
  @type parse_result() :: {:ok, t()} | {:error, ParseError.t()}

  @doc """
  Returns a new `Timecode` with a Timecode.seconds field value equal to the
  seconds arg.

  Timecode::with_frames takes many different formats (more than just numeric types) that
  represent the frame count of the timecode.

  # Arguments

  - `seconds` - A value which can be represented as a number of seconds.
  - `rate` - The Framerate at which the frames are being played back.
  """
  @spec with_seconds(Seconds.t(), Framerate.t()) :: parse_result
  def with_seconds(seconds, rate) do
    with {:ok, seconds} <- Seconds.seconds(seconds, rate) do
      {:ok, %__MODULE__{seconds: seconds, rate: rate}}
    end
  end

  @doc """
  As `Timecode.with_seconds/2`, but raises on error.
  """
  @spec with_seconds!(Seconds.t(), Framerate.t()) :: t()
  def with_seconds!(seconds, rate) do
    seconds
    |> with_seconds(rate)
    |> handle_raise_function()
  end

  @doc """
  Returns a new `Timecode` with a `Timecode.frames/1` return value equal to the
  frames arg.

  with_frames takes many different formats (more than just numeric types) that
  represent the frame count of the timecode.

  # Arguments

  - `frames` - A value which can be represented as a frame number / frame count.
  - `rate` - The Framerate at which the frames are being played back.
  """
  @spec with_frames(Frames.t(), Framerate.t()) :: parse_result()
  def with_frames(frames, rate) do
    with {:ok, frames} <- Frames.frames(frames, rate) do
      seconds = frames / rate.playback
      with_seconds(seconds, rate)
    end
  end

  @doc """
  As `Timecode.with_frames/2`, but raises on error.
  """
  @spec with_frames!(Frames.t(), Framerate.t()) :: t()
  def with_frames!(frames, rate) do
    frames
    |> with_frames(rate)
    |> handle_raise_function()
  end

  @doc """
  Returns a new `Timecode` with a `Timecode.premiere_ticks/1` return value equal
  to the ticks arg.

  with_premiere_ticks takes many different formats (more than just numeric types) that
  can represent the tick count of the timecode.

  # Arguments

  - `frames` - A value which can be represented as a frame number / frame count.
  - `rate` - The Framerate at which the frames are being played back.
  """
  @spec with_premiere_ticks(PremiereTicks.t(), Framerate.t()) :: parse_result()
  def with_premiere_ticks(ticks, rate) do
    with {:ok, ticks} <- PremiereTicks.ticks(ticks, rate) do
      seconds = ticks / Consts.ppro_tick_per_second()
      with_seconds(seconds, rate)
    end
  end

  @doc """
  As `Timecode.with_premiere_ticks/2`, but raises on error.
  """
  @spec with_premiere_ticks!(Frames.t(), Framerate.t()) :: t()
  def with_premiere_ticks!(ticks, rate) do
    ticks
    |> with_premiere_ticks(rate)
    |> handle_raise_function()
  end

  @spec to_string(t()) :: String.t()
  def to_string(tc) do
    tc_str = timecode(tc)
    rate_str = String.Chars.to_string(tc.rate)

    "<#{tc_str} @ #{rate_str}>"
  end

  @spec handle_raise_function({:ok, t()} | {:error, Exception.t()}) :: t()
  defp handle_raise_function({:ok, result}), do: result
  defp handle_raise_function({:error, error}), do: raise(error)
end

defimpl Inspect, for: Timecode do
  alias Vtc.Timecode

  @spec inspect(Timecode.t(), Elixir.Inspect.Opts.t()) :: String.t()
  def inspect(tc, _opts), do: Timecode.to_string(tc)
end

defimpl String.Chars, for: Timecode do
  alias Vtc.Timecode

  @spec to_string(Timecode.t()) :: String.t()
  def to_string(term), do: Timecode.to_string(term)
end
