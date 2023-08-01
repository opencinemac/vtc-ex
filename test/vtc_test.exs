defmodule VtcTest do
  @moduledoc false
  use Vtc.Test.Support.TestCase

  alias Vtc.Framerate
  alias Vtc.Framestamp
  alias Vtc.Rates

  describe "#is_error/1" do
    is_error_table = [
      %{error: %Framestamp.ParseError{reason: :unrecognized_format}, expected: true},
      %{error: %Framestamp.ParseError{reason: :bad_drop_frames}, expected: true},
      %{error: %Framestamp.ParseError{reason: :drop_frame_maximum_exceeded}, expected: true},
      %{error: %Framestamp.ParseError{reason: :partial_frame}, expected: true},
      %{
        error: %Framestamp.MixedRateArithmeticError{
          func_name: :add,
          left_rate: Rates.f23_98(),
          right_rate: Rates.f24()
        },
        expected: true
      },
      %{
        error: %Framestamp.Range.MixedOutTypeArithmeticError{
          func_name: :intersection,
          left_out_type: :exclusive,
          right_out_type: :inclusive
        },
        expected: true
      },
      %{error: %Framerate.ParseError{reason: :invalid_ntsc}, expected: true},
      %{error: %Framerate.ParseError{reason: :coerce_requires_ntsc}, expected: true},
      %{error: %Framerate.ParseError{reason: :unrecognized_format}, expected: true},
      %{error: %Framerate.ParseError{reason: :imprecise_float_float}, expected: true},
      %{error: %Framerate.ParseError{reason: :non_positive}, expected: true},
      %{error: %Framerate.ParseError{reason: :invalid_ntsc_rate}, expected: true},
      %{error: %Framerate.ParseError{reason: :bad_drop_rate}, expected: true},
      %{error: ArgumentError.exception("some error message"), expected: false}
    ]

    table_test "returns true for <%= error %>", is_error_table, test_case do
      %{error: error, expected: expected} = test_case
      assert Vtc.is_error?(error) == expected
    end

    table_test "returns false for {:error, <%= error %>}", is_error_table, test_case do
      %{error: error} = test_case
      assert Vtc.is_error?({:error, error}) == false
    end
  end
end
