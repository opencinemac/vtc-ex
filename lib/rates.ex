defmodule Vtc.Rates do
  @moduledoc """
  Pre-defined framerates commonly used in the wild.
  """

  alias Vtc.Framerate

  @doc """
  23.98 NTSC Non-drop
  """
  @spec f23_98 :: Framerate.t()
  def f23_98, do: Framerate.new!(24, :NonDrop)

  @doc """
  24 fps
  """
  @spec f24 :: Framerate.t()
  def f24, do: Framerate.new!(24, :None)

  @doc """
  29.97 NTSC Non-drop
  """
  @spec f29_97_ndf :: Framerate.t()
  def f29_97_ndf, do: Framerate.new!(30, :NonDrop)

  @doc """
  29.97 NTSC Drop-frame
  """
  @spec f29_97_df :: Framerate.t()
  def f29_97_df, do: Framerate.new!(30, :Drop)

  @doc """
  30 fps
  """
  @spec f30 :: Framerate.t()
  def f30, do: Framerate.new!(30, :None)

  @doc """
  47.95 NTSC Non-drop
  """
  @spec f47_95 :: Framerate.t()
  def f47_95, do: Framerate.new!(48, :NonDrop)

  @doc """
  48 fps
  """
  @spec f48 :: Framerate.t()
  def f48, do: Framerate.new!(48, :None)

  @doc """
  59.94 NTSC Non-drop
  """
  @spec f59_94_ndf :: Framerate.t()
  def f59_94_ndf, do: Framerate.new!(60, :NonDrop)

  @doc """
  59.94 NTSC Drop-frame
  """
  @spec f59_94_df :: Framerate.t()
  def f59_94_df, do: Framerate.new!(60, :Drop)

  @doc """
  60 fps
  """
  @spec f60 :: Framerate.t()
  def f60, do: Framerate.new!(60, :None)
end
