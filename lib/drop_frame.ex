defmodule Private.Drop do
  @moduledoc false

  use Ratio

  # Adjusts the frame number based on drop-frame TC conventions.
  #
  # Algorithm adapted from:
  # https://www.davidheidelberger.com/2010/06/10/drop-frame-timecode/
  @spec parse_adjustment(Vtc.Timecode.Sections.t(), Vtc.Framerate.t()) ::
          {:ok, integer} | {:error, Vtc.Timecode.ParseError.t()}
  def parse_adjustment(sections, %Vtc.Framerate{ntsc: ntsc} = rate) when ntsc == :Drop do
    drop_frames = get_drop_frames(rate)

    # We have a bad frame value if our 'frames' place is less than the drop_frames we
    # skip on minutes not divisible by 10.
    has_bad_frame = sections.frames < drop_frames
    {_, remainder} = Private.Rat.divmod(sections.minutes, 10)
    is_tenth_minute = remainder == 0

    if has_bad_frame and not is_tenth_minute do
      {:error, %Vtc.Timecode.ParseError{reason: :bad_drop_frames}}
    else
      total_minutes = 60 * sections.hours + sections.minutes
      adjustment = drop_frames * (total_minutes - div(total_minutes, 10))
      {:ok, -adjustment}
    end
  end

  # If this is not an NTSC framerate, there is not adjustment
  def parse_adjustment(_sections, %Vtc.Framerate{ntsc: ntsc} = _rate) when ntsc != :Drop do
    {:ok, 0}
  end

  # Adjusts the frame number of a timecode so the proper drop-frame value is printed.
  #
  # Algorithm adapted from:
  # https://www.davidheidelberger.com/2010/06/10/drop-frame-timecode/
  @spec frame_num_adjustment(integer, Vtc.Framerate.t()) :: integer
  def frame_num_adjustment(frame_number, rate) do
    timebase = Vtc.Framerate.timebase(rate)
    drop_frames = get_drop_frames(rate)

    # Get the number frames-per-minute at the whole-frame rate
    frames_per_minute_whole = timebase * 60
    # Get the number of frames are in a minute where we have dropped frames at the
    # beginning
    frames_per_minute_with_drop = frames_per_minute_whole - drop_frames

    # Get the number of actual frames in a 10-minute span for drop frame timecode. Since
    # we drop 9 times a minute, it will be 9 drop-minute frame counts + 1 whole-minute
    # frame count.
    frames_per_10minutes_drop = frames_per_minute_with_drop * 9 + frames_per_minute_whole

    # Get the number of 10s of minutes in this count, and the remaining frames.
    {tens_of_minutes, frames} = Private.Rat.divmod(frame_number, frames_per_10minutes_drop)

    # Create an adjustment for the number of 10s of minutes. It will be 9 times the
    # drop value (we drop for the first 9 minutes, then leave the 10th alone).
    adjustment = 9 * drop_frames * tens_of_minutes

    # If our remaining frames are less than a whole minute, we aren't going to drop
    # again. Add the adjustment and return.
    if frames < frames_per_minute_whole do
      frame_number + adjustment
    else
      # Remove the first full minute (we don't drop until the next minute) and add the
      # drop-rate to the adjustment.
      frames = frames - timebase
      adjustment = adjustment + drop_frames

      # Get the number of remaining drop-minutes present, and add a drop adjustment for
      # each.
      minutes_drop = floor(div(frames, frames_per_minute_with_drop))
      adjustment = adjustment + minutes_drop * drop_frames

      # Return our original frame number adjusted by our calculated adjustment.
      frame_number + adjustment
    end
  end

  @spec get_drop_frames(Vtc.Framerate.t()) :: integer
  def get_drop_frames(rate) do
    timebase = Vtc.Framerate.timebase(rate)
    Private.Rat.round_ratio?(timebase * Ratio.new(0.066666, 1))
  end
end
