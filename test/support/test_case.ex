defmodule Vtc.Test.Support.TestCase do
  @moduledoc false
  alias Vtc.Framerate
  alias Vtc.Range
  alias Vtc.Rates
  alias Vtc.Source.Frames
  alias Vtc.Source.Frames.FeetAndFrames
  alias Vtc.Source.Seconds.PremiereTicks
  alias Vtc.Timecode

  @spec __using__(Keyword.t()) :: Macro.t()
  defmacro __using__(_) do
    quote do
      use ExUnit.Case, async: true

      import Vtc.Test.Support.TestCase

      require Vtc.Test.Support.TestCase
    end
  end

  # Common utilities for ExUnit tests.

  @spec test_id(String.t()) :: String.t()
  def test_id(test_name), do: :md5 |> :crypto.hash(test_name) |> Base.encode16(case: :lower) |> String.slice(0..16)

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

  # Negates secified ranges built by setup_ranges.
  @spec setup_negates(%{optional(:negate) => [Map.key()]}) :: Keyword.t()
  def setup_negates(%{negate: attrs} = context) do
    context
    |> Map.take(attrs)
    |> Enum.into([])
    |> Enum.map(fn {name, value} -> {name, setup_negate(value)} end)
  end

  def setup_negates(context), do: context

  @spec setup_negate(input) :: input | {:error, any()} when input: any()
  defp setup_negate(%Range{} = range) do
    %Range{in: in_tc, out: out_tc} = range
    %Range{range | in: Timecode.minus(out_tc), out: Timecode.minus(in_tc)}
  end

  defp setup_negate(%Timecode{} = timecode), do: Timecode.minus(timecode)
  defp setup_negate(%Ratio{} = ratio), do: Ratio.minus(ratio)
  defp setup_negate(%PremiereTicks{in: ticks}), do: %PremiereTicks{in: -ticks}

  defp setup_negate(%FeetAndFrames{feet: feet, frames: frames} = val),
    do: %FeetAndFrames{val | feet: -feet, frames: -frames}

  defp setup_negate(number) when is_number(number), do: -number
  defp setup_negate(string) when is_binary(string), do: "-#{string}"
  defp setup_negate({:error, _} = value), do: value

  @spec table_test(String.t(), Macto.t(), Macro.t(), do: Macro.t()) :: Macro.t()
  defmacro table_test(name, test_case, context, do: body) do
    quote do
      name = "#{unquote(name)}"
      id = test_id(name)

      @tag test_case: unquote(test_case)
      @tag test_id: id
      test "#{name} | id: #{id}", unquote(context) do
        unquote(body)
      end
    end
  end
end
