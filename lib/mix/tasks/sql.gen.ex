defmodule Mix.Tasks.Vtc.Sql.Gen do
  @moduledoc """
  Generates raw SQL for migrations.
  """
  use Mix.Task

  alias Vtc.Ecto.Postgres.Migrations
  alias Vtc.Ecto.Postgres.PgTypeMigration

  @migration_modules Migrations.modules()
  @valid_types Enum.map(@migration_modules, &PgTypeMigration.postgres_type(&1))
  @valid_types_str Enum.map(@valid_types, &Atom.to_string(&1))

  @spec run([binary()]) :: :ok
  def run(argv) do
    opts = build_opts(argv)

    @migration_modules
    |> PgTypeMigration.list_info_all(opts)
    |> Enum.map_join("\n\n", fn {_, up_command, _} -> up_command end)
    |> IO.puts()

    :ok
  end

  defp build_opts(argv) do
    {opts, _, _} = OptionParser.parse(argv, strict: [include: :keep, exclude: :keep])

    opts =
      Enum.reduce(opts, [], fn {opt, value}, opts ->
        Keyword.update(opts, opt, [value], fn opt_list -> [value | opt_list] end)
      end)

    includes = opts |> Keyword.get(:include, []) |> build_migration_list(:include)
    excludes = opts |> Keyword.get(:exclude, []) |> build_migration_list(:exclude)
    opts = Enum.concat(includes, excludes)

    Enum.reduce(opts, [], fn {type, type_opts}, opts ->
      Keyword.update(opts, type, type_opts, &Keyword.merge(&1, type_opts))
    end)
  end

  @spec build_migration_list([String.t()], :include | :exclude) :: [
          rational: [include: Keyword.t(atom()), exclude: Keyword.t(atom())],
          framerate: [include: Keyword.t(atom()), exclude: Keyword.t(atom())],
          framestamp: [include: Keyword.t(atom()), exclude: Keyword.t(atom())],
          framestamp_range: [include: Keyword.t(atom()), exclude: Keyword.t(atom())]
        ]
  defp build_migration_list(migrations, opt) do
    migrations
    |> Enum.map(fn migration ->
      case String.split(migration, ".") do
        [type, migration] -> {type, migration}
        _ -> raise "migration must be in format {type}.{migration}. got #{migration}"
      end
    end)
    |> Enum.map(fn
      {type, migration} when type in @valid_types_str ->
        {String.to_existing_atom(type), migration_to_atom(type, migration)}

      {type, _} ->
        raise "unrecognized postgres type: #{type}"
    end)
    |> Enum.reduce([], fn {type, migration}, opts ->
      Keyword.update(opts, type, [migration], fn type_list -> [migration | type_list] end)
    end)
    |> Enum.map(fn {type, migrations} -> {type, [{opt, migrations}]} end)
  end

  @spec migration_to_atom(String.t(), String.t()) :: atom()
  defp migration_to_atom(type, migration) do
    String.to_existing_atom(migration)
  rescue
    ArgumentError -> reraise "unrecognized migration for #{type}: #{migration}", __STACKTRACE__
  end
end
