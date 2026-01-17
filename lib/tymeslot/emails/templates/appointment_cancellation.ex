defmodule Tymeslot.Emails.Templates.AppointmentCancellation do
  @moduledoc """
  Email module for sending appointment cancellation notifications.
  """

  import Swoosh.Email

  alias Tymeslot.Emails.Shared.{
    Components,
    MjmlEmail,
    SharedHelpers,
    TemplateHelper,
    TextBodyHelper
  }

  @spec cancellation_email_attendee(String.t(), map()) :: Swoosh.Email.t()
  def cancellation_email_attendee(attendee_email, appointment_details) do
    mjml_content = """
    #{Components.alert_box("error",
    "Hi #{appointment_details.attendee_name}, I wanted to let you know that our appointment has been cancelled.",
    icon: "✕",
    title: "Meeting Cancelled")}

    #{Components.section_title("Meeting with #{appointment_details.organizer_name}", padding: "24px 0 16px 0")}

    #{Components.meeting_details_table(%{date: appointment_details.date, start_time: appointment_details.start_time, duration: appointment_details.duration, location: appointment_details.location, meeting_type: appointment_details.meeting_type})}

    #{Components.centered_text("Would you like to schedule a new appointment?", padding: "24px 0 8px 0")}
    #{Components.action_button("Schedule New Appointment", SharedHelpers.get_app_url(), color: "primary", full_width: true)}

    #{Components.system_footer_note("This time slot is now available for booking again.")}
    #{Components.system_footer_note("If you have any questions, please don't hesitate to reach out.")}
    """

    organizer_details = TemplateHelper.build_organizer_details(appointment_details)
    html_body = TemplateHelper.compile_template(mjml_content, organizer_details)

    MjmlEmail.base_email()
    |> to({appointment_details.attendee_name, attendee_email})
    |> subject(
      "Meeting Cancelled - #{SharedHelpers.format_date_short(appointment_details.date)} with #{appointment_details.organizer_name}"
    )
    |> html_body(html_body)
    |> text_body(text_body_attendee(appointment_details))
  end

  @spec cancellation_email_organizer(String.t(), map()) :: Swoosh.Email.t()
  def cancellation_email_organizer(organizer_email, appointment_details) do
    mjml_content = """
    #{Components.alert_box("error",
    "The appointment with #{appointment_details.attendee_name} has been cancelled.",
    icon: "✕",
    title: "Meeting Cancelled")}

    #{Components.section_title("Meeting with #{appointment_details.attendee_name}", padding: "24px 0 16px 0")}

    #{Components.meeting_details_table(%{date: appointment_details.date, start_time: appointment_details.start_time_owner_tz, duration: appointment_details.duration, location: appointment_details.location, meeting_type: appointment_details.meeting_type})}

    #{Components.system_footer_note("Your calendar has been updated to reflect this cancellation.")}
    #{Components.system_footer_note("The attendee has been notified of the cancellation.")}
    """

    organizer_details = TemplateHelper.build_organizer_details(appointment_details)
    html_body = TemplateHelper.compile_template(mjml_content, organizer_details)

    MjmlEmail.base_email()
    |> to({appointment_details.organizer_name, organizer_email})
    |> subject(
      "Meeting Cancelled - #{SharedHelpers.format_date_short(appointment_details.date)} with #{appointment_details.attendee_name}"
    )
    |> html_body(html_body)
    |> text_body(text_body_organizer(appointment_details))
  end

  defp text_body_attendee(appointment_details) do
    meeting_details = TextBodyHelper.format_meeting_details(appointment_details)

    """
    Meeting Cancelled

    Hi #{appointment_details.attendee_name},

    We're writing to confirm that your appointment has been cancelled.

    CANCELLED APPOINTMENT DETAILS:
    Meeting with: #{appointment_details.organizer_name}
    #{meeting_details}

    This time slot is now available for booking again.

    Would you like to schedule a new appointment?
    Visit: #{SharedHelpers.get_app_url()}

    If you have any questions, please don't hesitate to reach out.
    """
  end

  defp text_body_organizer(appointment_details) do
    meeting_details = TextBodyHelper.format_meeting_details(appointment_details)
    attendee_info = TextBodyHelper.format_attendee_info(appointment_details)

    """
    Meeting Cancelled

    The appointment with #{appointment_details.attendee_name} has been cancelled.

    CANCELLED APPOINTMENT DETAILS:
    #{meeting_details}#{attendee_info}

    Your calendar has been updated to reflect this cancellation.
    The attendee has been notified of the cancellation.
    """
  end
end
