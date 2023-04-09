defmodule Vtc.DocsTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Vtc.Framerate
  alias Vtc.Range
  alias Vtc.Rates
  alias Vtc.Timecode

  doctest Range
  doctest Framerate
  doctest Timecode
end
