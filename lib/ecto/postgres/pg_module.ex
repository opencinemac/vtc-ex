defmodule Ecto.Postgres.Module do
  @moduledoc false

  ## Exposes a macro for defining modules that will only be compiled if the caller
  ## has set `:vtc, :postgres_types?` to `true` in their application config.

  defmacro __using__(_) do
    quote do
      import Ecto.Postgres.Module

      require Ecto.Postgres.Module
    end
  end

  defmacro defpgmodule(name, do: body) do
    quote do
      if Application.get_env(:vtc, :postgres_types?, false) do
        unquote(__MODULE__).check_dep(Ecto, :ecto)
        unquote(__MODULE__).check_dep(Postgrex, :postgrex)

        defmodule unquote(name) do
          unquote(body)
        end
      end
    end
  end

  def check_dep(module, name) do
    if not Code.ensure_loaded?(module) do
      throw("vtc: `:postgres_types` config is true, but `#{module}` module not found. Add `#{name}` to your dependencies")
    end
  end
end
