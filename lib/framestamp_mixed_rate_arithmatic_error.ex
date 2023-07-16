defmodule Vtc.Framestamp.MixedRateArithmaticError do
  @moduledoc """
  Exception returned when mixed-rate arithmatic was attempted without specifying which
  side of the operation's rate should be inherited.

  ## Struct Fields

  - `left_rate`: The rate that was found on the left side of the operation.

  - `right_rate`: The rate that was found on the right side of the operation.
  """

  alias Vtc.Framerate

  @enforce_keys [:func_name, :left_rate, :right_rate]
  defexception @enforce_keys

  @typedoc """
  Type of `Framestamp.MixedRateError`.
  """
  @type t() :: %__MODULE__{
          func_name: :add | :sub,
          left_rate: Framerate.t(),
          right_rate: Framerate.t()
        }

  @doc """
  Returns a message for the error reason.
  """
  @spec message(t()) :: String.t()
  def message(error) do
    "attempted `Framestamp.#{error.func_name}(a, b)` where `a.rate` does not match" <>
      " `b.rate`. try `:inherit_rate` option to `:left` or `:right`." <>
      " alternatively, do your calculation in seconds, then cast back to `Framestamp`" <>
      " with the appropriate rate"
  end
end
