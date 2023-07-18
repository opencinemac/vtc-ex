defmodule Vtc.Framestamp.Range.MixedOutTypeArithmeticError do
  @moduledoc """
  Exception returned when mixed-out-type arithmetic was attempted without specifying
  which side of the operation's out type should be inherited.

  ## Struct Fields

  - `left_out_type`: The out type that was found on the left side of the operation.

  - `right_out_type`: The out type that was found on the right side of the operation.
  """
  alias Vtc.Framestamp

  @enforce_keys [:func_name, :left_out_type, :right_out_type]
  defexception @enforce_keys

  @typedoc """
  Type of `Framestamp.Range.MixedOutTypeArithmeticError`.
  """
  @type t() :: %__MODULE__{
          func_name: atom(),
          left_out_type: Framestamp.Range.out_type(),
          right_out_type: Framestamp.Range.out_type()
        }

  @doc """
  Returns a message for the error reason.
  """
  @spec message(t()) :: String.t()
  def message(error) do
    "attempted `Framestamp.Range.#{error.func_name}(a, b)` where `a.out_type` does not match" <>
      " `b.out_type`. try `:inherit_out_type` option to `:left` or `:right`"
  end
end
