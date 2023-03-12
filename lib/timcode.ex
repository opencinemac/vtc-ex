defmodule Vtc.Timecode do
  @moduledoc """
  Represents the frame at a particular time in a video.

  New Timecode values are created with the `with_seconds/2` and `with_frames/2`, and
  other function prefaced by `with_*`.
  """
  alias Vtc.Framerate
  alias Vtc.Private.Consts
  alias Vtc.Private.DropFrame
  alias Vtc.Source.Frames
  alias Vtc.Source.PremiereTicks
  alias Vtc.Source.Seconds
  alias Vtc.Utils.Rational

  @enforce_keys [:seconds, :rate]
  defstruct [:seconds, :rate]

  @typedoc """
  `Timecode` type.

  ## Fields

  - **seconds**: The real-world seconds elapsed since 01:00:00:00 as a rational value.
    (Note: The Ratio module automatically will coerce itself to an integer whenever
    possible, so this value may be an integer when exactly a whole-second value).

  - **rate**: the Framerate of the timecode.
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

  defmodule ParseError do
    @moduledoc """
    Exception returned when there is an error parsing a Timecode value.
    """
    defexception [:reason]

    @typedoc """
    Type of `Timecode.ParseError`

    ## Fields

    - **reason**: The reason the error occurred must be one of the following:

      - `:unrecognized_format`: Returned when a string value is not a recognized
        timecode, runtime, etc. format.

      - `:bad_drop_frames`: The field value cannot exist in properly formatted
         drop-frame timecode.
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
  Type returned by `with_seconds/2` and `with_frames/2`.
  """
  @type parse_result() :: {:ok, t()} | {:error, ParseError.t()}

  @doc """
  Returns a new `Timecode` with a Timecode.seconds field value equal to the
  seconds arg.

  ## Arguments

  - **seconds**: A value which can be represented as a number of seconds. Must implement
    the `Seconds` protocol.

  - **rate**: Frame-per-second playback value of the timecode.
  """
  @spec with_seconds(Seconds.t(), Framerate.t()) :: parse_result()
  def with_seconds(seconds, rate) do
    with {:ok, seconds} <- Seconds.seconds(seconds, rate) do
      {:ok, %__MODULE__{seconds: seconds, rate: rate}}
    end
  end

  @doc """
  As `with_seconds/2`, but raises on error.
  """
  @spec with_seconds!(Seconds.t(), Framerate.t()) :: t()
  def with_seconds!(seconds, rate) do
    seconds
    |> with_seconds(rate)
    |> handle_raise_function()
  end

  @doc """
  Returns a new `Timecode` with a `frames/1` return value equal to the `frames` arg.

  ## Arguments

  - **frames**: A value which can be represented as a frame number / frame count. Must
    implement the `Frames` protocol.

  - **rate**: Frame-per-second playback value of the timecode.
  """
  @spec with_frames(Frames.t(), Framerate.t()) :: parse_result()
  def with_frames(frames, rate) do
    with {:ok, frames} <- Frames.frames(frames, rate) do
      frames
      |> Ratio.div(rate.playback)
      |> with_seconds(rate)
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
  Returns a new `Timecode` with a `premiere_ticks/1` return value equal
  to the ticks arg.

  ## Arguments

  - **ticks**: Any value that can represent the number of ticks for a given timecode.
    Must implement the `PremiereTicks` protocol.

  - **rate**: Frame-per-second playback value of the timecode.
  """
  @spec with_premiere_ticks(PremiereTicks.t(), Framerate.t()) :: parse_result()
  def with_premiere_ticks(ticks, rate) do
    with {:ok, ticks} <- PremiereTicks.ticks(ticks, rate) do
      seconds = ticks / Consts.ppro_tick_per_second()
      with_seconds(seconds, rate)
    end
  end

  @doc """
  As `with_premiere_ticks/2`, but raises on error.
  """
  @spec with_premiere_ticks!(Frames.t(), Framerate.t()) :: t()
  def with_premiere_ticks!(ticks, rate) do
    ticks
    |> with_premiere_ticks(rate)
    |> handle_raise_function()
  end

  @doc """
  Rebases the timecode to a new framerate.

  The real-world seconds are recalculated using the same frame count as if they were
  being played back at `new_rate` instead of `timecode.rate`.

  ## Examples

  ```elixir
  iex> timecode = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> {:ok, rebased} = Timecode.rebase(timecode, Rates.f47_95())
  iex> Timecode.to_string(rebased)
  "<00:30:00:00 @ <47.95 NTSC NDF>>"
  ```
  """
  @spec rebase(t(), Framerate.t()) :: parse_result()
  def rebase(%__MODULE__{rate: rate} = timecode, rate), do: {:ok, timecode}
  def rebase(timecode, new_rate), do: timecode |> frames() |> with_frames(new_rate)

  @doc """
  As `rebase/2`, but raises on error.
  """
  @spec rebase!(t(), Framerate.t()) :: t()
  def rebase!(timecode, new_rate), do: timecode |> rebase(new_rate) |> handle_raise_function()

  @doc """
  Returns whether `a` is greater than, equal to, or less than `b` in terms of real-world
  seconds.

  `b` May be any value that implements the `Frames` protocol, such as a timecode string,
  and will be assumed to be the same framerate as `a`. This is mostly to support quick
  scripting. This function will raise if there is an error parsing `b`.

  ## Examples

  Using two timecodes, `01:00:00:00` NTSC is greater than `01:00:00:00` true because it
  represents more real-world time.

  ```elixir
  iex> a = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> b = Timecode.with_frames!("01:00:00:00", Rates.f24())
  iex> :gt = Timecode.compare(a, b)
  ```

  Using a timcode and a bare string:

  ```elixir
  iex> timecode = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> :eq = Timecode.compare(timecode, "01:00:00:00")
  ```
  """
  @spec compare(a :: t(), b :: t() | Frames.t()) :: :lt | :eq | :gt
  def compare(%__MODULE__{} = a, %__MODULE__{} = b), do: Ratio.compare(a.seconds, b.seconds)
  def compare(a, b), do: compare(a, with_frames!(b, a.rate))

  @doc """
  Adds two timecodoes together using their real-world seconds representation. When the
  rates of `a` and `b` are not equal, the result will inheret the framerat of `a` and
  be rounded to the seconds representation of the nearest whole-frame at that rate.

  `b` May be any value that implements the `Frames` protocol, such as a timecode string,
  and will be assumed to be the same framerate as `a`. This is mostly to support quick
  scripting. This function will raise if there is an error parsing `b`.

  ## Examples

  Two timecodes running at the same rate:

  ```elixir
  iex> a = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> b = Timecode.with_frames!("01:30:21:17", Rates.f23_98())
  iex> Timecode.add(a, b) |> Timecode.to_string()
  "<02:30:21:17 @ <23.98 NTSC NDF>>"
  ```

  Two timecodes running at different rates:

  ```elixir
  iex> a = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> b = Timecode.with_frames!("00:00:00:02", Rates.f47_95())
  iex> Timecode.add(a, b) |> Timecode.to_string()
  "<01:00:00:01 @ <23.98 NTSC NDF>>"
  ```

  Using a timcode and a bare string:

  ```elixir
  iex> a = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> Timecode.add(a, "01:30:21:17") |> Timecode.to_string()
  "<02:30:21:17 @ <23.98 NTSC NDF>>"
  ```
  """
  @spec add(a :: t(), b :: t() | Frames.t()) :: t()
  def add(%__MODULE__{rate: rate} = a, %__MODULE__{rate: rate} = b),
    do: %__MODULE__{seconds: Ratio.add(a.seconds, b.seconds), rate: rate}

  def add(a, %__MODULE__{} = b), do: a.seconds |> Ratio.add(b.seconds) |> with_seconds!(a.rate)
  def add(a, b), do: add(a, with_frames!(b, a.rate))

  @doc """
  Returns the number of frames that would have elapsed between 00:00:00:00 and this
  timecode.

  ## What it is

  Frame number / frames count is the number of a frame if the timecode started at
  00:00:00:00 and had been running until the current value. A timecode of '00:00:00:10'
  has a frame number of 10. A timecode of '01:00:00:00' has a frame number of 86400.

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
  """
  @spec frames(t()) :: integer()
  def frames(timecode) do
    timecode.seconds
    |> Ratio.mult(timecode.rate.playback)
    |> Rational.round()
  end

  @doc """
  The individual sections of a timecode string as i64 values.
  """
  @spec sections(t()) :: Sections.t()
  def sections(timecode) do
    rate = timecode.rate
    timebase = Framerate.timebase(rate)
    frames_per_minute = Ratio.mult(timebase, Consts.seconds_per_minute())
    frames_per_hour = Ratio.mult(timebase, Consts.seconds_per_hour())

    total_frames =
      timecode
      |> frames()
      |> abs()
      |> then(&(&1 + DropFrame.frame_num_adjustment(&1, rate)))

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

  ## What it is

  Timecode is used as a human-readable way to represent the id of a given frame. It is formatted
  to give a rough sense of where to find a frame: {HOURS}:{MINUTES}:{SECONDS}:{FRAME}. For more on
  timecode, see Frame.io's
  [excellent post](https://blog.frame.io/2017/07/17/timecode-and-frame-rates/) on the subject.

  ## Where you see it

  Timecode is ubiquitous in video editing, a small sample of places you might see timecode:

  - Source and Playback monitors in your favorite NLE.
  - Burned into the footage for dailies.
  - Cut lists like an EDL.
  """
  @spec timecode(t()) :: String.t()
  def timecode(timecode) do
    sections = sections(timecode)

    sign = if Ratio.compare(timecode.seconds, 0) == :lt, do: "-", else: ""
    frame_sep = if timecode.rate.ntsc == :drop, do: ";", else: ":"

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

  ## What it is

  The formatted version of seconds. It looks like timecode, but with a decimal seconds
  value instead of a frame number place.

  ## Where you see it

  • Anywhere real-world time is used.

  • FFMPEG commands:

    ```shell
    ffmpeg -ss 00:00:30.5 -i input.mov -t 00:00:10.25 output.mp4
    ```

  ## Note

  The true runtime will often diverge from the hours, minutes, and seconds
  value of the timecode representation when dealing with non-whole-frame
  framerates. Even drop-frame timecode does not continuously adhere 1:1 to the
  actual runtime. For instance, <01:00:00;00 @ <29.97 NTSC DF>> has a true runtime of
  '00:59:59.9964', and <01:00:00:00 @ <23.98 NTSC NDF>> has a true runtime of
  '01:00:03.6'
  """
  @spec runtime(t(), integer()) :: String.t()
  def runtime(timecode, precision) do
    {seconds, negative?} =
      if Ratio.compare(timecode.seconds, 0) == :lt,
        do: {Ratio.negate(timecode.seconds), true},
        else: {timecode.seconds, false}

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
  """
  @spec premiere_ticks(t()) :: integer()
  def premiere_ticks(timecode),
    do: timecode.seconds |> Ratio.mult(Consts.ppro_tick_per_second()) |> Rational.round()

  @doc """
  Returns the number of feet and frames this timecode represents if it were shot on 35mm
  4-perf film (16 frames per foot). ex: '5400+13'.

  ## What it is

  On physical film, each foot contains a certain number of frames. For 35mm, 4-perf film
  (the most common type on Hollywood movies), this number is 16 frames per foot.
  Feet-And-Frames was often used in place of Keycode to quickly reference a frame in the
  edit.

  ## Where you see it

  For the most part, feet + frames has died out as a reference, because digital media is
  not measured in feet. The most common place it is still used is Studio Sound
  Departments. Many Sound Mixers and Designers intuitively think in feet + frames, and it
  is often burned into the reference picture for them.

  - Telecine.

  - Sound turnover reference picture.

  - Sound turnover change lists.
  """
  @spec feet_and_frames(t()) :: String.t()
  def feet_and_frames(%__MODULE__{} = timecode) do
    total_frames = timecode |> frames() |> abs()

    feet = total_frames |> div(Consts.frames_per_foot()) |> Integer.to_string()

    frames =
      total_frames
      |> rem(Consts.frames_per_foot())
      |> Integer.to_string()
      |> String.pad_leading(2, "0")

    sign = if Ratio.compare(timecode.seconds, 0) == :lt, do: "-", else: ""

    "#{sign}#{feet}+#{frames}"
  end

  @spec to_string(t()) :: String.t()
  def to_string(timecode) do
    timecode_str = timecode(timecode)
    rate_str = String.Chars.to_string(timecode.rate)

    "<#{timecode_str} @ #{rate_str}>"
  end

  @spec handle_raise_function({:ok, t()} | {:error, Exception.t()}) :: t()
  defp handle_raise_function({:ok, result}), do: result
  defp handle_raise_function({:error, error}), do: raise(error)
end

defimpl Inspect, for: Vtc.Timecode do
  alias Vtc.Timecode

  @spec inspect(Timecode.t(), Elixir.Inspect.Opts.t()) :: String.t()
  def inspect(timecode, _opts), do: Timecode.to_string(timecode)
end

# opportunities

defimpl String.Chars, for: Vtc.Timecode do
  alias Vtc.Timecode

  @spec to_string(Timecode.t()) :: String.t()
  def to_string(timecode), do: Timecode.to_string(timecode)
end
