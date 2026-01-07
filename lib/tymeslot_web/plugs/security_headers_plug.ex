defmodule TymeslotWeb.Plugs.SecurityHeadersPlug do
  @moduledoc """
  Adds comprehensive security headers to all responses.
  """

  import Plug.Conn

  @spec init(keyword()) :: keyword()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def call(conn, _opts) do
    conn
    |> put_resp_header("content-security-policy", csp_header())
    |> put_resp_header("x-frame-options", "DENY")
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> put_resp_header("permissions-policy", permissions_policy())
    |> put_resp_header("strict-transport-security", "max-age=31536000; includeSubDomains")
    |> put_resp_header("x-xss-protection", "1; mode=block")
    |> put_resp_header("expect-ct", "max-age=86400, enforce")
  end

  defp csp_header do
    script_src =
      "'self' 'unsafe-inline' 'unsafe-eval' https://www.google.com https://www.gstatic.com"

    connect_src = "'self' wss: https://www.google.com https://accounts.google.com"

    Enum.join(
      [
        "default-src 'self'",
        # Phoenix LiveView requires unsafe-inline, reCAPTCHA requires Google domains
        "script-src #{script_src}",
        "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
        "img-src 'self' data: https:",
        "font-src 'self' data: https://fonts.gstatic.com",
        # Allow connections to reCAPTCHA and Google services
        "connect-src #{connect_src}",
        # Allow reCAPTCHA frames from Google
        "frame-src 'self' https://www.google.com https://accounts.google.com",
        "frame-ancestors 'none'",
        "base-uri 'self'",
        "form-action 'self'"
      ],
      "; "
    )
  end

  defp permissions_policy do
    Enum.join(
      [
        "camera=()",
        "microphone=()",
        "geolocation=()"
      ],
      ", "
    )
  end
end
