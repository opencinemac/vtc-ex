defmodule Vtc.Framerate.InvalidSMPTEValueError do
  @moduledoc """
  Exception returned when a function expects a valid SMPTE framerate.

  Valid SMPTE rates are:

  - Non-drop NTSC framerates. Must be cleanly divisible by 1001.
  - Drop-frame framerates. Must be cleanly divisible by 30_000/1001.
  - Whole-frame framerates such as 24fps.
  """
  defexception []

  @typedoc """
  Type of `InvalidSMPTERate`.
  """
  @type t() :: %__MODULE__{}

  @doc """
  Exception message.
  """
  @spec message(t()) :: String.t()
  def message(_), do: "framerate not valid SMPTE value. Must be non-drop, drop, or whole-frame."
end
