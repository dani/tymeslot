defmodule Tymeslot.Emails.Shared.ContentComponents do
  @moduledoc """
  Content-related MJML components for email templates.

  Implements design tokens for message containers:
  - **Message Box**: 10px radius, 20px padding, 700 weight for headers.
  - **Typography**: 15px body text with 22px line-height for readability.
  - **Theme**: Uses notification blue theme (#f0f9ff background, #0284c7 border).
  """

  alias Tymeslot.Emails.Shared.{SharedHelpers, Styles}

  @doc """
  Generates an attendee message box if a message is provided.
  """
  @spec attendee_message_box(String.t()) :: String.t()
  def attendee_message_box(message) when is_binary(message) and message != "" do
    sanitized_message = SharedHelpers.sanitize_for_email(message)

    """
    <mj-wrapper padding="16px 0">
      <mj-section
        background-color="#{Styles.notification_color(:bg_blue)}"
        border="1px solid #{Styles.notification_color(:border_blue)}"
        border-radius="10px"
        padding="20px"
      >
        <mj-column>
          <mj-text
            font-size="15px"
            font-weight="700"
            color="#{Styles.notification_color(:text_blue)}"
            padding="0 0 10px 0"
          >
            Message from Attendee
          </mj-text>
          <mj-text
            font-size="15px"
            line-height="22px"
            color="#{Styles.notification_color(:link_blue)}"
          >
            "#{sanitized_message}"
          </mj-text>
        </mj-column>
      </mj-section>
    </mj-wrapper>
    """
  end

  def attendee_message_box(_), do: ""
end
