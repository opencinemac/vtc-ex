defmodule Vtc.Source.Frames.FeetAndFrames do
  @moduledoc """
  Holds Feet+Frames information.

  ## Fields

  - `feet`: The amount of film in Feet that would run through the camera in a given
    amount of time.
  - `feet`: The number of frames left over after `feet` of film has run.
  - `film_format`: The type of film this value represents. Default: `:ff35mm_4perf`.

  ## String Conversion

  [FeetAndFrames](`Vtc.Source.Frames.FeetAndFrames`) can be converted into a string
  through the `String.Chars.to_string/1` function.

  ## Examples

  ```elixir
  iex> alias Vtc.Source.Frames.FeetAndFrames
  iex>
  iex> %FeetAndFrames{feet: 10, frames: 4} |> String.Chars.to_string()
  "10+04"
  ```
  """

  alias Vtc.FilmFormat
  alias Vtc.Timecode
  alias Vtc.Utils.Parse

  @enforce_keys [:feet, :frames]
  defstruct [:feet, :frames, film_format: :ff35mm_4perf]

  @typedoc """
  Contains only a single field for wrapping the underlying string.
  """
  @type t() :: %__MODULE__{feet: integer(), frames: integer(), film_format: FilmFormat.t()}

  @ff_regex ~r/(?P<negative>-)?(?P<feet>[0-9]+)\+(?P<frames>[0-9]+)/

  @doc """
  Parses a `FeetAndFrames` value from a string.
  """
  @spec from_string(String.t(), film_format: FilmFormat.t()) :: {:ok, t()} | {:error, Timecode.ParseError.t()}
  def from_string(ff_string, opts \\ []) do
    film_format = Keyword.get(opts, :film_format, :ff35mm_4perf)

    with {:ok, groups} <- Parse.apply_regex(@ff_regex, ff_string) do
      negative? = Map.fetch!(groups, "negative") == "-"
      multiplier = if negative?, do: -1, else: 1

      feet = groups |> Map.fetch!("feet") |> String.to_integer()
      feet = feet * multiplier

      frames = groups |> Map.fetch!("frames") |> String.to_integer()
      frames = frames * multiplier

      {:ok, %__MODULE__{feet: feet, frames: frames, film_format: film_format}}
    end
  end

  @doc """
  Parses a `FeetAndFrames` value from a string.
  """
  @spec from_string!(String.t(), film_format: FilmFormat.t()) :: t()
  def from_string!(ff_string, opts \\ []) do
    case from_string(ff_string, opts) do
      {:ok, parsed} -> parsed
      {:error, error} -> raise error
    end
  end

  @doc false
  @spec from_timecode(
          Timecode.t(),
          opts :: [film_format: FilmFormat.t(), round: Timecode.round()]
        ) :: t()
  def from_timecode(timecode, opts) do
    film_format = Keyword.get(opts, :film_format, :ff35mm_4perf)
    frames_opts = Keyword.take(opts, [:round])

    perfs_per_foot = FilmFormat.perfs_per_foot(film_format)
    perfs_per_frame = FilmFormat.perfs_per_frame(film_format)

    total_frames = Timecode.frames(timecode, frames_opts)

    perfs = perfs_per_frame * total_frames

    feet = div(perfs, perfs_per_foot)
    frames = perfs |> rem(perfs_per_foot) |> div(perfs_per_frame)

    %__MODULE__{feet: feet, frames: frames, film_format: film_format}
  end
end

defimpl String.Chars, for: Vtc.Source.Frames.FeetAndFrames do
  alias Vtc.Source.Frames.FeetAndFrames

  @spec to_string(FeetAndFrames.t()) :: binary()
  def to_string(feet_frames) do
    sign = if feet_frames.feet < 0, do: "-", else: ""
    feet = feet_frames.feet |> abs() |> Integer.to_string()
    frames = feet_frames.frames |> abs() |> Integer.to_string() |> String.pad_leading(2, "0")

    "#{sign}#{feet}+#{frames}"
  end
end

defimpl Inspect, for: Vtc.Source.Frames.FeetAndFrames do
  alias Vtc.Source.Frames.FeetAndFrames

  @spec inspect(FeetAndFrames.t(), Inspect.Opts.t()) :: String.t()
  def inspect(feet_frames, _), do: "<#{feet_frames} #{inspect(feet_frames.film_format)}>"
end

defimpl Vtc.Source.Frames, for: Vtc.Source.Frames.FeetAndFrames do
  @moduledoc """
  Implements [Seconds](`Vtc.Source.Seconds`) protocol for Premiere ticks.
  """

  alias Vtc.FilmFormat
  alias Vtc.Framerate
  alias Vtc.Source.Frames
  alias Vtc.Source.Frames.FeetAndFrames

  @spec frames(FeetAndFrames.t(), Framerate.t()) :: Frames.result()
  def frames(feet_frames, rate) do
    perfs_per_foot = FilmFormat.perfs_per_foot(feet_frames.film_format)
    perfs_per_frame = FilmFormat.perfs_per_frame(feet_frames.film_format)

    perfs = feet_frames.feet * perfs_per_foot + feet_frames.frames * perfs_per_frame
    frames = div(perfs, perfs_per_frame)

    Frames.frames(frames, rate)
  end
end
