defmodule Vtc.Range do
  @moduledoc """
  Holds a timecode range.

  ## Struct Fields

  - `in`: Start TC. Must be less than or equal to `out`.
  - `out`: End TC. Must be greater than or equal to `in`.
  - `inclusive`: See below for more information. Default: `false`

  ## Inclusive vs. Exclusive Ranges

  Inclusive ranges treat the `out` timecode as the last visible frame of a piece of
  footage. This style of tc range is most often associated with AVID.

  Exclusive timecode ranges treat the `out` timecode as the *boundary* where the range
  ends. This style of tc range is most often associated with Final Cut and Premiere.

  In mathematical notation, inclusive ranges are `[in, out]`, while exclusive ranges are
  `[in, out)`.
  """

  alias Vtc.Source.Frames
  alias Vtc.Timecode

  @typedoc """
  Whether the end point should be treated as the Range's boundary (:exclusive), or its
  last element (:inclusive).
  """
  @type out_type() :: :inclusive | :exclusive

  @typedoc """
  Range struct type.
  """
  @type t() :: %__MODULE__{
          in: Timecode.t(),
          out: Timecode.t(),
          out_type: out_type()
        }

  @enforce_keys [:in, :out, :out_type]
  defstruct [:in, :out, :out_type]

  @doc """
  Creates a new `Range`.

  `out_tc` may be a `Timecode` value for any value that implements the `Frames`
  protocol.

  Returns an error if the resulting range would not have a duration greater or eual to
  0, or if `tc_in` and `tc_out` do not have the same `rate`.

  ## Examples

  ```elixir
  iex> tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> tc_out = Timecode.with_frames!("02:00:00:00", Rates.f23_98())
  iex> Range.new(tc_in, tc_out) |> inspect()
  "{:ok, <01:00:00:00 - 02:00:00:00 :exclusive <23.98 NTSC NDF>>}"
  ```

  Using a timecode string as `b`:

  ```elixir
  iex> tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> Range.new(tc_in, "02:00:00:00") |> inspect()
  "{:ok, <01:00:00:00 - 02:00:00:00 :exclusive <23.98 NTSC NDF>>}"
  ```

  Making a range with an inclusive out:

  ```elixir
  iex> tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> Range.new(tc_in, "02:00:00:00", out_type: :inclusive) |> inspect()
  "{:ok, <01:00:00:00 - 02:00:00:00 :inclusive <23.98 NTSC NDF>>}"
  ```
  """
  @spec new(
          in_tc :: Timecode.t(),
          out_tc :: Timecode.t() | Frames.t(),
          opts :: [out_type: out_type()]
        ) :: {:ok, t()} | {:error, Exception.t() | Timecode.ParseError.t()}
  def new(tc_in, tc_out, opts \\ [])

  def new(tc_in, %Timecode{} = tc_out, opts) do
    out_type = Keyword.get(opts, :out_type, :exclusive)

    with :ok <- validate_rates_equal(tc_in, tc_out, :tc_in, :tc_out),
         :ok <- validate_in_and_out(tc_in, tc_out, out_type) do
      {:ok, %__MODULE__{in: tc_in, out: tc_out, out_type: out_type}}
    end
  end

  def new(tc_in, tc_out, opts) do
    with {:ok, tc_out} <- Timecode.with_frames(tc_out, tc_in.rate) do
      new(tc_in, tc_out, opts)
    end
  end

  @doc """
  As `new/3`, but raises on error.
  """
  @spec new!(Timecode.t(), Timecode.t(), opts :: [out_type: out_type()]) :: t()
  def new!(tc_in, tc_out, opts \\ []) do
    case new(tc_in, tc_out, opts) do
      {:ok, range} -> range
      {:error, error} -> raise error
    end
  end

  # Validates that `out_tc` is greater than or equal to `in_tc`, when measured
  # exclusively.
  @spec validate_in_and_out(Timecode.t(), Timecode.t(), out_type()) ::
          :ok | {:error, Exception.t()}
  defp validate_in_and_out(in_tc, out_tc, out_type) do
    out_tc = adjust_out_exclusive(out_tc, out_type)

    if Timecode.compare(out_tc, in_tc) in [:gt, :eq] do
      :ok
    else
      {:error, ArgumentError.exception("`tc_out` must be greater than or equal to `tc_in`")}
    end
  end

  @doc """
  Returns a range with an `:in` value of `tc_in` and a duration of `duration`.
  `duration` may be a `Timecode` value for any value that implements the `Frames`
  protocol.

  Returns an error if `duration` is less than `0` seconds or if `tc_in` and `tc_out` do
  not have  the same `rate`.

  ## Examples

  ```elixir
  iex> start_tc = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> duration = Timecode.with_frames!("00:30:00:00", Rates.f23_98())
  iex> Range.with_duration(start_tc, duration) |> inspect()
  "{:ok, <01:00:00:00 - 01:30:00:00 :exclusive <23.98 NTSC NDF>>}"
  ```

  Using a timecode string as `b`:

  ```elixir
  iex> start_tc = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> Range.with_duration(start_tc, "00:30:00:00") |> inspect()
  "{:ok, <01:00:00:00 - 01:30:00:00 :exclusive <23.98 NTSC NDF>>}"
  ```

  Making a range with an inclusive out:

  ```elixir
  iex> start_tc = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> Range.with_duration(start_tc, "00:30:00:00", out_type: :inclusive) |> inspect()
  "{:ok, <01:00:00:00 - 01:29:59:23 :inclusive <23.98 NTSC NDF>>}"
  ```
  """
  @spec with_duration(
          tc_in :: Timecode.t(),
          duration :: Timecode.t() | Frames.t(),
          opts :: [out_type: out_type()]
        ) :: {:ok, t()} | {:error, Exception.t() | Timecode.ParseError.t()}
  def with_duration(tc_in, duration, opts \\ [])

  def with_duration(tc_in, %Timecode{} = duration, out_type: :inclusive) do
    with {:ok, range} <- with_duration(tc_in, duration, []) do
      {:ok, with_inclusive_out(range)}
    end
  end

  def with_duration(tc_in, %Timecode{} = duration, _) do
    with :ok <- validate_rates_equal(tc_in, duration, :tc_in, :duration),
         :ok <- with_duration_validate_duration(duration) do
      tc_out = Timecode.add(tc_in, duration)
      new(tc_in, tc_out, out_type: :exclusive)
    end
  end

  def with_duration(tc_in, duration, opts) do
    with {:ok, duration} <- Timecode.with_frames(duration, tc_in.rate) do
      with_duration(tc_in, duration, opts)
    end
  end

  @doc """
  As with_duration/3, but raises on error.
  """
  @spec with_duration!(Timecode.t(), Timecode.t(), opts :: [out_type: out_type()]) :: t()
  def with_duration!(tc_in, duration, opts \\ []) do
    case with_duration(tc_in, duration, opts) do
      {:ok, range} -> range
      {:error, error} -> raise error
    end
  end

  @spec with_duration_validate_duration(Timecode.t()) :: :ok | {:error, Exception.t()}
  defp with_duration_validate_duration(duration) do
    if Timecode.compare(duration, 0) != :lt do
      :ok
    else
      {:error, ArgumentError.exception("`duration` must be greater than `0`")}
    end
  end

  @spec validate_rates_equal(Timecode.t(), Timecode.t(), atom(), atom()) ::
          :ok | {:error, Exception.t()}
  defp validate_rates_equal(%{rate: rate}, %{rate: rate}, _, _), do: :ok

  defp validate_rates_equal(_, _, a_name, b_name),
    do: {:error, ArgumentError.exception("`#{a_name}` and `#{b_name}` must have same `rate`")}

  @doc """
  Adjusts range to have an inclusive out timecode.

  ## Examples

  ```elixir
  iex> tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> range = Range.new!(tc_in, "02:00:00:00")
  iex> Range.with_inclusive_out(range) |> inspect()
  "<01:00:00:00 - 01:59:59:23 :inclusive <23.98 NTSC NDF>>"
  ```
  """
  @spec with_inclusive_out(t()) :: t()
  def with_inclusive_out(%{out_type: :inclusive} = range), do: range

  def with_inclusive_out(range) do
    new_out = Timecode.sub(range.out, 1, round: :off)
    %__MODULE__{range | out: new_out, out_type: :inclusive}
  end

  @doc """
  Adjusts range to have an exclusive out timecode.

  ## Examples

  ```elixir
  iex> tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> range = Range.new!(tc_in, "02:00:00:00", out_type: :inclusive)
  iex> Range.with_exclusive_out(range) |> inspect()
  "<01:00:00:00 - 02:00:00:01 :exclusive <23.98 NTSC NDF>>"
  ```
  """
  @spec with_exclusive_out(t()) :: t()
  def with_exclusive_out(%{out_type: :exclusive} = range), do: range

  def with_exclusive_out(range) do
    new_out = adjust_out_exclusive(range.out, :inclusive)
    %__MODULE__{range | out: new_out, out_type: :exclusive}
  end

  # Asdjusts an out TC to be an exclusive out.
  @spec adjust_out_exclusive(Timecode.t(), out_type()) :: Timecode.t()
  defp adjust_out_exclusive(tc, :exclusive), do: tc
  defp adjust_out_exclusive(tc, :inclusive), do: Timecode.add(tc, 1, round: :off)

  @doc """
  Returns the duration in timecode of `range`.

  ## Examples

  ```elixir
  iex> tc_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> range = Range.new!(tc_in, "01:30:00:00")
  iex> Range.duration(range) |> inspect()
  "<00:30:00:00 <23.98 NTSC NDF>>"
  ```
  """
  @spec duration(t()) :: Timecode.t()
  def duration(range) do
    %{in: in_tc, out: out_tc} = with_exclusive_out(range)
    Timecode.sub(out_tc, in_tc)
  end

  @doc """
  Returns `true` if there is overlap between `a` and `b`.

  ## Examples

  ```elixir
  iex> a_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> a = Range.new!(a_in, "02:00:00:00", out_type: :inclusive)
  iex>
  iex> b_in = Timecode.with_frames!("01:50:00:00", Rates.f23_98())
  iex> b = Range.new!(b_in, "02:30:00:00", out_type: :inclusive)
  iex> Range.overlaps?(a, b)
  true
  ```

  ```elixir
  iex> a_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> a = Range.new!(a_in, "02:00:00:00", out_type: :inclusive)
  iex>
  iex> b_in = Timecode.with_frames!("02:10:00:00", Rates.f23_98())
  iex> b = Range.new!(b_in, "03:30:00:00", out_type: :inclusive)
  iex> Range.overlaps?(a, b)
  false
  ```
  """
  @spec overlaps?(t(), t()) :: boolean()
  def overlaps?(%{out_type: :inclusive} = a, b) do
    a = with_exclusive_out(a)
    overlaps?(a, b)
  end

  def overlaps?(a, %{out_type: :inclusive} = b) do
    b = with_exclusive_out(b)
    overlaps?(a, b)
  end

  def overlaps?(%{out_type: :exclusive} = a, %{out_type: :exclusive} = b) do
    cond do
      Timecode.compare(a.in, b.out) in [:gt, :eq] -> false
      Timecode.compare(a.out, b.in) in [:lt, :eq] -> false
      true -> true
    end
  end

  @doc """
  Returns `nil` if the two ranges do not intersect, otherwise returns the Range
  of the intersection of the two Ranges.

  `a` and `b` do not have to have matching `out_inclusive?` settings, but the result
  will inherit `a`'s setting.

  ## Examples

  ```elixir
  iex> a_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> a = Range.new!(a_in, "02:00:00:00", out_type: :inclusive)
  iex>
  iex> b_in = Timecode.with_frames!("01:50:00:00", Rates.f23_98())
  iex> b = Range.new!(b_in, "02:30:00:00", out_type: :inclusive)
  iex> Range.intersection(a, b) |> inspect()
  "{:ok, <01:50:00:00 - 02:00:00:00 :inclusive <23.98 NTSC NDF>>}"
  ```

  ```elixir
  iex> a_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> a = Range.new!(a_in, "02:00:00:00", out_type: :inclusive)
  iex>
  iex> b_in = Timecode.with_frames!("02:10:00:00", Rates.f23_98())
  iex> b = Range.new!(b_in, "03:30:00:00", out_type: :inclusive)
  iex> Range.intersection(a, b)
  {:error, :none}
  ```
  """
  @spec intersection(t(), t()) :: {:ok, t()} | {:error, :none}
  def intersection(a, b), do: calc_overlap(a, b, &overlaps?(&1, &2))

  @doc """
  As `intersection`, but returns a Range from `00:00:00:00` - `00:00:00:00` when there
  is no overlap.

  This returned range inherets the framerate and `out_type` from `a`.

  ## Examples

  ```elixir
  iex> a_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> a = Range.new!(a_in, "02:00:00:00", out_type: :inclusive)
  iex>
  iex> b_in = Timecode.with_frames!("02:10:00:00", Rates.f23_98())
  iex> b = Range.new!(b_in, "03:30:00:00", out_type: :inclusive)
  iex> Range.intersection!(a, b) |> inspect()
  "<00:00:00:00 - -00:00:00:01 :inclusive <23.98 NTSC NDF>>"
  ```
  """
  @spec intersection!(t(), t()) :: t()
  def intersection!(a, b) do
    case intersection(a, b) do
      {:ok, overlap} -> overlap
      {:error, :none} -> create_zeroed_range(a)
    end
  end

  @doc """
  Returns `nil` if the two ranges do intersect, otherwise returns the Range of the space
  between the intersections of the two Ranges.

  `a` and `b` do not have to have matching `out_inclusive?` settings, but the result
  will inherit `a`'s setting.

  ## Examples

  ```elixir
  iex> a_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> a = Range.new!(a_in, "02:00:00:00", out_type: :inclusive)
  iex>
  iex> b_in = Timecode.with_frames!("02:10:00:00", Rates.f23_98())
  iex> b = Range.new!(b_in, "03:30:00:00", out_type: :inclusive)
  iex> Range.separation(a, b) |> inspect()
  "{:ok, <02:00:00:01 - 02:09:59:23 :inclusive <23.98 NTSC NDF>>}"
  ```

  ```elixir
  iex> a_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> a = Range.new!(a_in, "02:00:00:00", out_type: :inclusive)
  iex>
  iex> b_in = Timecode.with_frames!("01:50:00:00", Rates.f23_98())
  iex> b = Range.new!(b_in, "02:30:00:00", out_type: :inclusive)
  iex> Range.separation(a, b)
  {:error, :none}
  ```
  """
  @spec separation(t(), t()) :: {:ok, t()} | {:error, :none}
  def separation(a, b), do: calc_overlap(a, b, &(not overlaps?(&1, &2)))

  @doc """
  As `separation`, but returns a Range from `00:00:00:00` - `00:00:00:00` when there
  is overlap.

  This returned range inherets the framerate and `out_type` from `a`.

  ## Examples

  ```elixir
  iex> a_in = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  iex> a = Range.new!(a_in, "02:00:00:00", out_type: :inclusive)
  iex>
  iex> b_in = Timecode.with_frames!("01:50:00:00", Rates.f23_98())
  iex> b = Range.new!(b_in, "02:30:00:00", out_type: :inclusive)
  iex> Range.separation!(a, b) |> inspect()
  "<00:00:00:00 - -00:00:00:01 :inclusive <23.98 NTSC NDF>>"
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
    zero_timecode = Timecode.with_frames!(0, reference.in.rate)
    zero_range = with_duration!(zero_timecode, zero_timecode)

    case reference do
      %{out_type: :inclusive} -> with_inclusive_out(zero_range)
      _ -> zero_range
    end
  end

  # Returns the amount of intersection or separation between `a` and `b`, or `nil` if
  # `return_nil?` returns `true`.
  @spec calc_overlap(t(), t(), return_nil? :: (t(), t() -> nil)) :: {:ok, t()} | {:error, :none}
  defp calc_overlap(a, %{out_type: :inclusive} = b, do_calc?) do
    b = with_exclusive_out(b)
    calc_overlap(a, b, do_calc?)
  end

  defp calc_overlap(%{out_type: :inclusive} = a, b, do_calc?) do
    a = with_exclusive_out(a)

    with {:ok, overlap} <- calc_overlap(a, b, do_calc?) do
      {:ok, with_inclusive_out(overlap)}
    end
  end

  defp calc_overlap(%{out_type: :exclusive} = a, %{out_type: :exclusive} = b, do_calc?) do
    if do_calc?.(a, b) do
      result_rate = a.in.rate

      overlap_in = Enum.max([a.in, b.in], Timecode)
      overlap_in = Timecode.with_seconds!(overlap_in.seconds, result_rate)

      overlap_out = Enum.min([a.out, b.out], Timecode)
      overlap_out = Timecode.with_seconds!(overlap_out.seconds, result_rate)

      # These values will be flipped when calulcating separation range, so we need to
      # sort them.
      [overlap_in, overlap_out] = Enum.sort([overlap_in, overlap_out], Timecode)
      overlap = %__MODULE__{a | in: overlap_in, out: overlap_out}
      {:ok, overlap}
    else
      {:error, :none}
    end
  end
end

defimpl Inspect, for: Vtc.Range do
  alias Vtc.Range
  alias Vtc.Timecode

  @spec inspect(Range.t(), Elixir.Inspect.Opts.t()) :: String.t()
  def inspect(range, _opts) do
    "<#{Timecode.timecode(range.in)} - #{Timecode.timecode(range.out)} :#{range.out_type} #{inspect(range.in.rate)}>"
  end
end

defimpl String.Chars, for: Vtc.Range do
  alias Vtc.Range

  @spec to_string(Range.t()) :: String.t()
  def to_string(range), do: inspect(range)
end
