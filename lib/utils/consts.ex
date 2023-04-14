defmodule Vtc.Utils.Consts do
  @moduledoc false

  @spec seconds_per_minute() :: pos_integer()
  def seconds_per_minute, do: 60

  @spec seconds_per_hour() :: pos_integer()
  def seconds_per_hour, do: seconds_per_minute() * 60
end
