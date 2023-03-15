defmodule Vtc.DocsTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Vtc.Framerate
  alias Vtc.Rates
  alias Vtc.Timecode

  doctest Timecode
  doctest Framerate
end
