defmodule Private.Const do
  @moduledoc false

  @spec seconds_per_minute() :: integer
  def seconds_per_minute() do
    60
  end

  @spec seconds_per_hour() :: integer
  def seconds_per_hour() do
    seconds_per_minute() * 60
  end

  @spec ppro_tick_per_second() :: integer
  def ppro_tick_per_second() do
    254_016_000_000
  end

  @spec frames_per_foot() :: integer
  def frames_per_foot() do
    16
  end
end
