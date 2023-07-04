defmodule Vtc.Source.Frames.SMPTETimecodeStr do
  @moduledoc """
  Implementation of [Frames](`Vtc.Source.Frames`) for timecode string. See
  `Vtc.Framestamp.smpte_timecode/2` for more information on this format.

  This struct is used as an input wrapper only, not as the general-purpose Premiere
  ticks unit.

  By default, this wrapper does not need to be used by callers, as the string
  implementation of the frames protocol calls this type's impl automatically. Only use
  this type if you do not wish for the parser to fall back to feet+frames parsing as
  well.
  """

  alias Vtc.Framestamp

  @enforce_keys [:in]
  defstruct [:in]

  @typedoc """
  Contains only a single field for wrapping the underlying string.
  """
  @type t() :: %__MODULE__{in: String.t()}

  @doc false
  @spec from_framestamp(Framestamp.t(), opts :: [round: Framestamp.round()]) :: t()
  def from_framestamp(framestamp, opts) do
    sections = Framestamp.smpte_timecode_sections(framestamp, opts)

    sign = if Ratio.lt?(framestamp.seconds, 0), do: "-", else: ""
    frame_sep = if framestamp.rate.ntsc == :drop, do: ";", else: ":"

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
    |> then(&%__MODULE__{in: &1})
  end

  @spec render_tc_field(integer()) :: String.t()
  defp render_tc_field(value), do: value |> Integer.to_string() |> String.pad_leading(2, "0")
end

defimpl Vtc.Source.Frames, for: Vtc.Source.Frames.SMPTETimecodeStr do
  @moduledoc """
  Implements [Seconds](`Vtc.Source.Seconds`) protocol for Premiere ticks.
  """

  alias Vtc.Framerate
  alias Vtc.SMPTETimecode
  alias Vtc.Source.Frames
  alias Vtc.Source.Frames.SMPTETimecodeStr
  alias Vtc.Utils.Consts
  alias Vtc.Utils.DropFrame
  alias Vtc.Utils.Parse
  alias Vtc.Utils.Rational

  @tc_regex ~r/^(?P<negative>-)?((?P<section_1>[0-9]+)[:|;])?((?P<section_2>[0-9]+)[:|;])?((?P<section_3>[0-9]+)[:|;])?(?P<frames>[0-9]+)$/

  @spec frames(SMPTETimecodeStr.t(), Framerate.t()) :: Frames.result()
  def frames(tc_str, rate) do
    with {:ok, matched} <- Parse.apply_regex(@tc_regex, tc_str.in) do
      matched
      |> tc_matched_to_sections()
      |> tc_sections_to_frames(rate)
    end
  end

  # Extract TC sections from regex match.
  @spec tc_matched_to_sections(map()) :: SMPTETimecode.Sections.t()
  defp tc_matched_to_sections(matched) do
    negative? = Map.fetch!(matched, "negative") == "-"

    sections = Parse.extract_time_sections(matched, 3)

    {seconds, sections} = Parse.pop_time_section(sections)
    {minutes, sections} = Parse.pop_time_section(sections)
    {hours, _} = Parse.pop_time_section(sections)
    frames = matched |> Map.fetch!("frames") |> String.to_integer()

    %SMPTETimecode.Sections{
      negative?: negative?,
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      frames: frames
    }
  end

  # Converts all TC fields to a total frame count
  @spec tc_sections_to_frames(SMPTETimecode.Sections.t(), Framerate.t()) :: Frames.result()
  defp tc_sections_to_frames(sections, rate) do
    with {:ok, adjustment} <- DropFrame.parse_adjustment(sections, rate) do
      frames_per_second = Framerate.smpte_timebase(rate)

      seconds_for_minutes = Ratio.new(sections.minutes * Consts.seconds_per_minute())
      seconds_for_hours = Ratio.new(sections.hours * Consts.seconds_per_hour())
      frames_ratio = Ratio.new(sections.frames)

      sections.seconds
      |> Ratio.new()
      |> Ratio.add(seconds_for_minutes)
      |> Ratio.add(seconds_for_hours)
      |> Ratio.mult(frames_per_second)
      |> Ratio.add(frames_ratio)
      |> Ratio.add(Ratio.new(adjustment))
      |> Rational.round()
      |> then(fn frames -> if sections.negative?, do: -frames, else: frames end)
      |> then(&{:ok, &1})
    end
  end
end
