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
end
