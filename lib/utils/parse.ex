defmodule Vtc.Utils.Parse do
  @moduledoc false

  alias Vtc.Framerate
  alias Vtc.Source.Frames
  alias Vtc.Source.Seconds
  alias Vtc.Timecode
  alias Vtc.Utils.Consts
  alias Vtc.Utils.DropFrame
  alias Vtc.Utils.Rational

  @spec parse_frames_string(String.t(), Framerate.t()) :: Frames.result()
  def parse_frames_string(value, rate) do
    case parse_tc_string(value, rate) do
      {:ok, _} = result -> result
      {:error, %Timecode.ParseError{reason: :bad_drop_frames}} = error -> error
      {:error, _} -> parse_feet_and_frames(value, rate)
    end
  end

  @tc_regex ~r/^(?P<negative>-)?((?P<section_1>[0-9]+)[:|;])?((?P<section_2>[0-9]+)[:|;])?((?P<section_3>[0-9]+)[:|;])?(?P<frames>[0-9]+)$/

  @spec parse_tc_string(String.t(), Framerate.t()) :: Frames.result()
  def parse_tc_string(value, rate) do
    with {:ok, matched} <- apply_regex(@tc_regex, value) do
      matched
      |> tc_matched_to_sections()
      |> tc_sections_to_frames(rate)
    end
  end

  @spec apply_regex(Regex.t(), String.t()) :: {:ok, map()} | {:error, Timecode.ParseError.t()}
  defp apply_regex(regex, value) do
    regex
    |> Regex.named_captures(value)
    |> then(fn
      matched when is_map(matched) -> {:ok, matched}
      nil -> {:error, %Timecode.ParseError{reason: :unrecognized_format}}
    end)
  end

  # Extract TC sections from regex match.
  @spec tc_matched_to_sections(map()) :: Timecode.Sections.t()
  defp tc_matched_to_sections(matched) do
    negative? = Map.fetch!(matched, "negative") == "-"

    sections = extract_time_sections(matched, 3)

    {seconds, sections} = pop_time_section(sections)
    {minutes, sections} = pop_time_section(sections)
    {hours, _} = pop_time_section(sections)
    frames = matched |> Map.fetch!("frames") |> String.to_integer()

    %Timecode.Sections{
      negative?: negative?,
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      frames: frames
    }
  end

  # Extracts a set of sections in a time string of format xx:yy:.. that may or may not
  # be truncated at the head.
  #
  # The regex matches are expected to have a series of fields like "section_1",
  # "section_2", etc that denote present sections whose meaning depends on the  number
  # of sections present.
  @spec extract_time_sections(map(), non_neg_integer()) :: [String.t()]
  defp extract_time_sections(regex_matches, section_count) do
    1..section_count
    |> Enum.map(&Integer.to_string/1)
    |> Enum.reduce([], fn section_index, sections ->
      case Map.fetch!(regex_matches, "section_#{section_index}") do
        "" -> sections
        this_section -> [this_section | sections]
      end
    end)
  end

  # Pops the next section at the end of the list and returns it as an integer.
  #
  # Returns `0` if the value is not present
  @spec pop_time_section([String.t()]) :: {integer(), [String.t()]}
  defp pop_time_section(["" | remaining]), do: {0, remaining}
  defp pop_time_section([value | remaining]), do: {String.to_integer(value), remaining}
  defp pop_time_section([]), do: {0, []}

  # Converts all TC fields to a total frame count
  @spec tc_sections_to_frames(Timecode.Sections.t(), Framerate.t()) :: Frames.result()
  defp tc_sections_to_frames(sections, rate) do
    with {:ok, adjustment} <- DropFrame.parse_adjustment(sections, rate) do
      frames_per_second = Framerate.timebase(rate)

      sections.seconds
      |> Ratio.add(sections.minutes * Consts.seconds_per_minute())
      |> Ratio.add(sections.hours * Consts.seconds_per_hour())
      |> Ratio.mult(frames_per_second)
      |> Ratio.add(sections.frames)
      |> Ratio.add(adjustment)
      |> Rational.round()
      |> then(fn frames -> if sections.negative?, do: -frames, else: frames end)
      |> then(&{:ok, &1})
    end
  end

  @ff_regex ~r/(?P<negative>-)?(?P<feet>[0-9]+)\+(?P<frames>[0-9]+)/

  @spec parse_feet_and_frames(String.t(), Framerate.t()) :: Frames.result()
  defp parse_feet_and_frames(value, rate) do
    with {:ok, groups} <- apply_regex(@ff_regex, value) do
      negative? = Map.fetch!(groups, "negative") == "-"
      feet = groups |> Map.fetch!("feet") |> String.to_integer()

      groups
      |> Map.fetch!("frames")
      |> String.to_integer()
      |> Ratio.add(feet * Consts.frames_per_foot())
      |> then(fn frames -> if negative?, do: -frames, else: frames end)
      |> Frames.frames(rate)
    end
  end

  @runtime_regex ~r/^(?P<negative>-)?((?P<section_1>[0-9]+)[:|;])?((?P<section_2>[0-9]+)[:|;])?(?P<seconds>[0-9]+(\.[0-9]+)?)$/

  @spec parse_runtime_string(String.t(), Framerate.t()) :: Seconds.result()
  def parse_runtime_string(value, rate) do
    with {:ok, matched} <- apply_regex(@runtime_regex, value) do
      matched
      |> runtime_matched_to_second()
      |> Seconds.seconds(rate)
    end
  end

  @spec runtime_matched_to_second(map()) :: Rational.t()
  defp runtime_matched_to_second(matched) do
    negative? = Map.fetch!(matched, "negative") == "-"
    sections = extract_time_sections(matched, 2)

    {minutes, sections} = pop_time_section(sections)
    {hours, _} = pop_time_section(sections)

    matched
    |> Map.fetch!("seconds")
    |> Decimal.new()
    |> Ratio.new(1)
    |> Ratio.add(hours * Consts.seconds_per_hour())
    |> Ratio.add(minutes * Consts.seconds_per_minute())
    |> then(fn seconds -> if negative?, do: Ratio.minus(seconds), else: seconds end)
  end
end
