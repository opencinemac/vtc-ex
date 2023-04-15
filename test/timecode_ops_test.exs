defmodule Vtc.TimecodeTest.Ops do
  @moduledoc false

  use ExUnit.Case, async: true

  import Vtc.TestUtils

  alias Vtc.Framerate
  alias Vtc.Rates
  alias Vtc.Source.Frames
  alias Vtc.Timecode

  setup [:setup_test_case]

  test_cases = [
    %{
      original: {"01:00:00:00", Rates.f23_98()},
      new_rate: Rates.f47_95(),
      expected: {"00:30:00:00", Rates.f47_95()}
    },
    %{
      original: {"01:00:00:00", Rates.f47_95()},
      new_rate: Rates.f23_98(),
      expected: {"02:00:00:00", Rates.f23_98()}
    },
    %{
      original: {"01:00:00:00", Rates.f23_98()},
      new_rate: Rates.f24(),
      expected: {"01:00:00:00", Rates.f24()}
    },
    %{
      original: {"01:00:00;00", Rates.f29_97_df()},
      new_rate: Rates.f29_97_ndf(),
      expected: {"00:59:56;12", Rates.f29_97_ndf()}
    },
    %{
      original: {"01:00:00;00", Rates.f59_94_df()},
      new_rate: Rates.f59_94_ndf(),
      expected: {"00:59:56;24", Rates.f59_94_ndf()}
    }
  ]

  describe "#rebase/2" do
    setup [:setup_timecodes]
    @describetag timecodes: [:original, :expected]

    for test_case <- test_cases do
      @tag test_case: test_case
      test "#{inspect(test_case.original)} -> #{inspect(test_case.new_rate)}", context do
        %{original: original, new_rate: new_rate, expected: expected} = context
        assert {:ok, rebased} = Timecode.rebase(original, new_rate)
        assert rebased == expected

        assert {:ok, round_tripped} = Timecode.rebase(rebased, original.rate)
        assert round_tripped == original
      end
    end
  end

  describe "#rebase!/2" do
    setup [:setup_timecodes]
    @describetag timecodes: [:original, :expected]

    for test_case <- test_cases do
      @tag test_case: test_case
      test "#{inspect(test_case.original)} -> #{inspect(test_case.new_rate)}", context do
        %{original: original, new_rate: new_rate, expected: expected} = context
        assert %Timecode{} = rebased = Timecode.rebase!(original, new_rate)
        assert rebased == expected

        assert %Timecode{} = round_tripped = Timecode.rebase!(rebased, original.rate)
        assert round_tripped == original
      end
    end
  end

  describe "#compare/2" do
    setup [:setup_timecodes]
    @describetag timecodes: [:a, :b]

    test_cases = [
      %{
        a: "01:00:00:00",
        b: "01:00:00:00",
        expected: :eq
      },
      %{
        a: "00:00:00:00",
        b: "01:00:00:00",
        expected: :lt
      },
      %{
        a: "-01:00:00:00",
        b: "01:00:00:00",
        expected: :lt
      },
      %{
        a: "02:00:00:00",
        b: "01:00:00:00",
        expected: :gt
      },
      %{
        a: "02:00:00:00",
        b: "00:00:00:00",
        expected: :gt
      },
      %{
        a: "02:00:00:00",
        b: "-01:00:00:00",
        expected: :gt
      },
      %{
        a: "00:00:59:23",
        b: "01:00:00:00",
        expected: :lt
      },
      %{
        a: "01:00:00:01",
        b: "01:00:00:00",
        expected: :gt
      },
      %{
        a: {"01:00:00:00", Rates.f23_98()},
        b: {"01:00:00:00", Rates.f24()},
        expected: :gt
      },
      %{
        a: {"01:00:00:00", Rates.f23_98()},
        b: {"01:00:00:00", Rates.f59_94_ndf()},
        expected: :eq
      },
      %{
        a: {"01:00:00:00", Rates.f59_94_df()},
        b: {"01:00:00:00", Rates.f59_94_ndf()},
        expected: :lt
      }
    ]

    for test_case <- test_cases do
      @tag test_case: test_case
      test "#{inspect(test_case.a)} is #{inspect(test_case.expected)} #{inspect(test_case.b)}", context do
        %{a: a, b: b, expected: expected} = context
        assert Timecode.compare(a, b) == expected
      end

      if is_binary(test_case.a) and is_binary(test_case.b) do
        name = "#{inspect(test_case.a)} is #{inspect(test_case.expected)} #{inspect(test_case.b)} | b = tc string"

        @tag test_case: test_case
        test name, context do
          %{a: a, b: b, expected: expected} = context
          b = Timecode.timecode(b)

          assert Timecode.compare(a, b) == expected
        end

        name = "#{inspect(test_case.a)} is #{inspect(test_case.expected)} #{inspect(test_case.b)} | a = tc string"

        @tag test_case: test_case
        test name, context do
          %{a: a, b: b, expected: expected} = context
          a = Timecode.timecode(a)

          assert Timecode.compare(a, b) == expected
        end

        name = "#{inspect(test_case.a)} is #{inspect(test_case.expected)} #{inspect(test_case.b)} | b = frames int"

        @tag test_case: test_case
        test name, context do
          %{a: a, b: b, expected: expected} = context
          b = Timecode.frames(b)

          assert Timecode.compare(a, b) == expected
        end

        name = "#{inspect(test_case.a)} is #{inspect(test_case.expected)} #{inspect(test_case.b)} | a = frames int"

        @tag test_case: test_case
        test name, context do
          %{a: a, b: b, expected: expected} = context
          a = Timecode.frames(a)

          assert Timecode.compare(a, b) == expected
        end
      end
    end
  end

  describe "#eq?/2" do
    test "true" do
      a = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      b = Timecode.with_frames!("01:00:00:00", Rates.f23_98())

      assert Timecode.eq?(a, b)
    end

    test "false" do
      a = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      b = Timecode.with_frames!("01:00:00:01", Rates.f23_98())

      refute Timecode.eq?(a, b)
    end
  end

  describe "#lt?/2" do
    test "true" do
      a = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      b = Timecode.with_frames!("02:00:00:00", Rates.f23_98())

      assert Timecode.lt?(a, b)
    end

    test "false" do
      a = Timecode.with_frames!("02:00:00:00", Rates.f23_98())
      b = Timecode.with_frames!("01:00:00:00", Rates.f23_98())

      refute Timecode.lt?(a, b)
    end

    test "false | eq" do
      a = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      b = Timecode.with_frames!("01:00:00:00", Rates.f23_98())

      refute Timecode.lt?(a, b)
    end
  end

  describe "#lte?/2" do
    test "true" do
      a = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      b = Timecode.with_frames!("02:00:00:00", Rates.f23_98())

      assert Timecode.lte?(a, b)
    end

    test "true | eq" do
      a = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      b = Timecode.with_frames!("01:00:00:00", Rates.f23_98())

      assert Timecode.lte?(a, b)
    end

    test "false" do
      a = Timecode.with_frames!("02:00:00:00", Rates.f23_98())
      b = Timecode.with_frames!("01:00:00:00", Rates.f23_98())

      refute Timecode.lte?(a, b)
    end
  end

  describe "#gt?/2" do
    test "true" do
      a = Timecode.with_frames!("02:00:00:00", Rates.f23_98())
      b = Timecode.with_frames!("01:00:00:00", Rates.f23_98())

      assert Timecode.gt?(a, b)
    end

    test "false" do
      a = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      b = Timecode.with_frames!("02:00:00:00", Rates.f23_98())

      refute Timecode.gt?(a, b)
    end

    test "false | eq" do
      a = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      b = Timecode.with_frames!("01:00:00:00", Rates.f23_98())

      refute Timecode.gt?(a, b)
    end
  end

  describe "#gte?/2" do
    test "true" do
      a = Timecode.with_frames!("02:00:00:00", Rates.f23_98())
      b = Timecode.with_frames!("01:00:00:00", Rates.f23_98())

      assert Timecode.gte?(a, b)
    end

    test "true | eq" do
      a = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      b = Timecode.with_frames!("01:00:00:00", Rates.f23_98())

      assert Timecode.gte?(a, b)
    end

    test "false" do
      a = Timecode.with_frames!("01:00:00:00", Rates.f23_98())
      b = Timecode.with_frames!("02:00:00:00", Rates.f23_98())

      refute Timecode.gte?(a, b)
    end
  end

  describe "#add/2" do
    setup [:setup_timecodes]
    @describetag timecodes: [:a, :b, :expected]

    test_cases = [
      %{
        a: "01:00:00:00",
        b: "01:00:00:00",
        expected: "02:00:00:00"
      },
      %{
        a: "01:00:00:00",
        b: "00:00:00:00",
        expected: "01:00:00:00"
      },
      %{
        a: "01:00:00:00",
        b: "-01:00:00:00",
        expected: "00:00:00:00"
      },
      %{
        a: "01:00:00:00",
        b: "-02:00:00:00",
        expected: "-01:00:00:00"
      },
      %{
        a: "10:12:13:14",
        b: "14:13:12:11",
        expected: "24:25:26:01"
      },
      %{
        a: {"01:00:00:00", Rates.f23_98()},
        b: {"01:00:00:00", Rates.f47_95()},
        expected: {"02:00:00:00", Rates.f23_98()}
      },
      %{
        a: {"01:00:00:00", Rates.f23_98()},
        b: {"00:00:00:02", Rates.f47_95()},
        expected: {"01:00:00:01", Rates.f23_98()}
      }
    ]

    for test_case <- test_cases do
      @tag test_case: test_case
      test "#{inspect(test_case.a)} + #{inspect(test_case.b)} == #{inspect(test_case.expected)}", context do
        %{a: a, b: b, expected: expected} = context
        assert Timecode.add(a, b) == expected
      end

      if is_binary(test_case.a) and is_binary(test_case.b) do
        @tag test_case: test_case
        test "#{test_case.a} + #{test_case.b} == #{test_case.expected} | integer b", context do
          %{a: a, b: b, expected: expected} = context
          b = Timecode.frames(b)

          assert Timecode.add(a, b) == expected
        end

        @tag test_case: test_case
        test "#{test_case.a} + #{test_case.b} == #{test_case.expected} | integer a", context do
          %{a: a, b: b, expected: expected} = context
          a = Timecode.frames(a)

          assert Timecode.add(a, b) == expected
        end

        @tag test_case: test_case
        test "#{test_case.a} + #{test_case.b} == #{test_case.expected} | string b", context do
          %{a: a, b: b, expected: expected} = context
          b = Timecode.timecode(b)

          assert Timecode.add(a, b) == expected
        end

        @tag test_case: test_case
        test "#{test_case.a} + #{test_case.b} == #{test_case.expected} | string a", context do
          %{a: a, b: b, expected: expected} = context
          a = Timecode.timecode(a)

          assert Timecode.add(a, b) == expected
        end
      end
    end

    test "round | :closest | implied" do
      a = %Timecode{seconds: Ratio.new(23, 24), rate: Rates.f24()}
      b = %Timecode{seconds: Ratio.new(5, 240), rate: Rates.f24()}
      expected = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}

      assert Timecode.add(a, b) == expected
    end

    test "round | :closest | explicit" do
      a = %Timecode{seconds: Ratio.new(23, 24), rate: Rates.f24()}
      b = %Timecode{seconds: Ratio.new(5, 240), rate: Rates.f24()}
      expected = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}

      assert Timecode.add(a, b, round: :closest) == expected
    end

    test "round | :closest | down" do
      a = %Timecode{seconds: Ratio.new(23, 24), rate: Rates.f24()}
      b = %Timecode{seconds: Ratio.new(4, 240), rate: Rates.f24()}
      expected = %Timecode{seconds: Ratio.new(23, 24), rate: Rates.f24()}

      assert Timecode.add(a, b, round: :closest) == expected
    end

    test "round | :floor" do
      a = %Timecode{seconds: Ratio.new(23, 24), rate: Rates.f24()}
      b = %Timecode{seconds: Ratio.new(9, 240), rate: Rates.f24()}
      expected = %Timecode{seconds: Ratio.new(23, 24), rate: Rates.f24()}

      assert Timecode.add(a, b, round: :floor) == expected
    end

    test "round | :ceil" do
      a = %Timecode{seconds: Ratio.new(23, 24), rate: Rates.f24()}
      b = %Timecode{seconds: Ratio.new(1, 240), rate: Rates.f24()}
      expected = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}

      assert Timecode.add(a, b, round: :ceil) == expected
    end

    test "round | :off" do
      a = %Timecode{seconds: Ratio.new(23, 24), rate: Rates.f24()}
      b = %Timecode{seconds: Ratio.new(5, 240), rate: Rates.f24()}
      expected = %Timecode{seconds: Ratio.new(235, 240), rate: Rates.f24()}

      assert Timecode.add(a, b, round: :off) == expected
    end
  end

  describe "#sub/2" do
    setup [:setup_timecodes]
    @describetag timecodes: [:a, :b, :expected]

    test_cases = [
      %{
        a: "01:00:00:00",
        b: "01:00:00:00",
        expected: "00:00:00:00"
      },
      %{
        a: "01:00:00:00",
        b: "00:00:00:00",
        expected: "01:00:00:00"
      },
      %{
        a: "01:00:00:00",
        b: "-01:00:00:00",
        expected: "02:00:00:00"
      },
      %{
        a: "01:00:00:00",
        b: "02:00:00:00",
        expected: "-01:00:00:00"
      },
      %{
        a: "34:10:09:08",
        b: "10:06:07:14",
        expected: "24:04:01:18"
      },
      %{
        a: {"02:00:00:00", Rates.f23_98()},
        b: {"01:00:00:00", Rates.f47_95()},
        expected: {"01:00:00:00", Rates.f23_98()}
      },
      %{
        a: {"01:00:00:02", Rates.f23_98()},
        b: {"00:00:00:02", Rates.f47_95()},
        expected: {"01:00:00:01", Rates.f23_98()}
      }
    ]

    for test_case <- test_cases do
      @tag test_case: test_case
      test "#{inspect(test_case.a)} - #{inspect(test_case.b)} == #{inspect(test_case.expected)}", context do
        %{a: a, b: b, expected: expected} = context
        assert Timecode.sub(a, b) == expected
      end

      if is_binary(test_case.a) and is_binary(test_case.b) do
        @tag test_case: test_case
        test "#{test_case.a} - #{test_case.b} == #{test_case.expected} | integer b", context do
          %{a: a, b: b, expected: expected} = context
          b = Timecode.frames(b)

          assert Timecode.sub(a, b) == expected
        end

        @tag test_case: test_case
        test "#{test_case.a} - #{test_case.b} == #{test_case.expected} | integer a", context do
          %{a: a, b: b, expected: expected} = context
          a = Timecode.frames(a)

          assert Timecode.sub(a, b) == expected
        end

        @tag test_case: test_case
        test "#{test_case.a} - #{test_case.b} == #{test_case.expected} | string b", context do
          %{a: a, b: b, expected: expected} = context
          b = Timecode.timecode(b)

          assert Timecode.sub(a, b) == expected
        end

        @tag test_case: test_case
        test "#{test_case.a} - #{test_case.b} == #{test_case.expected} | string a", context do
          %{a: a, b: b, expected: expected} = context
          a = Timecode.timecode(a)

          assert Timecode.sub(a, b) == expected
        end
      end
    end

    test "round | :closest | implied" do
      a = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      b = %Timecode{seconds: Ratio.new(5, 240), rate: Rates.f24()}
      expected = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}

      assert Timecode.sub(a, b) == expected
    end

    test "round | :closest | explicit" do
      a = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      b = %Timecode{seconds: Ratio.new(5, 240), rate: Rates.f24()}
      expected = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}

      assert Timecode.sub(a, b, round: :closest) == expected
    end

    test "round | :closest | down" do
      a = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      b = %Timecode{seconds: Ratio.new(6, 240), rate: Rates.f24()}
      expected = %Timecode{seconds: Ratio.new(23, 24), rate: Rates.f24()}

      assert Timecode.sub(a, b, round: :closest) == expected
    end

    test "round | :floor" do
      a = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      b = %Timecode{seconds: Ratio.new(1, 240), rate: Rates.f24()}
      expected = %Timecode{seconds: Ratio.new(23, 24), rate: Rates.f24()}

      assert Timecode.sub(a, b, round: :floor) == expected
    end

    test "round | :ceil" do
      a = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      b = %Timecode{seconds: Ratio.new(9, 240), rate: Rates.f24()}
      expected = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}

      assert Timecode.sub(a, b, round: :ceil) == expected
    end

    test "round | :off" do
      a = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      b = %Timecode{seconds: Ratio.new(5, 240), rate: Rates.f24()}
      expected = %Timecode{seconds: Ratio.new(235, 240), rate: Rates.f24()}

      assert Timecode.sub(a, b, round: :off) == expected
    end
  end

  describe "#mult/2" do
    setup [:setup_timecodes]
    @describetag timecodes: [:a, :expected]

    test_cases = [
      %{
        a: "01:00:00:00",
        b: 2,
        expected: "02:00:00:00"
      },
      %{
        a: "01:00:00:00",
        b: 0.5,
        expected: "00:30:00:00"
      },
      %{
        a: "01:00:00:00",
        b: Ratio.new(1, 2),
        expected: "00:30:00:00"
      },
      %{
        a: "01:00:00:00",
        b: 1,
        expected: "01:00:00:00"
      },
      %{
        a: "01:00:00:00",
        b: 0,
        expected: "00:00:00:00"
      }
    ]

    for test_case <- test_cases do
      @tag test_case: test_case
      test "#{test_case.a} * #{inspect(test_case.b)} == #{test_case.expected}", context do
        %{a: a, b: b, expected: expected} = context
        assert Timecode.mult(a, b) == expected
      end
    end

    test "round | :closest | implied" do
      a = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      b = Ratio.new(235, 240)
      expected = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}

      assert Timecode.mult(a, b) == expected
    end

    test "round | :closest | explicit" do
      a = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      b = Ratio.new(235, 240)
      expected = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}

      assert Timecode.mult(a, b, round: :closest) == expected
    end

    test "round | :closest | down" do
      a = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      b = Ratio.new(234, 240)
      expected = %Timecode{seconds: Ratio.new(23, 24), rate: Rates.f24()}

      assert Timecode.mult(a, b, round: :closest) == expected
    end

    test "round | :floor" do
      a = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      b = Ratio.new(239, 240)
      expected = %Timecode{seconds: Ratio.new(23, 24), rate: Rates.f24()}

      assert Timecode.mult(a, b, round: :floor) == expected
    end

    test "round | :ceil" do
      a = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      b = Ratio.new(231, 240)
      expected = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}

      assert Timecode.mult(a, b, round: :ceil) == expected
    end

    test "round | :off" do
      a = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      b = Ratio.new(239, 240)
      expected = %Timecode{seconds: Ratio.new(239, 240), rate: Rates.f24()}

      assert Timecode.mult(a, b, round: :off) == expected
    end
  end

  describe "#div/2" do
    setup [:setup_timecodes]
    @describetag timecodes: [:a, :expected]

    test_cases = [
      %{
        a: "01:00:00:00",
        b: 2,
        expected: "00:30:00:00"
      },
      %{
        a: "01:00:00:00",
        b: 0.5,
        expected: "02:00:00:00"
      },
      %{
        a: "01:00:00:00",
        b: Ratio.new(3, 2),
        expected: "00:40:00:00"
      },
      %{
        a: "01:00:00:00",
        b: 1,
        expected: "01:00:00:00"
      }
    ]

    for test_case <- test_cases do
      @tag test_case: test_case
      test "#{test_case.a} * #{inspect(test_case.b)} == #{test_case.expected}", context do
        %{a: a, b: b, expected: expected} = context
        assert Timecode.div(a, b) == expected
      end
    end

    test "round | :closest | explicit" do
      a = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      b = 48
      expected = %Timecode{seconds: Ratio.new(1, 24), rate: Rates.f24()}

      assert Timecode.div(a, b, round: :closest) == expected
    end

    test "round | :closest | down" do
      a = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      b = 48 * 2
      expected = %Timecode{seconds: Ratio.new(0), rate: Rates.f24()}

      assert Timecode.div(a, b, round: :closest) == expected
    end

    test "round | :floor" do
      a = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      b = 36
      expected = %Timecode{seconds: Ratio.new(0), rate: Rates.f24()}

      assert Timecode.div(a, b, round: :floor) == expected
    end

    test "round | :floor | :implied" do
      a = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      b = 36
      expected = %Timecode{seconds: Ratio.new(0), rate: Rates.f24()}

      assert Timecode.div(a, b) == expected
    end

    test "round | :ceil" do
      a = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      b = 48 * 2
      expected = %Timecode{seconds: Ratio.new(1, 24), rate: Rates.f24()}

      assert Timecode.div(a, b, round: :ceil) == expected
    end

    test "round | :off" do
      a = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      b = 48
      expected = %Timecode{seconds: Ratio.new(1, 48), rate: Rates.f24()}

      assert Timecode.div(a, b, round: :off) == expected
    end
  end

  test_cases = [
    %{
      dividend: {"01:00:00:00", Rates.f24()},
      divisor: 2,
      expected_quotient: {"00:30:00:00", Rates.f24()},
      expected_remainder: {"00:00:00:00", Rates.f24()}
    },
    %{
      dividend: {"-01:00:00:00", Rates.f24()},
      divisor: 2,
      expected_quotient: {"-00:30:00:00", Rates.f24()},
      expected_remainder: {"00:00:00:00", Rates.f24()}
    },
    %{
      dividend: "01:00:00:00",
      divisor: 2,
      expected_quotient: "00:30:00:00",
      expected_remainder: "00:00:00:00"
    },
    %{
      dividend: {"01:00:00:01", Rates.f24()},
      divisor: 2,
      expected_quotient: {"00:30:00:00", Rates.f24()},
      expected_remainder: {"00:00:00:01", Rates.f24()}
    },
    %{
      dividend: {"-01:00:00:01", Rates.f24()},
      divisor: 2,
      expected_quotient: {"-00:30:00:00", Rates.f24()},
      expected_remainder: {"00:00:00:01", Rates.f24()}
    },
    %{
      dividend: {"-01:00:00:01", Rates.f24()},
      divisor: -2,
      expected_quotient: {"00:30:00:01", Rates.f24()},
      expected_remainder: {"-00:00:00:01", Rates.f24()}
    },
    %{
      dividend: "01:00:00:01",
      divisor: 2,
      expected_quotient: "00:30:00:00",
      expected_remainder: "00:00:00:01"
    },
    %{
      dividend: {"01:00:00:01", Rates.f24()},
      divisor: 4,
      expected_quotient: {"00:15:00:00", Rates.f24()},
      expected_remainder: {"00:00:00:01", Rates.f24()}
    },
    %{
      dividend: "01:00:00:01",
      divisor: 4,
      expected_quotient: "00:15:00:00",
      expected_remainder: "00:00:00:01"
    },
    %{
      dividend: "01:00:00:02",
      divisor: 4,
      expected_quotient: "00:15:00:00",
      expected_remainder: "00:00:00:02"
    },
    %{
      dividend: {"01:00:00:01", Rates.f24()},
      divisor: 1.5,
      expected_quotient: {"00:40:00:00", Rates.f24()},
      expected_remainder: {"00:00:00:01", Rates.f24()}
    },
    %{
      dividend: "01:00:00:01",
      divisor: 1.5,
      expected_quotient: "00:40:00:00",
      expected_remainder: "00:00:00:01"
    }
  ]

  describe "#divrem/2" do
    setup [:setup_timecodes]
    @describetag timecodes: [:dividend, :expected_quotient, :expected_remainder]

    for test_case <- test_cases do
      test_name =
        "#{inspect(test_case.dividend)} /% #{inspect(test_case.divisor)} == {#{inspect(test_case.expected_quotient)}, #{inspect(test_case.expected_remainder)}}"

      @tag test_case: test_case
      test test_name, context do
        %{
          dividend: dividend,
          divisor: divisor,
          expected_quotient: expected_quotient,
          expected_remainder: expected_remainder
        } = context

        result = Timecode.divrem(dividend, divisor)
        assert result == {expected_quotient, expected_remainder}
      end
    end

    test "round | frames :closest | implicit" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 1
      expected_q = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      expected_r = %Timecode{seconds: Ratio.new(0), rate: Rates.f24()}

      assert Timecode.divrem(a, b) == {expected_q, expected_r}
    end

    test "round | frames :closest | explicit" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 1
      expected_q = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      expected_r = %Timecode{seconds: Ratio.new(0), rate: Rates.f24()}

      assert Timecode.divrem(a, b, round_frames: :closest) == {expected_q, expected_r}
    end

    test "round | frames :floor" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 1
      expected_q = %Timecode{seconds: Ratio.new(23, 24), rate: Rates.f24()}
      expected_r = %Timecode{seconds: Ratio.new(0), rate: Rates.f24()}

      assert Timecode.divrem(a, b, round_frames: :floor) == {expected_q, expected_r}
    end

    test "round | frames :ceil" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 1
      expected_q = %Timecode{seconds: Ratio.new(1), rate: Rates.f24()}
      expected_r = %Timecode{seconds: Ratio.new(0), rate: Rates.f24()}

      assert Timecode.divrem(a, b, round_frames: :ceil) == {expected_q, expected_r}
    end

    test "round | rem :closest | implicit" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 5 / 3
      expected_q = %Timecode{seconds: Ratio.new(14, 24), rate: Rates.f24()}
      expected_r = %Timecode{seconds: Ratio.new(1, 24), rate: Rates.f24()}

      assert Timecode.divrem(a, b) == {expected_q, expected_r}
    end

    test "round | rem :closest | explicit" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 5 / 3
      expected_q = %Timecode{seconds: Ratio.new(14, 24), rate: Rates.f24()}
      expected_r = %Timecode{seconds: Ratio.new(1, 24), rate: Rates.f24()}

      assert Timecode.divrem(a, b, round_remainder: :closest) == {expected_q, expected_r}
    end

    test "round | rem :ceil" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 5 / 3
      expected_q = %Timecode{seconds: Ratio.new(14, 24), rate: Rates.f24()}
      expected_r = %Timecode{seconds: Ratio.new(1, 24), rate: Rates.f24()}

      assert Timecode.divrem(a, b, round_remainder: :ceil) == {expected_q, expected_r}
    end

    test "round | rem :floor" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 5 / 3
      expected_q = %Timecode{seconds: Ratio.new(14, 24), rate: Rates.f24()}
      expected_r = %Timecode{seconds: Ratio.new(0, 24), rate: Rates.f24()}

      assert Timecode.divrem(a, b, round_remainder: :floor) == {expected_q, expected_r}
    end

    test "round | frames :off | raises" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 1

      exception = assert_raise ArgumentError, fn -> Timecode.divrem(a, b, round_frames: :off) end
      assert Exception.message(exception) == "`round_frames` cannot be `:off`"
    end

    test "round | remainder :off | raises" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 1

      exception = assert_raise ArgumentError, fn -> Timecode.divrem(a, b, round_remainder: :off) end

      assert Exception.message(exception) == "`round_remainder` cannot be `:off`"
    end
  end

  describe "#rem/2" do
    setup [:setup_timecodes]
    @describetag timecodes: [:dividend, :expected_quotient, :expected_remainder]

    for test_case <- test_cases do
      name = "#{inspect(test_case.dividend)} % #{inspect(test_case.divisor)} == #{inspect(test_case.expected_remainder)}"

      @tag test_case: test_case
      test name, context do
        %{
          dividend: dividend,
          divisor: divisor,
          expected_remainder: expected
        } = context

        assert Timecode.rem(dividend, divisor) == expected
      end
    end

    test "round | frames :closest | implicit" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 1
      expected = %Timecode{seconds: Ratio.new(0), rate: Rates.f24()}

      assert Timecode.rem(a, b) == expected
    end

    test "round | frames :closest | explicit" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 1
      expected = %Timecode{seconds: Ratio.new(0), rate: Rates.f24()}

      assert Timecode.rem(a, b, round_frames: :closest) == expected
    end

    test "round | frames :floor" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 1
      expected = %Timecode{seconds: Ratio.new(0), rate: Rates.f24()}

      assert Timecode.rem(a, b, round_frames: :floor) == expected
    end

    test "round | frames :ceil" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 1
      expected = %Timecode{seconds: Ratio.new(0), rate: Rates.f24()}

      assert Timecode.rem(a, b, round_frames: :ceil) == expected
    end

    test "round | rem :closest | implicit" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 5 / 3
      expected = %Timecode{seconds: Ratio.new(1, 24), rate: Rates.f24()}

      assert Timecode.rem(a, b) == expected
    end

    test "round | rem :closest | explicit" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 5 / 3
      expected = %Timecode{seconds: Ratio.new(1, 24), rate: Rates.f24()}

      assert Timecode.rem(a, b, round_remainder: :closest) == expected
    end

    test "round | rem :ceil" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 5 / 3
      expected = %Timecode{seconds: Ratio.new(1, 24), rate: Rates.f24()}

      assert Timecode.rem(a, b, round_remainder: :ceil) == expected
    end

    test "round | rem :floor" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 5 / 3
      expected = %Timecode{seconds: Ratio.new(0, 24), rate: Rates.f24()}

      assert Timecode.rem(a, b, round_remainder: :floor) == expected
    end

    test "round | frames :off | raises" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 1

      exception = assert_raise ArgumentError, fn -> Timecode.rem(a, b, round_frames: :off) end
      assert Exception.message(exception) == "`round_frames` cannot be `:off`"
    end

    test "round | remainder :off | raises" do
      a = %Timecode{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 1

      exception = assert_raise ArgumentError, fn -> Timecode.rem(a, b, round_remainder: :off) end

      assert Exception.message(exception) == "`round_remainder` cannot be `:off`"
    end
  end

  describe "#negate/1" do
    test_cases = [
      %{
        input: %Timecode{seconds: Ratio.new(1), rate: Rates.f23_98()},
        expected: %Timecode{seconds: Ratio.new(-1), rate: Rates.f23_98()}
      },
      %{
        input: %Timecode{seconds: Ratio.new(-1), rate: Rates.f23_98()},
        expected: %Timecode{seconds: Ratio.new(1), rate: Rates.f23_98()}
      },
      %{
        input: %Timecode{seconds: Ratio.new(0), rate: Rates.f23_98()},
        expected: %Timecode{seconds: Ratio.new(0), rate: Rates.f23_98()}
      }
    ]

    for test_case <- test_cases do
      @tag test_case: test_case
      test "#{test_case.input} negated == #{test_case.expected}", context do
        %{input: input, expected: expected} = context

        assert Timecode.minus(input) == expected
      end
    end
  end

  describe "#abs/1" do
    test_cases = [
      %{
        input: %Timecode{seconds: Ratio.new(1), rate: Rates.f23_98()},
        expected: %Timecode{seconds: Ratio.new(1), rate: Rates.f23_98()}
      },
      %{
        input: %Timecode{seconds: Ratio.new(-1), rate: Rates.f23_98()},
        expected: %Timecode{seconds: Ratio.new(1), rate: Rates.f23_98()}
      },
      %{
        input: %Timecode{seconds: Ratio.new(0), rate: Rates.f23_98()},
        expected: %Timecode{seconds: Ratio.new(0), rate: Rates.f23_98()}
      }
    ]

    for test_case <- test_cases do
      @tag test_case: test_case
      test "#{test_case.input} negated == #{test_case.expected}", context do
        %{input: input, expected: expected} = context
        assert Timecode.abs(input) == expected
      end
    end
  end

  @spec setup_timecodes(map()) :: Keyword.t()
  defp setup_timecodes(context) do
    timecode_fields = Map.get(context, :timecodes, [])
    timecodes = Map.take(context, timecode_fields)

    Enum.map(timecodes, fn {field_name, value} -> {field_name, setup_timecode(value)} end)
  end

  @spec setup_timecode(Frames.t() | {Frames.t(), Framerate.t()}) :: Timecode.t()
  defp setup_timecode({frames, rate}), do: Timecode.with_frames!(frames, rate)
  defp setup_timecode(frames), do: setup_timecode({frames, Rates.f23_98()})
end
