defmodule Tymeslot.Emails.Shared.MjmlEmail do
  @moduledoc """
  Base module for MJML email templates.

  Provides structural design tokens and layout helpers that implement the
  Tymeslot redesign (January 2026).

  ## Layout Structure
  - **Wrapper**: 24px horizontal padding on mobile, 12px gutter.
  - **Container**: 12px border radius, white background.
  - **Header**: 56px circular avatar, bold 20px organizer name.
  - **Content**: 24px - 28px vertical padding for clear hierarchy.
  - **Footer**: 12px bottom radius, subtle gray background, 13px text.

  ## Brand Assets
  - Uses Google Fonts Inter with weights 400-800.
  - Consistent SVG-based default avatars.
  """

  import Swoosh.Email
  alias Tymeslot.Emails.Shared.{SharedHelpers, Styles}

  @doc """
  Compiles MJML template to HTML.
  """
  @spec compile_mjml(String.t()) :: String.t()
  def compile_mjml(mjml_content) do
    case Mjml.to_html(mjml_content) do
      {:ok, html} -> html
      {:error, errors} -> raise "MJML compilation failed: #{inspect(errors)}"
    end
  end

  @doc """
  Creates a base email with common settings.
  """
  @spec base_email() :: Swoosh.Email.t()
  def base_email do
    new()
    |> from({fetch_from_name(), fetch_from_email()})
    |> put_provider_option(:track_opens, true)
    |> put_provider_option(:track_links, "HtmlAndText")
  end

  @doc """
  Gets the from email address.
  """
  @spec fetch_from_email() :: String.t()
  def fetch_from_email do
    get_config_email_setting(:from_email)
  end

  @doc """
  Gets the from name.
  """
  @spec fetch_from_name() :: String.t()
  def fetch_from_name do
    get_config_email_setting(:from_name)
  end

  defp get_config_email_setting(key) do
    case Application.get_env(:tymeslot, :email) do
      config when is_list(config) -> config[key]
      _ -> nil
    end
  end

  @doc """
  Base MJML template with compact, personal design.
  Now accepts optional organizer_details parameter.
  """
  @spec base_mjml_template(String.t(), map() | nil) :: String.t()
  def base_mjml_template(content, organizer_details \\ nil) do
    # Use provided organizer details or fall back to defaults
    organizer_name = organizer_details[:name] || fetch_from_name()
    _organizer_email = organizer_details[:email] || fetch_from_email()

    organizer_avatar_url =
      organizer_details[:avatar_url] || generate_default_avatar_url(organizer_name)

    organizer_title = organizer_details[:title] || "Tymeslot"

    """
    <mjml>
      <mj-head>
        <mj-title>Appointment with #{organizer_name}</mj-title>
        <mj-font name="Inter" href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" />
        <mj-preview>Message from #{organizer_name}</mj-preview>
        #{Styles.mjml_base_attributes()}
        <mj-breakpoint width="480px" />
        #{Styles.email_css_styles()}
      </mj-head>
      <mj-body background-color="#fafafa">
        <mj-wrapper padding="24px 12px" background-color="#fafafa">
          <!-- Main Container -->
          <mj-section background-color="#ffffff" border-radius="12px" padding="0">
            <mj-column>
              <!-- Personal Header with native MJML responsiveness -->
              <mj-section padding="24px 24px 20px 24px">
                <mj-group>
                  <mj-column width="20%" vertical-align="middle">
                    <mj-image
                      src="#{organizer_avatar_url}"
                      width="56px"
                      height="56px"
                      border-radius="28px"
                      alt="#{organizer_name}"
                      align="center"
                    />
                  </mj-column>
                  <mj-column width="80%" vertical-align="middle">
                    <mj-text
                      font-size="20px"
                      font-weight="700"
                      padding="0 0 4px 0"
                      align="left"
                      line-height="26px"
                    >
                      #{organizer_name}
                    </mj-text>
                    <mj-text
                      font-size="14px"
                      color="#52525b"
                      padding="0"
                      align="left"
                      line-height="20px"
                    >
                      #{organizer_title}
                    </mj-text>
                  </mj-column>
                </mj-group>
              </mj-section>

              <mj-divider
                padding="0 24px"
                border-color="#e4e4e7"
                border-width="1px"
              />

              <!-- Content Section -->
              <mj-section padding="24px 24px 28px 24px">
                <mj-column>
                  #{content}
                </mj-column>
              </mj-section>

              <!-- Footer -->
              <mj-section
                background-color="#fafafa"
                border-radius="0 0 12px 12px"
                padding="16px 24px"
                border-top="1px solid #e4e4e7"
              >
                <mj-column>
                  <mj-text
                    color="#71717a"
                    font-size="13px"
                    align="center"
                    line-height="18px"
                  >
                    Sent by <a href="#{SharedHelpers.get_app_url()}" style="color: #14b8a6; text-decoration: none; font-weight: 600;">Tymeslot</a>
                  </mj-text>
                </mj-column>
              </mj-section>
            </mj-column>
          </mj-section>
        </mj-wrapper>
      </mj-body>
    </mjml>
    """
  end

  @spec generate_default_avatar_url(String.t()) :: String.t()
  defp generate_default_avatar_url(name) do
    # Generate a simple data URI for a default avatar
    initials = name |> String.split() |> Enum.map_join("", &String.first/1) |> String.upcase()

    svg = """
    <svg width="50" height="50" viewBox="0 0 50 50" xmlns="http://www.w3.org/2000/svg">
      <circle cx="25" cy="25" r="25" fill="#14b8a6"/>
      <text x="25" y="30" text-anchor="middle" font-family="sans-serif" font-size="20" font-weight="600" fill="white">#{initials}</text>
    </svg>
    """

    encoded = Base.encode64(svg)
    "data:image/svg+xml;base64,#{encoded}"
  end
end
