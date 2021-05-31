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
  def frames(tc = %Vtc.Timecode{}) do
    Private.Rat.round_ratio?(tc.seconds * tc.rate.playback)
  end

  @doc """
  The individual sections of a timecode string as i64 values.
  """
  @spec sections(Vtc.Timecode.t()) :: Sections.t()
  def sections(tc = %Vtc.Timecode{}) do
    timebase = Vtc.Framerate.timebase(tc.rate)
    framesPerMinute = timebase * Private.Const.secondsPerMinute()
    framesPerHour = timebase * Private.Const.secondsPerHour()

    is_negative = tc.seconds < 0
    frames = abs(frames(tc))

    # adjust our frame number if this is a drop-frame framerate.
    frames =
      if tc.rate.ntsc == :Drop do
        Private.Drop.frame_num_adjustment(frames, tc.rate)
      else
        frames
      end

    {hours, frames} = Private.Rat.divmod(frames, framesPerHour)
    {minutes, frames} = Private.Rat.divmod(frames, framesPerMinute)
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
  def timecode(tc = %Vtc.Timecode{}) do
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
    case Vtc.Source.Seconds.seconds(seconds, rate) do
      {:ok, seconds} -> {:ok, %Vtc.Timecode{seconds: seconds, rate: rate}}
      {:error, err} -> {:error, err}
    end
  end

  @doc """
  As `Vtc.Timecode.with_seconds/2`, but raises on error.
  """
  @spec with_seconds!(Vtc.Source.Seconds.t(), Vtc.Framerate.t()) :: Vtc.Timecode.t()
  def with_seconds!(seconds, %Vtc.Framerate{} = rate) do
    {:ok, tc} = with_seconds(seconds, rate)
    tc
  end

  @doc """
  Returns a new `Vtc.Timecode` with a `Vtc.Timecode.frames/1` return value equal to the
  frames arg.

  Timecode::with_frames takes many different formats (more than just numeric types) that
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
    {:ok, tc} = with_frames(frames, rate)
    tc
  end
end

defimpl Inspect, for: Vtc.Timecode do
  def inspect(tc, opts) do
    tc_str = Vtc.Timecode.timecode(tc)
    rate_str = Inspect.inspect(tc.rate, opts)

    "<#{tc_str} @ #{rate_str}>"
  end
end
