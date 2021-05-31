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
    - `String`
    - `Bitstring`
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
    def frames(value, rate), do: Private.Parse.parse_tc_string(value, rate)
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

  @spec parse_tc_string(String.t(), Vtc.Framerate.t()) :: Vtc.Source.frames_result()
  def parse_tc_string(value, rate) do
    with {:ok, matched} <- tc_apply_regex(value),
         sections <- tc_matched_to_sections(matched),
         frames <- tc_sections_to_frames(sections, rate) do
      {:ok, frames}
    else
      :no_match -> %Vtc.Timecode.ParseError{reason: :unrecognized_format}
    end
  end

  @spec tc_apply_regex(String.t()) :: :no_match | {:ok, map}
  defp tc_apply_regex(value) do
    tc_regex =
      ~r/^(?P<negative>-)?((?P<section1>[0-9]+)[:|;])?((?P<section2>[0-9]+)[:|;])?((?P<section3>[0-9]+)[:|;])?(?P<frames>[0-9]+)$/

    matched = Regex.named_captures(tc_regex, value)

    if matched == nil do
      :no_match
    else
      {:ok, matched}
    end
  end

  @spec tc_matched_to_sections(map) :: Vtc.Timecode.Sections.t()
  defp tc_matched_to_sections(matched) do
    # It's faster to append to the front of a list, so we will work backwards
    sectionKeys = ["section3", "section2", "section1"]

    # Reduce to our present section values.
    {_, sections} =
      Enum.map_reduce(sectionKeys, [], fn section_key, sections ->
        this_section = Map.fetch(matched, section_key)

        sections =
          case this_section do
            {:ok, value} -> [value | sections]
            :error -> sections
          end

        {this_section, sections}
      end)

    {seconds, sections} = tc_get_next_section(sections)
    {minutes, sections} = tc_get_next_section(sections)
    {hours, _} = tc_get_next_section(sections)

    # If the regex matched, then the frames place has to have matched.
    {:ok, frames_str} = Map.fetch(matched, "frames")
    frames = String.to_integer(frames_str)

    is_negative = Map.fetch(matched, "sign") != :error

    %Vtc.Timecode.Sections{
      negative: is_negative,
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      frames: frames
    }
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

  @spec tc_sections_to_frames(Vtc.Timecode.Sections.t(), Vtc.Framerate.t()) :: integer
  defp tc_sections_to_frames(%Vtc.Timecode.Sections{} = sections, %Vtc.Framerate{} = rate) do
    seconds =
      sections.minutes * Private.Const.secondsPerMinute() +
        sections.hours * Private.Const.secondsPerHour() +
        sections.seconds

    frames = sections.frames + seconds * Vtc.Framerate.timebase(rate)

    with {:ok, adjustment} <- Private.Drop.parse_adjustment(sections, rate),
         frames = frames + adjustment do
      Private.Rat.round_ratio?(frames)
    else
      {:error, err} -> {:error, err}
    end
  end
end
