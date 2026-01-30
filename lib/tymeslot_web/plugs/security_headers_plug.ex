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

    # Determine frame-ancestors based on the profile's allowed domains.
    # CSP frame-ancestors is the primary source of truth for modern browsers.
    {frame_ancestors, x_frame_options} =
      if allow_embedding do
        get_embed_security_headers(conn)
      else
        {"'none'", "DENY"}
      end

    conn =
      conn
      |> put_resp_header("content-security-policy", csp_header(frame_ancestors))
      |> put_resp_header("x-content-type-options", "nosniff")
      |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
      |> put_resp_header("permissions-policy", permissions_policy())
      |> put_resp_header("strict-transport-security", "max-age=31536000; includeSubDomains")
      |> put_resp_header("x-xss-protection", "1; mode=block")
      |> put_resp_header("expect-ct", "max-age=86400, enforce")

    if x_frame_options do
      put_resp_header(conn, "x-frame-options", x_frame_options)
    else
      # If X-Frame-Options is nil, we omit it to let CSP frame-ancestors
      # be the sole authority for modern browsers.
      conn
    end
  end

  # Extracts username from path and retrieves allowed embed domains
  # Returns {frame_ancestors, x_frame_options | nil}
  defp get_embed_security_headers(conn) do
    username = extract_username_from_path(conn.request_path)

    case username do
      nil ->
        # No username in path, allow all (e.g., for demo routes)
        Logger.debug("No username in path, allowing all embeds", path: conn.request_path)
        {"'self' *", nil}

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

            {"'self' *", nil}
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

  # Builds the security headers based on allowed domains.
  # CSP frame-ancestors is the primary security mechanism for modern browsers.
  # X-Frame-Options is provided as a best-effort fallback for legacy browsers.
  # Returns {frame_ancestors, x_frame_options | nil}
  defp build_security_headers([]), do: {"'self' *", nil}

  defp build_security_headers(nil), do: {"'self' *", nil}
  defp build_security_headers(["none"]), do: {"'none'", "DENY"}

  defp build_security_headers(allowed_domains) when is_list(allowed_domains) do
    # Build CSP frame-ancestors with appropriate protocols.
    # Modern browsers prioritize this over X-Frame-Options.
    domains =
      Enum.map_join(allowed_domains, " ", fn domain ->
        is_local = domain in ["localhost", "127.0.0.1", "::1"]
        is_dev = Application.get_env(:tymeslot, :environment) in [:dev, :test]

        cond do
          is_local and is_dev ->
            "http://#{domain}:*"

          true ->
            "https://#{domain}"
        end
      end)

    frame_ancestors = "'self' #{domains}"

    # X-Frame-Options ALLOW-FROM is deprecated and only supports a single domain.
    # It is provided only for defense-in-depth for legacy browsers (IE, old Firefox).
    # Chrome, Safari, and modern Firefox ignore it.
    x_frame_options =
      case allowed_domains do
        [first_domain | _] ->
          # X-Frame-Options ALLOW-FROM does not support wildcards or multiple domains.
          # Modern browsers use CSP frame-ancestors anyway.
          is_local = first_domain in ["localhost", "127.0.0.1", "::1"]
          is_dev = Application.get_env(:tymeslot, :environment) in [:dev, :test]

          cond do
            String.starts_with?(first_domain, "*") ->
              nil

            is_local and is_dev ->
              "ALLOW-FROM http://#{first_domain}"

            true ->
              "ALLOW-FROM https://#{first_domain}"
          end
      end

    {frame_ancestors, x_frame_options}
  end

  defp csp_header(frame_ancestors) do
    script_src =
      "'self' 'unsafe-inline' 'unsafe-eval' https://www.google.com https://www.gstatic.com https://js.stripe.com"

    connect_src =
      if Application.get_env(:tymeslot, :environment) == :dev do
        "'self' ws://localhost:* ws://127.0.0.1:* http://localhost:* http://127.0.0.1:* ws: wss: https://www.google.com https://accounts.google.com https://api.stripe.com"
      else
        "'self' wss: https://www.google.com https://accounts.google.com https://api.stripe.com"
      end

    Enum.join(
      [
        "default-src 'self'",
        # Phoenix LiveView requires unsafe-inline, reCAPTCHA + Stripe require external domains
        "script-src #{script_src}",
        "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
        "img-src 'self' data: https:",
        "font-src 'self' data: https://fonts.gstatic.com",
        # Allow connections to reCAPTCHA, Google services, and Stripe
        "connect-src #{connect_src}",
        # Allow reCAPTCHA and Stripe frames
        "frame-src 'self' https://www.google.com https://accounts.google.com https://js.stripe.com https://hooks.stripe.com",
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
