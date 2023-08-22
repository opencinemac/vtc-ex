defmodule Vtc.Framestamp.Range do
  @moduledoc """
  Holds a framestamp range.

  ## Struct Fields

  - `in`: Start TC. Must be less than or equal to `out`.
  - `out`: End TC. Must be greater than or equal to `in`.
  - `inclusive`: See below for more information. Default: `false`

  ## Inclusive vs. Exclusive Ranges

  Inclusive ranges treat the `out` framestamp as the last visible frame of a piece of
  footage. This style of timecode range is most often associated with AVID.

  Exclusive framestamp ranges treat the `out` framestamp as the *boundary* where the
  range ends. This style of timecode range is most often associated with Final Cut and
  Premiere.

  In mathematical notation, inclusive ranges are `[in, out]`, while exclusive ranges are
  `[in, out)`.
  """
  use Vtc.Ecto.Postgres.Utils

  alias Vtc.Ecto.Postgres.PgFramestamp
  alias Vtc.Framestamp
  alias Vtc.Framestamp.Range.MixedOutTypeArithmeticError
  alias Vtc.Source.Frames
  alias Vtc.Utils.MixedRateOps

  @typedoc """
  Whether the end point should be treated as the Range's boundary (:exclusive), or its
  last element (:inclusive).
  """
  @type out_type() :: :inclusive | :exclusive

  @typedoc """
  Range struct type.
  """
  @type t() :: %__MODULE__{
          in: Framestamp.t(),
          out: Framestamp.t(),
          out_type: out_type()
        }

  @enforce_keys [:in, :out, :out_type]
  defstruct [:in, :out, :out_type]

  @doc section: :parse
  @doc """
  Creates a new [Range](`Vtc.Framestamp.Range`).

  `out_tc` may be a [Framestamp](`Vtc.Framestamp`) value for any value that implements the
  [Frames](`Vtc.Source.Frames`) protocol.

  Returns an error if the resulting range would not have a duration greater or equal to
  0, or if `stamp_in` and `stamp_out` do not have the same `rate`.

  ## Examples

  ```elixir
  iex> stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex> stamp_out = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())
  iex>
  iex> result = Range.new(stamp_in, stamp_out)
  iex> inspect(result)
  "{:ok, <01:00:00:00 - 02:00:00:00 :exclusive <23.98 NTSC>>}"
  ```

  Using a timecode string as `b`:

  ```elixir
  iex> stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex>
  iex> result = Range.new(stamp_in, "02:00:00:00")
  iex> inspect(result)
  "{:ok, <01:00:00:00 - 02:00:00:00 :exclusive <23.98 NTSC>>}"
  ```

  Making a range with an inclusive out:

  ```elixir
  iex> stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex>
  iex> result = Range.new(stamp_in, "02:00:00:00", out_type: :inclusive)
  iex> inspect(result)
  "{:ok, <01:00:00:00 - 02:00:00:00 :inclusive <23.98 NTSC>>}"
  ```
  """
  @spec new(
          stamp_in :: Framestamp.t(),
          stamp_out :: Framestamp.t() | Frames.t(),
          opts :: [out_type: out_type()]
        ) :: {:ok, t()} | {:error, Exception.t() | Framestamp.ParseError.t()}
  def new(stamp_in, stamp_out, opts \\ [])

  def new(stamp_in, %Framestamp{} = stamp_out, opts) do
    out_type = Keyword.get(opts, :out_type, :exclusive)

    with :ok <- validate_rates_equal(stamp_in, stamp_out, :stamp_in, :stamp_out),
         :ok <- validate_in_and_out(stamp_in, stamp_out, out_type) do
      {:ok, %__MODULE__{in: stamp_in, out: stamp_out, out_type: out_type}}
    end
  end

  def new(stamp_in, stamp_out, opts) do
    with {:ok, stamp_out} <- Framestamp.with_frames(stamp_out, stamp_in.rate) do
      new(stamp_in, stamp_out, opts)
    end
  end

  @doc section: :parse
  @doc """
  As `new/3`, but raises on error.
  """
  @spec new!(Framestamp.t(), Framestamp.t(), opts :: [out_type: out_type()]) :: t()
  def new!(stamp_in, stamp_out, opts \\ []) do
    case new(stamp_in, stamp_out, opts) do
      {:ok, range} -> range
      {:error, error} -> raise error
    end
  end

  # Validates that `out_tc` is greater than or equal to `in_tc`, when measured
  # exclusively.
  @spec validate_in_and_out(Framestamp.t(), Framestamp.t(), out_type()) ::
          :ok | {:error, Exception.t()}
  defp validate_in_and_out(stamp_in, stamp_out, out_type) do
    stamp_out = adjust_out_exclusive(stamp_out, out_type)

    if Framestamp.compare(stamp_out, stamp_in) in [:gt, :eq] do
      :ok
    else
      {:error, ArgumentError.exception("`stamp_out` must be greater than or equal to `stamp_in`")}
    end
  end

  @doc section: :parse
  @doc """
  Returns a range with an `:in` value of `stamp_in` and a duration of `duration`.

  `duration` may be a [Framestamp](`Vtc.Framestamp`) value for any value that implements the
  [Frames](`Vtc.Source.Frames`) protocol. Returns an error if `duration` is less than
  `0` seconds or if `stamp_in` and `stamp_out` do not have the same `rate`.

  ## Examples

  ```elixir
  iex> stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex> duration = Framestamp.with_frames!("00:30:00:00", Rates.f23_98())
  iex>
  iex> result = Range.with_duration(stamp_in, duration)
  iex> inspect(result)
  "{:ok, <01:00:00:00 - 01:30:00:00 :exclusive <23.98 NTSC>>}"
  ```

  Using a timecode string as `b`:

  ```elixir
  iex> stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex>
  iex> result = Range.with_duration(stamp_in, "00:30:00:00")
  iex> inspect(result)
  "{:ok, <01:00:00:00 - 01:30:00:00 :exclusive <23.98 NTSC>>}"
  ```

  Making a range with an inclusive out:

  ```elixir
  iex> stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex>
  iex> result = Range.with_duration(stamp_in, "00:30:00:00", out_type: :inclusive)
  iex> inspect(result)
  "{:ok, <01:00:00:00 - 01:29:59:23 :inclusive <23.98 NTSC>>}"
  ```
  """
  @spec with_duration(
          stamp_in :: Framestamp.t(),
          duration :: Framestamp.t() | Frames.t(),
          opts :: [out_type: out_type()]
        ) :: {:ok, t()} | {:error, Exception.t() | Framestamp.ParseError.t()}
  def with_duration(stamp_in, duration, opts \\ [])

  def with_duration(stamp_in, %Framestamp{} = duration, out_type: :inclusive) do
    with {:ok, range} <- with_duration(stamp_in, duration, []) do
      {:ok, with_inclusive_out(range)}
    end
  end

  def with_duration(stamp_in, %Framestamp{} = duration, _) do
    with :ok <- validate_rates_equal(stamp_in, duration, :stamp_in, :duration),
         :ok <- with_duration_validate_duration(duration) do
      stamp_out = Framestamp.add(stamp_in, duration)
      new(stamp_in, stamp_out, out_type: :exclusive)
    end
  end

  def with_duration(stamp_in, duration, opts) do
    with {:ok, duration} <- Framestamp.with_frames(duration, stamp_in.rate) do
      with_duration(stamp_in, duration, opts)
    end
  end

  @doc section: :parse
  @doc """
  As with_duration/3, but raises on error.
  """
  @spec with_duration!(Framestamp.t(), Framestamp.t(), opts :: [out_type: out_type()]) :: t()
  def with_duration!(stamp_in, duration, opts \\ []) do
    case with_duration(stamp_in, duration, opts) do
      {:ok, range} -> range
      {:error, error} -> raise error
    end
  end

  @spec with_duration_validate_duration(Framestamp.t()) :: :ok | {:error, Exception.t()}
  defp with_duration_validate_duration(duration) do
    if Framestamp.compare(duration, 0) != :lt do
      :ok
    else
      {:error, ArgumentError.exception("`duration` must be greater than `0`")}
    end
  end

  @spec validate_rates_equal(Framestamp.t(), Framestamp.t(), atom(), atom()) ::
          :ok | {:error, Exception.t()}
  defp validate_rates_equal(%{rate: rate}, %{rate: rate}, _, _), do: :ok

  defp validate_rates_equal(_, _, a_name, b_name),
    do: {:error, ArgumentError.exception("`#{a_name}` and `#{b_name}` must have same `rate`")}

  @doc section: :manipulate
  @doc """
  Adjusts range to have an inclusive out framestamp.

  ## Examples

  ```elixir
  iex> stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex> range = Range.new!(stamp_in, "02:00:00:00")
  iex>
  iex> result = Range.with_inclusive_out(range)
  iex> inspect(result)
  "<01:00:00:00 - 01:59:59:23 :inclusive <23.98 NTSC>>"
  ```
  """
  @spec with_inclusive_out(t()) :: t()
  def with_inclusive_out(range), do: with_out_type(range, :inclusive)

  @doc section: :manipulate
  @doc """
  Adjusts range to have an exclusive out framestamp.

  ## Examples

  ```elixir
  iex> stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex> range = Range.new!(stamp_in, "02:00:00:00", out_type: :inclusive)
  iex>
  iex> result = Range.with_exclusive_out(range)
  iex> inspect(result)
  "<01:00:00:00 - 02:00:00:01 :exclusive <23.98 NTSC>>"
  ```
  """
  @spec with_exclusive_out(t()) :: t()
  def with_exclusive_out(range), do: with_out_type(range, :exclusive)

  # Adjusts `range` to have `out_type`.
  @spec with_out_type(t(), out_type()) :: t()
  defp with_out_type(%{out_type: out_type} = range, out_type), do: range

  defp with_out_type(range, :inclusive) do
    new_out = Framestamp.sub(range.out, 1)
    %__MODULE__{range | out: new_out, out_type: :inclusive}
  end

  defp with_out_type(range, :exclusive) do
    new_out = adjust_out_exclusive(range.out, :inclusive)
    %__MODULE__{range | out: new_out, out_type: :exclusive}
  end

  # Adjusts an out TC to be an exclusive out.
  @spec adjust_out_exclusive(Framestamp.t(), out_type()) :: Framestamp.t()
  defp adjust_out_exclusive(framestamp, :exclusive), do: framestamp
  defp adjust_out_exclusive(framestamp, :inclusive), do: Framestamp.add(framestamp, 1)

  @doc section: :manipulate
  @doc """
  Wrap `range.in` to the nearest valid TOD (time-of-day) timecode.

  Framestamps with a SMPTE timecode of less than `00:00:00:00` will have `24:00:00:00`
  recursively added until they are positive.

  Framestamps with a SMPTE timecode of greater than or equal to `24:00:00:00` will have
  `24:00:00:00` subtracted until they are less than `24:00:00:00`.

  Returned out point is always greater than in point, and may exceed `24:00:00:00` for
  if required for duration.

  ## Raises

  - `ArgumentError` if `range.in.rate` is not NTSC or whole-frame.

  ## Examples

  Adjusts ranges entirely outside of valid time-of-day timecode:

  ```elixir
  iex> stamp_in = Framestamp.with_frames!("24:00:00:00", Rates.f23_98())
  iex> stamp_out = Framestamp.with_frames!("24:01:00:00", Rates.f23_98())
  iex> range = Framestamp.Range.new!(stamp_in, stamp_out)
  iex> Framestamp.Range.smpte_timecode_wrap_tod(range) |> inspect()
  "<00:00:00:00 - 00:01:00:00 :exclusive <23.98 NTSC>>"
  ```

  Does not adjust ranges with an in-point that is valid for time-of-day timecode:

  ```elixir
  iex> stamp_in = Framestamp.with_frames!("23:59:59:00", Rates.f23_98())
  iex> stamp_out = Framestamp.with_frames!("24:01:00:00", Rates.f23_98())
  iex> range = Framestamp.Range.new!(stamp_in, stamp_out)
  iex> Framestamp.Range.smpte_timecode_wrap_tod(range) |> inspect()
  "<23:59:59:00 - 24:01:00:00 :exclusive <23.98 NTSC>>"
  ```

  Adjust negative ranges to wrap back from `24:00:00:00`:

  ```elixir
  iex> stamp_in = Framestamp.with_frames!("-01:00:00:00", Rates.f23_98())
  iex> stamp_out = Framestamp.with_frames!("-00:59:50:00", Rates.f23_98())
  iex> range = Framestamp.Range.new!(stamp_in, stamp_out)
  iex> Framestamp.Range.smpte_timecode_wrap_tod(range) |> inspect()
  "<23:00:00:00 - 23:00:10:00 :exclusive <23.98 NTSC>>"
  ```
  """
  @spec smpte_timecode_wrap_tod(t()) :: t()
  def smpte_timecode_wrap_tod(range) do
    range.in
    |> Framestamp.smpte_timecode_wrap_tod()
    |> with_duration!(duration(range), out_type: range.out_type)
  end

  @doc section: :manipulate
  @doc """
  Adds `scalar` to both `range.in` and `range.out`.

  [auto-casts](Vtc.Framestamp.html#module-arithmetic-autocasting)
  [Frames](`Vtc.Source.Frames`) values.

  ## Options

  - `inherit_rate`: Which side to inherit the framerate from in mixed-rate calculations.
    If `false`, this function will raise if `range.in.rate` does not match `scalar.rate`.
    Default: `false`.

  - `round`: How to round the result with respect to whole-frames when mixing
    framerates. Default: `:closest`.

  ## Examples

  ```elixir
  iex> stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex> range = Framestamp.Range.new!(stamp_in, "02:00:00:00")
  iex>
  iex> scalar = Framestamp.with_frames!("00:00:01:00", Rates.f23_98())
  iex>
  iex> Framestamp.Range.shift(range, scalar) |> inspect()
  "<01:00:01:00 - 02:00:01:00 :exclusive <23.98 NTSC>>"
  ```
  """
  @spec shift(
          t(),
          Framestamp.t() | Frames.t(),
          opts :: [inherit_rate: Framestamp.inherit_opt(), round: Framestamp.round()]
        ) :: t()
  def shift(range, scalar, opts \\ []) do
    stamp_in = Framestamp.add(range.in, scalar, opts)
    stamp_out = Framestamp.add(range.out, scalar, opts)

    new!(stamp_in, stamp_out)
  end

  @doc section: :inspect
  @doc """
  Returns the duration in [Framestamp](`Vtc.Framestamp`) of `range`.

  ## Examples

  ```elixir
  iex> stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex> range = Range.new!(stamp_in, "01:30:00:00")
  iex>
  iex> result = Range.duration(range)
  iex> inspect(result)
  "<00:30:00:00 <23.98 NTSC>>"
  ```
  """
  @spec duration(t()) :: Framestamp.t()
  def duration(range) do
    %{in: stamp_in, out: stamp_out} = with_exclusive_out(range)
    Framestamp.sub(stamp_out, stamp_in)
  end

  @doc section: :compare
  @doc """
  Returns `true` if `range` contains `framestamp`. `framestamp` may be any value that
  implements [Frames](`Vtc.Source.Frames`).

  ## Examples

  ```elixir
  iex> stamp_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex> range = Range.new!(stamp_in, "01:30:00:00")
  iex>
  iex> Range.contains?(range, "01:10:00:00")
  true
  iex> Range.contains?(range, "01:40:00:00")
  false
  ```
  """
  @spec contains?(t(), Framestamp.t() | Frames.t()) :: boolean()
  def contains?(range, %Framestamp{} = framestamp) do
    calc_with_exclusive([range], false, :contains?, fn range ->
      cond do
        Framestamp.lt?(framestamp, range.in) -> false
        Framestamp.gte?(framestamp, range.out) -> false
        true -> true
      end
    end)
  end

  def contains?(range, frames), do: contains?(range, Framestamp.with_frames!(frames, range.in.rate))

  @doc section: :compare
  @doc """
  Returns `true` if there is overlap between `a` and `b`.

  ## Examples

  ```elixir
  iex> a_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex> a = Range.new!(a_in, "02:00:00:00", out_type: :inclusive)
  iex>
  iex> b_in = Framestamp.with_frames!("01:50:00:00", Rates.f23_98())
  iex> b = Range.new!(b_in, "02:30:00:00", out_type: :inclusive)
  iex> Range.overlaps?(a, b)
  true
  ```

  ```elixir
  iex> a_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex> a = Range.new!(a_in, "02:00:00:00", out_type: :inclusive)
  iex>
  iex> b_in = Framestamp.with_frames!("02:10:00:00", Rates.f23_98())
  iex> b = Range.new!(b_in, "03:30:00:00", out_type: :inclusive)
  iex> Range.overlaps?(a, b)
  false
  ```
  """
  @spec overlaps?(t(), t()) :: boolean()
  def overlaps?(a, b) do
    calc_with_exclusive([a, b], :left, :overlaps?, fn a, b ->
      cond do
        Framestamp.compare(a.in, b.out) in [:gt, :eq] -> false
        Framestamp.compare(a.out, b.in) in [:lt, :eq] -> false
        true -> true
      end
    end)
  end

  @doc section: :compare
  @doc """
  Returns the the range where `a` and `b` overlap/intersect.

  Returns `{:error, :none}` if the two ranges do not intersect.

  ## Options

  - `inherit_rate`: Which side to inherit the framerate from in mixed-rate calculations.
    If `false`, this function will raise if `a`'s rate does not match `b`'s rate.
    Default: `false`.

  - `inherit_out_type`: Which side to inherit the out type from when `a.out_type`
    does not match `b.out_type`. If `false`, this function will raise if `a`'s rate does
    not match `b`'s rate. Default: `false`.

  ## Examples

  ```elixir
  iex> a_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex> a = Range.new!(a_in, "02:00:00:00", out_type: :inclusive)
  iex>
  iex> b_in = Framestamp.with_frames!("01:50:00:00", Rates.f23_98())
  iex> b = Range.new!(b_in, "02:30:00:00", out_type: :inclusive)
  iex>
  iex> result = Range.intersection(a, b)
  iex> inspect(result)
  "{:ok, <01:50:00:00 - 02:00:00:00 :inclusive <23.98 NTSC>>}"
  ```

  ```elixir
  iex> a_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex> a = Range.new!(a_in, "02:00:00:00", out_type: :inclusive)
  iex>
  iex> b_in = Framestamp.with_frames!("02:10:00:00", Rates.f23_98())
  iex> b = Range.new!(b_in, "03:30:00:00", out_type: :inclusive)
  iex> Range.intersection(a, b)
  {:error, :none}
  ```
  """
  @spec intersection(
          t(),
          t(),
          inherit_rate: Framestamp.inherit_opt(),
          inherit_out_type: Framestamp.inherit_opt()
        ) :: {:ok, t()} | {:error, :none}
  def intersection(a, b, opts \\ []), do: calc_overlap(a, b, opts, :intersection, &overlaps?(&1, &2))

  @doc section: :compare
  @doc """
  As `intersection`, but returns a Range from `00:00:00:00` - `00:00:00:00` when there
  is no overlap.

  ## Options

  - `inherit_rate`: Which side to inherit the framerate from in mixed-rate calculations.
    If `false`, this function will raise if `a`'s rate does not match `b`'s rate.
    Default: `false`.

  - `inherit_out_type`: Which side to inherit the out type from when `a.out_type`
    does not match `b.out_type`. If `false`, this function will raise if `a`'s rate does
    not match `b`'s rate. Default: `false`.

  ## Examples

  ```elixir
  iex> a_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex> a = Range.new!(a_in, "02:00:00:00", out_type: :inclusive)
  iex>
  iex> b_in = Framestamp.with_frames!("02:10:00:00", Rates.f23_98())
  iex> b = Range.new!(b_in, "03:30:00:00", out_type: :inclusive)
  iex>
  iex> result = Range.intersection!(a, b)
  iex> inspect(result)
  "<00:00:00:00 - -00:00:00:01 :inclusive <23.98 NTSC>>"
  ```
  """
  @spec intersection!(
          t(),
          t(),
          inherit_rate: Framestamp.inherit_opt(),
          inherit_out_type: Framestamp.inherit_opt()
        ) :: t()
  def intersection!(a, b, opts \\ []) do
    case intersection(a, b, opts) do
      {:ok, overlap} -> overlap
      {:error, :none} -> create_zeroed_range(a, b, :intersection, opts)
    end
  end

  @doc section: :compare
  @doc """
  Returns the range between two, non-overlapping ranges.

  Returns `{:error, :none}` if the two ranges are not separated.

  ## Options

  - `inherit_rate`: Which side to inherit the framerate from in mixed-rate calculations.
    If `false`, this function will raise if `a`'s rate does not match `b`'s rate.
    Default: `false`.

  - `inherit_out_type`: Which side to inherit the out type from when `a.out_type`
    does not match `b.out_type`. If `false`, this function will raise if `a`'s rate does
    not match `b`'s rate. Default: `false`.

  ## Examples

  ```elixir
  iex> a_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex> a = Range.new!(a_in, "02:00:00:00", out_type: :inclusive)
  iex>
  iex> b_in = Framestamp.with_frames!("02:10:00:00", Rates.f23_98())
  iex> b = Range.new!(b_in, "03:30:00:00", out_type: :inclusive)
  iex>
  iex> result = Range.separation(a, b)
  iex> inspect(result)
  "{:ok, <02:00:00:01 - 02:09:59:23 :inclusive <23.98 NTSC>>}"
  ```

  ```elixir
  iex> a_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex> a = Range.new!(a_in, "02:00:00:00", out_type: :inclusive)
  iex>
  iex> b_in = Framestamp.with_frames!("01:50:00:00", Rates.f23_98())
  iex> b = Range.new!(b_in, "02:30:00:00", out_type: :inclusive)
  iex> Range.separation(a, b)
  {:error, :none}
  ```
  """
  @spec separation(
          t(),
          t(),
          inherit_rate: Framestamp.inherit_opt(),
          inherit_out_type: Framestamp.inherit_opt()
        ) :: {:ok, t()} | {:error, :none}
  def separation(a, b, opts \\ []), do: calc_overlap(a, b, opts, :separation, &(not overlaps?(&1, &2)))

  @doc section: :compare
  @doc """
  As `separation`, but returns a Range from `00:00:00:00` - `00:00:00:00` when there
  is overlap.

  ## Options

  - `inherit_rate`: Which side to inherit the framerate from in mixed-rate calculations.
    If `false`, this function will raise if `a`'s rate does not match `b`'s rate.
    Default: `false`.

  - `inherit_out_type`: Which side to inherit the out type from when `a.out_type`
    does not match `b.out_type`. If `false`, this function will raise if `a`'s rate does
    not match `b`'s rate. Default: `false`.

  ## Examples

  ```elixir
  iex> a_in = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
  iex> a = Range.new!(a_in, "02:00:00:00", out_type: :inclusive)
  iex>
  iex> b_in = Framestamp.with_frames!("01:50:00:00", Rates.f23_98())
  iex> b = Range.new!(b_in, "02:30:00:00", out_type: :inclusive)
  iex>
  iex> result = Range.separation!(a, b)
  iex> inspect(result)
  "<00:00:00:00 - -00:00:00:01 :inclusive <23.98 NTSC>>"
  ```
  """
  @spec separation!(
          t(),
          t(),
          inherit_rate: Framestamp.inherit_opt(),
          inherit_out_type: Framestamp.inherit_opt()
        ) :: t()
  def separation!(a, b, opts \\ []) do
    case separation(a, b, opts) do
      {:ok, overlap} -> overlap
      {:error, :none} -> create_zeroed_range(a, b, :separation, opts)
    end
  end

  # Creates a zero-duration range using the framerate and `:out_type` of `reference`.
  @spec create_zeroed_range(
          t(),
          t(),
          atom(),
          inherit_rate: Framestamp.inherit_opt(),
          inherit_out_type: Framestamp.inherit_opt()
        ) :: t()
  defp create_zeroed_range(a, b, func_name, opts) do
    inherit_rate = Keyword.get(opts, :inherit_rate, false)
    inherit_out_type = Keyword.get(opts, :inherit_out_type, false)
    out_type = get_mixed_out_type([a, b], inherit_out_type, func_name)

    case MixedRateOps.get_rate(a.in, b.in, inherit_rate, func_name) do
      {:ok, framerate} ->
        zero_framestamp = Framestamp.with_frames!(0, framerate)
        zero_range = with_duration!(zero_framestamp, zero_framestamp)
        if out_type == :inclusive, do: with_inclusive_out(zero_range), else: zero_range

      {:error, error} ->
        raise error
    end
  end

  # Returns the amount of intersection or separation between `a` and `b`, or `nil` if
  # `return_nil?` returns `true`.
  @spec calc_overlap(
          t(),
          t(),
          [inherit_rate: Framestamp.inherit_opt(), inherit_out_type: Framestamp.inherit_opt()],
          func_name :: atom(),
          return_nil? :: (t(), t() -> nil)
        ) :: {:ok, t()} | {:error, :none}
  defp calc_overlap(a, b, opts, func_name, do_calc?) do
    inherit_rate = Keyword.get(opts, :inherit_rate, false)
    inherit_out_type = Keyword.get(opts, :inherit_out_type, false)

    result =
      calc_with_exclusive([a, b], inherit_out_type, func_name, fn a, b ->
        if do_calc?.(a, b) do
          case MixedRateOps.get_rate(a.in, b.in, inherit_rate, func_name) do
            {:ok, new_rate} ->
              overlap_in = Enum.max([a.in, b.in], Framestamp)
              overlap_in = Framestamp.with_seconds!(overlap_in.seconds, new_rate)

              overlap_out = Enum.min([a.out, b.out], Framestamp)
              overlap_out = Framestamp.with_seconds!(overlap_out.seconds, new_rate)

              # These values will be flipped when calculating separation range, so we need to
              # sort them.
              [overlap_in, overlap_out] = Enum.sort([overlap_in, overlap_out], Framestamp)
              %__MODULE__{a | in: overlap_in, out: overlap_out}

            {:error, error} ->
              raise error
          end
        else
          {:error, :none}
        end
      end)

    with %__MODULE__{} <- result do
      {:ok, result}
    end
  end

  # Runs a calculation, converting any ranges in `args` to exclusive out points then,
  # if the result is also a range, casting its out point to the same type as the first
  # Range argument in `args`.
  @spec calc_with_exclusive([t()], Framestamp.inherit_opt(), atom(), (... -> result)) :: result when result: any()
  defp calc_with_exclusive(args, inherit_opt, func_name, calc) do
    out_type = get_mixed_out_type(args, inherit_opt, func_name)

    args
    |> Enum.map(fn
      %__MODULE__{} = range -> with_exclusive_out(range)
      value -> value
    end)
    |> then(&apply(calc, &1))
    |> then(fn
      %__MODULE__{} = range -> with_out_type(range, out_type)
      value -> value
    end)
  end

  # Get the target out type for mixed frame operations.
  @spec get_mixed_out_type([t()], Framestamp.inherit_opt(), atom()) :: Framestamp.Range.out_type()
  defp get_mixed_out_type(args, inherit_opt, func_name) do
    case {args, inherit_opt} do
      {[%{out_type: out_type}], _} ->
        out_type

      {[%{out_type: out_type}, _], :left} ->
        out_type

      {[_, %{out_type: out_type}], :right} ->
        out_type

      {[%{out_type: out_type}, %{out_type: out_type}], false} ->
        out_type

      {[%{out_type: left}, %{out_type: right}], _} ->
        raise %MixedOutTypeArithmeticError{left_out_type: left, right_out_type: right, func_name: func_name}
    end
  end

  when_pg_enabled do
    use Ecto.Type

    @impl Ecto.Type
    @spec type() :: atom()
    defdelegate type, to: PgFramestamp.Range

    @impl Ecto.Type
    @spec cast(t() | %{String.t() => any()} | %{atom() => any()}) :: {:ok, t()} | :error
    defdelegate cast(value), to: PgFramestamp.Range

    @impl Ecto.Type
    @spec load(PgFramestamp.Range.db_record()) :: {:ok, t()} | :error
    defdelegate load(value), to: PgFramestamp.Range

    @impl Ecto.Type
    @spec dump(t()) :: {:ok, PgFramestamp.Range.db_record()} | :error
    defdelegate dump(value), to: PgFramestamp.Range
  end
end

defimpl Inspect, for: Vtc.Framestamp.Range do
  alias Vtc.Framestamp
  alias Vtc.Framestamp.Range

  @spec inspect(Range.t(), Elixir.Inspect.Opts.t()) :: String.t()
  def inspect(range, _opts) do
    "<#{Framestamp.smpte_timecode(range.in)} - #{Framestamp.smpte_timecode(range.out)} :#{range.out_type} #{inspect(range.in.rate)}>"
  end
end

defimpl String.Chars, for: Vtc.Framestamp.Range do
  alias Vtc.Framestamp.Range

  @spec to_string(Range.t()) :: String.t()
  def to_string(range), do: inspect(range)
end
