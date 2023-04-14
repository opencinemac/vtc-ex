defmodule Vtc.FilmFormat do
  @moduledoc """
  Functions and types for working with physical film data.
  """

  @typedoc """
  Enum like type of supported film formats for Vtc.
  """
  @type t() :: :ff35mm_4perf

  @doc """
  The number of frames a foot of film contains for `format`.
  """
  @spec frames_per_foot(t()) :: pos_integer()
  def frames_per_foot(format)
  def frames_per_foot(:ff35mm_4perf), do: 16
end
