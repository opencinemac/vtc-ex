if Application.get_env(:vtc, :env) in [:test, :dev] do
  defmodule Vtc.TestUtls.StreamDataVtc do
    @moduledoc """
    `StreamData` generators for use in tests that involve custom Ecto types. For use in
    property tests.

    This module is only available in `:test` and `:dev` envs.
    """

    alias Vtc.Framerate
    alias Vtc.Timecode

    @doc """
    Yields rational values as %Ratio{} structs.

    ## Options

    - `numerator`: A static value to use for the numerator of all genrated rationals.
      Default: nil.

    - `denominator`: A static value to use for the denominator of all genrated rationals.
      Default: nil.

    - `positive?`: If true, only positive values (greater than 0) are generated.
      Default: `false`.

    ## Examples

    ```elixir
    property "prop test" do
      check all(fraction <- StreamDataVtc.rational()) do
        ...
      end
    end
    ```
    """
    @spec rational(numerator: integer(), denominator: pos_integer(), positive?: boolean()) :: StreamData.t(Ratio.t())
    def rational(opts \\ []) do
      numerator = Keyword.get(opts, :numerator)
      denominator = Keyword.get(opts, :denominator)
      positive? = Keyword.get(opts, :positive?, false)

      numerator_gen = if positive?, do: StreamData.positive_integer(), else: StreamData.integer()
      numerator_gen = if is_integer(numerator), do: StreamData.constant(numerator), else: numerator_gen

      denominator_gen =
        if is_integer(denominator), do: StreamData.constant(denominator), else: StreamData.positive_integer()

      {numerator_gen, denominator_gen}
      |> StreamData.tuple()
      |> StreamData.map(fn {numerator, denominator} ->
        Ratio.new(numerator, denominator)
      end)
    end

    @typedoc """
    Describes the opts that can be passed to `framerate/1`.
    """
    @type rate_opts() :: [type: :whole | :fractional | :drop | :non_drop]

    @doc """
    Yields Vtc.Framerates, always yields true-frame or NTSC; never a mixture of the two.

    ## Options

    - `type`: The ntsc value all framerates should be generated with. Can be any of the
      following:

        - `:whole`: All yielded framerates will be non-ntsc, whole-frame rates. Ex: 24/1
          fps.
        - `:fractional`: All yielded framerates will be a random non-drop rate.
        - `:non_drop`: All yielded framerates will be NTSC, non-drop values.
        - `:drop`: All yielded framerates will be NTSC, drop-frame values.

        A list of the above options may be passed and each value yielded from this
        generator will pick randomly from them.

        Defaults to `[:whole, :fractional, :non_drop, :drop]`

    ## Examples

    ```elixir
    property "prop test" do
      check all(framerate <- StreamDataVtc.framerate()) do
        ...
      end
    end
    ```
    """
    @spec framerate(rate_opts()) :: StreamData.t(Framerate.t())
    def framerate(opts \\ []) do
      ntscs =
        case Keyword.get(opts, :type, [:whole, :fractional, :non_drop, :drop]) do
          ntscs when is_list(ntscs) -> ntscs
          ntsc -> [ntsc]
        end

      ntsc_gen =
        ntscs
        |> Enum.map(&StreamData.constant(&1))
        |> StreamData.one_of()

      numerator_gen = StreamData.positive_integer()
      denominator_gen = StreamData.positive_integer()
      drop_mult_gen = StreamData.integer(1..10)

      {numerator_gen, denominator_gen, drop_mult_gen, ntsc_gen}
      |> StreamData.tuple()
      |> StreamData.map(fn
        {numerator, _, _, :whole} ->
          numerator |> Ratio.new(1) |> Framerate.new!(ntsc: nil)

        {numerator, denominator, _, :fractional} ->
          numerator |> Ratio.new(denominator) |> Framerate.new!(ntsc: nil)

        {_, _, multiplier, :drop} ->
          multiplier = Ratio.new(multiplier, 1)
          30_000 |> Ratio.new(1001) |> Ratio.mult(multiplier) |> Framerate.new!(ntsc: :drop)

        {numerator, _, _, :non_drop} ->
          (numerator * 1000) |> Ratio.new(1001) |> Framerate.new!(ntsc: :non_drop)
      end)
    end

    @doc """
    Yields Vtc.Timecode values, always yields true-frame or NTSC; never a mixture of the
    two.

    ## Options

    - `non_negative?`: Will only return values greater than or equal to `00:00:00:00`.

    - `rate`: A framerate to use for this test. If one is not provided, a random one will
      be used.

    - `rate_opts`: Opts that should be passed to `framerate/1` when generating the
      framerate. Has no effect if `rate` is set.

    ## Examples

    ```elixir
    property "returns input of negate/1" do
      check all(positive <- StreamDataVtc.timecode(non_negative?: true)) do
        negative = Timecode.minus(positive)
        assert Timecode.abs(positive) == Timecode.abs(negative)
      end
    end
    ```
    """
    @spec timecode(non_negative?: boolean(), rate: Framerate.t(), rate_opts: rate_opts()) :: StreamData.t(Timecode.t())
    def timecode(opts \\ []) do
      non_negative? = Keyword.get(opts, :non_negative?, false)
      rate = Keyword.get(opts, :rate)
      rate_opts = Keyword.get(opts, :rate_opts, [])

      frames_gen = StreamData.integer(0..20_736_000)

      frames_gen =
        if non_negative?, do: StreamData.filter(frames_gen, &(&1 >= 0)), else: StreamData.integer(0..20_736_000)

      framerate_gen =
        case rate do
          %Framerate{} -> StreamData.constant(rate)
          nil -> framerate(rate_opts)
        end

      {frames_gen, framerate_gen}
      |> StreamData.tuple()
      |> StreamData.map(fn {frames, framerate} ->
        Timecode.with_frames!(frames, framerate)
      end)
    end
  end
end
