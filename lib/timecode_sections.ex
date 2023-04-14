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

  alias Vtc.Framerate
  alias Vtc.Timecode
  alias Vtc.Utils.Consts
  alias Vtc.Utils.DropFrame
  alias Vtc.Utils.Rational

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

  @doc false
  @spec from_timecode(Timecode.t(), opts :: [round: Timecode.round()]) :: t()
  def from_timecode(timecode, opts) do
    round = Keyword.get(opts, :round, :closest)

    rate = timecode.rate
    timebase = Framerate.timebase(rate)
    frames_per_minute = Ratio.mult(timebase, Ratio.new(Consts.seconds_per_minute()))
    frames_per_hour = Ratio.mult(timebase, Ratio.new(Consts.seconds_per_hour()))

    total_frames =
      timecode
      |> Timecode.frames(opts)
      |> Kernel.abs()
      |> then(&(&1 + DropFrame.frame_num_adjustment(&1, rate)))

    {hours, remainder} = total_frames |> Ratio.new() |> Rational.divrem(frames_per_hour)
    {minutes, remainder} = Rational.divrem(remainder, frames_per_minute)
    {seconds, frames} = Rational.divrem(remainder, timebase)

    %__MODULE__{
      negative?: timecode.seconds < 0,
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      frames: Rational.round(frames, round)
    }
  end
end
