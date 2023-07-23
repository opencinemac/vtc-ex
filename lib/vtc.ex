defmodule Vtc do
  @moduledoc """
  Global, top level utilities for Vtc.

  For this library's core functionality, see these modules:

  - [Framestamp](`Vtc.Framestamp`)
  - [Framestamp.Range](`Vtc.Framestamp.Range`)
  - [Framerate](`Vtc.Framerate`)
  - [Rates](`Vtc.Rates`)
  """

  alias Vtc.Framerate
  alias Vtc.Framestamp

  @doc """
  Returns `true` if `error` is an exception that was returned by a `Vtc` function.
  """
  @spec is_error?(any()) :: boolean()
  def is_error?(%Framestamp.MixedRateArithmeticError{}), do: true
  def is_error?(%Framestamp.ParseError{}), do: true
  def is_error?(%Framerate.ParseError{}), do: true
  def is_error?(%Framestamp.Range.MixedOutTypeArithmeticError{}), do: true
  def is_error?(_), do: false
end
