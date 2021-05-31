defmodule Vtc.Rate do
  @moduledoc """
  Pre-defined framerates commonly used in the wild.
  """

  @doc """
  23.98 NTSC Non-drop
  """
  def f23_98() do
    Vtc.Framerate.new!(24, :NonDrop)
  end

  @doc """
  24 fps
  """
  def f24() do
    Vtc.Framerate.new!(24, :None)
  end

  @doc """
  29.97 NTSC Non-drop
  """
  def f29_97_Ndf() do
    Vtc.Framerate.new!(30, :NonDrop)
  end

  @doc """
  29.97 NTSC Drop-frame
  """
  def f29_97_Df() do
    Vtc.Framerate.new!(30, :Drop)
  end

  @doc """
  30 fps
  """
  def f30() do
    Vtc.Framerate.new!(30, :None)
  end

  @doc """
  47.95 NTSC Non-drop
  """
  def f47_95() do
    Vtc.Framerate.new!(48, :NonDrop)
  end

  @doc """
  48 fps
  """
  def f48() do
    Vtc.Framerate.new!(48, :None)
  end

  @doc """
  59.94 NTSC Non-drop
  """
  def f59_94_Ndf() do
    Vtc.Framerate.new!(60, :NonDrop)
  end

  @doc """
  59.94 NTSC Drop-frame
  """
  def f59_94_Df() do
    Vtc.Framerate.new!(60, :Drop)
  end

  @doc """
  60 fps
  """
  def f60() do
    Vtc.Framerate.new!(60, :None)
  end
end
