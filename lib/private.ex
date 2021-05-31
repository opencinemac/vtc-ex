defmodule Private do
  use Ratio, comparison: true

  @spec round_ratio?(Ratio.t()) :: integer
  def round_ratio?(%Ratio{} = x) do
    floored = floor(x)
    remainder = x - floored

    rounded =
      if remainder > Ratio.new(1, 2) do
        floored + 1
      else
        floored
      end

    rounded
  end

  @spec round_ratio?(integer) :: integer
  def round_ratio?(x) when is_integer(x) do
    x
  end

  @spec divmod(Ratio.t() | integer, Ratio.t() | integer) :: {integer, Ratio.t() | integer}
  def divmod(a, b) do
    dividend = floor(a / b)
    multiplied = dividend * b
    remainder = a - multiplied
    {dividend, remainder}
  end

  @spec secondsPerMinute() :: integer
  def secondsPerMinute() do
    60
  end

  @spec secondsPerHour() :: integer
  def secondsPerHour() do
    secondsPerMinute() * 60
  end

  @spec from_seconds_core(Ratio.t() | integer, Vtc.Framerate.t()) :: Vtc.Sources.seconds_result()
  def from_seconds_core(value, rate) do
    # If our seconds are not cleanly divisible by the length of a single frame, we need
    # 	to round to the nearest frame.
    seconds =
      if not is_integer(value / rate.playback) do
        frames = Private.round_ratio?(rate.playback * value)
        seconds = frames / rate.playback
        seconds
      else
        value
      end

    {:ok, seconds}
  end

  @spec parse_tc_string(String.t(), Vtc.Framerate.t()) :: Vtc.Sources.frames_result()
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
      if value == nil do
        0
      else
        String.to_integer(value)
      end

    {value_int, sections}
  end

  @spec tc_sections_to_frames(Vtc.Timecode.Sections.t(), Vtc.Framerate.t()) :: integer
  defp tc_sections_to_frames(%Vtc.Timecode.Sections{} = sections, %Vtc.Framerate{} = rate) do
    seconds = sections.minutes * secondsPerMinute() + sections.hours * secondsPerHour()
    frames = sections.frames + seconds * Vtc.Framerate.timebase(rate)
    round_ratio?(frames)
  end
end
