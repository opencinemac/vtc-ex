defmodule Vtc.Test.Support.CommonTables do
  @moduledoc false
  alias Vtc.Rates
  alias Vtc.Test.Support.TestCase

  @doc """
  Data for running tests on comparison operators.
  """
  @spec framestamp_compare() ::
          [%{a: TestCase.framestamp_input(), b: TestCase.framestamp_input(), expected: :eq | :lt | :gt}]
  def framestamp_compare do
    [
      %{
        a: "01:00:00:00",
        b: "01:00:00:00",
        expected: :eq
      },
      %{
        a: "-01:00:00:00",
        b: "01:00:00:00",
        expected: :lt
      },
      %{
        a: "01:00:00:00",
        b: "-01:00:00:00",
        expected: :gt
      },
      %{
        a: "-01:00:00:00",
        b: "-01:00:00:00",
        expected: :eq
      },
      %{
        a: "00:00:00:00",
        b: "01:00:00:00",
        expected: :lt
      },
      %{
        a: "00:00:00:00",
        b: "-01:00:00:00",
        expected: :gt
      },
      %{
        a: "02:00:00:00",
        b: "01:00:00:00",
        expected: :gt
      },
      %{
        a: "-02:00:00:00",
        b: "01:00:00:00",
        expected: :lt
      },
      %{
        a: "02:00:00:00",
        b: "-01:00:00:00",
        expected: :gt
      },
      %{
        a: "-02:00:00:00",
        b: "-01:00:00:00",
        expected: :lt
      },
      %{
        a: "02:00:00:00",
        b: "00:00:00:00",
        expected: :gt
      },
      %{
        a: "-02:00:00:00",
        b: "00:00:00:00",
        expected: :lt
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
        a: {"-01:00:00:00", Rates.f23_98()},
        b: {"01:00:00:00", Rates.f24()},
        expected: :lt
      },
      %{
        a: {"01:00:00:00", Rates.f23_98()},
        b: {"-01:00:00:00", Rates.f24()},
        expected: :gt
      },
      %{
        a: {"-01:00:00:00", Rates.f23_98()},
        b: {"-01:00:00:00", Rates.f24()},
        expected: :lt
      },
      %{
        a: {"01:00:00:00", Rates.f23_98()},
        b: {"01:00:00:00", Rates.f59_94_ndf()},
        expected: :eq
      },
      %{
        a: {"-01:00:00:00", Rates.f23_98()},
        b: {"01:00:00:00", Rates.f59_94_ndf()},
        expected: :lt
      },
      %{
        a: {"01:00:00:00", Rates.f23_98()},
        b: {"-01:00:00:00", Rates.f59_94_ndf()},
        expected: :gt
      },
      %{
        a: {"-01:00:00:00", Rates.f23_98()},
        b: {"-01:00:00:00", Rates.f59_94_ndf()},
        expected: :eq
      },
      %{
        a: {"01:00:00:00", Rates.f59_94_df()},
        b: {"01:00:00:00", Rates.f59_94_ndf()},
        expected: :lt
      },
      %{
        a: {"-01:00:00:00", Rates.f59_94_df()},
        b: {"01:00:00:00", Rates.f59_94_ndf()},
        expected: :lt
      },
      %{
        a: {"01:00:00:00", Rates.f59_94_df()},
        b: {"-01:00:00:00", Rates.f59_94_ndf()},
        expected: :gt
      },
      %{
        a: {"-01:00:00:00", Rates.f59_94_df()},
        b: {"-01:00:00:00", Rates.f59_94_ndf()},
        expected: :gt
      }
    ]
  end

  @doc """
  Data for running tests on addition operators.
  """
  @spec framestamp_add() ::
          [%{a: TestCase.framestamp_input(), b: TestCase.framestamp_input(), expected: TestCase.framestamp_input()}]
  def framestamp_add do
    [
      %{
        a: "01:00:00:00",
        b: "01:00:00:00",
        opts: [],
        expected: "02:00:00:00"
      },
      %{
        a: "01:00:00:00",
        b: "00:00:00:00",
        opts: [],
        expected: "01:00:00:00"
      },
      %{
        a: "01:00:00:00",
        b: "-01:00:00:00",
        opts: [],
        expected: "00:00:00:00"
      },
      %{
        a: "01:00:00:00",
        b: "-02:00:00:00",
        opts: [],
        expected: "-01:00:00:00"
      },
      %{
        a: "10:12:13:14",
        b: "14:13:12:11",
        opts: [],
        expected: "24:25:26:01"
      },
      %{
        a: {"01:00:00:00", Rates.f23_98()},
        b: {"01:00:00:00", Rates.f47_95()},
        opts: [inherit_rate: :left],
        expected: {"02:00:00:00", Rates.f23_98()}
      },
      %{
        a: {"01:00:00:00", Rates.f23_98()},
        b: {"01:00:00:00", Rates.f47_95()},
        opts: [inherit_rate: :right],
        expected: {"02:00:00:00", Rates.f47_95()}
      },
      %{
        a: {"01:00:00:00", Rates.f23_98()},
        b: {"00:00:00:02", Rates.f47_95()},
        opts: [inherit_rate: :left],
        expected: {"01:00:00:01", Rates.f23_98()}
      },
      %{
        a: {"01:00:00:00", Rates.f23_98()},
        b: {"00:00:00:02", Rates.f47_95()},
        opts: [inherit_rate: :right],
        expected: {"01:00:00:02", Rates.f47_95()}
      }
    ]
  end

  @doc """
  Data for running tests on subtraction operators.
  """
  @spec framestamp_subtract() ::
          [%{a: TestCase.framestamp_input(), b: TestCase.framestamp_input(), expected: TestCase.framestamp_input()}]
  def framestamp_subtract do
    [
      %{
        a: "01:00:00:00",
        b: "01:00:00:00",
        opts: [],
        expected: "00:00:00:00"
      },
      %{
        a: "01:00:00:00",
        b: "00:00:00:00",
        opts: [],
        expected: "01:00:00:00"
      },
      %{
        a: "01:00:00:00",
        b: "-01:00:00:00",
        opts: [],
        expected: "02:00:00:00"
      },
      %{
        a: "01:00:00:00",
        b: "02:00:00:00",
        opts: [],
        expected: "-01:00:00:00"
      },
      %{
        a: "34:10:09:08",
        b: "10:06:07:14",
        opts: [],
        expected: "24:04:01:18"
      },
      %{
        a: {"02:00:00:00", Rates.f23_98()},
        b: {"01:00:00:00", Rates.f47_95()},
        opts: [inherit_rate: :left],
        expected: {"01:00:00:00", Rates.f23_98()}
      },
      %{
        a: {"02:00:00:00", Rates.f23_98()},
        b: {"01:00:00:00", Rates.f47_95()},
        opts: [inherit_rate: :right],
        expected: {"01:00:00:00", Rates.f47_95()}
      },
      %{
        a: {"01:00:00:02", Rates.f23_98()},
        b: {"00:00:00:02", Rates.f47_95()},
        opts: [inherit_rate: :left],
        expected: {"01:00:00:01", Rates.f23_98()}
      },
      %{
        a: {"01:00:00:02", Rates.f23_98()},
        b: {"00:00:00:02", Rates.f47_95()},
        opts: [inherit_rate: :right],
        expected: {"01:00:00:02", Rates.f47_95()}
      }
    ]
  end

  @doc """
  Test data for checking that a timecode range inclu
  """
  @spec range_contains() ::
          [
            %{
              name: String.t(),
              range: TestCase.range_shorthand(),
              framestamp: TestCase.framestamp_input(),
              expected: boolean(),
              expected_negative: boolean()
            }
          ]
  def range_contains do
    [
      %{
        name: "range.in < stamp < range.out | :exclusive",
        range: {"01:00:00:00", "02:00:00:00"},
        framestamp: "01:30:00:00",
        expected: true,
        expected_negative: true
      },
      %{
        name: "stamp == range.in | :exclusive",
        range: {"01:00:00:00", "02:00:00:00"},
        framestamp: "01:00:00:00",
        expected: true,
        expected_negative: false
      },
      %{
        name: "stamp == range.out - 1 | :exclusive",
        range: {"01:00:00:00", "02:00:00:00"},
        framestamp: "01:59:59:23",
        expected: true,
        expected_negative: true
      },
      %{
        name: "stamp == range.in - 1 | :exclusive",
        range: {"01:00:00:00", "02:00:00:00"},
        framestamp: "00:59:59:23",
        expected: false,
        expected_negative: false
      },
      %{
        name: "stamp == range.out | :exclusive",
        range: {"01:00:00:00", "02:00:00:00"},
        framestamp: "02:00:00:00",
        expected: false,
        expected_negative: true
      },
      %{
        name: "stamp < range.in | :exclusive",
        range: {"01:00:00:00", "02:00:00:00"},
        framestamp: "00:30:00:00",
        expected: false,
        expected_negative: false
      },
      %{
        name: "stamp < range.in | sign flipped | :exclusive",
        range: {"01:00:00:00", "02:00:00:00"},
        framestamp: "-01:30:00:00",
        expected: false,
        expected_negative: false
      },
      %{
        name: "stamp > range.out | :exclusive",
        range: {"01:00:00:00", "02:00:00:00"},
        framestamp: "02:30:00:00",
        expected: false,
        expected_negative: false
      },
      %{
        name: "range.in < stamp < range.out | :inclusive",
        range: {"01:00:00:00", "02:00:00:00", :inclusive},
        framestamp: "01:30:00:00",
        expected: true,
        expected_negative: true
      },
      %{
        name: "stamp == range.in | :inclusive",
        range: {"01:00:00:00", "02:00:00:00", :inclusive},
        framestamp: "01:00:00:00",
        expected: true,
        expected_negative: true
      },
      %{
        name: "stamp == range.out - 1 | :inclusive",
        range: {"01:00:00:00", "02:00:00:00", :inclusive},
        framestamp: "01:59:59:23",
        expected: true,
        expected_negative: true
      },
      %{
        name: "stamp == range.in - 1 | :inclusive",
        range: {"01:00:00:00", "02:00:00:00", :inclusive},
        framestamp: "00:59:59:23",
        expected: false,
        expected_negative: false
      },
      %{
        name: "stamp == range.out | :inclusive",
        range: {"01:00:00:00", "02:00:00:00", :inclusive},
        framestamp: "02:00:00:00",
        expected: true,
        expected_negative: true
      },
      %{
        name: "stamp == range.out + 1 | :inclusive",
        range: {"01:00:00:00", "02:00:00:00", :inclusive},
        framestamp: "02:00:00:01",
        expected: false,
        expected_negative: false
      },
      %{
        name: "stamp < range.in | :inclusive",
        range: {"01:00:00:00", "02:00:00:00", :inclusive},
        framestamp: "00:30:00:00",
        expected: false,
        expected_negative: false
      },
      %{
        name: "stamp < range.in | sign flipped | :inclusive",
        range: {"01:00:00:00", "02:00:00:00", :inclusive},
        framestamp: "-01:30:00:00",
        expected: false,
        expected_negative: false
      },
      %{
        name: "stamp > range.out | :inclusive",
        range: {"01:00:00:00", "02:00:00:00", :inclusive},
        framestamp: "02:30:00:00",
        expected: false,
        expected_negative: false
      }
    ]
  end

  @doc """
  Test data for checking if two timecode ranges overlap.
  """
  @spec range_overlaps() :: [
          %{
            name: String.t(),
            a: TestCase.range_shorthand(),
            b: TestCase.range_shorthand(),
            expected: boolean()
          }
        ]
  def range_overlaps do
    base_cases = [
      %{
        name: "a.in == b.in and a.out == b.out",
        a: {"01:00:00:00", "02:00:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: true
      },
      %{
        name: "a.in == b.in and a.out < b.out",
        a: {"01:00:00:00", "01:30:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: true
      },
      %{
        name: "a.in == b.in and a.out > b.out",
        a: {"01:00:00:00", "02:30:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: true
      },
      %{
        name: "a.in < b.in and a.out == b.out",
        a: {"00:30:00:00", "02:00:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: true
      },
      %{
        name: "a.in < b.in and a.out < b.out",
        a: {"00:30:00:00", "01:30:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: true
      },
      %{
        name: "a.in < b.in and a.out > b.out",
        a: {"00:30:00:00", "02:30:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: true
      },
      %{
        name: "a.in > b.in and a.out == b.out",
        a: {"01:30:00:00", "02:00:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: true
      },
      %{
        name: "a.in > b.in and a.out < b.out",
        a: {"01:15:00:00", "01:45:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: true
      },
      %{
        name: "a.in > b.in and a.out > b.out",
        a: {"01:30:00:00", "02:30:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: true
      },
      %{
        name: "a < b",
        a: {"00:00:00:00", "00:30:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: false
      },
      %{
        name: "a > b",
        a: {"02:30:00:00", "03:00:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: false
      },
      %{
        name: "a.out & b.in at boundary",
        a: {"01:00:00:00", "02:00:00:00"},
        b: {"02:00:00:00", "03:00:00:00"},
        expected: false
      },
      %{
        name: "a.in & b.out at boundary",
        a: {"03:00:00:00", "04:00:00:00"},
        b: {"02:00:00:00", "03:00:00:00"},
        expected: false
      }
    ]

    mixed_rate =
      Enum.map(base_cases, fn test_case ->
        %{name: name, b: {b_in, b_out}} = test_case

        test_case
        |> Map.put(:b, {b_in, b_out, Rates.f47_95()})
        |> Map.put(:name, name <> " | mixed rate")
      end)

    Enum.concat(base_cases, mixed_rate)
  end

  @doc """
  Test data for checking if two timecode ranges intersect.
  """
  @spec range_intersection() :: [
          %{
            name: String.t(),
            a: TestCase.range_shorthand(),
            b: TestCase.range_shorthand(),
            expected: TestCase.range_shorthand()
          }
        ]
  def range_intersection do
    base_cases = [
      %{
        name: "a.in == b.in and a.out == b.out",
        a: {"01:00:00:00", "02:00:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: {"01:00:00:00", "02:00:00:00"}
      },
      %{
        name: "a.in == b.in and a.out < b.out",
        a: {"01:00:00:00", "01:30:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: {"01:00:00:00", "01:30:00:00"}
      },
      %{
        name: "a.in == b.in and a.out > b.out",
        a: {"01:00:00:00", "02:30:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: {"01:00:00:00", "02:00:00:00"}
      },
      %{
        name: "a.in < b.in and a.out == b.out",
        a: {"00:30:00:00", "02:00:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: {"01:00:00:00", "02:00:00:00"}
      },
      %{
        name: "a.in < b.in and a.out < b.out",
        a: {"00:30:00:00", "01:30:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: {"01:00:00:00", "01:30:00:00"}
      },
      %{
        name: "a.in < b.in and a.out > b.out",
        a: {"00:30:00:00", "02:30:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: {"01:00:00:00", "02:00:00:00"}
      },
      %{
        name: "a.in > b.in and a.out == b.out",
        a: {"01:30:00:00", "02:00:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: {"01:30:00:00", "02:00:00:00"}
      },
      %{
        name: "a.in > b.in and a.out < b.out",
        a: {"01:15:00:00", "01:45:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: {"01:15:00:00", "01:45:00:00"}
      },
      %{
        name: "a.in > b.in and a.out > b.out",
        a: {"01:30:00:00", "02:30:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: {"01:30:00:00", "02:00:00:00"}
      },
      %{
        name: "a < b",
        a: {"01:00:00:00", "02:00:00:00"},
        b: {"03:00:00:00", "04:00:00:00"},
        expected: {:error, :none}
      },
      %{
        name: "a > b",
        a: {"03:00:00:00", "04:00:00:00"},
        b: {"01:00:00:00", "02:00:00:00"},
        expected: {:error, :none}
      },
      %{
        name: "a.out & b.in at boundary",
        a: {"01:00:00:00", "02:00:00:00"},
        b: {"02:00:00:00", "03:00:00:00"},
        expected: {:error, :none}
      },
      %{
        name: "a.in & b.out at boundary",
        a: {"03:00:00:00", "04:00:00:00"},
        b: {"02:00:00:00", "03:00:00:00"},
        expected: {:error, :none}
      }
    ]

    mixed_rate =
      Enum.map(base_cases, fn test_case ->
        %{name: name, b: {b_in, b_out}} = test_case

        test_case
        |> Map.put(:b, {b_in, b_out, Rates.f47_95()})
        |> Map.put(:name, name <> " | mixed rate")
      end)

    Enum.concat(base_cases, mixed_rate)
  end
end
