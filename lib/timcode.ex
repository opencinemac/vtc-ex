defmodule Vtc.Timecode do
  use Ratio, comparison: true

  @enforce_keys [:seconds, :rate]
  defstruct [:seconds, :rate]

  @typedoc """
      Type that represents Timecode struct with :seconds as the rational representation
      of the number of seconds that have elapsed since 01:00:00:00 and :rate as the
      framerate the timecode is being calculated at.
  """
  @type t :: %Vtc.Timecode{seconds: Ratio.t(), rate: Vtc.Framerate.t()}

  defmodule Sections do
    @enforce_keys [:negative, :hours, :minutes, :seconds, :frames]
    defstruct [:negative, :hours, :minutes, :seconds, :frames]

    @type t :: %Sections{
            negative: boolean,
            hours: integer,
            minutes: integer,
            seconds: integer,
            frames: integer
          }
  end

  @spec frames(Vtc.Timecode.t()) :: integer
  def frames(tc = %Vtc.Timecode{}) do
    Private.round_ratio?(tc.seconds * tc.rate.playback)
  end

  @spec sections(Vtc.Timecode.t()) :: Sections.t()
  def sections(tc = %Vtc.Timecode{}) do
    timebase = Vtc.Framerate.timebase(tc.rate)
    framesPerMinute = timebase * Private.secondsPerMinute()
    framesPerHour = timebase * Private.secondsPerHour()

    is_negative = tc.seconds < 0
    frames = abs(frames(tc))

    {hours, frames} = Private.divmod(frames, framesPerHour)
    {minutes, frames} = Private.divmod(frames, framesPerMinute)
    {seconds, frames} = Private.divmod(frames, timebase)
    frames = Private.round_ratio?(frames)

    %Sections{
      negative: is_negative,
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      frames: frames
    }
  end

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
    defexception [:reason]

    @type t :: %ParseError{reason: :unrecognized_format}

    @spec message(Vtc.Framerate.ParseError.t()) :: String.t()
    def message(error) do
      case error.reason do
        :unrecognized_format -> "string format not recognized"
      end
    end
  end

  @type parse_result :: {:ok, Vtc.Timecode.t()} | {:error, ParseError.t()}

  @spec with_seconds(Vtc.Sources.Seconds.t(), Vtc.Framerate.t()) :: parse_result
  def with_seconds(seconds, %Vtc.Framerate{} = rate) do
    case Vtc.Sources.Seconds.seconds(seconds, rate) do
      {:ok, seconds} -> {:ok, %Vtc.Timecode{seconds: seconds, rate: rate}}
      {:error, err} -> {:error, err}
    end
  end

  @spec with_frames(Vtc.Sources.Frames.t(), Vtc.Framerate.t()) :: parse_result
  def with_frames(frames, %Vtc.Framerate{} = rate) do
    case Vtc.Sources.Frames.frames(frames, rate) do
      {:ok, frames} ->
        seconds = frames / rate.playback
        with_seconds(seconds, rate)

      {:error, err} ->
        {:error, err}
    end
  end
end
