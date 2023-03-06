defmodule Vtc.Utils.Rational do
  @moduledoc """
  Helper functions and types for working with the Ratio module.
  """

  @typedoc """
  The Ratio module will often convert itself to an integer value if the result would be
  a whole number, but otherwise return a %Ratio{} struct.

  This type can be used when working with such a value.
  """
  @type t() :: Ratio.t() | integer()

  @doc """
  Rounds a Ratio to the nearest integer.
  """
  @spec round(t()) :: integer()
  def round(x) when is_integer(x), do: x

  def round(%Ratio{} = x) do
    floored = Ratio.floor(x)
    remainder = Ratio.sub(x, floored)

    case Ratio.compare(remainder, Ratio.new(1, 2)) do
      :gt -> Ratio.add(floored, 1)
      _ -> floored
    end
  end

  @doc """
  Does the divmod operation on a rational vale, returns a
  {whole_dividend, rational_rainder} tuple.
  """
  @spec divmod(t(), t()) :: {integer(), t()}
  def divmod(a, b) do
    dividend = a |> Ratio.div(b) |> Ratio.floor()
    multiplied = Ratio.mult(dividend, b)
    remainder = Ratio.sub(a, multiplied)
    {dividend, remainder}
  end
end