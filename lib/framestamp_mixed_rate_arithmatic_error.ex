defmodule Vtc.Framestamp.MixedRateArithmeticError do
  @moduledoc """
  Exception returned when mixed-rate arithmetic was attempted without specifying which
  side of the operation's rate should be inherited.

  ## Struct Fields

  - `left_rate`: The rate that was found on the left side of the operation.

  - `right_rate`: The rate that was found on the right side of the operation.
  """

  alias Vtc.Framerate
  alias Vtc.Framestamp
  alias Vtc.Source.Frames

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

  # Gets a the correct rate for a mixed rate operation.
  @doc false
  @spec get_rate(
          Framestamp.t() | Frames.t(),
          Framestamp.t() | Frames.t(),
          Framestamp.inherit_opt(),
          func_name :: atom()
        ) :: {:ok, Framerate.t()} | {:error, t()}
  def get_rate(a, b, opt, func_name) do
    with :ok <- get_rate_validate(a, b, opt, func_name) do
      case {a, b, opt} do
        {%Framestamp{rate: rate}, _, :left} -> {:ok, rate}
        {_, %Framestamp{rate: rate}, _} -> {:ok, rate}
        {%Framestamp{rate: rate}, _, _} -> {:ok, rate}
      end
    end
  end

  @spec get_rate_validate(
          Framestamp.t() | Frames.t(),
          Framestamp.t() | Frames.t(),
          Framestamp.inherit_opt(),
          func_name :: atom()
        ) ::
          :ok | {:error, t()}
  defp get_rate_validate(%Framestamp{rate: rate}, %Framestamp{rate: rate}, _, _), do: :ok
  defp get_rate_validate(_, _, :left, _), do: :ok
  defp get_rate_validate(_, _, :right, _), do: :ok
  defp get_rate_validate(_, b, _, _) when not is_struct(b, Framestamp), do: :ok
  defp get_rate_validate(a, _, _, _) when not is_struct(a, Framestamp), do: :ok

  defp get_rate_validate(a, b, _, func_name),
    do: {:error, %__MODULE__{func_name: func_name, left_rate: a.rate, right_rate: b.rate}}
end
