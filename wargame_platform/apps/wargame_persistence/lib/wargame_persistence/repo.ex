defmodule WargamePersistence.Repo do
  use Ecto.Repo,
    otp_app: :wargame_persistence,
    adapter: Ecto.Adapters.Postgres
end
