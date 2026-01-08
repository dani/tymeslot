defmodule TymeslotWeb.Plugs.SecurityHeadersPlug do
  @moduledoc """
  Adds comprehensive security headers to all responses.
  Supports domain whitelisting for embedding via the profile's allowed_embed_domains field.
  """

  import Plug.Conn

  require Logger
  alias Tymeslot.DatabaseQueries.ProfileQueries

  @spec init(keyword()) :: keyword()
  def init(opts), do: opts

  @spec call(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def call(conn, opts) do
    allow_embedding = Keyword.get(opts, :allow_embedding, false)

    # Determine frame-ancestors based on the profile's allowed domains
    {frame_ancestors, x_frame_options} =
      if allow_embedding do
        get_embed_security_headers(conn)
      else
        {"'none'", "DENY"}
      end

    conn
    |> put_resp_header("content-security-policy", csp_header(frame_ancestors))
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> put_resp_header("permissions-policy", permissions_policy())
    |> put_resp_header("strict-transport-security", "max-age=31536000; includeSubDomains")
    |> put_resp_header("x-xss-protection", "1; mode=block")
    |> put_resp_header("expect-ct", "max-age=86400, enforce")
    |> put_resp_header("x-frame-options", x_frame_options)
  end

  # Extracts username from path and retrieves allowed embed domains
  # Returns {frame_ancestors, x_frame_options}
  defp get_embed_security_headers(conn) do
    username = extract_username_from_path(conn.request_path)

    case username do
      nil ->
        # No username in path, allow all (e.g., for demo routes)
        Logger.debug("No username in path, allowing all embeds", path: conn.request_path)
        {"'self' *", "ALLOWALL"}

      username ->
        case ProfileQueries.get_by_username(username) do
          {:ok, profile} ->
            {frame_ancestors, x_frame_options} =
              build_security_headers(profile.allowed_embed_domains)

            # Log when embedding is restricted
            if profile.allowed_embed_domains != nil and length(profile.allowed_embed_domains) > 0 do
              referer = List.first(get_req_header(conn, "referer"))
              Logger.info("Embed security restrictions applied",
                username: username,
                profile_id: profile.id,
                allowed_domains: inspect(profile.allowed_embed_domains),
                referer: referer
              )
            end

            {frame_ancestors, x_frame_options}

          {:error, :not_found} ->
            # Profile not found, default to permissive
            Logger.warning("Profile not found for username, allowing all embeds",
              username: username,
              path: conn.request_path
            )

            {"'self' *", "ALLOWALL"}
        end
    end
  end

  # Extracts username from scheduling paths like /:username or /:username/...
  defp extract_username_from_path(path) do
    # List of reserved paths that can't be usernames
    reserved_paths = [
      "",
      "auth",
      "dashboard",
      "api",
      "dev",
      "assets",
      "docs",
      "admin",
      "healthcheck",
      "robots.txt",
      "favicon.ico",
      "embed.js"
    ]

    case String.split(path, "/", parts: 3) do
      ["", username | _] ->
        if username in reserved_paths, do: nil, else: username

      _ ->
        nil
    end
  end

  # Builds the security headers based on allowed domains
  # Returns {frame_ancestors, x_frame_options}
  defp build_security_headers([]), do: {"'self' *", "ALLOWALL"}

  defp build_security_headers(nil), do: {"'self' *", "ALLOWALL"}

  defp build_security_headers(allowed_domains) when is_list(allowed_domains) do
    # Build CSP frame-ancestors with HTTPS URLs
    domains = Enum.map_join(allowed_domains, " ", &"https://#{&1}")

    frame_ancestors = "'self' #{domains}"

    # Build X-Frame-Options ALLOW-FROM for the first domain
    # Note: ALLOW-FROM is deprecated but provides defense-in-depth for older browsers
    x_frame_options =
      case allowed_domains do
        [first_domain | _] -> "ALLOW-FROM https://#{first_domain}"
        [] -> "ALLOWALL"
      end

    {frame_ancestors, x_frame_options}
  end

  defp csp_header(frame_ancestors) do
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
        "frame-ancestors #{frame_ancestors}",
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
