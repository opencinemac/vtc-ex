defmodule Vtc.Timecode.Sections do
  @moduledoc """
  Holds the individual sections of a timecode for formatting / manipulation.

  ## Struct Fields

  - `negative`: Whether the timecode is less than 0.
  - `hours`: Hours place value.
  - `minutes`: Minutes place value. This is not the toal minutes, but the minutes added
    to `hours` to get a final time.
  - `seconds`: Seconds place value. As minutes, remainder value rather than total
    value.
  - `frames`: Frames place value. As seconds, remainder value rather than total
    value.
  """

  @enforce_keys [:negative?, :hours, :minutes, :seconds, :frames]
  defstruct [:negative?, :hours, :minutes, :seconds, :frames]

  @typedoc """
  Struct type.
  """
  @type t :: %__MODULE__{
          negative?: boolean(),
          hours: integer(),
          minutes: integer(),
          seconds: integer(),
          frames: integer()
        }
end
