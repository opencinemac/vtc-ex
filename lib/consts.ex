defmodule Private.Const do
  @moduledoc false

  @spec secondsPerMinute() :: integer
  def secondsPerMinute() do
    60
  end

  @spec secondsPerHour() :: integer
  def secondsPerHour() do
    secondsPerMinute() * 60
  end

  @spec ppro_tick_per_second() :: integer
  def ppro_tick_per_second() do
    254_016_000_000
  end
end
