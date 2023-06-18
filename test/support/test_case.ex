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

      import Vtc.Test.Support.TestCase, only: [table_test: 4, table_test: 5]

      alias Vtc.Test.Support.TestCase

      require TestCase

      setup context, do: TestCase.setup_test_case(context)
    end
  end

  # Common utilities for ExUnit tests.

  @doc """
  Generates an id for a test case by hashing it's name + data.
  """
  @spec test_id(String.t(), map()) :: String.t()
  def test_id(name, test_case) do
    test_case_binary = :erlang.term_to_binary(test_case)
    :md5 |> :crypto.hash(name <> test_case_binary) |> Base.encode16(case: :lower) |> String.slice(0..16)
  end

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

  @doc """
  Mathematically negates a list of keys in the context.

  Pass keys to a test by decorating it with `@tag negate: [keys]`
  """
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

  @doc """
  Creates one ex-unit test for each test case in `test_cases` using the `table_test`
  macro.

  Must have `setup_test_case/1` registered as an ExUnit setup function.

  `test_cases` must unquote to a list of atom-keyed maps. The context/test_case data of
  each test will be set to the variable passed to `test_case` and can be used just
  like a normal ExUnit test context.

  For each test generated:

  - A `@tag test_case: test_case` value is placed above the test to pass the test case
    into the context using `setup_test_case`.

  - A `@tag test_id: {unique_id}` value is palces above the test to make running an
    individual test easier. This ID is static against runs so long as the test name and
    data do not change.

  - The test_id is added to the end of the name of the test.

  ## Example

  ```elixir
  test_cases = [
    %{a: 1, sb: 1, expected: 2},
    %{a: 5, b: 5, expected: 10}
  ]

  table_test "<%= a > + <%= b > == <%= expected >", test_cases, test_case do
    assert test_case.a + test_case.b == test_case.expected
  end
  ```

  The above example would generate 2 tests, loading the data for each map into the
  ExUnit context captured by the `test_case` variable.

  ## Test Names

  You can use test data in the name of your table test using the EEx `<%= field >`
  convention. When the test is generated, each test name will be rendered with the
  data from that particular case. For example:

  ```elixir
  tests_table = [
    %{a: 1, b: 1, expected: 2},
    %{a: 5, b: 5, expected: 10}
  ]

  table_test "<%= a > + <%= b > == <%= expected >", tests_table, test_case do
    assert test_case.a + test_case.b == test_case.expected
  end
  ```

  ... would generate two tests. The first named:

  ```elixir
  "1 + 1 == 2"
  ```

  And the second named:

  ```elixir
  "5 + 5 == 10"
  ```

  Unlike normal EEx interpolation, `inspect/1` is called on the relevant data before
  it is rendered to a string, so any value can be used, not just those that implement
  `String.Chars`.

  The data must be fetchable from the test case using an `atom` key.

  ## Conditional tests

  You may not with to run every case of a given table. You can pass an expression to
  the `:if` option to be evaluated. If the expression resolves to `false`, the test will
  be skipped.

  The argument name passed to `test_case` may be used as part of this expression.
  """
  @spec table_test(String.t(), Macro.t(), Macro.t(), Keyword.t(Macro.t()), do: Macro.t()) :: Macro.t()
  defmacro table_test(name, table, test_case, opts \\ [], do: body) do
    condition = Keyword.get(opts, :if, true)

    quote do
      tags = Module.get_attribute(__MODULE__, :tag, [])
      Module.delete_attribute(__MODULE__, :tag)

      for unquote(test_case) <- unquote(table) do
        if unquote(condition) do
          for tag <- tags do
            @tag tag
          end

          unquote(__MODULE__).run_table_test_case unquote(name), unquote(test_case) do
            unquote(body)
          end
        end
      end
    end
  end

  # Runs a single test case for `table_test`.
  @spec run_table_test_case(String.t(), Macto.t(), do: Macro.t()) :: Macro.t()
  defmacro run_table_test_case(name, test_case, do: body) do
    case test_case do
      {name, _, nil} = var when is_atom(name) -> var
      _ -> throw("`test_case` must be map var loaded with test data")
    end

    quote do
      name = unquote(__MODULE__).table_test_render_name(unquote(name), unquote(test_case))
      id = unquote(__MODULE__).test_id(name, unquote(test_case))

      @tag test_case: unquote(test_case)
      @tag test_id: id
      test "#{name} | id: #{id}", unquote(test_case) do
        unquote(body)
      end
    end
  end

  @spec table_test_render_name(String.t(), %{atom() => any()}) :: String.t()
  def table_test_render_name(name, test_case) do
    {:ok, tokens} = EEx.tokenize(name, trim: true)

    fields =
      tokens
      |> Enum.filter(fn
        {:expr, operator, _, _} when operator in [~c"="] -> true
        _ -> false
      end)
      |> Enum.map(fn {:expr, _, field_name, _} ->
        field_name |> String.Chars.to_string() |> String.trim() |> String.to_existing_atom()
      end)

    bindings =
      test_case
      |> Map.take(fields)
      |> Enum.map(fn {key, value} -> {key, inspect(value)} end)
      |> Keyword.new()

    EEx.eval_string(name, bindings)
  end
end
