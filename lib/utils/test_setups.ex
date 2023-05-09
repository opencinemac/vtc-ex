defmodule Vtc.TestSetups do
  @moduledoc false

  alias Vtc.Framerate
  alias Vtc.Rates
  alias Vtc.Source.Frames
  alias Vtc.Timecode

  # Common utilities for ExUnit tests.

  @spec test_id(String.t()) :: String.t()
  def test_id(test_name), do: :md5 |> :crypto.hash(test_name) |> Base.encode16()

  @doc """
  Extracts a map in `:test_case` and merges it into the top-level context.
  """
  @spec setup_test_case(%{optional(:test_case) => map()}) :: map()
  def setup_test_case(%{test_case: test_case} = context), do: Map.merge(context, test_case)
  def setup_test_case(context), do: context

  @doc """
  Sets up timecodes found in any context fields listed in the `:timecodes` context
  field.
  """
  @spec setup_timecodes(map()) :: Keyword.t()
  def setup_timecodes(context) do
    timecode_fields = Map.get(context, :timecodes, [])
    timecodes = Map.take(context, timecode_fields)

    Enum.map(timecodes, fn {field_name, value} -> {field_name, setup_timecode(value)} end)
  end

  @spec setup_timecode(Frames.t() | {Frames.t(), Framerate.t()}) :: Timecode.t()
  defp setup_timecode({frames, rate}), do: Timecode.with_frames!(frames, rate)
  defp setup_timecode(frames), do: setup_timecode({frames, Rates.f23_98()})
end
