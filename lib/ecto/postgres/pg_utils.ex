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
    if Code.ensure_loaded?(Ecto) and Code.ensure_loaded?(Postgrex) do
      action.()
    else
      otherwise.()
    end
  end
end
