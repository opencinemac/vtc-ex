defmodule Vtc.Utils.Consts do
  @moduledoc false

  @spec seconds_per_minute() :: pos_integer()
  def seconds_per_minute, do: 60

  @spec seconds_per_hour() :: pos_integer()
  def seconds_per_hour, do: seconds_per_minute() * 60

  @spec ppro_tick_per_second() :: pos_integer()
  def ppro_tick_per_second, do: 254_016_000_000

  @spec frames_per_foot() :: pos_integer()
  def frames_per_foot, do: 16
end
