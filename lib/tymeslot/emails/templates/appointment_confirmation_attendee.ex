defmodule Tymeslot.Emails.Templates.AppointmentConfirmationAttendee do
  @moduledoc """
  Email module for sending appointment confirmations to the attendee (person booking).
  """

  import Swoosh.Email
  alias Tymeslot.Integrations.Calendar.IcsGenerator

  alias Tymeslot.Emails.Shared.{
    Components,
    MjmlEmail,
    SharedHelpers,
    TemplateHelper,
    TextBodyHelper
  }

  @spec confirmation_email(String.t(), map()) :: Swoosh.Email.t()
  def confirmation_email(attendee_email, appointment_details) do
    meeting_details = %{
      date: appointment_details.date,
      start_time: appointment_details.start_time_attendee_tz,
      duration: appointment_details.duration,
      location: appointment_details.location,
      meeting_type: appointment_details.meeting_type,
      video_url: appointment_details.attendee_video_url,
      video_url_role: "attendee"
    }

    mjml_content = """
    #{Components.title_section("Appointment Confirmed!",
    emoji: "✓",
    subtitle: "Hi #{appointment_details.attendee_name}, I'm looking forward to our meeting. I've blocked the time on my calendar and will be ready for you.",
    align: "left")}

    #{Components.meeting_details_table(meeting_details)}

    #{if appointment_details.attendee_video_url do
      Components.video_meeting_section(appointment_details.attendee_video_url,
      style: :confirmation,
      title: "Ready to Join?",
      button_text: "Join Video Meeting")
    end}

    #{Components.section_title("Need to make changes?")}

    #{Components.meeting_actions_bar([%{text: "Reschedule", url: appointment_details.reschedule_url, style: :secondary}, %{text: "Cancel Appointment", url: appointment_details.cancel_url, style: :danger}])}

    #{if appointment_details.organizer_contact_info do
      Components.centered_text("Questions? #{appointment_details.organizer_contact_info}", font_size: "15px", padding: "12px 0 8px 0")
    end}

    #{if appointment_details.reminders_summary do
      Components.alert_box("info", appointment_details.reminders_summary, icon: "⏰", title: "Reminders Scheduled")
    end}
    """

    organizer_details = TemplateHelper.build_organizer_details(appointment_details)
    html_body = TemplateHelper.compile_template(mjml_content, organizer_details)

    MjmlEmail.base_email()
    |> to({appointment_details.attendee_name, attendee_email})
    |> subject(
      "Appointment Confirmed - #{SharedHelpers.format_date_short(appointment_details.date)} with #{appointment_details.organizer_name}"
    )
    |> html_body(html_body)
    |> text_body(text_body(appointment_details))
    |> attachment(
      IcsGenerator.generate_ics_attachment(
        appointment_details,
        "appointment-#{appointment_details.uid}.ics"
      )
    )
  end

  defp text_body(appointment_details) do
    meeting_details = TextBodyHelper.format_meeting_details(appointment_details)
    video_section = TextBodyHelper.format_video_section(appointment_details.attendee_video_url)
    action_links = TextBodyHelper.format_action_links(appointment_details)

    """
    Appointment Confirmed!

    Hi #{appointment_details.attendee_name},

    I'm looking forward to our meeting. I've blocked the time on my calendar and will be ready for you.

    MEETING DETAILS:
    #{meeting_details}#{video_section}
    #{action_links}
    #{if appointment_details.organizer_contact_info, do: "\nQUESTIONS?\n#{appointment_details.organizer_contact_info}\n"}
    #{if appointment_details.reminders_summary, do: "\n#{appointment_details.reminders_summary}\n", else: ""}

    Looking forward to meeting you!
    #{appointment_details.organizer_name}
    """
  end
end
