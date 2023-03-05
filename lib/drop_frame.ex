defmodule Vtc.Private.DropFrame do
  @moduledoc false

  use Ratio, override_math: false, operator: false

  alias Vtc.Framerate
  alias Vtc.Utils.Rational
  alias Vtc.Timecode

  # Adjusts the frame number based on drop-frame TC conventions.
  #
  # Algorithm adapted from:
  # https://www.davidheidelberger.com/2010/06/10/drop-frame-timecode/
  @spec parse_adjustment(Timecode.Sections.t(), Framerate.t()) ::
          {:ok, integer()} | {:error, Timecode.ParseError.t()}

  def parse_adjustment(sections, %Framerate{ntsc: :Drop} = rate) do
    drop_rate = frames_dropped_per_minute(rate)

    with :ok <- parse_adjustment_validate(sections, drop_rate) do
      total_minutes = 60 * sections.hours + sections.minutes
      adjustment = drop_rate * (total_minutes - div(total_minutes, 10))
      {:ok, -adjustment}
    end
  end

  def parse_adjustment(_, _), do: {:ok, 0}

  @spec parse_adjustment_validate(Timecode.Sections.t(), integer()) ::
          :ok | {:error, Timecode.ParseError.t()}
  defp parse_adjustment_validate(sections, drop_rate) do
    tenth_minute? = match?({_, 0}, Rational.divmod(sections.minutes, 10))

    # We have a bad frame value if our frames place is less than the drop_frames we
    # are supposed to skip.
    if sections.frames < drop_rate and not tenth_minute? do
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
  def frame_num_adjustment(frame_number, rate) do
    timebase = Framerate.timebase(rate)
    drop_rate = frames_dropped_per_minute(rate)

    # Get the number frames-per-minute at the whole-frame rate
    frames_per_minute_whole = Ratio.mult(timebase, 60)
    # Get the number of frames are in a minute where we have dropped frames at the
    # beginning
    frames_per_minute_with_drop = frames_per_minute_whole - drop_rate

    # Get the number of actual frames in a 10-minute span for drop frame timecode. Since
    # we drop 9 times a minute, it will be 9 drop-minute frame counts + 1 whole-minute
    # frame count.
    frames_per_10minutes_drop = frames_per_minute_with_drop * 9 + frames_per_minute_whole

    # Get the number of 10s of minutes in this count, and the remaining frames.
    {tens_of_minutes, frames} = Rational.divmod(frame_number, frames_per_10minutes_drop)

    # Create an adjustment for the number of 10s of minutes. It will be 9 times the
    # drop value (we drop for the first 9 minutes, then leave the 10th alone).
    adjustment = 9 * drop_rate * tens_of_minutes

    # If our remaining frames are less than a whole minute, we aren't going to drop
    # again. Add the adjustment and return.
    if frames < frames_per_minute_whole do
      frame_number + adjustment
    else
      # Remove the first full minute (we don't drop until the next minute) and add the
      # drop-rate to the adjustment.
      frames = Ratio.sub(frames, timebase)
      adjustment = adjustment + drop_rate

      # Get the number of remaining drop-minutes present, and add a drop adjustment for
      # each.
      minutes_drop = floor(div(frames, frames_per_minute_with_drop))
      adjustment = adjustment + minutes_drop * drop_rate

      # Return our original frame number adjusted by our calculated adjustment.
      frame_number + adjustment
    end
  end

  # Get the number of frames that need to be dropped per minute (minus the 10th miute).
  @spec frames_dropped_per_minute(Framerate.t()) :: integer()
  defp frames_dropped_per_minute(rate) do
    rate
    |> Framerate.timebase()
    |> Ratio.mult(Ratio.new(0.066666, 1))
    |> Rational.round()
  end
end
