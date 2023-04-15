defmodule Vtc.Timecode do
  @moduledoc """
  Represents a particular frame in a video clip.

  New Timecode values are created with the `with_seconds/3` and `with_frames/2`, and
  other function prefaced by `with_*`.

  ## Struct Fields

  - `seconds`: The real-world seconds elapsed since 01:00:00:00 as a rational value.
    (Note: The Ratio module automatically will coerce itself to an integer whenever
    possible, so this value may be an integer when exactly a whole-second value).

  - `rate`: the Framerate of the timecode.

  ## Sorting Support

  `Vtc.Timecode` implements `compare/2`, and as such, can be used wherever the standard
  library calls for a `Sorter` module. Let's see it in action:

  ```elixir
  iex> tc_01 = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> tc_02 = Timecode.with_frames!("02:00:00:00", Rates.f23_98())
  iex>
  iex>
  iex> Enum.sort([tc_02, tc_01], Timecode) |> inspect()
  "[<01:00:00:00 <23.98 NTSC>>, <02:00:00:00 <23.98 NTSC>>]"
  iex>
  iex>
  iex> Enum.sort([tc_01, tc_02], {:desc, Timecode}) |> inspect()
  "[<02:00:00:00 <23.98 NTSC>>, <01:00:00:00 <23.98 NTSC>>]"
  iex>
  iex>
  iex> Enum.max([tc_02, tc_01], Timecode) |> inspect()
  "<02:00:00:00 <23.98 NTSC>>"
  iex>
  iex>
  iex> Enum.min([tc_02, tc_01], Timecode) |> inspect()
  "<01:00:00:00 <23.98 NTSC>>"
  iex>
  iex>
  iex> data_01 = %{id: 2, tc: tc_01}
  iex> data_02 = %{id: 1, tc: tc_02}
  iex> Enum.sort_by([data_02, data_01], &(&1.tc), Timecode) |> inspect()
  "[%{id: 2, tc: <01:00:00:00 <23.98 NTSC>>}, %{id: 1, tc: <02:00:00:00 <23.98 NTSC>>}]"
  ```
  """

  import Kernel, except: [div: 2, rem: 2, abs: 1]

  alias Vtc.FilmFormat
  alias Vtc.Framerate
  alias Vtc.Source.Frames
  alias Vtc.Source.Frames.FeetAndFrames
  alias Vtc.Source.Frames.TimecodeStr
  alias Vtc.Source.Seconds
  alias Vtc.Source.Seconds.PremiereTicks
  alias Vtc.Source.Seconds.RuntimeStr
  alias Vtc.Timecode
  alias Vtc.Timecode.Eval
  alias Vtc.Timecode.ParseError
  alias Vtc.Timecode.Sections
  alias Vtc.Utils.Rational

  @enforce_keys [:seconds, :rate]
  defstruct [:seconds, :rate]

  @typedoc """
  `Vtc.Timecode` type.
  """
  @type t() :: %__MODULE__{
          seconds: Ratio.t(),
          rate: Framerate.t()
        }

  @typedoc """
  Valid values for rounding options.

  - `:closest`: Round the to the closet whole frame.
  - `:floor`: Always round down to the closest whole-frame.
  - `:ciel`: Always round up to the closest whole-frame.
  """
  @type round() :: :closest | :floor | :ceil

  @typedoc """
  As `round/0`, but includes `:off` option to disable rounding entirely. Not all
  functions exposed by this module make logical sense without some form of rouding, so
  `:off` will not be accepted by all functions.
  """
  @type maybe_round() :: round() | :off

  @typedoc """
  Type returned by `with_seconds/3` and `with_frames/3`.
  """
  @type parse_result() :: {:ok, t()} | {:error, ParseError.t() | %ArgumentError{}}

  @doc """
  Returns a new `Vtc.Timecode` with a `Timecode.seconds` field value equal to the
  `seconds` arg.

  ## Arguments

  - `seconds`: A value which can be represented as a number of real-world seconds.
    Must implement the `Vtc.Source.Seconds` protocol.

  - `rate`: Frame-per-second playback value of the timecode.

  ## Options

  - `round`: How to round the result with regards to whole-frames.

  ## Examples

  Accetps runtime strings...

  ```elixir
  iex> Timecode.with_seconds("01:00:00.5", Rates.f23_98()) |> inspect()
  "{:ok, <00:59:56:22 <23.98 NTSC>>}"
  ```

  ... floats...

  ```elixir
  iex> Timecode.with_seconds(3600.5, Rates.f23_98()) |> inspect()
  "{:ok, <00:59:56:22 <23.98 NTSC>>}"
  ```

  ... integers...

  ```elixir
  iex> Timecode.with_seconds(3600, Rates.f23_98()) |> inspect()
  "{:ok, <00:59:56:10 <23.98 NTSC>>}"
  ```

  ... integer Strings...

  ```elixir
  iex> Timecode.with_seconds("3600", Rates.f23_98()) |> inspect()
  "{:ok, <00:59:56:10 <23.98 NTSC>>}"
  ```

  ... and float strings.

  ```elixir
  iex> Timecode.with_seconds("3600.5", Rates.f23_98()) |> inspect()
  "{:ok, <00:59:56:22 <23.98 NTSC>>}"
  ```

  ## Premiere Ticks

  The `Vtc.Source.Seconds.PremiereTicks` struck implements the `Vtc.Source.Seconds`
  protocol and can be used to parse the format. This struct is not a general-purpose
  Module for the unit, and only exists to hint to the parsing function how it should be
  processed:

  ```elixir
  iex> alias Vtc.Source.Seconds.PremiereTicks
  iex>
  iex> input = %PremiereTicks{in: 254_016_000_000}
  iex> Timecode.with_seconds!(input, Rates.f23_98()) |> inspect()
  "<00:00:01:00 <23.98 NTSC>>"
  ```
  """
  @spec with_seconds(Seconds.t(), Framerate.t(), opts :: [round: maybe_round()]) :: parse_result()
  def with_seconds(seconds, rate, opts \\ []) do
    round = Keyword.get(opts, :round, :closest)

    with {:ok, seconds} <- Seconds.seconds(seconds, rate) do
      # If the vaue doesn't cleany divide into the framerate then we need to round to the
      # nearest frame.
      seconds = with_seconds_round_to_frame(seconds, rate, round)
      {:ok, %__MODULE__{seconds: seconds, rate: rate}}
    end
  end

  # Rounds seconds value to the nearest whole-frame.
  @spec with_seconds_round_to_frame(Ratio.t(), Framerate.t(), maybe_round()) :: Ratio.t()
  defp with_seconds_round_to_frame(seconds, _, :off), do: seconds

  defp with_seconds_round_to_frame(seconds, rate, round) do
    case Ratio.div(seconds, rate.playback) do
      %Ratio{denominator: 1} ->
        seconds

      %Ratio{} ->
        rate.playback
        |> Ratio.mult(seconds)
        |> Rational.round(round)
        |> Ratio.new()
        |> Ratio.div(rate.playback)
    end
  end

  @doc """
  As `with_seconds/3`, but raises on error.
  """
  @spec with_seconds!(Seconds.t(), Framerate.t(), opts :: [round: maybe_round()]) :: t()
  def with_seconds!(seconds, rate, opts \\ []) do
    seconds
    |> with_seconds(rate, opts)
    |> handle_raise_function()
  end

  @doc """
  Returns a new `Vtc.Timecode` with a `frames/2` return value equal to the `frames` arg.

  ## Arguments

  - `frames`: A value which can be represented as a frame number / frame count. Must
    implement the `Vtc.Source.Frames` protocol.

  - `rate`: Frame-per-second playback value of the timecode.

  ## Options

  - `round`: How to round the result with regards to whole-frames.

  ## Examples

  Accepts timecode strings...

  ```elixir
  iex> Timecode.with_frames("01:00:00:00", Rates.f23_98()) |> inspect()
  "{:ok, <01:00:00:00 <23.98 NTSC>>}"
  ```

  ... feet+frames strings...

  ```elixir
  iex> Timecode.with_frames("5400+00", Rates.f23_98()) |> inspect()
  "{:ok, <01:00:00:00 <23.98 NTSC>>}"
  ```

  By default, feet+frames is interpreted as 35mm, 4perf film. You can use the
  `Vtc.Source.Frames.FeetAndFrames` struct to parse other film formats:

  ```elixir
  iex> alias Vtc.Source.Frames.FeetAndFrames
  iex>
  iex> {:ok, feet_and_frames} = FeetAndFrames.from_string("5400+00", film_format: :ff16mm)
  iex> Timecode.with_frames(feet_and_frames, Rates.f23_98()) |> inspect()
  "{:ok, <01:15:00:00 <23.98 NTSC>>}"
  ```

  ... integers...

  ```elixir
  iex> Timecode.with_frames(86400, Rates.f23_98()) |> inspect()
  "{:ok, <01:00:00:00 <23.98 NTSC>>}"
  ```

  ... and integer strings.

  ```elixir
  iex> Timecode.with_frames("86400", Rates.f23_98()) |> inspect()
  "{:ok, <01:00:00:00 <23.98 NTSC>>}"
  ```
  """
  @spec with_frames(Frames.t(), Framerate.t()) :: parse_result()
  def with_frames(frames, rate) do
    case frames do
      %Ratio{} -> raise "HERE"
      val -> val
    end

    with {:ok, frames} <- Frames.frames(frames, rate) do
      frames
      |> Ratio.new()
      |> Ratio.div(rate.playback)
      |> with_seconds(rate)
    end
  end

  @doc """
  As `Timecode.with_frames/3`, but raises on error.
  """
  @spec with_frames!(Frames.t(), Framerate.t()) :: t()
  def with_frames!(frames, rate) do
    frames
    |> with_frames(rate)
    |> handle_raise_function()
  end

  @doc """
  Rebases `timecode` to a new framerate.

  The real-world seconds are recalculated using the same frame count as if they were
  being played back at `new_rate` instead of `timecode.rate`.

  ## Examples

  ```elixir
  iex> timecode = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> {:ok, rebased} = Timecode.rebase(timecode, Rates.f47_95())
  iex> inspect(rebased)
  "<00:30:00:00 <47.95 NTSC>>"
  ```
  """
  @spec rebase(t(), Framerate.t()) :: parse_result()
  def rebase(%{rate: rate} = timecode, rate), do: {:ok, timecode}
  def rebase(timecode, new_rate), do: timecode |> frames() |> with_frames(new_rate)

  @doc """
  As `rebase/2`, but raises on error.
  """
  @spec rebase!(t(), Framerate.t()) :: t()
  def rebase!(timecode, new_rate), do: timecode |> rebase(new_rate) |> handle_raise_function()

  @doc """
  Comapare the values of `a` and `b`.

  Compatible with `Enum.sort/2`. For more on sorting non-builtin values, see
  [the Elixir ducumentation](https://hexdocs.pm/elixir/1.13/Enum.html#sort/2-sorting-structs).

  > #### Argument Autocasting {: .info}
  >
  > As long as one argument is a `Vtc.Timecode` value, `a` or `b` May be any value that
  > implements the `Vtc.Source.Frames` protocol, such as a timecode string, and will be assumed to
  > be the same framerate as the other. This is mostly to support quick scripting. Will

  > #### Raises {: .error}
  >
  > Raises if there is an error parsing a `Vtc.Source.Frames` value from either argument.

  > #### Sorting with Timecodes {: .info}
  >
  > This function can be used anyware the standard library expexts a `sorter`. See
  > top-level `Vtc.Timecode` docs for more information.

  ## Examples

  Using two timecodes, `01:00:00:00` NTSC is greater than `01:00:00:00` true because it
  represents more real-world time.

  ```elixir
  iex> a = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> b = Timecode.with_frames!("01:00:00:00", Rates.f24())
  iex> :gt = Timecode.compare(a, b)
  ```

  Using a timcode and a bare string:

  ```elixir
  iex> timecode = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> :eq = Timecode.compare(timecode, "01:00:00:00")
  ```
  """
  @spec compare(a :: t() | Frames.t(), b :: t() | Frames.t()) :: :lt | :eq | :gt
  def compare(a, b) do
    {a, b} = cast_op_args(a, b)
    Ratio.compare(a.seconds, b.seconds)
  end

  @doc """
  Returns `true` if `a` is eqaul to `b`.

  > #### Argument Autocasting {: .info}
  >
  > As long as one argument is a `Vtc.Timecode` value, `a` or `b` May be any value that
  > implements the `Vtc.Source.Frames` protocol, such as a timecode string, and will be assumed to
  > be the same framerate as the other. This is mostly to support quick scripting. Will

  > #### Raises {: .error}
  >
  > Raises if there is an error parsing a `Vtc.Source.Frames` value from either argument.
  """
  @spec eq?(a :: t() | Frames.t(), b :: t() | Frames.t()) :: boolean()
  def eq?(a, b), do: compare(a, b) == :eq

  @doc """
  Returns `true` if `a` is less than `b`.

  > #### Argument Autocasting {: .info}
  >
  > As long as one argument is a `Vtc.Timecode` value, `a` or `b` May be any value that
  > implements the `Vtc.Source.Frames` protocol, such as a timecode string, and will be assumed to
  > be the same framerate as the other. This is mostly to support quick scripting. Will

  > #### Raises {: .error}
  >
  > Raises if there is an error parsing a `Vtc.Source.Frames` value from either argument.

  ## Examples

  ```elixir
  iex> a = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> b = Timecode.with_frames!("02:00:00:00", Rates.f23_98())
  iex> true = Timecode.lt?(a, b)
  iex> false = Timecode.lt?(b, a)
  ```
  """
  @spec lt?(a :: t() | Frames.t(), b :: t() | Frames.t()) :: boolean()
  def lt?(a, b), do: compare(a, b) == :lt

  @doc """
  Returns `true` if `a` is less than or equal to `b`.

  > #### Argument Autocasting {: .info}
  >
  > As long as one argument is a `Vtc.Timecode` value, `a` or `b` May be any value that
  > implements the `Vtc.Source.Frames` protocol, such as a timecode string, and will be assumed to
  > be the same framerate as the other. This is mostly to support quick scripting. Will

  > #### Raises {: .error}
  >
  > Raises if there is an error parsing a `Vtc.Source.Frames` value from either argument.
  """
  @spec lte?(a :: t() | Frames.t(), b :: t() | Frames.t()) :: boolean()
  def lte?(a, b), do: compare(a, b) in [:lt, :eq]

  @doc """
  Returns `true` if `a` is greater than `b`.

  > #### Argument Autocasting {: .info}
  >
  > As long as one argument is a `Vtc.Timecode` value, `a` or `b` May be any value that
  > implements the `Vtc.Source.Frames` protocol, such as a timecode string, and will be assumed to
  > be the same framerate as the other. This is mostly to support quick scripting. Will

  > #### Raises {: .error}
  >
  > Raises if there is an error parsing a `Vtc.Source.Frames` value from either argument.
  """
  @spec gt?(a :: t() | Frames.t(), b :: t() | Frames.t()) :: boolean()
  def gt?(a, b), do: compare(a, b) == :gt

  @doc """
  Returns `true` if `a` is greater than or eqaul to `b`.

  > #### Argument Autocasting {: .info}
  >
  > As long as one argument is a `Vtc.Timecode` value, `a` or `b` May be any value that
  > implements the `Vtc.Source.Frames` protocol, such as a timecode string, and will be assumed to
  > be the same framerate as the other. This is mostly to support quick scripting. Will

  > #### Raises {: .error}
  >
  > Raises if there is an error parsing a `Vtc.Source.Frames` value from either argument.
  """
  @spec gte?(a :: t() | Frames.t(), b :: t() | Frames.t()) :: boolean()
  def gte?(a, b), do: compare(a, b) in [:gt, :eq]

  @doc """
  Add two timecodes.

  Uses the real-world seconds representation. When the rates of `a` and `b` are not
  equal, the result will inheret the framerat of `a` and be rounded to the seconds
  representation of the nearest whole-frame at that rate.

  As long as one argument is a `Vtc.Timecode` value, `a` or `b` May be any value that
  implements the `Vtc.Source.Frames` protocol, such as a timecode string, and will be assumed to be
  the same framerate as the other. This is mostly to support quick scripting. Will raise
  if there is an error parsing a `Vtc.Source.Frames` value.

  ## Options

  - `round`: How to round the result with respect to whole-frames when mixing
    framerates. Default: `:closest`.

  ## Examples

  Two timecodes running at the same rate:

  ```elixir
  iex> a = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> b = Timecode.with_frames!("01:30:21:17", Rates.f23_98())
  iex> Timecode.add(a, b) |> inspect()
  "<02:30:21:17 <23.98 NTSC>>"
  ```

  Two timecodes running at different rates:

  ```elixir
  iex> a = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> b = Timecode.with_frames!("00:00:00:02", Rates.f47_95())
  iex> Timecode.add(a, b) |> inspect()
  "<01:00:00:01 <23.98 NTSC>>"
  ```

  Using a timcode and a bare string:

  ```elixir
  iex> a = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> Timecode.add(a, "01:30:21:17") |> inspect()
  "<02:30:21:17 <23.98 NTSC>>"
  ```
  """
  @spec add(a :: t() | Frames.t(), b :: t() | Frames.t(), opts :: [round: maybe_round()]) :: t()
  def add(a, b, opts \\ []) do
    {a, b} = cast_op_args(a, b)
    a.seconds |> Ratio.add(b.seconds) |> with_seconds!(a.rate, opts)
  end

  @doc """
  Subtract `b` from `a`.

  Uses their real-world seconds representation. When the rates of `a` and `b` are not
  equal, the result will inheret the framerat of `a` and be rounded to the seconds
  representation of the nearest whole-frame at that rate.

  As long as one argument is a `Vtc.Timecode` value, `a` or `b` May be any value that
  implements the `Vtc.Source.Frames` protocol, such as a timecode string, and will be
  assumed to be the same framerate as the other. This is mostly to support quick
  scripting. Will raise if there is an error parsing a `Vtc.Source.Frames` value.

  ## Options

  - `round`: How to round the result with respect to whole-frames when mixing
    framerates. Default: `:closest`.

  ## Examples

  Two timecodes running at the same rate:

  ```elixir
  iex> a = Timecode.with_frames!("01:30:21:17", Rates.f23_98())
  iex> b = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> Timecode.sub(a, b) |> inspect()
  "<00:30:21:17 <23.98 NTSC>>"
  ```

  When `b` is greater than `a`, the result is negative:

  ```elixir
  iex> a = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> b = Timecode.with_frames!("02:00:00:00", Rates.f23_98())
  iex> Timecode.sub(a, b) |> inspect()
  "<-01:00:00:00 <23.98 NTSC>>"
  ```

  Two timecodes running at different rates:

  ```elixir
  iex> a = Timecode.with_frames!("01:00:00:02", Rates.f23_98())
  iex> b = Timecode.with_frames!("00:00:00:02", Rates.f47_95())
  iex> Timecode.sub(a, b) |> inspect()
  "<01:00:00:01 <23.98 NTSC>>"
  ```

  Using a timcode and a bare string:

  ```elixir
  iex> a = Timecode.with_frames!("01:30:21:17", Rates.f23_98())
  iex> Timecode.sub(a, "01:00:00:00") |> inspect()
  "<00:30:21:17 <23.98 NTSC>>"
  ```
  """
  @spec sub(a :: t(), b :: t() | Frames.t(), opts :: [round: maybe_round()]) :: t()
  def sub(a, b, opts \\ []) do
    {a, b} = cast_op_args(a, b)
    a.seconds |> Ratio.sub(b.seconds) |> with_seconds!(a.rate, opts)
  end

  # Casts args for ops with two timecodes as long as at least one argument is a
  # timecode. The non-timecode argument inherents the framerate of the timecode
  # argument.
  @spec cast_op_args(t() | Frames.t(), t() | Frames.t()) :: {t(), t()}
  defp cast_op_args(%__MODULE__{} = a, %__MODULE__{} = b), do: {a, b}
  defp cast_op_args(%__MODULE__{} = a, b), do: {a, with_frames!(b, a.rate)}
  defp cast_op_args(a, %__MODULE__{} = b), do: {with_frames!(a, b.rate), b}

  @doc """
  Scales `a` by `b`.

  The result will inheret the framerat of `a` and be rounded to the seconds
  representation of the nearest whole-frame based on the `:round` option.

  ## Options

  - `round`: How to round the result with respect to whole-frame values. Defaults to
    `:closest`.

  ## Examples

  ```elixir
  iex> a = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> Timecode.mult(a, 2) |> inspect()
  "<02:00:00:00 <23.98 NTSC>>"

  iex> a = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> Timecode.mult(a, 0.5) |> inspect()
  "<00:30:00:00 <23.98 NTSC>>"
  ```
  """
  @spec mult(a :: t(), b :: Ratio.t() | number(), opts :: [round: maybe_round()]) :: t()
  def mult(a, b, opts \\ []), do: a.seconds |> Ratio.mult(Ratio.new(b)) |> with_seconds!(a.rate, opts)

  @doc """
  Divides `dividend` by `divisor`.

  The result will inherit the framerate of `dividend` and rounded to the nearest
  whole-frame based on the `:round` option.

  ## Options

  - `round`: How to round the result with respect to whole-frame values. Defaults to
    `:floor` to match `divmod` and the expected meaning of `div` to mean integer
    division in elixir.

  ## Examples

  ```elixir
  iex> dividend = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> Timecode.div(dividend, 2) |> inspect()
  "<00:30:00:00 <23.98 NTSC>>"

  iex> dividend = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> Timecode.div(dividend, 0.5) |> inspect()
  "<02:00:00:00 <23.98 NTSC>>"
  ```
  """
  @spec div(
          dividend :: t(),
          divisor :: Ratio.t() | number(),
          opts :: [round: maybe_round()]
        ) :: t()
  def div(dividend, divisor, opts \\ []) do
    opts = Keyword.put_new(opts, :round, :floor)
    dividend.seconds |> Ratio.div(Ratio.new(divisor)) |> with_seconds!(dividend.rate, opts)
  end

  @doc """
  Divides the total frame count of `dividend` by `divisor` and returns both a quotient
  and a remainder.

  The quotient returned is equivalent to `Timecode.div/3` with the `:round` option set
  to `:floor`.

  ## Options

  - `round_frames`: How to round the frame count before doing the divrem operation.
    Default: `:closest`.

  - `round_remainder`: How to round the remainder frames when a non-whole frame would
    be the result. Default: `:closest`.

  ## Examples

  ```elixir
  iex> dividend = Timecode.with_frames!("01:00:00:01", Rates.f23_98())
  iex> Timecode.divrem(dividend, 4) |> inspect()
  "{<00:15:00:00 <23.98 NTSC>>, <00:00:00:01 <23.98 NTSC>>}"
  ```
  """
  @spec divrem(
          dividend :: t(),
          divisor :: Ratio.t() | number(),
          opts :: [round_frames: round(), round_remainder: round()]
        ) :: {t(), t()}
  def divrem(dividend, divisor, opts \\ []) do
    round_frames = Keyword.get(opts, :round_frames, :closest)
    round_remainder = Keyword.get(opts, :round_remainder, :closest)

    with :ok <- ensure_round_enabled(round_frames, "round_frames"),
         :ok <- ensure_round_enabled(round_remainder, "round_remainder") do
      %{rate: rate} = dividend

      {quotient, remainder} =
        dividend
        |> frames(round: round_frames)
        |> Ratio.new()
        |> Rational.divrem(Ratio.new(divisor))

      remainder = Rational.round(remainder, round_remainder)

      {with_frames!(quotient, rate), with_frames!(remainder, rate)}
    end
  end

  @doc """
  Devides the total frame count of `dividend` by `devisor`, and returns the remainder.

  The quotient is floored before the remainder is calculated.

  ## Options

  - `round_frames`: How to round the frame count before doing the rem operation.
    Default: `:closest`.

  - `round_remainder`: How to round the remainder frames when a non-whole frame would
    be the result. Default: `:closest`.

  ## Examples

  ```elixir
  iex> dividend = Timecode.with_frames!("01:00:00:01", Rates.f23_98())
  iex> Timecode.rem(dividend, 4) |> inspect()
  "<00:00:00:01 <23.98 NTSC>>"
  ```
  """
  @spec rem(
          dividend :: t(),
          divisor :: Ratio.t() | number(),
          opts :: [round_frames: round(), round_remainder: round()]
        ) :: t()
  def rem(dividend, divisor, opts \\ []), do: dividend |> divrem(Ratio.new(divisor), opts) |> elem(1)

  @doc """
  As the kernel `-/1` function.

  - Makes a positive `tc` value negative.
  - Makes a negative `tc` value positive.

  ## Examples

  ```elixir
  iex> tc = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> Timecode.minus(tc) |> inspect()
  "<-01:00:00:00 <23.98 NTSC>>"
  ```

  ```elixir
  iex> tc = Timecode.with_frames!("-01:00:00:00", Rates.f23_98())
  iex> Timecode.minus(tc) |> inspect()
  "<01:00:00:00 <23.98 NTSC>>"
  ```
  """
  @spec minus(t()) :: t()
  def minus(tc), do: %{tc | seconds: Ratio.minus(tc.seconds)}

  @doc """
  Returns the absolute value of `tc`.

  ## Examples

  ```elixir
  iex> tc = Timecode.with_frames!("-01:00:00:00", Rates.f23_98())
  iex> Timecode.abs(tc) |> inspect()
  "<01:00:00:00 <23.98 NTSC>>"
  ```

  ```elixir
  iex> tc = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> Timecode.abs(tc) |> inspect()
  "<01:00:00:00 <23.98 NTSC>>"
  ```
  """
  @spec abs(t()) :: t()
  def abs(tc), do: %{tc | seconds: Ratio.abs(tc.seconds)}

  @doc """
  Evalutes timecode mathematical expressions in a `do` block.

  Any code captured within this macro can use Kernel operators to work with timecode
  values instead of module functions like `add/2`.

  ## Options

  - `at`: The Framerate to cast non-timecode values to. If this value is not set, then
    at least one value in each operation must be a `Vtc.Timecode`. This value can be any
    value accepted by `Framerate.new/2`.

  - `ntsc`: The `ntsc` value to use when creating a new Framerate with `at`. Not needed
    if `at` is a `Vtc.Framerate` value.

  ## Examples

  Use eval to do some quick math. The block captures variables from the outer scope,
  but contains the expression within its own scope, just like an `if` or `with`
  statement.

  ```elixir
  iex> require Timecode
  iex>
  iex> a = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> b = Timecode.with_frames!("00:30:00:00", Rates.f23_98())
  iex> c = Timecode.with_frames!("00:15:00:00", Rates.f23_98())
  iex>
  iex> result = Timecode.eval do
  iex>   a + b * 2 - c
  iex> end
  iex>
  iex> inspect(result)
  "<01:45:00:00 <23.98 NTSC>>"
  ```

  Or if you want to do it in one line:

  ```elixir
  iex> require Timecode
  iex>
  iex> a = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> b = Timecode.with_frames!("00:30:00:00", Rates.f23_98())
  iex> c = Timecode.with_frames!("00:15:00:00", Rates.f23_98())
  iex>
  iex> result = Timecode.eval(a + b * 2 - c)
  iex>
  iex> inspect(result)
  "<01:45:00:00 <23.98 NTSC>>"
  ```

  Just like the regular `Vtc.Timecode` functions, only one value in an arithmatic expression
  needs to be a `Vtc.Timecode` value. In the case above, since multiplication happens first,
  that's `b`:

  ```elixir
  iex> b = Timecode.with_frames!("00:30:00:00", Rates.f23_98())
  iex>
  iex> result = Timecode.eval do
  iex>   "01:00:00:00" + b * 2 - "00:15:00:00"
  iex> end
  iex>
  iex> inspect(result)
  "<01:45:00:00 <23.98 NTSC>>"
  ```

  You can supply a default framerate if you just want to do some quick calculations.
  This framerate is inherited by every value that implements the `Vtc.Source.Frames` protocol in
  the block, including integers:

  ```elixir
  iex> result = Timecode.eval at: Rates.f23_98() do
  iex>   "01:00:00:00" + "00:30:00:00" * 2 - "00:15:00:00"
  iex> end
  iex>
  iex> inspect(result)
  "<01:45:00:00 <23.98 NTSC>>"
  ```

  You can use any value that can be parsed by `Framerate.new/2`.

  ```elixir
  iex> result = Timecode.eval at: 23.98 do
  iex>   "01:00:00:00" + "00:30:00:00" * 2 - "00:15:00:00"
  iex> end
  iex>
  iex> inspect(result)
  "<01:45:00:00 <23.98 NTSC>>"
  ```

  `ntsc: :non_drop` is assumed by default, but you can set a different value with the
  `:ntsc` option:

  ```elixir
  iex> result = Timecode.eval at: 24, ntsc: nil do
  iex>   "01:00:00:00" + "00:30:00:00" * 2 - "00:15:00:00"
  iex> end
  iex>
  iex> inspect(result)
  "<01:45:00:00 <24.0 fps>>"
  ```
  """
  @spec eval([at: Framerate.t() | number() | Ratio.t(), ntsc: Framerate.ntsc()], Macro.input()) :: Macro.t()
  defmacro eval(opts \\ [], body), do: Eval.eval(opts, body)

  @doc """
  Returns the number of frames that would have elapsed between 00:00:00:00 and
  `timecode`.

  ## Options

  - `round`: How to round the resulting frame number.

  ## What it is

  Frame number / frames count is the number of a frame if the timecode started at
  00:00:00:00 and had been running until the current value. A timecode of '00:00:00:10'
  has a frame number of 10. A timecode of '01:00:00:00' has a frame number of 86400.

  ## Where you see it

  - Frame-sequence files: 'my_vfx_shot.0086400.exr'
  - FCP7XML cut lists:

      ```xml
      <timecode>
          <rate>
              <timebase>24</timebase>
              <ntsc>TRUE</ntsc>
          </rate>
          <string>01:00:00:00</string>
          <frame>86400</frame>  <!-- <====THIS LINE-->
          <displayformat>NDF</displayformat>
      </timecode>
      ```
  """
  @spec frames(t(), opts :: [round: round()]) :: integer()
  def frames(timecode, opts \\ []) do
    round = Keyword.get(opts, :round, :closest)

    with :ok <- ensure_round_enabled(round) do
      timecode.seconds
      |> Ratio.mult(timecode.rate.playback)
      |> Rational.round(round)
    end
  end

  @doc """
  The individual sections of a timecode string as i64 values.
  """
  @spec sections(t(), opts :: [round: round()]) :: Sections.t()
  def sections(timecode, opts \\ []) do
    round = Keyword.get(opts, :round, :closest)

    with :ok <- ensure_round_enabled(round) do
      Sections.from_timecode(timecode, opts)
    end
  end

  @doc """
  Returns the the formatted SMPTE timecode

  Ex: `01:00:00:00`. Drop frame timecode will be rendered with a ';' sperator before the
  frames field.

  ## Options

  - `round`: How to round the resulting frames field.

  ## What it is

  Timecode is used as a human-readable way to represent the id of a given frame. It is
  formatted to give a rough sense of where to find a frame:
  `{HOURS}:{MINUTES}:{SECONDS}:{FRAME}`. For more on timecode, see Frame.io's
  [excellent post](https://blog.frame.io/2017/07/17/timecode-and-frame-rates/) on the subject.

  ## Where you see it

  Timecode is ubiquitous in video editing, a small sample of places you might see timecode:

  - Source and Playback monitors in your favorite NLE.
  - Burned into the footage for dailies.
  - Cut lists like an EDL.
  """
  @spec timecode(t(), opts :: [round: round()]) :: String.t()
  def timecode(timecode, opts \\ []), do: timecode |> TimecodeStr.from_timecode(opts) |> then(& &1.in)

  @doc """
  Runtime Returns the true, real-world runtime of `timecode` in HH:MM:SS.FFFFFFFFF
  format.

  Arguments

  - `precision`: The number of places to round to. Extra trailing 0's will still be
    trimmed.

  ## What it is

  The formatted version of seconds. It looks like timecode, but with a decimal seconds
  value instead of a frame number place.

  ## Where you see it

  • Anywhere real-world time is used.

  • FFMPEG commands:

    ```shell
    ffmpeg -ss 00:00:30.5 -i input.mov -t 00:00:10.25 output.mp4
    ```

  ## Note

  The true runtime will often diverge from the hours, minutes, and seconds
  value of the timecode representation when dealing with non-whole-frame
  framerates. Even drop-frame timecode does not continuously adhere 1:1 to the
  actual runtime. For instance, <01:00:00;00 <29.97 NTSC DF>> has a true runtime of
  '00:59:59.9964', and <01:00:00:00 <23.98 NTSC>> has a true runtime of
  '01:00:03.6'
  """
  @spec runtime(t(), integer()) :: String.t()
  def runtime(timecode, precision \\ 9), do: timecode |> RuntimeStr.from_timecode(precision) |> then(& &1.in)

  @doc """
  Returns the number of elapsed ticks `timecode` represents in Adobe Premiere Pro.

  ## Options

  - `round`: How to round the resulting ticks.

  ## What it is

  Internally, Adobe Premiere Pro uses ticks to divide up a second, and keep track of how
  far into that second we are. There are 254016000000 ticks in a second, regardless of
  framerate in Premiere.

  ## Where you see it

  - Premiere Pro Panel functions and scripts.

  - FCP7XML cutlists generated from Premiere:

    ```xml
    <clipitem id="clipitem-1">
    ...
    <in>158</in>
    <out>1102</out>
    <pproTicksIn>1673944272000</pproTicksIn>
    <pproTicksOut>11675231568000</pproTicksOut>
    ...
    </clipitem>
    ```
  """
  @spec premiere_ticks(t(), opts :: [round: round()]) :: integer()
  def premiere_ticks(timecode, opts \\ []) do
    round = Keyword.get(opts, :round, :closest)

    with :ok <- ensure_round_enabled(round) do
      timecode |> PremiereTicks.from_timecode(opts) |> then(& &1.in)
    end
  end

  @doc """
  Returns the number of physical film feet and frames `timecode` represents if shot
  on film.

  Ex: '5400+13'.

  ## Options

  - `round`: How to round the internal frame count before conversion. Default: `:closest`.

  - `fiim_format`: The film format to use when doing the calculation. For more on film
    formats, see `Vtc.FilmFormat`. Default: `:ff35mm_4perf`, by far the most common
    format used to shoot Hollywood movies.

  ## What it is

  On physical film, each foot contains a certain number of frames. For 35mm, 4-perf film
  (the most common type on Hollywood movies), this number is 16 frames per foot.
  Feet-And-Frames was often used in place of Keycode to quickly reference a frame in the
  edit.

  ## Where you see it

  For the most part, feet + frames has died out as a reference, because digital media is
  not measured in feet. The most common place it is still used is Studio Sound
  Departments. Many Sound Mixers and Designers intuitively think in feet + frames, and it
  is often burned into the reference picture for them.

  - Telecine.
  - Sound turnover reference picture.
  - Sound turnover change lists.

  For more information on individual film formats, see the `Vtc.FilmFormat` module.
  """
  @spec feet_and_frames(t(), opts :: [fiim_format: FilmFormat.t(), round: round()]) :: FeetAndFrames.t()
  def feet_and_frames(timecode, opts \\ []), do: FeetAndFrames.from_timecode(timecode, opts)

  # Ensures that rounding is enabled for functions that cannot meaningfully turn
  # rounding off, such as those that must return an integer.
  @spec ensure_round_enabled(maybe_round(), String.t()) :: :ok
  defp ensure_round_enabled(round, arg_name \\ "round")
  defp ensure_round_enabled(:off, arg_name), do: raise(ArgumentError.exception("`#{arg_name}` cannot be `:off`"))
  defp ensure_round_enabled(_, _), do: :ok

  @spec handle_raise_function({:ok, t()} | {:error, Exception.t()}) :: t()
  defp handle_raise_function({:ok, result}), do: result
  defp handle_raise_function({:error, error}), do: raise(error)
end

defimpl Inspect, for: Vtc.Timecode do
  alias Vtc.Timecode

  @spec inspect(Timecode.t(), Elixir.Inspect.Opts.t()) :: String.t()
  def inspect(timecode, _opts) do
    "<#{Timecode.timecode(timecode)} #{inspect(timecode.rate)}>"
  end
end

defimpl String.Chars, for: Vtc.Timecode do
  alias Vtc.Timecode

  @spec to_string(Timecode.t()) :: String.t()
  def to_string(timecode), do: inspect(timecode)
end
