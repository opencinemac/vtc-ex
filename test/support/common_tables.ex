defmodule Vtc.Test.Support.CommonTables do
  @moduledoc false
  alias Vtc.Rates
  alias Vtc.Test.Support.TestCase

  @doc """
  Data for running tests on comparison operators.
  """
  @spec compare_table() ::
          [%{a: TestCase.framestamp_input(), b: TestCase.framestamp_input(), expected: :eq | :lt | :gt}]
  def compare_table do
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
  @spec add_table() ::
          [%{a: TestCase.framestamp_input(), b: TestCase.framestamp_input(), expected: TestCase.framestamp_input()}]
  def add_table do
    [
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
  end

  @doc """
  Data for running tests on subtraction operators.
  """
  @spec subtract_table() ::
          [%{a: TestCase.framestamp_input(), b: TestCase.framestamp_input(), expected: TestCase.framestamp_input()}]
  def subtract_table do
    [
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
  end
end
