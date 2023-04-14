defmodule Vtc.Timecode.ParseError do
  @moduledoc """
  Exception returned when there is an error parsing a Timecode value.

  ## Struct Fields

  - `reason`: The reason the error occurred.

  ## Failure Reasons

  The following values can appear in the `:reason` fields:

  - `:unrecognized_format`: Returned when a string value is not a recognized
      timecode, runtime, etc. format.

  - `:bad_drop_frames`: The field value cannot exist in properly formatted
      drop-frame timecode.
  """
  defexception [:reason]

  @typedoc """
  Type of `Timecode.ParseError`
  """
  @type t() :: %__MODULE__{reason: :unrecognized_format | :bad_drop_frames}

  @doc """
  Returns a message for the error reason.
  """
  @spec message(t()) :: String.t()
  def message(%{reason: :unrecognized_format}), do: "string format not recognized"

  def message(%{reason: :bad_drop_frames}),
    do: "frames value not allowed for drop-frame timecode. frame should have been dropped"
end
