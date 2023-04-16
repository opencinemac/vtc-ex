defmodule Vtc.Rates do
  @moduledoc """
  Pre-defined framerates commonly found in the wild.
  """

  alias Vtc.Framerate

  @doc section: :consts
  @doc """
  23.98 NTSC, non-drop.
  """
  @spec f23_98 :: Framerate.t()
  def f23_98, do: Framerate.new!(Ratio.new(24_000, 1001))

  @doc section: :consts
  @doc """
  24 fps.
  """
  @spec f24 :: Framerate.t()
  def f24, do: Framerate.new!(24, ntsc: nil)

  @doc section: :consts
  @doc """
  29.97 NTSC, non-drop.
  """
  @spec f29_97_ndf :: Framerate.t()
  def f29_97_ndf, do: Framerate.new!(Ratio.new(30_000, 1001))

  @doc section: :consts
  @doc """
  29.97 NTSC, drop-frame.
  """
  @spec f29_97_df :: Framerate.t()
  def f29_97_df, do: Framerate.new!(Ratio.new(30_000, 1001), ntsc: :drop)

  @doc section: :consts
  @doc """
  30 fps.
  """
  @spec f30 :: Framerate.t()
  def f30, do: Framerate.new!(30, ntsc: nil)

  @doc section: :consts
  @doc """
  47.95 NTSC non-drop.
  """
  @spec f47_95 :: Framerate.t()
  def f47_95, do: Framerate.new!(Ratio.new(48_000, 1001))

  @doc section: :consts
  @doc """
  48 fps.
  """
  @spec f48 :: Framerate.t()
  def f48, do: Framerate.new!(48, ntsc: nil)

  @doc section: :consts
  @doc """
  59.94 NTSC non-drop.
  """
  @spec f59_94_ndf :: Framerate.t()
  def f59_94_ndf, do: Framerate.new!(Ratio.new(60_000, 1001))

  @doc section: :consts
  @doc """
  59.94 NTSC drop-frame.
  """
  @spec f59_94_df :: Framerate.t()
  def f59_94_df, do: Framerate.new!(Ratio.new(60_000, 1001), ntsc: :drop)

  @doc section: :consts
  @doc """
  60 fps.
  """
  @spec f60 :: Framerate.t()
  def f60, do: Framerate.new!(60, ntsc: nil)
end
