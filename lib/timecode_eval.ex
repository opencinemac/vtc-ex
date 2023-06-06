defmodule Vtc.Timecode.Eval do
  @moduledoc false
  alias Vtc.Framerate
  alias Vtc.Source.Frames
  alias Vtc.Timecode

  @self_alias [:Vtc, :Timecode, :Eval]

  # Escapes variable that the default rate for the eval will be kept in,
  @default_rate_var_ast Macro.var(:default_rate, :vtc_eval)

  @spec eval([at: Framerate.t() | number() | Ratio.t(), ntsc: Framerate.ntsc()], Macro.input()) :: Macro.t()
  def eval(opts, body) do
    body =
      case body do
        [do: body] -> body
        body -> body
      end

    default_rate = Keyword.get(opts, :at, nil)
    ntsc = Keyword.take(opts, [:ntsc])

    setup_default = aliased_func_call(@self_alias, :setup_rate, [], [default_rate, ntsc])
    set_default_var = {:=, [], [@default_rate_var_ast, setup_default]}

    body = Macro.postwalk(body, &replace_ops_ast/1)

    quote do
      with do
        unquote(set_default_var)
        unquote(body)
      end
    end
  end

  @tc_ops %{
    {:+, 2} => :add,
    {:-, 2} => :sub,
    {:==, 2} => :eq?,
    {:<, 2} => :lt?,
    {:<=, 2} => :lte?,
    {:>, 2} => :gt?,
    {:>=, 2} => :gte?,
    {:*, 2} => :mult,
    {:/, 2} => :div,
    {:%, 2} => :rem,
    {:div, 2} => :div,
    {:divrem, 2} => :divrem,
    {:-, 1} => :minus,
    {:abs, 1} => :abs
  }

  @single_tc_ops [
    {:*, 2},
    {:/, 2},
    {:%, 2},
    {:div, 2},
    {:divrem, 2},
    {:-, 1},
    {:abs, 1}
  ]

  # Replaces operators with calls to a `Timecode` function.
  @spec replace_ops_ast(Macro.t()) :: Macro.t()
  defp replace_ops_ast({op, _, args} = ast) when is_map_key(@tc_ops, {op, length(args)}) do
    tc_func_name = Map.fetch!(@tc_ops, {op, length(args)})
    tc_arg_count = if {op, length(args)} in @single_tc_ops, do: 1, else: 2

    replace_tc_op(tc_func_name, tc_arg_count, ast)
  end

  defp replace_ops_ast(ast), do: ast

  # Replaces ops where both args are timecodes.
  @spec replace_tc_op(atom(), pos_integer(), Macro.t()) :: Macro.t()
  defp replace_tc_op(tc_func_name, tc_arg_count, ast) do
    {_, meta, args} = ast

    args
    |> Enum.with_index()
    |> Enum.map(fn
      {arg_ast, i} when i < tc_arg_count -> wrap_tc_val_in_cast(arg_ast, meta)
      {arg_ast, _} -> arg_ast
    end)
    |> then(&timecode_func(tc_func_name, meta, &1))
  end

  # Wraps timecode args in `cast_timecode_arg/2`.
  @spec wrap_tc_val_in_cast(Macro.t(), Macro.metadata()) :: Macro.t()
  def wrap_tc_val_in_cast({:num, _, [arg]}, _), do: arg

  def wrap_tc_val_in_cast(arg_ast, meta),
    do: aliased_func_call([:Vtc, :Timecode, :Eval], :cast_timecode_arg, meta, [arg_ast, @default_rate_var_ast])

  # Casts `frames` to `default` rate if one was provided, and `frames` is not already
  # a timecode value.
  @doc false
  @spec cast_timecode_arg(Timecode.t() | Frames.t(), Framerate.t() | nil) :: Timecode.t() | Frames.t()
  def cast_timecode_arg(%Timecode{} = timecode, _), do: timecode
  def cast_timecode_arg(frames, nil), do: frames

  def cast_timecode_arg(frames, default_rate) do
    if Frames.impl_for(frames) do
      Timecode.with_frames!(frames, default_rate)
    else
      frames
    end
  end

  # Inserted into the head of each eval block. Sets up the default framerate variable.
  @spec setup_rate(Framerate.t() | number() | Ratio.t() | nil, ntsc: Framerate.ntsc()) :: Framerate.t() | nil
  def setup_rate(nil, _), do: nil
  def setup_rate(%Framerate{} = rate, _), do: rate

  def setup_rate(rate, opts) do
    opts = if is_float(rate), do: Keyword.put_new(opts, :coerce_ntsc?, true), else: opts
    Framerate.new!(rate, opts)
  end

  # Escapes a timecode function name for use in an ast.
  @spec timecode_func(atom(), Macro.metadata(), [Macro.t()]) :: Macro.t()
  defp timecode_func(name, meta, args), do: aliased_func_call([:Vtc, :Timecode], name, meta, args)

  # Constructs the AST for an alias + function call.
  @spec aliased_func_call([atom()], atom(), Macro.metadata(), [Macro.t()]) :: Macro.t()
  defp aliased_func_call(aliases, func_name, meta, args) do
    func_call = {:., meta, [{:__aliases__, meta, aliases}, func_name]}
    {func_call, meta, args}
  end
end
