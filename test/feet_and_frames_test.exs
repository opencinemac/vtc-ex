defmodule Vtc.Source.Frames.FeetAndFramesTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Vtc.Framestamp
  alias Vtc.Source.Frames.FeetAndFrames

  describe "#from_string!/2" do
    test "succeeds on good input" do
      expected = %FeetAndFrames{feet: 10, frames: 04, film_format: :ff35mm_4perf}
      assert ^expected = FeetAndFrames.from_string!("10+04")
    end

    test "succeeds on good input with format opt" do
      expected = %FeetAndFrames{feet: 10, frames: 04, film_format: :ff16mm}
      assert ^expected = FeetAndFrames.from_string!("10+04", film_format: :ff16mm)
    end

    test "raises on bad input" do
      error = assert_raise Framestamp.ParseError, fn -> FeetAndFrames.from_string!("bad_value") end

      assert error.reason == :unrecognized_format
      assert Exception.message(error) == "string format not recognized"
    end
  end
end
