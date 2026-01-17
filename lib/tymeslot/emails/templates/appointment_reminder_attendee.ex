defmodule Tymeslot.Emails.Templates.AppointmentReminderAttendee do
  @moduledoc """
  Email module for sending appointment reminders to the attendee.
  """

  import Swoosh.Email

  alias Tymeslot.Emails.Shared.{
    Components,
    MjmlEmail,
    SharedHelpers,
    Styles,
    TemplateHelper,
    TextBodyHelper
  }

  @spec reminder_email(String.t(), map()) :: Swoosh.Email.t()
  def reminder_email(attendee_email, appointment_details) do
    mjml_content = """
    #{Components.time_alert_badge(appointment_details.time_until, icon: "⏰", color: :blue)}

    #{Components.title_section("Our meeting is coming up!",
    emoji: "📅",
    align: "center")}

    <mj-section padding="0 0 12px 0">
      <mj-column>
        <mj-text
          font-size="18px"
          font-weight="600"
          color="#{Styles.text_color(:primary)}"
          align="center"
          padding="0 0 4px 0"
          line-height="1.4"
          css-class="mobile-text"
        >
          #{SharedHelpers.format_date_short(appointment_details.date)}
        </mj-text>
        <mj-text
          font-size="16px"
          color="#{Styles.text_color(:secondary)}"
          align="center"
          padding="0"
          css-class="mobile-text"
        >
          #{Calendar.strftime(appointment_details.start_time_attendee_tz, "%I:%M %p")} #{appointment_details.attendee_timezone}
        </mj-text>
      </mj-column>
    </mj-section>

    #{Components.quick_info_grid([%{label: "Duration", value: "#{appointment_details.duration} min"}, %{label: "Location", value: appointment_details.location || "Virtual"}])}

    #{if Map.get(appointment_details, :meeting_url) do
      Components.video_meeting_section(appointment_details.meeting_url,
      style: :reminder,
      title: "Join When Ready",
      button_text: "Join Meeting")
    end}

    <mj-section padding="8px 0">
      <mj-column>
        <mj-text
          font-size="13px"
          color="#{Styles.text_color(:secondary)}"
          align="center"
          padding="0 0 8px 0"
          css-class="mobile-text"
        >
          Need to change plans?
        </mj-text>
      </mj-column>
    </mj-section>

    #{Components.meeting_actions_bar([%{text: "Reschedule", url: appointment_details.reschedule_url, style: :secondary}, %{text: "Cancel", url: appointment_details.cancel_url, style: :danger}])}

    <mj-section padding="12px 0 0 0">
      <mj-column>
        <mj-text
          align="center"
          font-size="15px"
          color="#{Styles.text_color(:dark)}"
          line-height="1.5"
          css-class="mobile-text"
        >
          I'm looking forward to our conversation!
        </mj-text>
        <mj-text
          align="center"
          font-size="14px"
          color="#{Styles.text_color(:secondary)}"
          padding-top="8px"
          css-class="mobile-text"
        >
          See you #{appointment_details.time_until_friendly || "soon"}!
        </mj-text>
      </mj-column>
    </mj-section>
    """

    organizer_details = TemplateHelper.build_organizer_details(appointment_details)
    html_body = TemplateHelper.compile_template(mjml_content, organizer_details)

    MjmlEmail.base_email()
    |> to({appointment_details.attendee_name, attendee_email})
    |> subject("Reminder: Our meeting is #{appointment_details.time_until}")
    |> html_body(html_body)
    |> text_body(text_body(appointment_details))
  end

  defp text_body(appointment_details) do
    meeting_details = TextBodyHelper.format_meeting_details(appointment_details)
    video_section = TextBodyHelper.format_video_section(appointment_details.meeting_url)
    action_links = TextBodyHelper.format_action_links(appointment_details)

    """
    REMINDER: Our meeting in #{appointment_details.time_until}

    Hi #{appointment_details.attendee_name},

    I'm looking forward to our conversation!

    DETAILS:
    #{meeting_details}#{video_section}
    Need to change plans?#{action_links}

    See you #{appointment_details.time_until_friendly || "soon"}!

    Best,
    #{appointment_details.organizer_name}
    """
  end
end
