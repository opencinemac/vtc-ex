defmodule Vtc.Source.Seconds.PremiereTicks do
  @moduledoc """
  Implements [Seconds](`Vtc.Source.Seconds`) protocol for Premiere ticks. See
  `Vtc.Framestamp.premiere_ticks/2` for more information on this unit.

  This struct is used as an input wrapper only, not as the general-purpose Premiere
  ticks unit.
  """

  alias Vtc.Framestamp
  alias Vtc.Utils.Rational

  @enforce_keys [:in]
  defstruct [:in]

  @typedoc """
  Contains only a single field for wrapping the underlying integer.
  """
  @type t() :: %__MODULE__{in: integer()}

  @doc """
  Returns the number of ticks in a second.
  """
  @spec per_second() :: pos_integer()
  def per_second, do: 254_016_000_000

  @doc false
  @spec from_framestamp(Framestamp.t(), opts :: [round: Framestamp.round()]) :: t()
  def from_framestamp(framestamp, opts) do
    round = Keyword.get(opts, :round, :closest)

    framestamp.seconds
    |> Ratio.mult(Ratio.new(per_second()))
    |> Rational.round(round)
    |> then(&%__MODULE__{in: &1})
  end
end

defimpl Vtc.Source.Seconds, for: Vtc.Source.Seconds.PremiereTicks do
  @moduledoc """
  Implements [Seconds](`Vtc.Source.Seconds`) protocol for Premiere ticks.
  """

  alias Vtc.Framerate
  alias Vtc.Source.Seconds
  alias Vtc.Source.Seconds.PremiereTicks

  @spec seconds(PremiereTicks.t(), Framerate.t()) :: Seconds.result()
  def seconds(ticks, _), do: {:ok, Ratio.new(ticks.in, PremiereTicks.per_second())}
end
