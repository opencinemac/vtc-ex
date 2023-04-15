defmodule Vtc.Framerate.ParseError do
  @moduledoc """
  Exception returned when a framerate cannot be parsed.

  ## Struct Fields

  - `reason`: The reason the error occurred.

  ## Failure Reasons

  The following values can appear in the `:reason` fields:

  - `:bad_drop_rate`: Returned when the playback speed of a framerate with an ntsc
      value of :drop is not divisible by 3000/1001 (29.97), for more on why drop-frame
      framerates must be a multiple of 29.97, see:
      https://www.davidheidelberger.com/2010/06/10/drop-frame-timecode/

  - `:invalid_ntsc`: Returned when the ntsc value is not one of the allowed atom
    values.

  - `:unrecognized_format`: Returned when a string value is not a recognized format.

  - `:imprecise` - Returned when a float was passed with an NTSC value of nil.
    Without the ability to round to the nearest valid NTSC value, floats are not
    precise enough to build an arbitrary framerate.
  """
  defexception [:reason]

  @typedoc """
  Type of `ParseError`
  """
  @type t() :: %__MODULE__{
          reason: :bad_drop_rate | :invalid_ntsc | :unrecognized_format | :imprecise
        }

  @doc """
  Returns a message for the error reason.
  """
  @spec message(t()) :: String.t()
  def message(%{reason: :bad_drop_rate}), do: "drop-frame rates must be divisible by 30000/1001"
  def message(%{reason: :invalid_ntsc}), do: "ntsc is not a valid atom. must be :non_drop, :drop, or nil"
  def message(%{reason: :unrecognized_format}), do: "framerate string format not recognized"
  def message(%{reason: :imprecise}), do: "non-whole floats are not precise enough to create a non-NTSC Framerate"
end
