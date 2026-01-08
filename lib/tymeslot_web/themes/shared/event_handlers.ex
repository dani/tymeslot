defmodule TymeslotWeb.Themes.Shared.EventHandlers do
  @moduledoc """
  Shared event handlers for theme scheduling LiveViews.
  """
  import Phoenix.Component, only: [assign: 3]

  @doc """
  Handles toggling the language dropdown.
  """
  @spec handle_toggle_language_dropdown(Phoenix.LiveView.Socket.t()) :: {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_toggle_language_dropdown(socket) do
    {:noreply, assign(socket, :language_dropdown_open, !socket.assigns.language_dropdown_open)}
  end

  @doc """
  Handles closing the language dropdown.
  """
  @spec handle_close_language_dropdown(Phoenix.LiveView.Socket.t()) :: {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_close_language_dropdown(socket) do
    {:noreply, assign(socket, :language_dropdown_open, false)}
  end

  @doc """
  Handles locale change with push_navigate for reliability.
  """
  @spec handle_change_locale(Phoenix.LiveView.Socket.t(), String.t(), module()) :: {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_change_locale(socket, locale, path_handlers_module) do
    path = path_handlers_module.build_path_with_locale(socket, locale)
    {:noreply, Phoenix.LiveView.push_navigate(socket, to: path)}
  end

  @doc """
  Handles common timezone change logic.
  """
  @spec handle_timezone_change(Phoenix.LiveView.Socket.t(), map(), module()) :: {:noreply, Phoenix.LiveView.Socket.t()}
  def handle_timezone_change(socket, data, timezone_handler_module) do
    case timezone_handler_module.handle_timezone_change(socket, data) do
      {:ok, updated_socket} -> {:noreply, updated_socket}
    end
  end
end
