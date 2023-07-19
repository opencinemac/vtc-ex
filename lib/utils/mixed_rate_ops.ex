defmodule Vtc.Utils.MixedRateOps do
  @moduledoc false

  alias Vtc.Framerate
  alias Vtc.Framestamp
  alias Vtc.Framestamp.MixedRateArithmeticError
  alias Vtc.Source.Frames

  # Gets a the correct rate for a mixed rate operation.
  @doc false
  @spec get_rate(
          Framestamp.t() | Frames.t(),
          Framestamp.t() | Frames.t(),
          Framestamp.inherit_opt(),
          func_name :: atom()
        ) :: {:ok, Framerate.t()} | {:error, MixedRateArithmeticError.t()}
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
        ) :: :ok | {:error, MixedRateArithmeticError.t()}
  defp get_rate_validate(%Framestamp{rate: rate}, %Framestamp{rate: rate}, _, _), do: :ok
  defp get_rate_validate(_, _, :left, _), do: :ok
  defp get_rate_validate(_, _, :right, _), do: :ok
  defp get_rate_validate(_, b, _, _) when not is_struct(b, Framestamp), do: :ok
  defp get_rate_validate(a, _, _, _) when not is_struct(a, Framestamp), do: :ok

  defp get_rate_validate(a, b, _, func_name),
    do: {:error, %MixedRateArithmeticError{func_name: func_name, left_rate: a.rate, right_rate: b.rate}}
end
