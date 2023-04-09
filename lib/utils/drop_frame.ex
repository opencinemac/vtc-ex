defmodule Vtc.Private.DropFrame do
  @moduledoc false
  alias Vtc.Framerate
  alias Vtc.Timecode
  alias Vtc.Utils.Rational

  # Adjusts the frame number based on drop-frame TC conventions.
  #
  # Algorithm adapted from:
  # https://www.davidheidelberger.com/2010/06/10/drop-frame-timecode/
  @spec parse_adjustment(Timecode.Sections.t(), Framerate.t()) ::
          {:ok, integer()} | {:error, Timecode.ParseError.t()}
  def parse_adjustment(sections, %{ntsc: :drop} = rate) do
    drop_rate = frames_dropped_per_minute(rate)

    with :ok <- parse_adjustment_validate(sections, drop_rate) do
      total_minutes = 60 * sections.hours + sections.minutes
      adjustment = round(drop_rate * (total_minutes - div(total_minutes, 10)))
      {:ok, -adjustment}
    end
  end

  def parse_adjustment(_, _), do: {:ok, 0}

  # Validates that the frame value from our string is not a frame that should have been
  # skipped on a non-tenth minute.s
  @spec parse_adjustment_validate(Timecode.Sections.t(), integer()) ::
          :ok | {:error, Timecode.ParseError.t()}
  defp parse_adjustment_validate(sections, drop_rate) do
    tenth_minute? = rem(sections.minutes, 10) == 0
    minute_boundary? = sections.seconds == 0

    if sections.frames < drop_rate and not tenth_minute? and minute_boundary? do
      {:error, %Timecode.ParseError{reason: :bad_drop_frames}}
    else
      :ok
    end
  end

  # Adjusts the frame number of a timecode so the proper drop-frame value is printed.
  #
  # Algorithm adapted from:
  # https://www.davidheidelberger.com/2010/06/10/drop-frame-timecode/
  @spec frame_num_adjustment(integer(), Framerate.t()) :: integer()
  def frame_num_adjustment(frame_number, %{ntsc: :drop} = rate) do
    framerate = Ratio.to_float(rate.playback)

    dropped_per_min = round(framerate * 0.066666)
    frames_per_hour = round(framerate * 60 * 60)
    frames_per_24_hours = frames_per_hour * 24
    frames_per_10_min = round(framerate * 60 * 10)
    frames_per_min = round(framerate) * 60 - dropped_per_min

    frame_number = rem(frame_number, frames_per_24_hours)

    tens_of_mins = div(frame_number, frames_per_10_min)
    remaining_mins = rem(frame_number, frames_per_10_min)

    tens_of_mins_adjustment = dropped_per_min * 9 * tens_of_mins

    if remaining_mins > dropped_per_min do
      remaining_minutes_adjustment =
        dropped_per_min * div(remaining_mins - dropped_per_min, frames_per_min)

      tens_of_mins_adjustment + remaining_minutes_adjustment
    else
      tens_of_mins_adjustment
    end
  end

  def frame_num_adjustment(_, _), do: 0

  # Get the number of frames that need to be dropped per minute (minus the 10th miute).
  @spec frames_dropped_per_minute(Framerate.t()) :: integer()
  defp frames_dropped_per_minute(rate) do
    time_base = rate |> Framerate.timebase() |> Rational.round()
    round(time_base * 0.066666)
  end
end
