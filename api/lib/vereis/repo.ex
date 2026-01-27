defmodule Vereis.Repo do
  use Ecto.Repo,
    otp_app: :vereis,
    adapter: Ecto.Adapters.SQLite3
end
