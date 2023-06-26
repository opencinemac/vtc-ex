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
  Type of `Timecode.ParseError`.
  """
  @type t() :: %__MODULE__{
          reason: :unrecognized_format | :bad_drop_frames | :drop_frame_maximum_exceeded | :partial_frame
        }

  @doc """
  Returns a message for the error reason.
  """
  @spec message(t()) :: String.t()
  def message(%{reason: :unrecognized_format}), do: "string format not recognized"

  def message(%{reason: :bad_drop_frames}),
    do: "frames value not allowed for drop-frame timecode. frame should have been dropped"

  def message(%{reason: :partial_frame}),
    do:
      "`seconds` is not cleanly divisible by `rate.playback`." <>
        " This check can be turned off by setting `:allow_partial_frames?` to `true`"

  def message(%{reason: :drop_frame_maximum_exceeded}), do: "frame number exceeded 24 hours for drop-frame timecode"
end
