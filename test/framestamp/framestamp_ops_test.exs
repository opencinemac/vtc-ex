defmodule Vtc.FramestampTest.Ops do
  @moduledoc false
  use Vtc.Test.Support.TestCase

  alias Vtc.Framerate
  alias Vtc.Framestamp
  alias Vtc.Rates
  alias Vtc.Test.Support.CommonTables

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
    setup context, do: TestCase.setup_framestamps(context)
    @describetag framestamps: [:original, :expected]

    table_test "<%= original %> -> <%= new_rate %>", rebase_table, test_case do
      %{original: original, new_rate: new_rate, expected: expected} = test_case
      assert {:ok, rebased} = Framestamp.rebase(original, new_rate)
      assert rebased == expected

      assert {:ok, round_tripped} = Framestamp.rebase(rebased, original.rate)
      assert round_tripped == original
    end
  end

  describe "#rebase!/2" do
    setup context, do: TestCase.setup_framestamps(context)
    @describetag framestamps: [:original, :expected]

    table_test "<%= original %> -> <%= new_rate %>", rebase_table, test_case do
      %{original: original, new_rate: new_rate, expected: expected} = test_case
      assert %Framestamp{} = rebased = Framestamp.rebase!(original, new_rate)
      assert rebased == expected

      assert %Framestamp{} = round_tripped = Framestamp.rebase!(rebased, original.rate)
      assert round_tripped == original
    end
  end

  describe "#compare/2" do
    setup context, do: TestCase.setup_framestamps(context)
    @describetag framestamps: [:a, :b]

    table_test "<%= a %> is <%= expected %> <%= b %>", CommonTables.framestamp_compare(), test_case do
      %{a: a, b: b, expected: expected} = test_case
      assert Framestamp.compare(a, b) == expected
    end

    table_test "<%= a %> is <%= expected %> <%= b %> | b = tc string", CommonTables.framestamp_compare(), test_case,
      if: is_binary(test_case.a) and is_binary(test_case.b) do
      %{a: a, b: b, expected: expected} = test_case
      b = Framestamp.smpte_timecode(b)

      assert Framestamp.compare(a, b) == expected
    end

    table_test "<%= a %> is <%= expected %> <%= b %> | a = tc string", CommonTables.framestamp_compare(), test_case,
      if: is_binary(test_case.a) and is_binary(test_case.b) do
      %{a: a, b: b, expected: expected} = test_case
      a = Framestamp.smpte_timecode(a)

      assert Framestamp.compare(a, b) == expected
    end

    table_test "<%= a %> is <%= expected %> <%= b %> | b = frames int", CommonTables.framestamp_compare(), test_case,
      if: is_binary(test_case.a) and is_binary(test_case.b) do
      %{a: a, b: b, expected: expected} = test_case
      b = Framestamp.frames(b)

      assert Framestamp.compare(a, b) == expected
    end

    table_test "<%= a %> is <%= expected %> <%= b %> | a = frames int", CommonTables.framestamp_compare(), test_case,
      if: is_binary(test_case.a) and is_binary(test_case.b) do
      %{a: a, b: b, expected: expected} = test_case
      a = Framestamp.frames(a)

      assert Framestamp.compare(a, b) == expected
    end
  end

  describe "#eq?/2" do
    setup context, do: TestCase.setup_framestamps(context)
    @describetag framestamps: [:a, :b]

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

    table_test "<%= a %>, <%= b %>", CommonTables.framestamp_compare(), test_case do
      %{a: a, b: b, expected: cmp_expected} = test_case
      expected = cmp_expected == :eq

      assert Framestamp.eq?(a, b) == expected
    end
  end

  describe "#lt?/2" do
    setup context, do: TestCase.setup_framestamps(context)
    @describetag framestamps: [:a, :b]

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

    table_test "<%= a %>, <%= b %>", CommonTables.framestamp_compare(), test_case do
      %{a: a, b: b, expected: cmp_expected} = test_case
      expected = cmp_expected == :lt

      assert Framestamp.lt?(a, b) == expected
    end
  end

  describe "#lte?/2" do
    setup context, do: TestCase.setup_framestamps(context)
    @describetag framestamps: [:a, :b]

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

    table_test "<%= a %>, <%= b %>", CommonTables.framestamp_compare(), test_case do
      %{a: a, b: b, expected: cmp_expected} = test_case
      expected = cmp_expected in [:lt, :eq]

      assert Framestamp.lte?(a, b) == expected
    end
  end

  describe "#gt?/2" do
    setup context, do: TestCase.setup_framestamps(context)
    @describetag framestamps: [:a, :b]

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

    table_test "<%= a %>, <%= b %>", CommonTables.framestamp_compare(), test_case do
      %{a: a, b: b, expected: cmp_expected} = test_case
      expected = cmp_expected == :gt

      assert Framestamp.gt?(a, b) == expected
    end
  end

  describe "#gte?/2" do
    setup context, do: TestCase.setup_framestamps(context)
    @describetag framestamps: [:a, :b]

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

    table_test "<%= a %>, <%= b %>", CommonTables.framestamp_compare(), test_case do
      %{a: a, b: b, expected: cmp_expected} = test_case
      expected = cmp_expected in [:gt, :eq]

      assert Framestamp.gte?(a, b) == expected
    end
  end

  describe "#add/2" do
    setup context, do: TestCase.setup_framestamps(context)
    @describetag framestamps: [:a, :b, :expected]

    add_table = CommonTables.framestamp_add()

    table_test "<%= a %> + <%= b %> == <%= expected %> | opts: <%= opts %>", add_table, test_case do
      %{a: a, b: b, opts: opts, expected: expected} = test_case
      assert Framestamp.add(a, b, opts) == expected
    end

    table_test "<%= a %> + <%= b %> == <%= expected %> | opts: <%= opts %> | flipped", add_table, test_case,
      if: not Keyword.has_key?(test_case.opts, :inherit_rate) do
      %{a: a, b: b, opts: opts, expected: expected} = test_case
      assert Framestamp.add(b, a, opts) == expected
    end

    table_test "<%= a %> + <%= b %> == <%= expected %> | opts: [inherit_rate: false]", add_table, test_case,
      if: is_binary(test_case.a) and is_binary(test_case.b) do
      %{a: a, b: b, opts: opts, expected: expected} = test_case
      opts = Keyword.put(opts, :inherit_rate, false)

      assert Framestamp.add(b, a, opts) == expected
    end

    table_test "<%= a %> + <%= b %> == <%= expected %> | opts: [inherit_rate: :left]", add_table, test_case,
      if: is_binary(test_case.a) and is_binary(test_case.b) do
      %{a: a, b: b, opts: opts, expected: expected} = test_case
      opts = Keyword.put(opts, :inherit_rate, :left)

      assert Framestamp.add(b, a, opts) == expected
    end

    table_test "<%= a %> + <%= b %> == <%= expected %> | opts: [inherit_rate: :right]", add_table, test_case,
      if: is_binary(test_case.a) and is_binary(test_case.b) do
      %{a: a, b: b, opts: opts, expected: expected} = test_case
      opts = Keyword.put(opts, :inherit_rate, :right)

      assert Framestamp.add(b, a, opts) == expected
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
        b: %Framestamp{seconds: Ratio.new(1, 24), rate: Rates.f24()},
        opts: [round: :off],
        description: "",
        expected: %Framestamp{seconds: Ratio.new(1), rate: Rates.f24()}
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

    mixed_rate_error_table = [
      %{
        a: Framestamp.with_frames!("01:00:00:00", Rates.f24()),
        b: Framestamp.with_frames!("01:00:00:00", Rates.f48())
      },
      %{
        a: Framestamp.with_frames!("01:00:00:00", Rates.f23_98()),
        b: Framestamp.with_frames!("01:00:00:00", Framerate.new!(Ratio.new(24_000, 1001), ntsc: nil))
      },
      %{
        a: Framestamp.with_frames!("01:00:00:00", Rates.f29_97_ndf()),
        b: Framestamp.with_frames!("01:00:00:00", Rates.f29_97_df())
      }
    ]

    table_test "<%= a %> + <%= b %> raises on mixed rate", mixed_rate_error_table, test_case do
      %{a: a, b: b} = test_case

      error = assert_raise Framestamp.MixedRateArithmeticError, fn -> Framestamp.add(a, b) end

      assert Framestamp.MixedRateArithmeticError.message(error) ==
               "attempted `Framestamp.add(a, b)` where `a.rate` does not match `b.rate`." <>
                 " try `:inherit_rate` option to `:left` or `:right`. alternatively," <>
                 " do your calculation in seconds, then cast back to `Framestamp` with" <>
                 " the appropriate framerate using `with_seconds/3`"
    end
  end

  describe "#sub/2" do
    setup context, do: TestCase.setup_framestamps(context)
    @describetag framestamps: [:a, :b, :expected]

    sub_table = CommonTables.framestamp_subtract()

    table_test "<%= a %> + <%= b %> == <%= expected %> | opts: <%= opts %>", sub_table, test_case do
      %{a: a, b: b, opts: opts, expected: expected} = test_case

      assert Framestamp.sub(a, b, opts) == expected
    end

    table_test "<%= a %> + <%= b %> == <%= expected %> | opts: [inherit_rate: false]", sub_table, test_case,
      if: is_binary(test_case.a) and is_binary(test_case.b) do
      %{a: a, b: b, opts: opts, expected: expected} = test_case
      opts = Keyword.put(opts, :inherit_rate, false)

      assert Framestamp.sub(a, b, opts) == expected
    end

    table_test "<%= a %> + <%= b %> == <%= expected %> | opts: [inherit_rate: :left]", sub_table, test_case,
      if: is_binary(test_case.a) and is_binary(test_case.b) do
      %{a: a, b: b, opts: opts, expected: expected} = test_case
      opts = Keyword.put(opts, :inherit_rate, :left)

      assert Framestamp.sub(a, b, opts) == expected
    end

    table_test "<%= a %> + <%= b %> == <%= expected %> | opts: [inherit_rate: :right]", sub_table, test_case,
      if: is_binary(test_case.a) and is_binary(test_case.b) do
      %{a: a, b: b, opts: opts, expected: expected} = test_case
      opts = Keyword.put(opts, :inherit_rate, :right)

      assert Framestamp.sub(a, b, opts) == expected
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

    mixed_rate_error_table = [
      %{
        a: Framestamp.with_frames!("01:00:00:00", Rates.f24()),
        b: Framestamp.with_frames!("01:00:00:00", Rates.f48())
      },
      %{
        a: Framestamp.with_frames!("01:00:00:00", Rates.f23_98()),
        b: Framestamp.with_frames!("01:00:00:00", Framerate.new!(Ratio.new(24_000, 1001), ntsc: nil))
      },
      %{
        a: Framestamp.with_frames!("01:00:00:00", Rates.f29_97_ndf()),
        b: Framestamp.with_frames!("01:00:00:00", Rates.f29_97_df())
      }
    ]

    table_test "<%= a %> + <%= b %> raises on mixed rate", mixed_rate_error_table, test_case do
      %{a: a, b: b} = test_case

      error = assert_raise Framestamp.MixedRateArithmeticError, fn -> Framestamp.sub(a, b) end

      assert Framestamp.MixedRateArithmeticError.message(error) ==
               "attempted `Framestamp.sub(a, b)` where `a.rate` does not match `b.rate`." <>
                 " try `:inherit_rate` option to `:left` or `:right`. alternatively," <>
                 " do your calculation in seconds, then cast back to `Framestamp` with" <>
                 " the appropriate framerate using `with_seconds/3`"
    end
  end

  describe "#smpte_wrap_tod!/1" do
    setup context, do: TestCase.setup_framestamps(context)
    @describetag framestamps: [:value, :expected]

    smpte_wrap_tod_table = [
      %{value: "01:00:00:00", expected: "01:00:00:00"},
      %{value: "23:59:59:23", expected: "23:59:59:23"},
      %{value: "00:00:00:00", expected: "00:00:00:00"},
      %{value: "24:01:00:00", expected: "00:01:00:00"},
      %{value: "25:01:00:00", expected: "01:01:00:00"},
      %{value: "24:00:00:00", expected: "00:00:00:00"},
      %{value: "32:14:56:21", expected: "08:14:56:21"},
      %{value: "-01:00:00:00", expected: "23:00:00:00"},
      %{value: "-23:00:00:00", expected: "01:00:00:00"},
      %{value: "48:00:00:00", expected: "00:00:00:00"},
      %{value: "-48:00:00:00", expected: "00:00:00:00"},
      %{value: "48:17:12:01", expected: "00:17:12:01"},
      %{value: {"01:00:00:00", Rates.f29_97_df()}, expected: {"01:00:00:00", Rates.f29_97_df()}},
      %{value: {"23:59:59:29", Rates.f29_97_df()}, expected: {"23:59:59:29", Rates.f29_97_df()}},
      %{value: {"00:00:00:00", Rates.f29_97_df()}, expected: {"00:00:00:00", Rates.f29_97_df()}},
      %{value: {"-01:00:00:00", Rates.f29_97_df()}, expected: {"23:00:00:00", Rates.f29_97_df()}}
    ]

    table_test "<%= value %> wraps to <%= expected %>", smpte_wrap_tod_table, test_case do
      %{value: value, expected: expected} = test_case

      assert Framestamp.smpte_wrap_tod!(value) == expected
    end

    test "raises on non-NTSC fractional rate" do
      rate = Framerate.new!(Ratio.new(23.98))
      stamp = Framestamp.with_frames!(0, rate)

      error = assert_raise ArgumentError, fn -> Framestamp.smpte_wrap_tod!(stamp) end

      assert Exception.message(error) ==
               "`framerate` must be NTSC or whole-frame. time-of-day timecode is not defined for other rated"
    end
  end

  describe "#mult/2" do
    setup context, do: TestCase.setup_framestamps(context)
    @describetag framestamps: [:a, :expected]

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
    setup context, do: TestCase.setup_framestamps(context)
    @describetag framestamps: [:a, :expected]

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
      description: "divisor negative",
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
    setup context, do: TestCase.setup_framestamps(context)
    @describetag framestamps: [:dividend, :expected_q, :expected_r]

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
      assert Exception.message(exception) == "`:round_frames` cannot be `:off`"
    end

    test "round | remainder :off | raises" do
      a = %Framestamp{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 1

      exception = assert_raise ArgumentError, fn -> Framestamp.divrem(a, b, round_remainder: :off) end

      assert Exception.message(exception) == "`:round_remainder` cannot be `:off`"
    end
  end

  describe "#rem/2" do
    setup context, do: TestCase.setup_framestamps(context)
    @describetag framestamps: [:dividend, :expected_q, :expected_r]

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
      assert Exception.message(exception) == "`:round_frames` cannot be `:off`"
    end

    test "round | remainder :off | raises" do
      a = %Framestamp{seconds: Ratio.new(47, 48), rate: Rates.f24()}
      b = 1

      exception = assert_raise ArgumentError, fn -> Framestamp.rem(a, b, round_remainder: :off) end

      assert Exception.message(exception) == "`:round_remainder` cannot be `:off`"
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
