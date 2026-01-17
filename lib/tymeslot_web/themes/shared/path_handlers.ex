defmodule TymeslotWeb.Themes.Shared.PathHandlers do
  @moduledoc """
  Shared path building logic for theme scheduling LiveViews.
  """

  @doc """
  Builds a path with locale and theme query parameters.
  """
  @spec build_path_with_locale(Phoenix.LiveView.Socket.t(), String.t()) :: String.t()
  def build_path_with_locale(socket, locale) do
    base_path = get_base_path(socket)
    query_params = build_query_params(socket, locale)
    query_string = URI.encode_query(query_params)
    "#{base_path}?#{query_string}"
  end

  defp get_base_path(socket) do
    username = socket.assigns[:username_context]

    if is_nil(username) do
      "/"
    else
      do_get_base_path(socket.assigns[:live_action], username, socket)
    end
  end

  defp do_get_base_path(:overview, username, _socket), do: "/#{username}"

  defp do_get_base_path(:schedule, username, socket) do
    slug =
      socket.assigns[:duration] || socket.assigns[:selected_duration]
      |> Tymeslot.MeetingTypes.normalize_duration_slug()

    if slug, do: "/#{username}/#{slug}", else: "/#{username}"
  end

  defp do_get_base_path(:booking, username, socket) do
    slug =
      socket.assigns[:duration] || socket.assigns[:selected_duration]
      |> Tymeslot.MeetingTypes.normalize_duration_slug()

    if slug, do: "/#{username}/#{slug}/book", else: "/#{username}"
  end

  defp do_get_base_path(:confirmation, username, _socket), do: "/#{username}/thank-you"
  defp do_get_base_path(_, username, _socket), do: "/#{username}"

  defp build_query_params(socket, locale) do
    slug =
      socket.assigns[:duration] || socket.assigns[:selected_duration]
      |> Tymeslot.MeetingTypes.normalize_duration_slug()

    %{"locale" => locale}
    |> maybe_put_query_param("theme", socket.assigns[:theme_id])
    |> maybe_put_query_param("slug", slug)
  end

  defp maybe_put_query_param(params, _key, nil), do: params
  defp maybe_put_query_param(params, key, value), do: Map.put(params, key, value)
end
