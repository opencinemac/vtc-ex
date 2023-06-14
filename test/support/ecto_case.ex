defmodule Vtc.Test.Support.EctoCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox
  alias Vtc.Test.Support.Repo

  using do
    quote do
      alias Vtc.Test.Support.Repo
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
