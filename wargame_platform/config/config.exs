# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Ecto Repo configuration
config :wargame_persistence,
  ecto_repos: [WargamePersistence.Repo]

config :wargame_persistence, WargamePersistence.Repo,
  database: "wargame_platform_dev",
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  port: 5432,
  pool_size: 10

config :wargame_web,
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :wargame_web, WargameWebWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: WargameWebWeb.ErrorHTML, json: WargameWebWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: WargameWeb.PubSub,
  live_view: [signing_salt: "S+TdJYGr"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  wargame_web: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=. --loader:.ts=ts --loader:.tsx=tsx),
    cd: Path.expand("../apps/wargame_web/assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Path.expand("../apps/wargame_web/assets/node_modules", __DIR__), Mix.Project.build_path()]}
  ],
  wargame_engine: [
    args:
      ~w(ts/index.ts --bundle --target=es2022 --outdir=../priv/static/assets/js --format=esm --loader:.ts=ts --loader:.tsx=tsx),
    cd: Path.expand("../apps/wargame_web/assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../apps/wargame_web/assets/node_modules", __DIR__)]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  wargame_web: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("../apps/wargame_web", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

# Sample configuration:
#
#     config :logger, :console,
#       level: :info,
#       format: "$date $time [$level] $metadata$message\n",
#       metadata: [:user_id]
#
