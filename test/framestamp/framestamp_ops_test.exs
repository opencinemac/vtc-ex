defmodule Vtc.FramestampTest.Ops do
  @moduledoc false
  use Vtc.Test.Support.TestCase

  alias Vtc.Framestamp
  alias Vtc.Rates

  rebase_table = [
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
    setup context, do: TestCase.setup_timecodes(context)
    @describetag timecodes: [:original, :expected]

    table_test "<%= original %> -> <%= new_rate %>", rebase_table, test_case do
      %{original: original, new_rate: new_rate, expected: expected} = test_case
      assert {:ok, rebased} = Framestamp.rebase(original, new_rate)
      assert rebased == expected

      assert {:ok, round_tripped} = Framestamp.rebase(rebased, original.rate)
      assert round_tripped == original
    end
  end

  describe "#rebase!/2" do
    setup context, do: TestCase.setup_timecodes(context)
    @describetag timecodes: [:original, :expected]

    table_test "<%= original %> -> <%= new_rate %>", rebase_table, test_case do
      %{original: original, new_rate: new_rate, expected: expected} = test_case
      assert %Framestamp{} = rebased = Framestamp.rebase!(original, new_rate)
      assert rebased == expected

      assert %Framestamp{} = round_tripped = Framestamp.rebase!(rebased, original.rate)
      assert round_tripped == original
    end
  end

  describe "#compare/2" do
    setup context, do: TestCase.setup_timecodes(context)
    @describetag timecodes: [:a, :b]

    compare_table = [
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

    table_test "<%= a %> is <%= expected %> <%= b %>", compare_table, test_case do
      %{a: a, b: b, expected: expected} = test_case
      assert Framestamp.compare(a, b) == expected
    end

    name = "<%= a %> is <%= expected %> <%= b %> | b = tc string"

    table_test name, compare_table, test_case, if: is_binary(test_case.a) and is_binary(test_case.b) do
      %{a: a, b: b, expected: expected} = test_case
      b = Framestamp.smpte_timecode(b)

      assert Framestamp.compare(a, b) == expected
    end

    name = "<%= a %> is <%= expected %> <%= b %> | a = tc string"

    table_test name, compare_table, test_case, if: is_binary(test_case.a) and is_binary(test_case.b) do
      %{a: a, b: b, expected: expected} = test_case
      a = Framestamp.smpte_timecode(a)

      assert Framestamp.compare(a, b) == expected
    end

    name = "<%= a %> is <%= expected %> <%= b %> | b = frames int"

    table_test name, compare_table, test_case, if: is_binary(test_case.a) and is_binary(test_case.b) do
      %{a: a, b: b, expected: expected} = test_case
      b = Framestamp.frames(b)

      assert Framestamp.compare(a, b) == expected
    end

    name = "<%= a %> is <%= expected %> <%= b %> | a = frames int"

    table_test name, compare_table, test_case, if: is_binary(test_case.a) and is_binary(test_case.b) do
      %{a: a, b: b, expected: expected} = test_case
      a = Framestamp.frames(a)

      assert Framestamp.compare(a, b) == expected
    end
  end

  describe "#eq?/2" do
    test "true" do
      a = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      b = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())

      assert Framestamp.eq?(a, b)
    end

    test "false" do
      a = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      b = Framestamp.with_frames!("01:00:00:01", Rates.f23_98())

      refute Framestamp.eq?(a, b)
    end
  end

  describe "#lt?/2" do
    test "true" do
      a = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      b = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())

      assert Framestamp.lt?(a, b)
    end

    test "false" do
      a = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())
      b = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())

      refute Framestamp.lt?(a, b)
    end

    test "false | eq" do
      a = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      b = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())

      refute Framestamp.lt?(a, b)
    end
  end

  describe "#lte?/2" do
    test "true" do
      a = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      b = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())

      assert Framestamp.lte?(a, b)
    end

    test "true | eq" do
      a = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      b = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())

      assert Framestamp.lte?(a, b)
    end

    test "false" do
      a = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())
      b = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())

      refute Framestamp.lte?(a, b)
    end
  end

  describe "#gt?/2" do
    test "true" do
      a = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())
      b = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())

      assert Framestamp.gt?(a, b)
    end

    test "false" do
      a = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      b = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())

      refute Framestamp.gt?(a, b)
    end

    test "false | eq" do
      a = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      b = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())

      refute Framestamp.gt?(a, b)
    end
  end

  describe "#gte?/2" do
    test "true" do
      a = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())
      b = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())

      assert Framestamp.gte?(a, b)
    end

    test "true | eq" do
      a = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      b = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())

      assert Framestamp.gte?(a, b)
    end

    test "false" do
      a = Framestamp.with_frames!("01:00:00:00", Rates.f23_98())
      b = Framestamp.with_frames!("02:00:00:00", Rates.f23_98())

      refute Framestamp.gte?(a, b)
    end
  end

  describe "#add/2" do
    setup context, do: TestCase.setup_timecodes(context)
    @describetag timecodes: [:a, :b, :expected]

    add_table = [
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

    table_test "<%= a %> + <%= b %> == <%= expected %>", add_table, test_case do
      %{a: a, b: b, expected: expected} = test_case
      assert Framestamp.add(a, b) == expected
    end

    table_test "<%= a %> + <%= b %> == <%= expected %> | integer b", add_table, test_case,
      if: is_binary(test_case.a) and is_binary(test_case.b) do
      %{a: a, b: b, expected: expected} = test_case
      b = Framestamp.frames(b)

      assert Framestamp.add(a, b) == expected
    end

    table_test "<%= a %> + <%= b %> == <%= expected %> | integer a", add_table, test_case,
      if: is_binary(test_case.a) and is_binary(test_case.b) do
      %{a: a, b: b, expected: expected} = test_case
      a = Framestamp.frames(a)

      assert Framestamp.add(a, b) == expected
    end

    table_test "<%= a %> + <%= b %> == <%= expected %> | string b", add_table, test_case,
      if: is_binary(test_case.a) and is_binary(test_case.b) do
      %{a: a, b: b, expected: expected} = test_case
      b = Framestamp.smpte_timecode(b)

      assert Framestamp.add(a, b) == expected
    end

    table_test "<%= a %> + <%= b %> == <%= expected %> | string a", add_table, test_case,
      if: is_binary(test_case.a) and is_binary(test_case.b) do
      %{a: a, b: b, expected: expected} = test_case
      a = Framestamp.smpte_timecode(a)

      assert Framestamp.add(a, b) == expected
    end

    round_table = [
      %{
        a: %Framestamp{seconds: Ratio.new(23, 24), rate: Rates.f24()},
        b: %Framestamp{seconds: Ratio.new(5, 240), rate: Rates.f24()},
        opts: [],
        description: "round :closest implicit",
        expected: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(-23, 24), rate: Rates.f24()},
        b: %Framestamp{seconds: Ratio.new(-5, 240), rate: Rates.f24()},
        opts: [],
        description: "round :closest implicit negative",
        expected: %Framestamp{seconds: Ratio.new(-1), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(23, 24), rate: Rates.f24()},
        b: %Framestamp{seconds: Ratio.new(5, 240), rate: Rates.f24()},
        opts: [round: :closest],
        description: "",
        expected: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(-23, 24), rate: Rates.f24()},
        b: %Framestamp{seconds: Ratio.new(-5, 240), rate: Rates.f24()},
        opts: [round: :closest],
        description: "negative",
        expected: %Framestamp{seconds: Ratio.new(-1), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(23, 24), rate: Rates.f24()},
        b: %Framestamp{seconds: Ratio.new(4, 240), rate: Rates.f24()},
        opts: [round: :closest],
        description: "towards zero",
        expected: %Framestamp{seconds: Ratio.new(23, 24), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(-23, 24), rate: Rates.f24()},
        b: %Framestamp{seconds: Ratio.new(-4, 240), rate: Rates.f24()},
        opts: [round: :closest],
        description: "towards zero negative",
        expected: %Framestamp{seconds: Ratio.new(-23, 24), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(23, 24), rate: Rates.f24()},
        b: %Framestamp{seconds: Ratio.new(9, 240), rate: Rates.f24()},
        opts: [round: :floor],
        description: "",
        expected: %Framestamp{seconds: Ratio.new(23, 24), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(-23, 24), rate: Rates.f24()},
        b: %Framestamp{seconds: Ratio.new(-9, 240), rate: Rates.f24()},
        opts: [round: :floor],
        description: "negative",
        expected: %Framestamp{seconds: Ratio.new(-1), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(23, 24), rate: Rates.f24()},
        b: %Framestamp{seconds: Ratio.new(1, 240), rate: Rates.f24()},
        opts: [round: :ceil],
        description: "",
        expected: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(-23, 24), rate: Rates.f24()},
        b: %Framestamp{seconds: Ratio.new(-1, 240), rate: Rates.f24()},
        opts: [round: :ceil],
        description: "negative",
        expected: %Framestamp{seconds: Ratio.new(-23, 24), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(23, 24), rate: Rates.f24()},
        b: %Framestamp{seconds: Ratio.new(9, 240), rate: Rates.f24()},
        opts: [round: :trunc],
        description: "",
        expected: %Framestamp{seconds: Ratio.new(23, 24), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(-23, 24), rate: Rates.f24()},
        b: %Framestamp{seconds: Ratio.new(-9, 240), rate: Rates.f24()},
        opts: [round: :trunc],
        description: "negative",
        expected: %Framestamp{seconds: Ratio.new(-23, 24), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(23, 24), rate: Rates.f24()},
        b: %Framestamp{seconds: Ratio.new(5, 240), rate: Rates.f24()},
        opts: [round: :off, allow_partial_frames?: true],
        description: "",
        expected: %Framestamp{seconds: Ratio.new(235, 240), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(-23, 24), rate: Rates.f24()},
        b: %Framestamp{seconds: Ratio.new(-5, 240), rate: Rates.f24()},
        opts: [round: :off, allow_partial_frames?: true],
        description: "negative",
        expected: %Framestamp{seconds: Ratio.new(-235, 240), rate: Rates.f24()}
      }
    ]

    table_test "opts: | <%= opts %> <%= description %>", round_table, test_case do
      %{a: a, b: b, opts: opts, expected: expected} = test_case
      assert Framestamp.add(a, b, opts) == expected
    end

    test "error | round | :off" do
      a = %Framestamp{seconds: Ratio.new(23, 24), rate: Rates.f24()}
      b = %Framestamp{seconds: Ratio.new(5, 240), rate: Rates.f24()}

      error = assert_raise Framestamp.ParseError, fn -> Framestamp.add(a, b, round: :off) end
      assert error.reason == :partial_frame
    end
  end

  describe "#sub/2" do
    setup context, do: TestCase.setup_timecodes(context)
    @describetag timecodes: [:a, :b, :expected]

    sub_table = [
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

    table_test "<%= a %> - <%= b %> == <%= expected %>", sub_table, test_case do
      %{a: a, b: b, expected: expected} = test_case
      assert Framestamp.sub(a, b) == expected
    end

    table_test "<%= a %> - <%= b %> == <%= expected %> | integer b", sub_table, test_case,
      if: is_binary(test_case.a) and is_binary(test_case.b) do
      %{a: a, b: b, expected: expected} = test_case
      b = Framestamp.frames(b)

      assert Framestamp.sub(a, b) == expected
    end

    table_test "<%= a %> - <%= b %> == <%= expected %> | integer a", sub_table, test_case,
      if: is_binary(test_case.a) and is_binary(test_case.b) do
      %{a: a, b: b, expected: expected} = test_case
      a = Framestamp.frames(a)

      assert Framestamp.sub(a, b) == expected
    end

    table_test "<%= a %> - <%= b %> == <%= expected %> | string b", sub_table, test_case,
      if: is_binary(test_case.a) and is_binary(test_case.b) do
      %{a: a, b: b, expected: expected} = test_case
      b = Framestamp.smpte_timecode(b)

      assert Framestamp.sub(a, b) == expected
    end

    table_test "<%= a %> - <%= b %> == <%= expected %> | string a", sub_table, test_case,
      if: is_binary(test_case.a) and is_binary(test_case.b) do
      %{a: a, b: b, expected: expected} = test_case
      a = Framestamp.smpte_timecode(a)

      assert Framestamp.sub(a, b) == expected
    end

    round_table = [
      %{
        a: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()},
        b: %Framestamp{seconds: Ratio.new(5, 240), rate: Rates.f24()},
        opts: [],
        description: ":closest implicit",
        expected: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(-1), rate: Rates.f24()},
        b: %Framestamp{seconds: Ratio.new(5, 240), rate: Rates.f24()},
        opts: [],
        description: ":closest implicit negative",
        expected: %Framestamp{seconds: Ratio.new(-25, 24), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()},
        b: %Framestamp{seconds: Ratio.new(5, 240), rate: Rates.f24()},
        opts: [round: :closest],
        description: "explicit",
        expected: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(-1), rate: Rates.f24()},
        b: %Framestamp{seconds: Ratio.new(5, 240), rate: Rates.f24()},
        opts: [round: :closest],
        description: "explicit negative",
        expected: %Framestamp{seconds: Ratio.new(-25, 24), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()},
        b: %Framestamp{seconds: Ratio.new(6, 240), rate: Rates.f24()},
        opts: [round: :closest],
        description: "towards zero",
        expected: %Framestamp{seconds: Ratio.new(23, 24), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()},
        b: %Framestamp{seconds: Ratio.new(4, 240), rate: Rates.f24()},
        opts: [round: :closest],
        description: "towards zero negative",
        expected: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()},
        b: %Framestamp{seconds: Ratio.new(1, 240), rate: Rates.f24()},
        opts: [round: :floor],
        description: "",
        expected: %Framestamp{seconds: Ratio.new(23, 24), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(-1), rate: Rates.f24()},
        b: %Framestamp{seconds: Ratio.new(1, 240), rate: Rates.f24()},
        opts: [round: :floor],
        description: "negative",
        expected: %Framestamp{seconds: Ratio.new(-25, 24), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()},
        b: %Framestamp{seconds: Ratio.new(9, 240), rate: Rates.f24()},
        opts: [round: :ceil],
        description: "",
        expected: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(-1), rate: Rates.f24()},
        b: %Framestamp{seconds: Ratio.new(9, 240), rate: Rates.f24()},
        opts: [round: :ceil],
        description: "negative",
        expected: %Framestamp{seconds: Ratio.new(-1), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()},
        b: %Framestamp{seconds: Ratio.new(1, 240), rate: Rates.f24()},
        opts: [round: :trunc],
        description: "",
        expected: %Framestamp{seconds: Ratio.new(23, 24), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(-23, 24), rate: Rates.f24()},
        b: %Framestamp{seconds: Ratio.new(9, 240), rate: Rates.f24()},
        opts: [round: :trunc],
        description: "negative",
        expected: %Framestamp{seconds: Ratio.new(-23, 24), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()},
        b: %Framestamp{seconds: Ratio.new(5, 240), rate: Rates.f24()},
        opts: [round: :off, allow_partial_frames?: true],
        description: "",
        expected: %Framestamp{seconds: Ratio.new(235, 240), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(-1), rate: Rates.f24()},
        b: %Framestamp{seconds: Ratio.new(5, 240), rate: Rates.f24()},
        opts: [round: :off, allow_partial_frames?: true],
        description: "negative",
        expected: %Framestamp{seconds: Ratio.new(-245, 240), rate: Rates.f24()}
      }
    ]

    table_test "opts: | <%= opts %> <%= description %>", round_table, test_case do
      %{a: a, b: b, opts: opts, expected: expected} = test_case
      assert Framestamp.sub(a, b, opts) == expected
    end

    test "error | round | :off" do
      a = %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()}
      b = %Framestamp{seconds: Ratio.new(5, 240), rate: Rates.f24()}

      error = assert_raise Framestamp.ParseError, fn -> Framestamp.sub(a, b, round: :off) end
      assert error.reason == :partial_frame
    end
  end

  describe "#mult/2" do
    setup context, do: TestCase.setup_timecodes(context)
    @describetag timecodes: [:a, :expected]

    mult_table = [
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

    table_test "<%= a %> * <%= b %> == <%= expected %>", mult_table, test_case do
      %{a: a, b: b, expected: expected} = test_case
      assert Framestamp.mult(a, b) == expected
    end

    round_table = [
      %{
        a: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()},
        b: Ratio.new(235, 240),
        opts: [],
        description: ":closest implicit",
        expected: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()},
        b: Ratio.new(-235, 240),
        opts: [],
        description: ":closest implicit negative",
        expected: %Framestamp{seconds: Ratio.new(-1), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()},
        b: Ratio.new(235, 240),
        opts: [round: :closest],
        description: "",
        expected: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()},
        b: Ratio.new(-235, 240),
        opts: [round: :closest],
        description: "negative",
        expected: %Framestamp{seconds: Ratio.new(-1), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()},
        b: Ratio.new(234, 240),
        opts: [round: :closest],
        description: "towards zero",
        expected: %Framestamp{seconds: Ratio.new(23, 24), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()},
        b: Ratio.new(-234, 240),
        opts: [round: :closest],
        description: "towards zero negative",
        expected: %Framestamp{seconds: Ratio.new(-23, 24), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()},
        b: Ratio.new(239, 240),
        opts: [round: :floor],
        description: "",
        expected: %Framestamp{seconds: Ratio.new(23, 24), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()},
        b: Ratio.new(-231, 240),
        opts: [round: :floor],
        description: "negative",
        expected: %Framestamp{seconds: Ratio.new(-1), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()},
        b: Ratio.new(231, 240),
        opts: [round: :ceil],
        description: "",
        expected: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()},
        b: Ratio.new(-239, 240),
        opts: [round: :ceil],
        description: "negative",
        expected: %Framestamp{seconds: Ratio.new(-23, 24), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()},
        b: Ratio.new(239, 240),
        opts: [round: :off, allow_partial_frames?: true],
        description: "",
        expected: %Framestamp{seconds: Ratio.new(239, 240), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()},
        b: Ratio.new(-239, 240),
        opts: [round: :off, allow_partial_frames?: true],
        description: "negative",
        expected: %Framestamp{seconds: Ratio.new(-239, 240), rate: Rates.f24()}
      }
    ]

    table_test "opts: | <%= opts %> <%= description %>", round_table, test_case do
      %{a: a, b: b, opts: opts, expected: expected} = test_case
      assert Framestamp.mult(a, b, opts) == expected
    end

    test "error | round | :off" do
      a = %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()}
      b = Ratio.new(239, 240)

      error = assert_raise Framestamp.ParseError, fn -> Framestamp.mult(a, b, round: :off) end
      assert error.reason == :partial_frame
    end
  end

  describe "#div/2" do
    setup context, do: TestCase.setup_timecodes(context)
    @describetag timecodes: [:a, :expected]

    div_table = [
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

    table_test "<%= a %> / <%= b %> == <%= expected %>", div_table, test_case do
      %{a: a, b: b, expected: expected} = test_case
      assert Framestamp.div(a, b) == expected
    end

    round_table = [
      %{
        a: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()},
        b: 48,
        opts: [round: :closest],
        description: "",
        expected: %Framestamp{seconds: Ratio.new(1, 24), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(-1), rate: Rates.f24()},
        b: 48,
        opts: [round: :closest],
        description: "negative",
        expected: %Framestamp{seconds: Ratio.new(-1, 24), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()},
        b: 48 * 2,
        opts: [round: :closest],
        description: "towards zero",
        expected: %Framestamp{seconds: Ratio.new(0), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()},
        b: -48 * 2,
        opts: [round: :closest],
        description: "towards zero negative",
        expected: %Framestamp{seconds: Ratio.new(0), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()},
        b: 36,
        opts: [round: :floor],
        description: "",
        expected: %Framestamp{seconds: Ratio.new(0), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()},
        b: -36,
        opts: [round: :floor],
        description: "negative",
        expected: %Framestamp{seconds: Ratio.new(-1, 24), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()},
        b: 48 * 2,
        opts: [round: :ceil],
        description: "",
        expected: %Framestamp{seconds: Ratio.new(1, 24), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()},
        b: -48 * 2,
        opts: [round: :ceil],
        description: "negative",
        expected: %Framestamp{seconds: Ratio.new(0, 24), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()},
        b: 48,
        opts: [round: :off, allow_partial_frames?: true],
        description: "",
        expected: %Framestamp{seconds: Ratio.new(1, 48), rate: Rates.f24()}
      },
      %{
        a: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()},
        b: 48,
        opts: [round: :off, allow_partial_frames?: true],
        description: "negative",
        expected: %Framestamp{seconds: Ratio.new(1, 48), rate: Rates.f24()}
      }
    ]

    table_test "opts: | <%= opts %> <%= description %>", round_table, test_case do
      %{a: a, b: b, opts: opts, expected: expected} = test_case
      assert Framestamp.div(a, b, opts) == expected
    end

    test "error | round | :off" do
      a = %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()}
      b = 48

      error = assert_raise Framestamp.ParseError, fn -> Framestamp.div(a, b, round: :off) end
      assert error.reason == :partial_frame
    end
  end

  divrem_table = [
    %{
      dividend: {"01:00:00:00", Rates.f24()},
      divisor: 2,
      expected_q: {"00:30:00:00", Rates.f24()},
      expected_r: {"00:00:00:00", Rates.f24()}
    },
    %{
      dividend: {"-01:00:00:00", Rates.f24()},
      divisor: 2,
      expected_q: {"-00:30:00:00", Rates.f24()},
      expected_r: {"00:00:00:00", Rates.f24()}
    },
    %{
      dividend: "01:00:00:00",
      divisor: 2,
      expected_q: "00:30:00:00",
      expected_r: "00:00:00:00"
    },
    %{
      dividend: {"01:00:00:01", Rates.f24()},
      divisor: 2,
      expected_q: {"00:30:00:00", Rates.f24()},
      expected_r: {"00:00:00:01", Rates.f24()}
    },
    %{
      dividend: {"-01:00:00:01", Rates.f24()},
      divisor: 2,
      expected_q: {"-00:30:00:00", Rates.f24()},
      expected_r: {"-00:00:00:01", Rates.f24()}
    },
    %{
      dividend: {"-01:00:00:01", Rates.f24()},
      divisor: -2,
      expected_q: {"00:30:00:00", Rates.f24()},
      expected_r: {"-00:00:00:01", Rates.f24()}
    },
    %{
      dividend: "01:00:00:01",
      divisor: 2,
      expected_q: "00:30:00:00",
      expected_r: "00:00:00:01"
    },
    %{
      dividend: {"01:00:00:01", Rates.f24()},
      divisor: 4,
      expected_q: {"00:15:00:00", Rates.f24()},
      expected_r: {"00:00:00:01", Rates.f24()}
    },
    %{
      dividend: "01:00:00:01",
      divisor: 4,
      expected_q: "00:15:00:00",
      expected_r: "00:00:00:01"
    },
    %{
      dividend: "01:00:00:02",
      divisor: 4,
      expected_q: "00:15:00:00",
      expected_r: "00:00:00:02"
    },
    %{
      dividend: {"01:00:00:01", Rates.f24()},
      divisor: 1.5,
      expected_q: {"00:40:00:00", Rates.f24()},
      expected_r: {"00:00:00:01", Rates.f24()}
    },
    %{
      dividend: "01:00:00:01",
      divisor: 1.5,
      expected_q: "00:40:00:00",
      expected_r: "00:00:00:01"
    }
  ]

  divrem_round_table = [
    %{
      a: %Framestamp{seconds: Ratio.new(47, 48), rate: Rates.f24()},
      b: 1,
      opts: [],
      description: "round frames closest implicit",
      expected_q: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()},
      expected_r: %Framestamp{seconds: Ratio.new(0), rate: Rates.f24()}
    },
    %{
      a: %Framestamp{seconds: Ratio.new(-47, 48), rate: Rates.f24()},
      b: 1,
      opts: [],
      description: "round frames closest implicit negative",
      expected_q: %Framestamp{seconds: Ratio.new(-1), rate: Rates.f24()},
      expected_r: %Framestamp{seconds: Ratio.new(0), rate: Rates.f24()}
    },
    %{
      a: %Framestamp{seconds: Ratio.new(47, 48), rate: Rates.f24()},
      b: 1,
      opts: [round_frames: :closest],
      description: "",
      expected_q: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()},
      expected_r: %Framestamp{seconds: Ratio.new(0), rate: Rates.f24()}
    },
    %{
      a: %Framestamp{seconds: Ratio.new(-47, 48), rate: Rates.f24()},
      b: 1,
      opts: [round_frames: :closest],
      description: "negative",
      expected_q: %Framestamp{seconds: Ratio.new(-1), rate: Rates.f24()},
      expected_r: %Framestamp{seconds: Ratio.new(0), rate: Rates.f24()}
    },
    %{
      a: %Framestamp{seconds: Ratio.new(234, 240), rate: Rates.f24()},
      b: 1,
      opts: [round_frames: :closest],
      description: "towards zero",
      expected_q: %Framestamp{seconds: Ratio.new(23, 24), rate: Rates.f24()},
      expected_r: %Framestamp{seconds: Ratio.new(0), rate: Rates.f24()}
    },
    %{
      a: %Framestamp{seconds: Ratio.new(-234, 240), rate: Rates.f24()},
      b: 1,
      opts: [round_frames: :closest],
      description: "towards zero negative",
      expected_q: %Framestamp{seconds: Ratio.new(-23, 24), rate: Rates.f24()},
      expected_r: %Framestamp{seconds: Ratio.new(0), rate: Rates.f24()}
    },
    %{
      a: %Framestamp{seconds: Ratio.new(47, 48), rate: Rates.f24()},
      b: 1,
      opts: [round_frames: :floor],
      description: "",
      expected_q: %Framestamp{seconds: Ratio.new(23, 24), rate: Rates.f24()},
      expected_r: %Framestamp{seconds: Ratio.new(0), rate: Rates.f24()}
    },
    %{
      a: %Framestamp{seconds: Ratio.new(-47, 48), rate: Rates.f24()},
      b: 1,
      opts: [round_frames: :floor],
      description: "frames negative",
      expected_q: %Framestamp{seconds: Ratio.new(-1), rate: Rates.f24()},
      expected_r: %Framestamp{seconds: Ratio.new(0), rate: Rates.f24()}
    },
    %{
      a: %Framestamp{seconds: Ratio.new(47, 48), rate: Rates.f24()},
      b: -1,
      opts: [round_frames: :floor],
      description: "dvisor negative",
      expected_q: %Framestamp{seconds: Ratio.new(-23, 24), rate: Rates.f24()},
      expected_r: %Framestamp{seconds: Ratio.new(0), rate: Rates.f24()}
    },
    %{
      a: %Framestamp{seconds: Ratio.new(47, 48), rate: Rates.f24()},
      b: 1,
      opts: [round_frames: :ceil],
      description: "",
      expected_q: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()},
      expected_r: %Framestamp{seconds: Ratio.new(0), rate: Rates.f24()}
    },
    %{
      a: %Framestamp{seconds: Ratio.new(-47, 48), rate: Rates.f24()},
      b: 1,
      opts: [round_frames: :ceil],
      description: "frames negative",
      expected_q: %Framestamp{seconds: Ratio.new(-23, 24), rate: Rates.f24()},
      expected_r: %Framestamp{seconds: Ratio.new(0), rate: Rates.f24()}
    },
    %{
      a: %Framestamp{seconds: Ratio.new(47, 48), rate: Rates.f24()},
      b: -1,
      opts: [round_frames: :ceil],
      description: "divisor negative",
      expected_q: %Framestamp{seconds: Ratio.new(-1), rate: Rates.f24()},
      expected_r: %Framestamp{seconds: Ratio.new(0), rate: Rates.f24()}
    },
    %{
      a: %Framestamp{seconds: Ratio.new(239, 240), rate: Rates.f24()},
      b: 1,
      opts: [round_frames: :trunc],
      description: "",
      expected_q: %Framestamp{seconds: Ratio.new(23, 24), rate: Rates.f24()},
      expected_r: %Framestamp{seconds: Ratio.new(0), rate: Rates.f24()}
    },
    %{
      a: %Framestamp{seconds: Ratio.new(-239, 240), rate: Rates.f24()},
      b: 1,
      opts: [round_frames: :trunc],
      description: "dividend negative",
      expected_q: %Framestamp{seconds: Ratio.new(-23, 24), rate: Rates.f24()},
      expected_r: %Framestamp{seconds: Ratio.new(0), rate: Rates.f24()}
    },
    %{
      a: %Framestamp{seconds: Ratio.new(239, 240), rate: Rates.f24()},
      b: -1,
      opts: [round_frames: :trunc],
      description: "divisor negative",
      expected_q: %Framestamp{seconds: Ratio.new(-23, 24), rate: Rates.f24()},
      expected_r: %Framestamp{seconds: Ratio.new(0), rate: Rates.f24()}
    },
    %{
      a: %Framestamp{seconds: Ratio.new(47, 48), rate: Rates.f24()},
      b: 5 / 3,
      opts: [],
      description: "rem closest implicit",
      expected_q: %Framestamp{seconds: Ratio.new(14, 24), rate: Rates.f24()},
      expected_r: %Framestamp{seconds: Ratio.new(1, 24), rate: Rates.f24()}
    },
    %{
      a: %Framestamp{seconds: Ratio.new(47, 48), rate: Rates.f24()},
      b: -5 / 3,
      opts: [],
      description: "rem closest implicit negative",
      expected_q: %Framestamp{seconds: Ratio.new(-14, 24), rate: Rates.f24()},
      expected_r: %Framestamp{seconds: Ratio.new(1, 24), rate: Rates.f24()}
    },
    %{
      a: %Framestamp{seconds: Ratio.new(47, 48), rate: Rates.f24()},
      b: 5 / 3,
      opts: [round_remainder: :closest],
      description: "",
      expected_q: %Framestamp{seconds: Ratio.new(14, 24), rate: Rates.f24()},
      expected_r: %Framestamp{seconds: Ratio.new(1, 24), rate: Rates.f24()}
    },
    %{
      a: %Framestamp{seconds: Ratio.new(47, 48), rate: Rates.f24()},
      b: -5 / 3,
      opts: [round_remainder: :closest],
      description: "divisor negative",
      expected_q: %Framestamp{seconds: Ratio.new(-14, 24), rate: Rates.f24()},
      expected_r: %Framestamp{seconds: Ratio.new(1, 24), rate: Rates.f24()}
    },
    %{
      a: %Framestamp{seconds: Ratio.new(47, 48), rate: Rates.f24()},
      b: 5 / 3,
      opts: [round_remainder: :ceil],
      description: "",
      expected_q: %Framestamp{seconds: Ratio.new(14, 24), rate: Rates.f24()},
      expected_r: %Framestamp{seconds: Ratio.new(1, 24), rate: Rates.f24()}
    },
    %{
      a: %Framestamp{seconds: Ratio.new(47, 48), rate: Rates.f24()},
      b: -5 / 3,
      opts: [round_remainder: :ceil],
      description: "divisor negative",
      expected_q: %Framestamp{seconds: Ratio.new(-14, 24), rate: Rates.f24()},
      expected_r: %Framestamp{seconds: Ratio.new(1, 24), rate: Rates.f24()}
    },
    %{
      a: %Framestamp{seconds: Ratio.new(47, 48), rate: Rates.f24()},
      b: 5 / 3,
      opts: [round_remainder: :floor],
      description: "",
      expected_q: %Framestamp{seconds: Ratio.new(14, 24), rate: Rates.f24()},
      expected_r: %Framestamp{seconds: Ratio.new(0, 24), rate: Rates.f24()}
    },
    %{
      a: %Framestamp{seconds: Ratio.new(47, 48), rate: Rates.f24()},
      b: -5 / 3,
      opts: [round_remainder: :floor],
      description: "divisor negative",
      expected_q: %Framestamp{seconds: Ratio.new(-14, 24), rate: Rates.f24()},
      expected_r: %Framestamp{seconds: Ratio.new(0, 24), rate: Rates.f24()}
    }
  ]

  describe "#divrem/2" do
    setup context, do: TestCase.setup_timecodes(context)
    @describetag timecodes: [:dividend, :expected_q, :expected_r]

    table_test "<%= dividend %> /% <%= divisor %> == <%= expected_q %>, <%= expected_r %>", divrem_table, test_case do
      %{dividend: dividend, divisor: divisor, expected_q: expected_quotient, expected_r: expected_remainder} = test_case

      result = Framestamp.divrem(dividend, divisor)
      assert result == {expected_quotient, expected_remainder}
    end

    table_test "opts: | <%= opts %> <%= description %>", divrem_round_table, test_case do
      %{a: a, b: b, opts: opts, expected_q: expected_quotient, expected_r: expected_remainder} = test_case

      assert {quotient, remainder} = Framestamp.divrem(a, b, opts)
      assert quotient == expected_quotient
      assert remainder == expected_remainder
    end

    test "round | frames :off | raises" do
      a = %Framestamp{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 1

      exception = assert_raise ArgumentError, fn -> Framestamp.divrem(a, b, round_frames: :off) end
      assert Exception.message(exception) == "`round_frames` cannot be `:off`"
    end

    test "round | remainder :off | raises" do
      a = %Framestamp{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 1

      exception = assert_raise ArgumentError, fn -> Framestamp.divrem(a, b, round_remainder: :off) end

      assert Exception.message(exception) == "`round_remainder` cannot be `:off`"
    end
  end

  describe "#rem/2" do
    setup context, do: TestCase.setup_timecodes(context)
    @describetag timecodes: [:dividend, :expected_q, :expected_r]

    table_test "<%= dividend %> % <%= divisor %> == <%= expected_r %>", divrem_table, test_case do
      %{dividend: dividend, divisor: divisor, expected_r: expected} = test_case
      assert Framestamp.rem(dividend, divisor) == expected
    end

    table_test "opts: | <%= opts %> <%= description %>", divrem_round_table, test_case do
      %{a: a, b: b, opts: opts, expected_r: expected_remainder} = test_case
      assert Framestamp.rem(a, b, opts) == expected_remainder
    end

    test "round | frames :off | raises" do
      a = %Framestamp{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 1

      exception = assert_raise ArgumentError, fn -> Framestamp.rem(a, b, round_frames: :off) end
      assert Exception.message(exception) == "`round_frames` cannot be `:off`"
    end

    test "round | remainder :off | raises" do
      a = %Framestamp{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 1

      exception = assert_raise ArgumentError, fn -> Framestamp.rem(a, b, round_remainder: :off) end

      assert Exception.message(exception) == "`round_remainder` cannot be `:off`"
    end
  end

  describe "#negate/1" do
    negate_table = [
      %{
        input: %Framestamp{seconds: Ratio.new(1), rate: Rates.f23_98()},
        expected: %Framestamp{seconds: Ratio.new(-1), rate: Rates.f23_98()}
      },
      %{
        input: %Framestamp{seconds: Ratio.new(-1), rate: Rates.f23_98()},
        expected: %Framestamp{seconds: Ratio.new(1), rate: Rates.f23_98()}
      },
      %{
        input: %Framestamp{seconds: Ratio.new(0), rate: Rates.f23_98()},
        expected: %Framestamp{seconds: Ratio.new(0), rate: Rates.f23_98()}
      }
    ]

    table_test "<%= input %> == <%= expected %>", negate_table, test_case do
      %{input: input, expected: expected} = test_case

      assert Framestamp.minus(input) == expected
    end
  end

  describe "#abs/1" do
    abs_table = [
      %{
        input: %Framestamp{seconds: Ratio.new(1), rate: Rates.f23_98()},
        expected: %Framestamp{seconds: Ratio.new(1), rate: Rates.f23_98()}
      },
      %{
        input: %Framestamp{seconds: Ratio.new(-1), rate: Rates.f23_98()},
        expected: %Framestamp{seconds: Ratio.new(1), rate: Rates.f23_98()}
      },
      %{
        input: %Framestamp{seconds: Ratio.new(0), rate: Rates.f23_98()},
        expected: %Framestamp{seconds: Ratio.new(0), rate: Rates.f23_98()}
      }
    ]

    table_test "<%= input %> == <%= expected %>", abs_table, test_case do
      %{input: input, expected: expected} = test_case
      assert Framestamp.abs(input) == expected
    end
  end
end