defmodule TymeslotWeb.Live.Dashboard.EmbedSettings.Helpers do
  @moduledoc """
  Helper functions for the embed settings dashboard.
  """

  @doc """
  Generates the embed code snippet for a given type.
  """
  def embed_code("inline", %{username: username, base_url: base_url}) do
    username = escape(username)
    base_url = escape(base_url)

    """
    <div id="tymeslot-booking" data-username="#{username}"></div>
    <script src="#{base_url}/embed.js"></script>
    """
    |> String.trim()
  end

  def embed_code("popup", %{username: username, base_url: base_url}) do
    username = escape(username)
    base_url = escape(base_url)

    """
    <button onclick="TymeslotBooking.open('#{username}')">Book a Meeting</button>
    <script src="#{base_url}/embed.js"></script>
    """
    |> String.trim()
  end

  def embed_code("link", %{booking_url: booking_url}) do
    booking_url = escape(booking_url)

    """
    <a href="#{booking_url}">Schedule a meeting</a>
    """
    |> String.trim()
  end

  def embed_code("floating", %{username: username, base_url: base_url}) do
    username = escape(username)
    base_url = escape(base_url)

    """
    <script src="#{base_url}/embed.js"></script>
    <script>
      TymeslotBooking.initFloating('#{username}');
    </script>
    """
    |> String.trim()
  end

  def embed_code(_, _), do: ""

  defp escape(nil), do: ""
  defp escape(val), do: val |> Phoenix.HTML.html_escape() |> Phoenix.HTML.safe_to_string()
end
