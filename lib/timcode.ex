defmodule Vtc.Timecode do
  @moduledoc """
  Represents the frame at a particular time in a video.

  New Timecode values are created with the `Vtc.Timecode.with_seconds/2` and
  `Vtc.Timecode.with_frames/2`
  """

  use Ratio, comparison: true

  @enforce_keys [:seconds, :rate]
  defstruct [:seconds, :rate]

  @typedoc """
  `Vtc.Timecode` type.

  # Fields

  - **:seconds**: The real-world seconds elapsed since 01:00:00:00 as a rational value.
    (Note: The Ratio module automatically will coerce itself to an integer whenever
    possible, so this value may be an integer when exactly a whole-second value).

  - **:rate**: the Framerate of the timecode.
  """
  @type t :: %Vtc.Timecode{seconds: Ratio.t() | integer, rate: Vtc.Framerate.t()}

  defmodule Sections do
    @moduledoc """
    Holds the individual sections of a timecode for formatting / manipulation.
    """

    @enforce_keys [:negative, :hours, :minutes, :seconds, :frames]
    defstruct [:negative, :hours, :minutes, :seconds, :frames]

    @typedoc """
    The type of Vtc.Timecode.Sections.

    # Fields

    - **negative**: Whether the timecode is less than 0.
    - **hours**: Hours place value.
    - **minutes**: Minutes place value.
    - **seconds**: Seconds place value.
    - **frames**: Frames place value.
    """
    @type t :: %Sections{
            negative: boolean,
            hours: integer,
            minutes: integer,
            seconds: integer,
            frames: integer
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
  @spec frames(Vtc.Timecode.t()) :: integer
  def frames(%Vtc.Timecode{} = tc) do
    Private.Rat.round_ratio?(tc.seconds * tc.rate.playback)
  end

  @doc """
  The individual sections of a timecode string as i64 values.
  """
  @spec sections(Vtc.Timecode.t()) :: Sections.t()
  def sections(%Vtc.Timecode{} = tc) do
    timebase = Vtc.Framerate.timebase(tc.rate)
    frames_per_minute = timebase * Private.Const.seconds_per_minute()
    frames_per_hour = timebase * Private.Const.seconds_per_hour()

    is_negative = tc.seconds < 0
    frames = abs(frames(tc))

    # adjust our frame number if this is a drop-frame framerate.
    frames =
      if tc.rate.ntsc == :Drop do
        Private.Drop.frame_num_adjustment(frames, tc.rate)
      else
        frames
      end

    {hours, frames} = Private.Rat.divmod(frames, frames_per_hour)
    {minutes, frames} = Private.Rat.divmod(frames, frames_per_minute)
    {seconds, frames} = Private.Rat.divmod(frames, timebase)
    frames = Private.Rat.round_ratio?(frames)

    %Sections{
      negative: is_negative,
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      frames: frames
    }
  end

  @doc """
  Returns the the formatted SMPTE timecode: (ex: 01:00:00:00).

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
  @spec timecode(Vtc.Timecode.t()) :: String.t()
  def timecode(%Vtc.Timecode{} = tc) do
    sections = sections(tc)

    # We'll add a negative sign if the timecode is negative.
    sign =
      if tc.seconds < 0 do
        "-"
      else
        ""
      end

    # If this is a drop-frame timecode, we need to use a ';' to separate the frames
    # 	from the seconds.
    frame_sep =
      if tc.rate.ntsc == :Drop do
        ";"
      else
        ":"
      end

    hours = sections.hours |> Integer.to_string() |> String.pad_leading(2, "0")
    minutes = sections.minutes |> Integer.to_string() |> String.pad_leading(2, "0")
    seconds = sections.seconds |> Integer.to_string() |> String.pad_leading(2, "0")
    frames = sections.frames |> Integer.to_string() |> String.pad_leading(2, "0")

    "#{sign}#{hours}:#{minutes}:#{seconds}#{frame_sep}#{frames}"
  end

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
  @spec runtime(Vtc.Timecode.t(), integer) :: String.t()
  def runtime(tc, precision) do
    {seconds, is_negative} =
      if tc.seconds < 0 do
        {-tc.seconds, true}
      else
        {tc.seconds, false}
      end

    seconds = Decimal.div(Ratio.numerator(seconds), Ratio.denominator(seconds))

    {hours, seconds} = Decimal.div_rem(seconds, Private.Const.seconds_per_hour())
    {minutes, seconds} = Decimal.div_rem(seconds, Private.Const.seconds_per_minute())

    Decimal.Context
    seconds = Decimal.round(seconds, precision)
    seconds_floor = Decimal.round(seconds, 0, :down)
    seconds_fractal = Decimal.sub(seconds, seconds_floor)

    hours = hours |> Decimal.to_integer() |> Integer.to_string() |> String.pad_leading(2, "0")
    minutes = minutes |> Decimal.to_integer() |> Integer.to_string() |> String.pad_leading(2, "0")

    seconds_floor =
      seconds_floor |> Decimal.to_integer() |> Integer.to_string() |> String.pad_leading(2, "0")

    seconds_fractal =
      if Decimal.eq?(seconds_fractal, 0) do
        ""
      else
        # We dont want the leadin zero and we want to trim all trailing zeroes. We are
        # also going to trim the '.' if there is nothing less so that the string is blank
        # for a later check.
        Decimal.to_string(seconds_fractal)
        |> String.trim_leading("0")
        |> String.trim_trailing("0")
        |> String.trim_trailing(".")
      end

    # If the fractal string is blank, use ".0"
    seconds_fractal =
      if seconds_fractal == "" do
        ".0"
      else
        seconds_fractal
      end

    # We'll add a negative sign if the timecode is negative.
    sign =
      if is_negative do
        "-"
      else
        ""
      end

    "#{sign}#{hours}:#{minutes}:#{seconds_floor}#{seconds_fractal}"
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
  @spec premiere_ticks(Vtc.Timecode.t()) :: integer
  def premiere_ticks(%Vtc.Timecode{} = tc) do
    Private.Rat.round_ratio?(tc.seconds * Private.Const.ppro_tick_per_second())
  end

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
  @spec feet_and_frames(Vtc.Timecode.t()) :: String.t()
  def feet_and_frames(%Vtc.Timecode{} = tc) do
    frames = abs(Vtc.Timecode.frames(tc))

    # We need to call these functions from the kernel or we are going to get Ratio's
    # since we are using Ratio to overload these functions.
    feet = Kernel.div(frames, Private.Const.frames_per_foot())
    frames = Kernel.rem(frames, Private.Const.frames_per_foot())

    feet = Integer.to_string(feet)
    frames = frames |> Integer.to_string() |> String.pad_leading(2, "0")

    # We'll add a negative sign if the timecode is negative.
    sign =
      if tc.seconds < 0 do
        "-"
      else
        ""
      end

    "#{sign}#{feet}+#{frames}"
  end

  defmodule ParseError do
    @moduledoc """
    Exception returned when there is an error parsing a Timecode value.
    """
    defexception [:reason]

    @typedoc """
    Type of `Vtc.Timecode.ParseError`

    # Fields

    - `:reason`: The reason the error occurred must be one of the following:

      - `:unrecognized_format`: Returned when a string value is not a recognized
        timecode, runtime, etc. format.
    """
    @type t :: %ParseError{reason: :unrecognized_format | :bad_drop_frames}

    @doc """
    Returns a message for the error reason.
    """
    @spec message(Vtc.Framerate.ParseError.t()) :: String.t()
    def message(error) do
      case error.reason do
        :unrecognized_format ->
          "string format not recognized"

        :bad_drop_frames ->
          "frames value not allowed for drop-frame timecode. frame should have been dropped"
      end
    end
  end

  @typedoc """
  Type returned by `Vtc.Timecode.with_seconds/2` and `Vtc.Timecode.with_frames/2`.
  """
  @type parse_result :: {:ok, Vtc.Timecode.t()} | {:error, ParseError.t()}

  @doc """
  Returns a new `Vtc.Timecode` with a Vtc.Timecode.seconds field value equal to the
  seconds arg.

  Timecode::with_frames takes many different formats (more than just numeric types) that
  represent the frame count of the timecode.

  # Arguments

  - `seconds` - A value which can be represented as a number of seconds.
  - `rate` - The Framerate at which the frames are being played back.
  """
  @spec with_seconds(Vtc.Source.Seconds.t(), Vtc.Framerate.t()) :: parse_result
  def with_seconds(seconds, %Vtc.Framerate{} = rate) do
    result = Vtc.Source.Seconds.seconds(seconds, rate)

    case result do
      {:ok, seconds} -> {:ok, %Vtc.Timecode{seconds: seconds, rate: rate}}
      {:error, err} -> {:error, err}
    end
  end

  @doc """
  As `Vtc.Timecode.with_seconds/2`, but raises on error.
  """
  @spec with_seconds!(Vtc.Source.Seconds.t(), Vtc.Framerate.t()) :: Vtc.Timecode.t()
  def with_seconds!(seconds, %Vtc.Framerate{} = rate) do
    case with_seconds(seconds, rate) do
      {:ok, tc} -> tc
      {:error, err} -> raise err
    end
  end

  @doc """
  Returns a new `Vtc.Timecode` with a `Vtc.Timecode.frames/1` return value equal to the
  frames arg.

  with_frames takes many different formats (more than just numeric types) that
  represent the frame count of the timecode.

  # Arguments

  - `frames` - A value which can be represented as a frame number / frame count.
  - `rate` - The Framerate at which the frames are being played back.
  """
  @spec with_frames(Vtc.Source.Frames.t(), Vtc.Framerate.t()) :: parse_result
  def with_frames(frames, %Vtc.Framerate{} = rate) do
    case Vtc.Source.Frames.frames(frames, rate) do
      {:ok, frames} ->
        seconds = frames / rate.playback
        with_seconds(seconds, rate)

      {:error, err} ->
        {:error, err}
    end
  end

  @doc """
  As `Vtc.Timecode.with_frames/2`, but raises on error.
  """
  @spec with_frames!(Vtc.Source.Frames.t(), Vtc.Framerate.t()) :: Vtc.Timecode.t()
  def with_frames!(frames, %Vtc.Framerate{} = rate) do
    case with_frames(frames, rate) do
      {:ok, tc} -> tc
      {:error, err} -> raise err
    end
  end

  @doc """
  Returns a new `Vtc.Timecode` with a `Vtc.Timecode.premiere_ticks/1` return value equal
  to the ticks arg.

  with_premiere_ticks takes many different formats (more than just numeric types) that
  can represent the tick count of the timecode.

  # Arguments

  - `frames` - A value which can be represented as a frame number / frame count.
  - `rate` - The Framerate at which the frames are being played back.
  """
  @spec with_premiere_ticks(Vtc.Source.PremiereTicks.t(), Vtc.Framerate.t()) :: parse_result
  def with_premiere_ticks(ticks, %Vtc.Framerate{} = rate) do
    case Vtc.Source.PremiereTicks.ticks(ticks, rate) do
      {:ok, ticks} ->
        seconds = ticks / Private.Const.ppro_tick_per_second()
        with_seconds(seconds, rate)

      {:error, err} ->
        {:error, err}
    end
  end

  @doc """
  As `Vtc.Timecode.with_premiere_ticks/2`, but raises on error.
  """
  @spec with_premiere_ticks!(Vtc.Source.Frames.t(), Vtc.Framerate.t()) :: Vtc.Timecode.t()
  def with_premiere_ticks!(ticks, %Vtc.Framerate{} = rate) do
    case with_premiere_ticks(ticks, rate) do
      {:ok, tc} -> tc
      {:error, err} -> raise err
    end
  end

  @spec to_string(Vtc.Timecode.t()) :: String.t()
  def to_string(tc) do
    tc_str = Vtc.Timecode.timecode(tc)
    rate_str = String.Chars.to_string(tc.rate)

    "<#{tc_str} @ #{rate_str}>"
  end
end

defimpl Inspect, for: Vtc.Timecode do
  def inspect(tc, _opts) do
    Vtc.Timecode.to_string(tc)
  end
end

defimpl String.Chars, for: Vtc.Timecode do
  @spec to_string(Vtc.Timecode.t()) :: String.t()
  def to_string(term) do
    Vtc.Timecode.to_string(term)
  end
end
