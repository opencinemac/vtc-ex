defmodule Vtc.Ecto.Postgres.Utils do
  @moduledoc false

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
  def get_config(opt, default), do: :vtc |> Application.get_env(Postgres, []) |> Keyword.get(opt, default)

  @doc """
  Affirms that module from dep is present, throwing otherwise.
  """
  @spec enforce_dep(module(), atom()) :: :ok
  def enforce_dep(module, name) do
    if not Code.ensure_loaded?(module) do
      throw(
        ":vtc, Postgres, `:include?` config is true, but `#{module}` module not found. Add `#{name}` to your dependencies"
      )
    end

    :ok
  end

  @typedoc """
  Alias of String.t() that hints raw SQL text.
  """
  @type raw_sql() :: String.t()

  @typedoc """
  Options type for `plpgsql_add_function/2`
  """
  @type create_func_opts() :: [
          args: Keyword.t(atom()),
          returns: atom(),
          declares: Keyword.t(atom() | {atom(), raw_sql()}),
          body: raw_sql()
        ]

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
  @spec create_plpgsql_function(atom(), create_func_opts()) :: raw_sql()
  def create_plpgsql_function(name, opts) do
    args = Keyword.get(opts, :args, [])
    returns = Keyword.fetch!(opts, :returns)
    declares = Keyword.get(opts, :declares, nil)
    body = Keyword.fetch!(opts, :body)
    cost = Keyword.get(opts, :cost, 100)

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
          STRICT
          IMMUTABLE
          LEAKPROOF
          PARALLEL SAFE
          COST #{cost}
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

  @doc """
  Builds an SQL query for creating a new native operator.
  """
  @spec create_operator(atom(), atom(), atom(), atom(), commutator: atom(), negator: atom()) :: raw_sql()
  def create_operator(name, left_type, right_type, func_name, opts \\ []) do
    commutator = Keyword.get(opts, :commutator)
    negator = Keyword.get(opts, :negator)

    commutator_sql = if is_nil(commutator), do: "", else: "COMMUTATOR = #{commutator},"
    negator_sql = if is_nil(negator), do: "", else: "NEGATOR = #{negator},"

    """
    DO $wrapper$ BEGIN
      CREATE OPERATOR #{name} (
        LEFTARG = #{left_type},
        RIGHTARG = #{right_type},
        #{commutator_sql}
        #{negator_sql}
        FUNCTION = #{func_name}
      );
    EXCEPTION WHEN duplicate_function
      THEN null;
    END $wrapper$;
    """
  end

  @doc """
  Builds an SQL query for creating a new native CAST
  """
  @spec create_operator_class(atom(), atom(), atom(), Keyword.t(pos_integer()), Keyword.t(pos_integer())) :: raw_sql()
  def create_operator_class(name, type, index_type, operators, functions) do
    operators_sql_list =
      Enum.map(operators, fn {operator, index} ->
        "operator #{index} #{operator}"
      end)

    functions_sql_list =
      Enum.map(functions, fn {function, index} ->
        "function #{index} #{function}(#{type}, #{type})"
      end)

    sql_list = operators_sql_list |> Enum.concat(functions_sql_list) |> Enum.join(",")

    """
    DO $wrapper$ BEGIN
      CREATE OPERATOR CLASS #{name}
      DEFAULT FOR TYPE #{type} USING #{index_type} AS
        #{sql_list};
    EXCEPTION WHEN duplicate_object
      THEN null;
    END $wrapper$;
    """
  end

  @doc """
  Builds an SQL query for creating a new native CAST
  """
  @spec create_cast(atom(), atom(), atom()) :: raw_sql()
  def create_cast(left_type, right_type, func_name) do
    """
    DO $wrapper$ BEGIN
      CREATE CAST (#{left_type} AS #{right_type}) WITH FUNCTION #{func_name}(#{left_type});
    EXCEPTION WHEN duplicate_object
      THEN null;
    END $wrapper$;
    """
  end

  @doc """
  Returns a configuration option for a specific vtc Postgres type and Repo.
  """
  @spec get_type_config(Ecto.Repo.t(), atom(), atom(), Keyword.value()) :: Keyword.value()
  def get_type_config(repo, type_name, opt, default),
    do: repo.config() |> Keyword.get(:vtc, []) |> Keyword.get(type_name) |> Keyword.get(opt, default)

  @doc """
  Returns a the public function prefix for a specific vtc Postgres type and Repo.
  """
  @spec type_function_prefix(Ecto.Repo.t(), atom()) :: String.t()
  def type_function_prefix(repo, type_name), do: calculate_prefix(repo, type_name, :functions_schema)

  @spec type_private_function_prefix(Ecto.Repo.t(), atom()) :: String.t()
  def type_private_function_prefix(repo, type_name), do: calculate_prefix(repo, type_name, :functions_private_schema)

  # Calculate a function prefix for a specific schema and vtc postgres type based on the
  # Repo configuration.
  @spec calculate_prefix(Ecto.Repo.t(), atom(), atom()) :: String.t()
  defp calculate_prefix(repo, type_name, schema_config_opt) do
    functions_schema = get_type_config(repo, type_name, schema_config_opt, :public)
    custom_prefix = get_type_config(repo, type_name, :functions_prefix, "")

    functions_prefix =
      cond do
        functions_schema == :public and custom_prefix == "" -> "rational_"
        custom_prefix != "" -> "#{custom_prefix}_"
        true -> ""
      end

    "#{functions_schema}.#{functions_prefix}"
  end
end
