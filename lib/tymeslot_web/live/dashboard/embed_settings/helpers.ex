defmodule TymeslotWeb.Live.Dashboard.EmbedSettings.Helpers do
  @moduledoc """
  Helper functions for the embed settings dashboard.
  """

  alias Phoenix.HTML

  @doc """
  Generates the embed code snippet for a given type.
  """
  @spec embed_code(String.t(), map()) :: String.t()
  def embed_code("inline", %{username: username, base_url: base_url}) do
    username = escape(username)
    base_url = escape(base_url)

    String.trim("""
    <div id="tymeslot-booking" data-username="#{username}"></div>
    <script src="#{base_url}/embed.js"></script>
    """)
  end

  @spec embed_code(String.t(), map()) :: String.t()
  def embed_code("popup", %{username: username, base_url: base_url}) do
    username = escape(username)
    base_url = escape(base_url)

    String.trim("""
    <button onclick="TymeslotBooking.open('#{username}')">Book a Meeting</button>
    <script src="#{base_url}/embed.js"></script>
    """)
  end

  @spec embed_code(String.t(), map()) :: String.t()
  def embed_code("link", %{booking_url: booking_url}) do
    booking_url = escape(booking_url)

    String.trim("""
    <a href="#{booking_url}">Schedule a meeting</a>
    """)
  end

  @spec embed_code(String.t(), map()) :: String.t()
  def embed_code("floating", %{username: username, base_url: base_url}) do
    username = escape(username)
    base_url = escape(base_url)

    String.trim("""
    <script src="#{base_url}/embed.js"></script>
    <script>
      TymeslotBooking.initFloating('#{username}');
    </script>
    """)
  end

  @spec embed_code(any(), any()) :: String.t()
  def embed_code(_, _), do: ""

  defp escape(nil), do: ""
  defp escape(val), do: val |> HTML.html_escape() |> HTML.safe_to_string()
end
