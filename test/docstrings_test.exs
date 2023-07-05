defmodule Vtc.DocsTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Vtc.Framerate
  alias Vtc.Framestamp
  alias Vtc.Framestamp.Range
  alias Vtc.Rates
  alias Vtc.Source

  doctest Range
  doctest Framerate
  doctest Framestamp
  doctest Source.Frames.FeetAndFrames
end
