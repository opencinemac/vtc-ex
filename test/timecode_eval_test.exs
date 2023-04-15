defmodule Vtc.Timecode.EvalTest do
  @moduledoc false

  use ExUnit.Case, async: true

  alias Vtc.Rates
  alias Vtc.Timecode

  require Timecode

  test "eval +/2" do
    result =
      Timecode.eval at: Rates.f23_98() do
        "01:00:00:00" + "02:00:00:00"
      end

    assert result == Timecode.with_frames!("03:00:00:00", Rates.f23_98())
  end

  test "eval -/2" do
    result =
      Timecode.eval at: Rates.f23_98() do
        "01:00:00:00" - "02:00:00:00"
      end

    assert result == Timecode.with_frames!("-01:00:00:00", Rates.f23_98())
  end

  test "eval */2" do
    result =
      Timecode.eval at: Rates.f23_98() do
        "01:00:00:00" * 2
      end

    assert result == Timecode.with_frames!("02:00:00:00", Rates.f23_98())
  end

  test "eval //2" do
    result =
      Timecode.eval at: Rates.f23_98() do
        "01:00:00:00" / 2
      end

    assert result == Timecode.with_frames!("00:30:00:00", Rates.f23_98())
  end

  test "eval ==/2 | true" do
    result =
      Timecode.eval at: Rates.f23_98() do
        "01:00:00:00" == "01:00:00:00"
      end

    assert result == true
  end

  test "eval ==/2 | false" do
    tc1 = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
    tc2 = Timecode.with_frames!("01:00:00:00", Rates.f24())

    result =
      Timecode.eval at: Rates.f23_98() do
        tc1 == tc2
      end

    assert result == false
  end

  test "eval </2 | true" do
    result =
      Timecode.eval at: Rates.f23_98() do
        "01:00:00:00" < "02:00:00:00"
      end

    assert result == true
  end

  test "eval </2 | false" do
    result =
      Timecode.eval at: Rates.f23_98() do
        "02:00:00:00" < "01:00:00:00"
      end

    assert result == false
  end

  test "eval <=/2 | true | lt" do
    result =
      Timecode.eval at: Rates.f23_98() do
        "01:00:00:00" < "02:00:00:00"
      end

    assert result == true
  end

  test "eval <=/2 | true | eq" do
    result =
      Timecode.eval at: Rates.f23_98() do
        "01:00:00:00" < "02:00:00:00"
      end

    assert result == true
  end

  test "eval <=/2 | false" do
    result =
      Timecode.eval at: Rates.f23_98() do
        "02:00:00:00" < "01:00:00:00"
      end

    assert result == false
  end

  test "eval >/2 | true" do
    result =
      Timecode.eval at: Rates.f23_98() do
        "02:00:00:00" > "01:00:00:00"
      end

    assert result == true
  end

  test "eval >/2 | false" do
    result =
      Timecode.eval at: Rates.f23_98() do
        "01:00:00:00" > "02:00:00:00"
      end

    assert result == false
  end

  test "eval >=/2 | true | gt" do
    result =
      Timecode.eval at: Rates.f23_98() do
        "02:00:00:00" >= "01:00:00:00"
      end

    assert result == true
  end

  test "eval >=/2 | true | eq" do
    result =
      Timecode.eval at: Rates.f23_98() do
        "01:00:00:00" >= "01:00:00:00"
      end

    assert result == true
  end

  test "eval >=/2 | false" do
    result =
      Timecode.eval at: Rates.f23_98() do
        "01:00:00:00" >= "02:00:00:00"
      end

    assert result == false
  end

  test "abs | pos" do
    result =
      Timecode.eval at: Rates.f23_98() do
        abs("01:00:00:00")
      end

    assert result == Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  end

  test "abs | neg" do
    result =
      Timecode.eval at: Rates.f23_98() do
        abs("-01:00:00:00")
      end

    assert result == Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  end

  test "-/1 | pos" do
    result =
      Timecode.eval at: Rates.f23_98() do
        -"01:00:00:00"
      end

    assert result == Timecode.with_frames!("-01:00:00:00", Rates.f23_98())
  end

  test "-/1 | neg" do
    result =
      Timecode.eval at: Rates.f23_98() do
        -"-01:00:00:00"
      end

    assert result == Timecode.with_frames!("01:00:00:00", Rates.f23_98())
  end

  test "no default framerate" do
    tc1 = Timecode.with_frames!("01:00:00:00", Rates.f23_98())

    result = Timecode.eval(tc1 + "01:00:00:00")
    assert result == Timecode.with_frames!("02:00:00:00", Rates.f23_98())
  end

  test "float default framerate" do
    result =
      Timecode.eval at: 23.98 do
        "01:00:00:00" + "01:00:00:00"
      end

    assert result == Timecode.with_frames!("02:00:00:00", Rates.f23_98())
  end

  test "float, drop default framerate" do
    result =
      Timecode.eval at: 29.97, ntsc: :drop do
        "01:00:00:00" + "01:00:00:00"
      end

    assert result == Timecode.with_frames!("02:00:00:00", Rates.f29_97_df())
  end

  test "operator precedence respected" do
    result =
      Timecode.eval at: 23.98 do
        "01:00:00:00" + "00:30:00:00" * 2 - "00:15:00:00"
      end

    assert result == Timecode.with_frames!("01:45:00:00", Rates.f23_98())
  end
end
