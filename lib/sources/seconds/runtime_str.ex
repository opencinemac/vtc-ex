defmodule Vtc.Source.Seconds.RuntimeStr do
  @moduledoc """
  Implementation of [Seconds](`Vtc.Source.Seconds`) for runtime strings. See
  `Vtc.Framestamp.runtime/2` for more information on this format.

  By default, this wrapper does not need to be used by callers, as the string
  implementation of the [Seconds](`Vtc.Source.Seconds`) protocol calls this type's impl
  automatically. Only use this type if you do not wish for the parser to fall back to
  other type parsing as well.
  """

  alias Vtc.Framestamp
  alias Vtc.Utils.Consts

  @enforce_keys [:in]
  defstruct [:in]

  @typedoc """
  Contains only a single field for wrapping the underlying string.
  """
  @type t() :: %__MODULE__{in: String.t()}

  @doc false
  @spec from_framestamp(Framestamp.t(), precision: non_neg_integer(), trim_zeros?: boolean()) :: t()
  def from_framestamp(framestamp, opts) do
    precision = Keyword.get(opts, :precision, 9)
    trim_zeros = Keyword.get(opts, :trim_zeros?, true)

    {seconds, negative?} =
      if Ratio.lt?(framestamp.seconds, 0),
        do: {Ratio.minus(framestamp.seconds), true},
        else: {framestamp.seconds, false}

    seconds = Decimal.div(Ratio.numerator(seconds), Ratio.denominator(seconds))

    {hours, seconds} = Decimal.div_rem(seconds, Consts.seconds_per_hour())
    {minutes, seconds} = Decimal.div_rem(seconds, Consts.seconds_per_minute())

    Decimal.Context
    seconds = Decimal.round(seconds, precision)
    seconds_floor = Decimal.round(seconds, 0, :down)
    fractal_seconds = Decimal.sub(seconds, seconds_floor)

    hours = hours |> Decimal.to_integer() |> Integer.to_string() |> String.pad_leading(2, "0")
    minutes = minutes |> Decimal.to_integer() |> Integer.to_string() |> String.pad_leading(2, "0")

    seconds_floor = seconds_floor |> Decimal.to_integer() |> Integer.to_string() |> String.pad_leading(2, "0")

    fractal_seconds = runtime_render_fractal_seconds(fractal_seconds, trim_zeros)

    # We'll add a negative sign if the framestamp is negative.
    sign = if negative?, do: "-", else: ""

    %__MODULE__{in: "#{sign}#{hours}:#{minutes}:#{seconds_floor}#{fractal_seconds}"}
  end

  # Renders fractal seconds to a string.
  @spec runtime_render_fractal_seconds(Decimal.t(), boolean()) :: String.t()
  defp runtime_render_fractal_seconds(seconds_fractal, trim_zeros?) do
    rendered = seconds_fractal |> Decimal.to_string(:normal) |> String.trim_leading("0")
    rendered = if trim_zeros?, do: String.trim_trailing(rendered, "0"), else: rendered

    case rendered do
      "." -> ".0"
      rendered -> rendered
    end
  end
end

defimpl Vtc.Source.Seconds, for: Vtc.Source.Seconds.RuntimeStr do
  @moduledoc """
  Implements [Seconds](`Vtc.Source.Seconds`) protocol for Premiere ticks.
  """

  alias Vtc.Framerate
  alias Vtc.Source.Seconds
  alias Vtc.Source.Seconds.RuntimeStr
  alias Vtc.Utils.Consts
  alias Vtc.Utils.Parse

  @runtime_regex ~r/^(?P<negative>-)?((?P<section_1>[0-9]+)[:|;])?((?P<section_2>[0-9]+)[:|;])?(?P<seconds>[0-9]+(\.[0-9]+)?)$/

  @spec seconds(RuntimeStr.t(), Framerate.t()) :: Seconds.result()
  def seconds(runtime_str, rate) do
    with {:ok, matched} <- Parse.apply_regex(@runtime_regex, runtime_str.in) do
      matched
      |> runtime_matched_to_second()
      |> Seconds.seconds(rate)
    end
  end

  @spec runtime_matched_to_second(map()) :: Ratio.t()
  defp runtime_matched_to_second(matched) do
    negative? = Map.fetch!(matched, "negative") == "-"
    sections = Parse.extract_time_sections(matched, 2)

    {minutes, sections} = Parse.pop_time_section(sections)
    {hours, _} = Parse.pop_time_section(sections)

    seconds_for_hours = Ratio.new(hours * Consts.seconds_per_hour())
    minutes_for_hours = Ratio.new(minutes * Consts.seconds_per_minute())

    matched
    |> Map.fetch!("seconds")
    |> Decimal.new()
    |> Ratio.new()
    |> Ratio.add(seconds_for_hours)
    |> Ratio.add(minutes_for_hours)
    |> then(fn seconds -> if negative?, do: Ratio.minus(seconds), else: seconds end)
  end
end
