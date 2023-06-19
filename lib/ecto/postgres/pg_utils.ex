defmodule Vtc.Ecto.Postgres.Utils do
  @moduledoc false

  ## Exposes a macro for defining modules that will only be compiled if the caller
  ## has set `:vtc, :postgres_types?` to `true` in their application config.

  @spec __using__(Keyword.t()) :: Macro.t()
  defmacro __using__(_) do
    quote do
      import Vtc.Ecto.Postgres.Utils

      require Vtc.Ecto.Postgres.Utils
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

  @typedoc """
  Options type for `plpgsql_add_function/2`
  """
  @type add_function_opt() :: {:returns, atom()} | {:declare, Keyword.t(atom())} | {:body, String.t()}

  @doc """
  Builds a [plpgsql](https://www.postgresql.org/docs/current/plpgsql.html) function,
  taking care of all the biolerplate.

  ## Args

  - `name`: The name of the function, including schema namespace.

  ## Options

  - `args`: The arguments the function takes and their types in a `arg: type` keyword
    list.

  - `returns`: The type the function returns.

  - `declares`: A `name: type` keyword list of variables that should be declared in the
    function's "DECLARES" block. Optionally can pass `name: {type, calculation}` to
    declare a short calculation to set the variable.

  - `body`: The function body.
  """
  @spec plpgsql_add_function(String.t(), [add_function_opt()]) :: String.t()
  def plpgsql_add_function(name, opts) do
    args = Keyword.get(opts, :args, [])
    returns = Keyword.fetch!(opts, :returns)
    declares = Keyword.get(opts, :declares, nil)
    body = Keyword.fetch!(opts, :body)

    args = Enum.map_join(args, ", ", fn {arg, type} -> "#{arg} #{type}" end)

    declare =
      if is_nil(declares) do
        ""
      else
        vars =
          Enum.map_join(declares, fn
            {var, {type, value}} -> "#{var} #{type} := #{value};\n"
            {var, type} -> "#{var} #{type};\n"
          end)

        """
        DECLARE
        #{vars}
        """
      end

    """
    DO $wrapper$ BEGIN
        CREATE FUNCTION #{name}(#{args})
          RETURNS #{returns}
          LANGUAGE plpgsql
          IMMUTABLE
          LEAKPROOF
          PARALLEL SAFE
          COST 3
        AS $func$
          #{declare}
          BEGIN
            #{body}
          END;
        $func$;
        EXCEPTION WHEN duplicate_function
          THEN null;
      END $wrapper$;
    """
  end
end
