defmodule Vtc.Utils.Rational do
  @moduledoc false

  @typedoc """
  The Ratio module will often convert itself to an integer value if the result would be
  a whole number, but otherwise return a %Ratio{} struct.

  This type can be used when working with such a value.
  """
  @type t() :: Ratio.t() | integer()

  @doc """
  Rounds `x` based on `method`.

  ## Arguments

  - `x`: The Rational value to round.

  - `method`: Rounding strategy. Defaults to `:closest`.

    - `:closest`: Round the to the closet whole frame, rounding up when fractional
      remainder is equal to `1/2`.

    - `:floor`: Always round down to the closest whole-frame.

    - `:ciel`: Always round up to the closest whole-frame.

    - `:off`: Pass value through without rounding.
  """
  @spec round(t(), :closest | :floor | :ceil) :: integer()
  @spec round(t(), :off) :: t()
  def round(x, method \\ :closest)
  def round(x, _) when is_integer(x), do: x
  def round(%{numerator: n, denominator: d}, :closest), do: round_closest(n, d)
  def round(x, :floor), do: Ratio.floor(x)
  def round(x, :ceil), do: Ratio.ceil(x)
  def round(x, :off), do: x

  # Handles roundinf to the closest integer. Adapted loosly from Python's
  # implementation, only rounds up rather than down:
  # https://github.com/python/cpython/blob/3.11/Lib/fractions.py
  @spec round_closest(integer(), pos_integer()) :: integer()
  defp round_closest(n, d) when n < 0, do: -round_closest(-n, d)
  defp round_closest(n, d) when rem(n, d) * 2 < d, do: div(n, d)
  defp round_closest(n, d), do: div(n, d) + 1

  @doc """
  Does the divrem operation on a rational vale, returns a
  {whole_dividend, rational_remainder} tuple.
  """
  @spec divrem(t(), t()) :: {integer(), t()}
  def divrem(x, divisor) when is_integer(x) and x < 0,
    do: divrem(%Ratio{numerator: x, denominator: 1}, divisor)

  def divrem(%{numerator: n} = dividend, divisor) when n < 0,
    do: dividend |> Ratio.abs() |> divrem(divisor) |> then(fn {q, r} -> {-q, r} end)

  def divrem(dividend, divisor) do
    quotient = dividend |> Ratio.div(divisor) |> Ratio.floor()
    remainder = Ratio.sub(dividend, Ratio.mult(divisor, quotient))
    {quotient, remainder}
  end
end
