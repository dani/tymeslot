defmodule TymeslotWeb.Themes.Shared.LocaleHandler do
  @moduledoc """
  Shared locale handling for scheduling LiveViews.
  Provides functions for managing locale in LiveView context.
  """

  @doc """
  Assigns the current locale to the socket from the connection assigns.
  Sets the locale in Gettext for the current process.
  """
  def assign_locale(socket) do
    locale = socket.assigns[:locale] || default_locale()
    Gettext.put_locale(TymeslotWeb.Gettext, locale)
    Phoenix.Component.assign(socket, :locale, locale)
  end

  @doc """
  Changes the locale for the current socket.
  Validates that the new locale is supported before applying the change.

  The locale is applied to the current LiveView session. For session persistence
  across navigation, the locale should be included in URL params (via push_patch)
  which will be picked up by LocalePlug on subsequent page loads.

  Changes are idempotent to avoid unnecessary updates.
  """
  def handle_locale_change(socket, new_locale) do
    current_locale = socket.assigns[:locale]

    # Skip if locale is already set (idempotent)
    cond do
      new_locale == current_locale ->
        socket

      new_locale in supported_locales() ->
        # Update Gettext for current process
        Gettext.put_locale(TymeslotWeb.Gettext, new_locale)

        # Update socket assigns
        # Note: For persistence across navigation, themes should push_patch
        # with the locale in query params
        Phoenix.Component.assign(socket, :locale, new_locale)

      true ->
        socket
    end
  end

  @doc """
  Returns the list of supported locale codes.
  """
  def supported_locales do
    Application.get_env(:tymeslot, TymeslotWeb.Gettext)[:locales] || ["en"]
  end

  @doc """
  Returns the full locale metadata including name and country code for UI rendering.
  """
  def get_locales_with_metadata do
    Application.get_env(:tymeslot, :locales)[:supported] || []
  end

  @doc """
  Returns the default locale code.
  """
  def default_locale do
    Application.get_env(:tymeslot, :locales)[:default] || "en"
  end
end
