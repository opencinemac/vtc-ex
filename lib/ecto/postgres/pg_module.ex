defmodule Vtc.Ecto.Postgres.Module do
  @moduledoc false

  ## Exposes a macro for defining modules that will only be compiled if the caller
  ## has set `:vtc, :postgres_types?` to `true` in their application config.

  @spec __using__(Keyword.t()) :: Macro.t()
  defmacro __using__(_) do
    quote do
      import Ecto.Postgres.Module

      require Ecto.Postgres.Module
    end
  end

  # Wraps defmodule, conditionally declaring the module during compilation
  # based on caller configuration.
  @spec defpgmodule(module(), do: Macro.t()) :: Macro.t()
  defmacro defpgmodule(name, do: body) do
    quote do
      if Application.get_env(:vtc, :postgres_types?, false) do
        :ok = unquote(__MODULE__).enforce_dep(Ecto, :ecto)
        :ok = unquote(__MODULE__).enforce_dep(Postgrex, :postgrex)

        defmodule unquote(name) do
          unquote(body)
        end
      end
    end
  end

  # Affirms that module from dep is present, throwing otherwise.
  @spec enforce_dep(module(), atom()) :: :ok
  def enforce_dep(module, name) do
    if not Code.ensure_loaded?(module) do
      throw(
        "vtc: `:postgres_types?` config is true, but `#{module}` module not found. Add `#{name}` to your dependencies"
      )
    end

    :ok
  end
end
