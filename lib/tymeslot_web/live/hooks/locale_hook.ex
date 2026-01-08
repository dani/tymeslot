defmodule TymeslotWeb.Hooks.LocaleHook do
  @moduledoc """
  LiveView hook to handle locale assignment for scheduling pages.
  Ensures the locale is set in Gettext and socket assigns from either
  URL parameters or the session.
  """

  import Phoenix.Component
  alias TymeslotWeb.Themes.Shared.LocaleHandler

  @spec on_mount(atom(), map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:cont, Phoenix.LiveView.Socket.t()}
  def on_mount(:default, params, session, socket) do
    # Priority: 1. URL parameter, 2. Session, 3. Default
    locale =
      params["locale"] ||
      session["locale"] ||
      LocaleHandler.default_locale()

    # Validate locale is supported
    locale = if locale in LocaleHandler.supported_locales(), do: locale, else: LocaleHandler.default_locale()

    # Set for Gettext process dictionary
    Gettext.put_locale(TymeslotWeb.Gettext, locale)

    # Assign to socket
    {:cont, assign(socket, :locale, locale)}
  end
end
