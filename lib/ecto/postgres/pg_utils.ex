defmodule Vtc.Ecto.Postgres.Utils do
  @moduledoc false

  @typedoc """
  Alias of String.t() that hints raw SQL text.
  """
  @type raw_sql() :: String.t()

  ## Exposes a macro for defining modules that will only be compiled if the caller
  ## has set `:vtc, Postrgrex, :include?` to `true` in their application config.

  @spec __using__(Keyword.t()) :: Macro.t()
  defmacro __using__(_) do
    quote do
      import Vtc.Ecto.Postgres.Utils, only: [defpgmodule: 2, when_pg_enabled: 1]

      require Vtc.Ecto.Postgres.Utils
    end
  end

  @doc """
  Wraps defmodule, conditionally declaring the module during compilation
  based on caller configuration.
  """
  @spec defpgmodule(module(), do: Macro.t()) :: Macro.t()
  defmacro defpgmodule(name, do: body) do
    if_pg_enabled(fn ->
      quote do
        defmodule unquote(name) do
          unquote(body)
        end
      end
    end)
  end

  @doc """
  Only executes if the calling application has Postgres types enabled.
  """
  @spec when_pg_enabled(do: Macro.t()) :: Macro.t()
  defmacro when_pg_enabled(do: body) do
    if_pg_enabled(fn ->
      quote do
        unquote(body)
      end
    end)
  end

  defp if_pg_enabled(action, otherwise \\ fn -> nil end) do
    if get_config(:include?, false) do
      :ok = enforce_dep(Ecto, :ecto)
      :ok = enforce_dep(Postgrex, :postgrex)

      action.()
    else
      otherwise.()
    end
  end

  @doc """
  Fetches a config for `:vtc, Postgrex`
  """
  @spec get_config(atom(), result) :: result when result: any()
  def get_config(opt, default), do: :vtc |> Application.get_env(Postgrex, []) |> Keyword.get(opt, default)

  @doc """
  Affirms that module from dep is present, throwing otherwise.
  """
  @spec enforce_dep(module(), atom()) :: :ok
  def enforce_dep(module, name) do
    if not Code.ensure_loaded?(module) do
      throw(
        ":vtc, Postgrex, `:include?` config is true, but `#{module}` module not found. Add `#{name}` to your dependencies"
      )
    end

    :ok
  end
end
