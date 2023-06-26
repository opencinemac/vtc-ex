defmodule Vtc.Test.Support.BenchCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox
  alias Vtc.Test.Support.Repo

  using do
    quote do
      use Vtc.Test.Support.EctoCase, async: false

      Sandbox.mode(Repo, :auto)
    end
  end
end
