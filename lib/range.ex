defmodule Vtc.Range do
  @moduledoc """
  Holds a timecode range.

  ## Struct Fields

  - **in**: Start TC. Must be less than or equal to `out`.
  - **out**: End TC. Must be greater than or equal to `in`.
  - **inclusive** Default: `false`. See below for more information.

  ## Inclusive vs. Exclusive Ranges.

  Inclusive ranges include the `out` timecode value as a frame that is part of the
  range. This style of tc range is most often associated with AVID.

  Exclusive timecode ranges treat the `out` timecde value as the *boundry* where the
  range ends. This style of tc range is most often associated with Final Cut and
  Premiere.

  In mathematical notation, inclusive ranges are `[in, out]`, while exclusive ranges are
  `[in, out)`.
  """

  alias Vtc.Timecode

  @typedoc """
  Range struct type.
  """
  @type t() :: %__MODULE__{
          in: Timecode.t(),
          out: Timecode.t(),
          out_inclusive?: boolean()
        }

  @enforce_keys [:in, :out, :out_inclusive?]
  defstruct [:in, :out, :out_inclusive?]

  @doc """
  Creates a new timecode.

  Returns an error if `tc_out` is less than `tc_in` (when measured wuth an exclusive
  out) or if `tc_in` and `tc_out` do not have the same `rate`.
  """
  @spec new(Timecode.t(), Timecode.t(), boolean()) :: {:ok, t()} | {:error, Exception.t()}
  def new(tc_in, tc_out, out_inclusive? \\ false)

  def new(tc_in, tc_out, out_inclusive?) do
    with :ok <- validate_rates_equal(tc_in, tc_out, :tc_in, :tc_out),
         :ok <- validate_in_amd_out(tc_in, tc_out, out_inclusive?) do
      {:ok, %__MODULE__{in: tc_in, out: tc_out, out_inclusive?: out_inclusive?}}
    end
  end

  @doc """
  As `new/3`, but raises on error.
  """
  @spec new!(Timecode.t(), Timecode.t(), boolean()) :: t()
  def new!(tc_in, tc_out, out_inclusive? \\ false) do
    case new(tc_in, tc_out, out_inclusive?) do
      {:ok, range} -> range
      {:error, error} -> raise error
    end
  end

  # Validates that `out_tc` is greater than or equal to `in_tc`, when measured
  # exclusively.
  @spec validate_in_amd_out(Timecode.t(), Timecode.t(), boolean()) ::
          :ok | {:error, Exception.t()}
  defp validate_in_amd_out(in_tc, out_tc, out_inclusive?) do
    out_tc = adjust_out_exclusive(out_tc, out_inclusive?)

    if Timecode.compare(out_tc, in_tc) in [:gt, :eq] do
      :ok
    else
      {:error, ArgumentError.exception("`tc_out` must be greater than or equal to `tc_in`")}
    end
  end

  @doc """
  Returns a range with an `:in` value of `tc_in` and a duration of `duration`.

  Returns an error if `duration` is less than `0` seconds or if `tc_in` and `tc_out` do
  not have  the same `rate`.
  """
  @spec with_duration(Timecode.t(), Timecode.t(), boolean()) ::
          {:ok, t()} | {:error, Exception.t()}
  def with_duration(tc_in, duration, out_inclusive? \\ false)

  def with_duration(tc_in, duration, true) do
    with {:ok, range} <- with_duration(tc_in, duration, false) do
      {:ok, with_exclusive_out(range)}
    end
  end

  def with_duration(tc_in, duration, false) do
    with :ok <- validate_rates_equal(tc_in, duration, :tc_in, :duration),
         :ok <- with_duration_validate_duration(duration) do
      tc_out = Timecode.add(tc_in, duration)
      new(tc_in, tc_out, false)
    end
  end

  @doc """
  As with_duration/3, but raises on error.
  """
  @spec with_duration!(Timecode.t(), Timecode.t(), boolean()) :: t()
  def with_duration!(tc_in, duration, out_inclusive? \\ false) do
    case with_duration(tc_in, duration, out_inclusive?) do
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
  """
  @spec with_inclusive_out(t()) :: t()
  def with_inclusive_out(%{out_inclusive?: true} = range), do: range

  def with_inclusive_out(range),
    do: %__MODULE__{range | out: Timecode.sub(range.out, 1), out_inclusive?: true} |> dbg()

  @doc """
  Adjusts range to have an exclusive out timecode.
  """
  @spec with_exclusive_out(t()) :: t()
  def with_exclusive_out(%{out_inclusive?: false} = range), do: range

  def with_exclusive_out(range),
    do: %__MODULE__{range | out: adjust_out_exclusive(range.out, true), out_inclusive?: false}

  # Asdjusts an out TC to be an exclusive out.
  @spec adjust_out_exclusive(Timecode.t(), out_inclusive? :: boolean()) :: Timecode.t()
  defp adjust_out_exclusive(tc, false), do: tc
  defp adjust_out_exclusive(tc, true), do: Timecode.add(tc.out, 1)

  @doc """
  Returns the duration in timecode of `range`.
  """
  @spec duration(t()) :: Timecode.t()
  def duration(range) do
    %{in: in_tc, out: out_tc} = with_exclusive_out(range)
    Timecode.sub(out_tc, in_tc)
  end

  @doc """
  Returns `true` if there is overlap between `a` and `b`.
  """
  @spec overlaps?(t(), t()) :: boolean()
  def overlaps?(%{out_inclusive?: true} = a, b) do
    a = with_exclusive_out(a)
    overlaps?(a, b)
  end

  def overlaps?(a, %{out_inclusive?: true} = b) do
    b = with_exclusive_out(b)
    overlaps?(a, b)
  end

  def overlaps?(%{out_inclusive?: false} = a, %{out_inclusive?: false} = b) do
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
  """
  @spec intersection(t(), t()) :: t() | nil
  def intersection(a, b), do: calc_overlap(a, b, &(not overlaps?(&1, &2)))

  @doc """
  Returns `nil` if the two ranges do intersect, otherwise returns the Range of the space
  between the intersections of the two Ranges.

  `a` and `b` do not have to have matching `out_inclusive?` settings, but the result
  will inherit `a`'s setting.
  """
  @spec separation(t(), t()) :: t() | nil
  def separation(a, b), do: calc_overlap(a, b, &(not overlaps?(&1, &2)))

  # Returns the amount of intersection or separation between `a` and `b`, or `nil` if
  # `return_nil?` returns `true`.
  @spec calc_overlap(t(), t(), return_nil? :: (t(), t() -> nil)) :: t() | nil
  defp calc_overlap(a, %{out_inclusive?: true} = b, return_nil?) do
    b = with_exclusive_out(b)
    calc_overlap(a, b, return_nil?)
  end

  defp calc_overlap(%{out_inclusive?: true} = a, b, return_nil?) do
    a
    |> with_exclusive_out()
    |> calc_overlap(b, return_nil?)
    |> with_inclusive_out()
  end

  defp calc_overlap(%{out_inclusive?: false} = a, %{out_inclusive?: false} = b, return_nil?) do
    if return_nil?.(a, b) do
      overlap_in = Timecode.max([a.in, b.in])
      overlap_out = Timecode.min([a.out, b.out])
      %__MODULE__{a | in: overlap_in, out: overlap_out}
    else
      nil
    end
  end
end
