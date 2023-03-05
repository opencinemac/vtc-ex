defmodule Vtc.Private.Rational do
  @moduledoc false

  use Ratio, comparison: true

  @spec round_ratio?(Ratio.t()) :: integer
  def round_ratio?(%Ratio{} = x) do
    floored = floor(x)
    remainder = x - floored

    rounded =
      if remainder > Ratio.new(1, 2) do
        floored + 1
      else
        floored
      end

    rounded
  end

  @spec round_ratio?(integer) :: integer
  def round_ratio?(x) when is_integer(x) do
    x
  end

  @spec divmod(Ratio.t() | integer, Ratio.t() | integer) :: {integer, Ratio.t() | integer}
  def divmod(a, b) do
    dividend = floor(a / b)
    multiplied = dividend * b
    remainder = a - multiplied
    {dividend, remainder}
  end
end
