defmodule Vtc.Utils.Rational do
  @moduledoc false

  import Kernel, except: [rem: 2]

  @doc """
  Rounds `x` based on `method`.

  ## Arguments

  - `x`: The Rational value to round.

  - `method`: Rounding strategy. Defaults to `:closest`.

    - `:closest`: Round the to the closet whole frame, rounding up when fractional
      remainder is equal to `1/2`.

    - `:floor`: Always round down to the closest whole-frame.

    - `:ciel`: Always round up to the closest whole-frame.

    - `:trunc`: Always rounds towards zero.

    - `:off`: Pass value through without rounding.
  """
  @spec round(Ratio.t(), :closest | :floor | :ceil | :trunc) :: integer()
  @spec round(Ratio.t(), :off) :: Ratio.t()
  def round(x, method \\ :closest)
  def round(%{numerator: n, denominator: d}, :closest), do: round_closest(n, d)
  def round(x, :floor), do: Ratio.floor(x)
  def round(x, :ceil), do: Ratio.ceil(x)
  def round(x, :trunc), do: Ratio.trunc(x)
  def round(x, :off), do: x

  # Handles rounding to the closest integer. Adapted loosely from Python's
  # implementation, only rounds up rather than down:
  # https://github.com/python/cpython/blob/3.11/Lib/fractions.py
  @spec round_closest(integer(), pos_integer()) :: integer()
  defp round_closest(n, d) when n * d < 0, do: -round_closest(-n, d)
  defp round_closest(n, d) when Kernel.rem(n, d) * 2 < d, do: div(n, d)
  defp round_closest(n, d), do: div(n, d) + 1

  @doc """
  Does the divrem operation on a rational vale, returns a
  {whole_dividend, rational_remainder} tuple.
  """
  @spec divrem(Ratio.t(), Ratio.t() | number()) :: {integer(), Ratio.t()}
  def divrem(dividend, divisor) do
    dividend = Ratio.new(dividend)
    divisor = Ratio.new(divisor)

    # Round towards zero instead of infinity
    quotient = dividend |> Ratio.div(divisor) |> then(&div(&1.numerator, &1.denominator))
    remainder = rem(dividend, divisor)
    {quotient, remainder}
  end

  @spec rem(Ratio.t(), Ratio.t()) :: Ratio.t()
  def rem(dividend, divisor) do
    numerator = Kernel.rem(dividend.numerator * divisor.denominator, divisor.numerator * dividend.denominator)
    denominator = dividend.denominator * divisor.denominator

    result = Ratio.new(numerator, denominator)

    if dividend.numerator < 0 do
      %Ratio{numerator: abs(result.numerator) * -1, denominator: result.denominator}
    else
      result
    end
  end
end
