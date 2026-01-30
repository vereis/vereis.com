defmodule VereisWeb.Router do
  use VereisWeb, :router

  alias VereisWeb.GraphQL.Schema

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/" do
    pipe_through :api
    forward "/graphql", Absinthe.Plug, schema: Schema

    if Mix.env() == :dev do
      forward "/graphiql", Absinthe.Plug.GraphiQL,
        schema: Schema,
        interface: :playground
    end
  end

  scope "/api", VereisWeb do
    pipe_through :api
  end

  scope "/assets", VereisWeb do
    pipe_through :api
    get "/*slug", AssetController, :show
  end

  get "/livez", VereisWeb.ServiceController, :liveness
  get "/healthz", VereisWeb.ServiceController, :readiness
  get "/version", VereisWeb.ServiceController, :version

  if Application.compile_env(:vereis, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]
      live_dashboard "/dashboard", metrics: VereisWeb.Telemetry
    end
  end
end
