defmodule Vtc.Source.PremiereTicks do
  @moduledoc """
  Implements `Seconds` protocol for Premiere ticks. See `Timecode.premiere_ticks/1`
  for more information on this unit.

  Thus struct is used as an input wrapper only, not as the general-purpose Premiere
  ticks unit.
  """

  @enforce_keys [:in]
  defstruct [:in]

  @typedoc """
  Contains only a single field for wrapping the underlying integer.
  """
  @type t() :: %__MODULE__{in: integer()}
end

defimpl Vtc.Source.Seconds, for: Vtc.Source.PremiereTicks do
  @moduledoc """
  Implements `Seconds` protocol for Premiere ticks.
  """

  alias Vtc.Framerate
  alias Vtc.Source.PremiereTicks
  alias Vtc.Source.Seconds
  alias Vtc.Utils.Consts

  @spec seconds(PremiereTicks.t(), Framerate.t()) :: Seconds.result()
  def seconds(ticks, _), do: {:ok, Ratio.new(ticks.in, Consts.ppro_tick_per_second())}
end
