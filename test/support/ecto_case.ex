defmodule Vtc.Test.Support.EctoCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox
  alias Vtc.Test.Support.Repo

  using do
    quote do
      use Vtc.Test.Support.TestCase

      alias Vtc.Test.Support.Repo

      @moduletag :ecto
      @moduletag :postgres
    end
  end

  setup context do
    :ok = Sandbox.checkout(Repo)

    unless context[:async] do
      Sandbox.mode(Repo, {:shared, self()})
    end

    :ok
  end
end
