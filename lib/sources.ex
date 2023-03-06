defmodule Vtc.Source do
  @moduledoc """
  Protocols for source values that can be used to construct a timecode.
  """
  alias Vtc.Timecode
  alias Vtc.Utils.Rational

  @typedoc """
  Result type of `Source.Seconds.seconds/2`.
  """
  @type seconds_result() :: {:ok, Rational.t()} | {:error, Timecode.ParseError.t()}

  defprotocol Seconds do
    alias Vtc.Framerate
    alias Vtc.Source

    @moduledoc """
    Protocol which types can implement to be passed as the main value of
    `with_seconds/2`.

    ## Implementations

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

    ## Returns

    A result tuple with a rational representation of the seconds value using `Ratio` on
    success.
    """
    @spec seconds(t(), Framerate.t()) :: Source.seconds_result()
    def seconds(value, rate)
  end

  defimpl Seconds, for: [Ratio, Integer] do
    alias Vtc.Framerate
    alias Vtc.Private.Parse
    alias Vtc.Source
    alias Vtc.Utils.Rational

    @spec seconds(Rational.t(), Framerate.t()) :: Source.seconds_result()
    def seconds(value, rate), do: Parse.from_seconds_core(value, rate)
  end

  defimpl Seconds, for: Float do
    alias Vtc.Framerate
    alias Vtc.Source

    @spec seconds(float(), Framerate.t()) :: Source.seconds_result()
    def seconds(value, rate), do: value |> Ratio.new(1) |> Seconds.seconds(rate)
  end

  defimpl Seconds, for: [String, BitString] do
    alias Vtc.Framerate
    alias Vtc.Private.Parse
    alias Vtc.Source

    @spec seconds(String.t(), Framerate.t()) :: Source.seconds_result()
    def seconds(value, rate), do: Parse.parse_runtime_string(value, rate)
  end

  @typedoc """
  Result type of `Vtc.Source.Frames.frames/2`.
  """
  @type frames_result() :: {:ok, integer()} | {:error, Timecode.ParseError.t()}

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

    alias Vtc.Framerate
    alias Vtc.Source

    @spec frames(t(), Framerate.t()) :: Source.frames_result()
    def frames(value, rate)
  end

  defimpl Frames, for: Integer do
    alias Vtc.Framerate
    alias Vtc.Source

    @spec frames(integer(), Framerate.t()) :: Source.frames_result()
    def frames(value, _rate), do: {:ok, value}
  end

  defimpl Frames, for: [String, BitString] do
    alias Vtc.Framerate
    alias Vtc.Private.Parse
    alias Vtc.Source

    @spec frames(String.t(), Framerate.t()) :: Source.frames_result()
    def frames(value, rate), do: Parse.parse_frames_string(value, rate)
  end

  @typedoc """
  Result type of `Vtc.Source.PremiereTicks.ticks/2`.
  """
  @type ticks_result() :: {:ok, integer()} | {:error, Timecode.ParseError.t()}

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

    alias Vtc.Framerate
    alias Vtc.Source

    @spec ticks(t(), Framerate.t()) :: Source.ticks_result()
    def ticks(value, rate)
  end

  defimpl PremiereTicks, for: Integer do
    alias Vtc.Framerate
    alias Vtc.Source

    @spec ticks(integer(), Framerate.t()) :: Source.ticks_result()
    def ticks(value, _rate), do: {:ok, value}
  end
end

defmodule Vtc.Private.Parse do
  @moduledoc false

  use Ratio

  alias Vtc.Framerate
  alias Vtc.Private.Consts
  alias Vtc.Private.DropFrame
  alias Vtc.Utils.Rational
  alias Vtc.Source
  alias Vtc.Source.Frames
  alias Vtc.Timecode

  @spec from_seconds_core(Rational.t(), Framerate.t()) :: Source.seconds_result()
  def from_seconds_core(value, rate) do
    case Ratio.div(value, rate.playback) do
      %Ratio{} ->
        frames = rate.playback |> Ratio.mult(value) |> Rational.round()
        {:ok, Ratio.div(frames, rate.playback)}

      integer_value ->
        {:ok, integer_value}
    end
  end

  @spec parse_frames_string(String.t(), Framerate.t()) :: Source.frames_result()
  def parse_frames_string(value, rate) do
    case parse_tc_string(value, rate) do
      {:ok, _} = result -> result
      {:error, %Timecode.ParseError{reason: :bad_drop_frames}} = error -> error
      {:error, _} -> parse_feet_and_frames(value, rate)
    end
  end

  @tc_regex ~r/^(?P<negative>-)?((?P<section_1>[0-9]+)[:|;])?((?P<section_2>[0-9]+)[:|;])?((?P<section_3>[0-9]+)[:|;])?(?P<frames>[0-9]+)$/

  @spec parse_tc_string(String.t(), Framerate.t()) :: Source.frames_result()
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
  @spec tc_sections_to_frames(Timecode.Sections.t(), Framerate.t()) :: Source.frames_result()
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

  @spec parse_feet_and_frames(String.t(), Framerate.t()) :: Source.frames_result()
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

  @spec parse_runtime_string(String.t(), Framerate.t()) :: Source.seconds_result()
  def parse_runtime_string(value, rate) do
    with {:ok, matched} <- apply_regex(@runtime_regex, value) do
      matched
      |> runtime_matched_to_second()
      |> Source.Seconds.seconds(rate)
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
    |> then(fn seconds -> if negative?, do: -seconds, else: seconds end)
  end
end
