defmodule Vtc.Range do
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

  alias Vtc.Framestamp
  alias Vtc.Source.Frames

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
  Creates a new [Range](`Vtc.Range`).

  `out_tc` may be a [Framestamp](`Vtc.Framestamp`) value for any value that implements the
  [Frames](`Vtc.Source.Frames`) protocol.

  Returns an error if the resulting range would not have a duration greater or eual to
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
  `0` seconds or if `stamp_in` and `stamp_out` do not have  the same `rate`.

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
    new_out = Framestamp.sub(range.out, 1, round: :off)
    %__MODULE__{range | out: new_out, out_type: :inclusive}
  end

  defp with_out_type(range, :exclusive) do
    new_out = adjust_out_exclusive(range.out, :inclusive)
    %__MODULE__{range | out: new_out, out_type: :exclusive}
  end

  # Asdjusts an out TC to be an exclusive out.
  @spec adjust_out_exclusive(Framestamp.t(), out_type()) :: Framestamp.t()
  defp adjust_out_exclusive(framestamp, :exclusive), do: framestamp
  defp adjust_out_exclusive(framestamp, :inclusive), do: Framestamp.add(framestamp, 1, round: :off)

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
    calc_with_exclusive([range], fn range ->
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
    calc_with_exclusive([a, b], fn a, b ->
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

  Returns `nil` if the two ranges do not intersect.

  `a` and `b` do not have to have matching `:out_type` settings, but the result will
  inherit `a`'s setting.

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
  @spec intersection(t(), t()) :: {:ok, t()} | {:error, :none}
  def intersection(a, b), do: calc_overlap(a, b, &overlaps?(&1, &2))

  @doc section: :compare
  @doc """
  As `intersection`, but returns a Range from `00:00:00:00` - `00:00:00:00` when there
  is no overlap.

  This returned range inherets the framerate and `out_type` from `a`.

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
  @spec intersection!(t(), t()) :: t()
  def intersection!(a, b) do
    case intersection(a, b) do
      {:ok, overlap} -> overlap
      {:error, :none} -> create_zeroed_range(a)
    end
  end

  @doc section: :compare
  @doc """
  Returns the range between two, non-overlapping ranges.

  Returns `nil` if the two ranges are not separated.

  `a` and `b` do not have to have matching `:out_type` settings, but the result will
  inherit `a`'s setting.

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
  @spec separation(t(), t()) :: {:ok, t()} | {:error, :none}
  def separation(a, b), do: calc_overlap(a, b, &(not overlaps?(&1, &2)))

  @doc section: :compare
  @doc """
  As `separation`, but returns a Range from `00:00:00:00` - `00:00:00:00` when there
  is overlap.

  This returned range inherets the framerate and `out_type` from `a`.

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
  @spec separation!(t(), t()) :: t()
  def separation!(a, b) do
    case separation(a, b) do
      {:ok, overlap} -> overlap
      {:error, :none} -> create_zeroed_range(a)
    end
  end

  # Creates a zero-duraiton range using the framerate and `:out_type` of `reference`.
  @spec create_zeroed_range(t()) :: t()
  defp create_zeroed_range(reference) do
    zero_framestamp = Framestamp.with_frames!(0, reference.in.rate)
    zero_range = with_duration!(zero_framestamp, zero_framestamp)

    case reference do
      %{out_type: :inclusive} -> with_inclusive_out(zero_range)
      _ -> zero_range
    end
  end

  # Returns the amount of intersection or separation between `a` and `b`, or `nil` if
  # `return_nil?` returns `true`.
  @spec calc_overlap(t(), t(), return_nil? :: (t(), t() -> nil)) :: {:ok, t()} | {:error, :none}
  defp calc_overlap(a, b, do_calc?) do
    result =
      calc_with_exclusive([a, b], fn a, b ->
        if do_calc?.(a, b) do
          result_rate = a.in.rate

          overlap_in = Enum.max([a.in, b.in], Framestamp)
          overlap_in = Framestamp.with_seconds!(overlap_in.seconds, result_rate)

          overlap_out = Enum.min([a.out, b.out], Framestamp)
          overlap_out = Framestamp.with_seconds!(overlap_out.seconds, result_rate)

          # These values will be flipped when calulcating separation range, so we need to
          # sort them.
          [overlap_in, overlap_out] = Enum.sort([overlap_in, overlap_out], Framestamp)
          %__MODULE__{a | in: overlap_in, out: overlap_out}
        else
          {:error, :none}
        end
      end)

    with %__MODULE__{} <- result do
      {:ok, result}
    end
  end

  # Runs a calculation, converting any ranges in `args` to excusive out points then,
  # if the result is also a range, casting it's out point to the same type as the first
  # Range argument in `args`.
  @spec calc_with_exclusive([t() | any()], (... -> result)) :: result when result: any()
  defp calc_with_exclusive(args, calc) do
    out_type =
      Enum.find_value(args, :exclusive, fn
        %__MODULE__{out_type: out_type} -> out_type
        _ -> nil
      end)

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
end

defimpl Inspect, for: Vtc.Range do
  alias Vtc.Framestamp
  alias Vtc.Range

  @spec inspect(Range.t(), Elixir.Inspect.Opts.t()) :: String.t()
  def inspect(range, _opts) do
    "<#{Framestamp.smpte_timecode(range.in)} - #{Framestamp.smpte_timecode(range.out)} :#{range.out_type} #{inspect(range.in.rate)}>"
  end
end

defimpl String.Chars, for: Vtc.Range do
  alias Vtc.Range

  @spec to_string(Range.t()) :: String.t()
  def to_string(range), do: inspect(range)
end
