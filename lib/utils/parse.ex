defmodule Vtc.Utils.Parse do
  @moduledoc false

  alias Vtc.Timecode

  @doc """
  Applies regex and returns the appropriate error when not correct.
  """
  @spec apply_regex(Regex.t(), String.t()) :: {:ok, map()} | {:error, Timecode.ParseError.t()}
  def apply_regex(regex, value) do
    regex
    |> Regex.named_captures(value)
    |> then(fn
      matched when is_map(matched) -> {:ok, matched}
      nil -> {:error, %Timecode.ParseError{reason: :unrecognized_format}}
    end)
  end

  @doc """
  Extracts a set of sections in a time string of format xx:yy:.. that may or may not
  be truncated at the head.

  The regex matches are expected to have a series of fields like "section_1",
  "section_2", etc that denote present sections whose meaning depends on the  number
  of sections present.
  """
  @spec extract_time_sections(map(), non_neg_integer()) :: [String.t()]
  def extract_time_sections(regex_matches, section_count) do
    1..section_count
    |> Enum.map(&Integer.to_string/1)
    |> Enum.reduce([], fn section_index, sections ->
      case Map.fetch!(regex_matches, "section_#{section_index}") do
        "" -> sections
        this_section -> [this_section | sections]
      end
    end)
  end

  @doc """
    Pops the next section at the end of the list and returns it as an integer.

    Returns `0` if the value is not present
  """
  @spec pop_time_section([String.t()]) :: {integer(), [String.t()]}
  def pop_time_section(["" | remaining]), do: {0, remaining}
  def pop_time_section([value | remaining]), do: {String.to_integer(value), remaining}
  def pop_time_section([]), do: {0, []}
end
