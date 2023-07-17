defmodule Vtc.Ecto.Postgres.Fragments do
  @moduledoc false

  # Calling sub-functions inside of a pl/pgsql function is expensive, and can add up
  # to 20% overhead in a call, the compiler does a bad job of optimizing it away.
  #
  # This module offers some commmon fragments for logic shared between our postgres
  # types that can be inlined into the function definitions.

  @typedoc """
  String.t() alias that hints we are using a raw SQL string.
  """
  @type raw_sql() :: String.t()

  @doc """
  Inline fragment for simplifying a fraction.
  """
  @spec sql_inline_simplify(atom(), atom(), atom()) :: raw_sql()
  def sql_inline_simplify(numerator_var, denominator_var, gcd_var) do
    """
    #{numerator_var} := #{numerator_var} / #{gcd_var};
    #{numerator_var} := #{numerator_var} * SIGN(#{denominator_var});
    #{denominator_var} := ABS(#{denominator_var} / #{gcd_var});
    """
  end
end
