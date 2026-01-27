defmodule VereisWeb do
  @moduledoc false

  def static_paths do
    ~w(assets fonts images favicon.ico robots.txt)
  end

  def router do
    quote do
      use Phoenix.Router, helpers: false

      import Phoenix.Controller
      import Plug.Conn
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  def controller do
    quote do
      use Phoenix.Controller, formats: [:html, :json]
      use Gettext, backend: VereisWeb.Gettext

      import Plug.Conn

      unquote(verified_routes())
    end
  end

  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: VereisWeb.Endpoint,
        router: VereisWeb.Router,
        statics: VereisWeb.static_paths()
    end
  end

  @doc "When used, dispatch to the appropriate controller/live_view/etc."
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
