defmodule Vtc.Test.Support.Repo do
  use Ecto.Repo,
    otp_app: :vtc,
    adapter: Ecto.Adapters.Postgres
end
