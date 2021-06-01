defmodule Vtc.Source do
  @moduledoc """
  Protocols for source values that can be used to construct a timecode.
  """

  use Ratio

  @typedoc """
  Result type of `Vtc.Source.Seconds.seconds/2`.
  """
  @type seconds_result :: {:ok, Ratio.t() | integer} | {:error, Vtc.Timecode.ParseError.t()}

  defprotocol Seconds do
    @moduledoc """
    Protocol which types can implement to be passed as the main value of
    `Vtc.Timecode.with_seconds/2`.

    # Implementations

    Out of the box, this protocol is implemented for the following types:

    - `Ratio`
    - `Integer`
    - `Float`
    - `String` & 'BitString'
      - runtime ("01:00:00.0")
      - decimal ("3600.0")
    """

    @doc """
    Returns the value as a rational seconds value.

    # Arguments

    - **value**: The source value.

    - **rate**: The framerate of the timecode being parsed.

    # Returns

    A result tuple with a rational representation of the seconds value using `Ratio` on
    success.
    """
    @spec seconds(t, Vtc.Framerate.t()) :: Vtc.Source.seconds_result()
    def seconds(value, rate)
  end

  defimpl Seconds, for: [Ratio, Integer] do
    @spec seconds(Ratio.t() | integer, Vtc.Framerate.t()) :: Vtc.Source.seconds_result()
    def seconds(value, rate), do: Private.Parse.from_seconds_core(value, rate)
  end

  defimpl Seconds, for: Float do
    @spec seconds(float, Vtc.Framerate.t()) :: Vtc.Source.seconds_result()
    def seconds(value, rate), do: Seconds.seconds(Ratio.new(value, 1), rate)
  end

  defimpl Seconds, for: [String, BitString] do
    @spec seconds(String.t() | bitstring, Vtc.Framerate.t()) :: Vtc.Source.seconds_result()
    def seconds(value, rate), do: Private.Parse.parse_runtime_string(value, rate)
  end

  @typedoc """
  Result type of `Vtc.Source.Frames.frames/2`.
  """
  @type frames_result :: {:ok, integer} | {:error, Vtc.Timecode.ParseError.t()}

  defprotocol Frames do
    @moduledoc """
    Protocol which types can implement to be passed as the main value of
    `Vtc.Timecode.with_frames/2`.

    # Implementations

    Out of the box, this protocol is implemented for the following types:

    - `Integer`
    - `String` & 'BitString'
      - timecode ("01:00:00:00")
      - integer ("86400")
      - Feet+Frames ("5400+00")
    """

    @doc """
    Returns the value as a frame count.

    # Arguments

    - **value**: The source value.

    - **rate**: The framerate of the timecode being parsed.

    # Returns

    A result tuple with an integer value representing the frame count on success.
    """
    @spec frames(t, Vtc.Framerate.t()) :: Vtc.Source.frames_result()
    def frames(value, rate)
  end

  defimpl Frames, for: Integer do
    @spec frames(integer, Vtc.Framerate.t()) :: Vtc.Source.frames_result()
    def frames(value, _rate), do: {:ok, value}
  end

  defimpl Frames, for: [String, BitString] do
    @spec frames(String.t() | Bitstring, Vtc.Framerate.t()) :: Vtc.Source.frames_result()
    def frames(value, rate), do: Private.Parse.parse_frames_string(value, rate)
  end

  @typedoc """
  Result type of `Vtc.Source.PremiereTicks.ticks/2`.
  """
  @type ticks_result :: {:ok, integer} | {:error, Vtc.Timecode.ParseError.t()}

  defprotocol PremiereTicks do
    @moduledoc """
    Protocol which types can implement to be passed as the main value of
    `Vtc.Timecode.with_premiere_ticks/2`.

    # Implementations

    Out of the box, this protocol is implemented for the following types:

    - `Integer`
    """

    @doc """
    Returns the number of Adobe Premiere Pro ticks as an integer.

    # Arguments

    - **value**: The source value.

    - **rate**: The framerate of the timecode being parsed.

    # Returns

    A result tuple with a rational representation of the seconds value using `Ratio` on
    success.
    """
    @spec ticks(t, Vtc.Framerate.t()) :: Vtc.Source.ticks_result()
    def ticks(value, rate)
  end

  defimpl PremiereTicks, for: Integer do
    @spec ticks(integer, Vtc.Framerate.t()) :: Vtc.Source.ticks_result()
    def ticks(value, _rate), do: {:ok, value}
  end
end

defmodule Private.Parse do
  @moduledoc false

  use Ratio

  @spec from_seconds_core(Ratio.t() | integer, Vtc.Framerate.t()) :: Vtc.Source.seconds_result()
  def from_seconds_core(value, rate) do
    # If our seconds are not cleanly divisible by the length of a single frame, we need
    # 	to round to the nearest frame.
    seconds =
      if not is_integer(value / rate.playback) do
        frames = Private.Rat.round_ratio?(rate.playback * value)
        seconds = frames / rate.playback
        seconds
      else
        value
      end

    {:ok, seconds}
  end

  @spec parse_frames_string(String.t(), Vtc.Framerate.t()) :: Vtc.Source.frames_result()
  def parse_frames_string(value, rate) do
    case parse_tc_string(value, rate) do
      {:ok, tc} -> {:ok, tc}
      {:error, %Vtc.Timecode.ParseError{reason: :bad_drop_frames} = err} -> {:error, err}
      {:error, _} -> parse_feet_and_frames(value, rate)
    end
  end

  @spec parse_tc_string(String.t(), Vtc.Framerate.t()) :: Vtc.Source.frames_result()
  def parse_tc_string(value, rate) do
    tc_regex =
      ~r/^(?P<negative>-)?((?P<section1>[0-9]+)[:|;])?((?P<section2>[0-9]+)[:|;])?((?P<section3>[0-9]+)[:|;])?(?P<frames>[0-9]+)$/

    with {:ok, matched} <- apply_regex(tc_regex, value),
         sections <- tc_matched_to_sections(matched),
         {:ok, frames} <- tc_sections_to_frames(sections, rate) do
      {:ok, frames}
    else
      :no_match -> {:error, %Vtc.Timecode.ParseError{reason: :unrecognized_format}}
      {:error, err} -> {:error, err}
    end
  end

  @spec apply_regex(Regex.t(), String.t()) :: :no_match | {:ok, map}
  defp apply_regex(regex, value) do
    matched = Regex.named_captures(regex, value)

    if matched == nil do
      :no_match
    else
      {:ok, matched}
    end
  end

  @spec tc_matched_to_sections(map) :: Vtc.Timecode.Sections.t()
  defp tc_matched_to_sections(matched) do
    # It's faster to append to the front of a list, so we will work backwards
    section_keys = ["section3", "section2", "section1"]
    sections = build_groups(matched, section_keys)

    {seconds, sections} = tc_get_next_section(sections)
    {minutes, sections} = tc_get_next_section(sections)
    {hours, _} = tc_get_next_section(sections)

    # If the regex matched, then the frames place has to have matched.
    frames = String.to_integer(matched["frames"])

    is_negative = matched["negative"] != ""

    %Vtc.Timecode.Sections{
      negative: is_negative,
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      frames: frames
    }
  end

  # Extracts groups that may or may not be in the match into a list of values.
  @spec build_groups(map, list(String.t())) :: list(String.t())
  defp build_groups(matched, section_keys) do
    # Reduce to our present section values.
    {_, sections} =
      Enum.map_reduce(section_keys, [], fn section_key, sections ->
        this_section = matched[section_key]

        sections =
          if this_section != "" do
            [this_section | sections]
          else
            sections
          end

        {this_section, sections}
      end)

    sections
  end

  @spec tc_get_next_section(list(String.t())) :: {integer, list(String.t())}
  defp tc_get_next_section(sections) do
    {value, sections} = List.pop_at(sections, -1)

    value_int =
      if value == nil or value == "" do
        0
      else
        String.to_integer(value)
      end

    {value_int, sections}
  end

  @spec tc_sections_to_frames(Vtc.Timecode.Sections.t(), Vtc.Framerate.t()) ::
          Vtc.Source.frames_result()
  defp tc_sections_to_frames(%Vtc.Timecode.Sections{} = sections, %Vtc.Framerate{} = rate) do
    seconds =
      sections.minutes * Private.Const.secondsPerMinute() +
        sections.hours * Private.Const.secondsPerHour() +
        sections.seconds

    frames = sections.frames + seconds * Vtc.Framerate.timebase(rate)

    with {:ok, adjustment} <- Private.Drop.parse_adjustment(sections, rate) do
      frames = frames + adjustment
      frames = Private.Rat.round_ratio?(frames)

      frames =
        if sections.negative do
          -frames
        else
          frames
        end

      {:ok, frames}
    else
      {:error, err} -> {:error, err}
    end
  end

  @spec parse_feet_and_frames(String.t(), Vtc.Framerate.t()) :: Vtc.Source.frames_result()
  def parse_feet_and_frames(value, rate) do
    ff_regex = ~r/(?P<negative>-)?(?P<feet>[0-9]+)\+(?P<frames>[0-9]+)/

    with {:ok, matched} <- apply_regex(ff_regex, value) do
      feet = matched["feet"] |> String.to_integer()
      frames = matched["frames"] |> String.to_integer()
      frames = feet * Private.Const.frames_per_foot() + frames

      frames =
        if matched["negative"] != "" do
          -frames
        else
          frames
        end

      Vtc.Source.Frames.frames(frames, rate)
    else
      :no_match -> {:error, %Vtc.Timecode.ParseError{reason: :unrecognized_format}}
    end
  end

  @spec parse_runtime_string(String.t(), Vtc.Framerate.t()) :: Vtc.Source.seconds_result()
  def parse_runtime_string(value, rate) do
    runtime_regex =
      ~r/^(?P<negative>-)?((?P<section1>[0-9]+)[:|;])?((?P<section2>[0-9]+)[:|;])?(?P<seconds>[0-9]+(\.[0-9]+)?)$/

    with {:ok, matched} <- apply_regex(runtime_regex, value),
         seconds <- runtime_matched_to_second(matched),
         {:ok, seconds} = Vtc.Source.Seconds.seconds(seconds, rate) do
      {:ok, seconds}
    else
      :no_match -> {:error, %Vtc.Timecode.ParseError{reason: :unrecognized_format}}
      {:error, err} -> {:error, err}
    end
  end

  @spec runtime_matched_to_second(map) :: Ratio.t() | integer
  defp runtime_matched_to_second(matched) do
    section_keys = ["section2", "section1"]
    sections = build_groups(matched, section_keys)

    {minutes, sections} = tc_get_next_section(sections)
    {hours, _} = tc_get_next_section(sections)

    # We will always have a 'seconds' group.
    seconds = Ratio.new(Decimal.new(matched["seconds"]), 1)

    is_negative = matched["negative"] != ""

    seconds =
      hours * Private.Const.secondsPerHour() + minutes * Private.Const.secondsPerMinute() +
        seconds

    if is_negative do
      -seconds
    else
      seconds
    end
  end
end
