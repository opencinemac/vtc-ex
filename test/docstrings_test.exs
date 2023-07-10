defmodule Vtc.DocsTest do
  @moduledoc false

  use Vtc.Test.Support.EctoCase, async: true

  alias Ecto.Query
  alias Vtc.Framerate
  alias Vtc.Framestamp
  alias Vtc.Framestamp.Range
  alias Vtc.Rates
  alias Vtc.Source

  require Query

  doctest Range
  doctest Framerate
  doctest Framestamp
  doctest Source.Frames.FeetAndFrames
  doctest Vtc.Ecto.Postgres.PgFramestamp.Migrations
end
