defmodule TymeslotWeb.Themes.Rhythm.Scheduling.Components.BookingComponent do
  @moduledoc """
  Rhythm theme component for the booking/contact form step.
  Extracted from the monolithic RhythmSlidesComponent to improve separation of concerns.
  """
  use TymeslotWeb, :live_component
  use Gettext, backend: TymeslotWeb.Gettext

  alias Tymeslot.Demo
  alias Tymeslot.Profiles
  alias Tymeslot.Utils.TimezoneUtils
  alias TymeslotWeb.Themes.Shared.LocalizationHelpers

  @impl true
  def update(assigns, socket) do
    filtered_assigns = Map.drop(assigns, [:flash, :socket])

    {:ok,
     socket
     |> assign(filtered_assigns)
     |> assign_new(:attendee_name, fn -> "" end)
     |> assign_new(:attendee_email, fn -> "" end)
     |> assign_new(:attendee_message, fn -> "" end)
     |> assign_new(:validation_errors, fn -> [] end)
     |> assign_new(:submitting, fn -> false end)}
  end

  @impl true
  def handle_event("validate_booking", params, socket) do
    socket =
      socket
      |> assign(:attendee_name, params["name"] || "")
      |> assign(:attendee_email, params["email"] || "")
      |> assign(:attendee_message, params["message"] || "")
      |> assign(:validation_errors, [])

    {:noreply, socket}
  end

  @impl true
  def handle_event("submit_booking", params, socket) do
    # Set submitting state immediately for instant UI feedback
    socket = assign(socket, :submitting, true)
    send(self(), {:step_event, :booking, :submit_booking, params})
    {:noreply, socket}
  end

  @impl true
  def handle_event("prev_slide", _params, socket) do
    send(self(), {:step_event, :booking, :prev_step, %{}})
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="scheduling-box" data-locale={@locale}>
      <div class="slide-container">
        <div class="slide active">
          <div
            class="slide-content booking-slide"
            style="display: flex; flex-direction: column; height: 100%;"
          >
            <!-- Organizer Header -->
            <div class="schedule-header" style="flex-shrink: 0;">
              <div class="organizer-profile-small">
                <img
                  src={Demo.avatar_url(@organizer_profile, :thumb)}
                  alt={Demo.avatar_alt_text(@organizer_profile)}
                  class="avatar-image-small"
                />
                <div class="organizer-info-small">
                  <div class="organizer-name">{gettext("Schedule with")}</div>
                  <div class="organizer-name-full">
                    {Profiles.display_name(@organizer_profile) || ""}
                  </div>
                  <div class="meeting-duration">{gettext("%{duration} minutes", duration: @selected_duration)}</div>
                </div>
              </div>
            </div>
            
    <!-- Meeting Summary -->
            <div class="meeting-summary compact">
              <div class="summary-row">
                <div class="summary-item">
                  <span class="summary-icon">📅</span>
                  <div>
                    <div class="summary-value">{LocalizationHelpers.format_date(@selected_date)}</div>
                    <div class="summary-label">{@selected_time || gettext("No time selected")}</div>
                  </div>
                </div>
                <div class="summary-item">
                  <span class="summary-icon">🌍</span>
                  <div>
                    <div class="summary-value">
                      {TimezoneUtils.format_timezone(@user_timezone || "America/New_York")}
                    </div>
                    <div class="summary-label">{LocalizationHelpers.format_duration(@selected_duration)} {gettext("meeting")}</div>
                  </div>
                </div>
              </div>
            </div>
            
    <!-- Contact Form -->
            <form
              phx-submit="submit_booking"
              phx-change="validate_booking"
              phx-target={@myself}
              data-testid="booking-form"
              class="booking-form"
              style="flex: 1;"
            >
              <div class="form-group compact">
                <label for="name" class="form-group label">
                  {gettext("name")}
                </label>
                <input
                  type="text"
                  id="name"
                  name="name"
                  class={["form-input", error_class(assigns[:validation_errors], :name)]}
                  placeholder={gettext("enter_full_name")}
                  value={assigns[:attendee_name] || ""}
                />
                <%= if error = get_error(assigns[:validation_errors], :name) do %>
                  <span
                    class="error-message"
                    style="color: #ef4444; font-size: 0.8rem; margin-top: 2px; display: block; opacity: 0.9;"
                  >
                    {error}
                  </span>
                <% end %>
              </div>

              <div class="form-group compact">
                <label for="email" class="form-group label">
                  {gettext("email")}
                </label>
                <input
                  type="email"
                  id="email"
                  name="email"
                  class={["form-input", error_class(assigns[:validation_errors], :email)]}
                  placeholder={gettext("enter_email")}
                  value={assigns[:attendee_email] || ""}
                />
                <%= if error = get_error(assigns[:validation_errors], :email) do %>
                  <span
                    class="error-message"
                    style="color: #ef4444; font-size: 0.8rem; margin-top: 2px; display: block; opacity: 0.9;"
                  >
                    {error}
                  </span>
                <% end %>
              </div>

              <div class="form-group compact">
                <label for="message" class="form-group label">
                  {gettext("message_optional")}
                </label>
                <textarea
                  id="message"
                  name="message"
                  rows="4"
                  class={["form-textarea", error_class(assigns[:validation_errors], :message)]}
                  placeholder={gettext("add_details")}
                ><%= assigns[:attendee_message] || "" %></textarea>
                <%= if error = get_error(assigns[:validation_errors], :message) do %>
                  <span
                    class="error-message"
                    style="color: #ef4444; font-size: 0.8rem; margin-top: 2px; display: block; opacity: 0.9;"
                  >
                    {error}
                  </span>
                <% end %>
              </div>
              
    <!-- Navigation -->
              <div class="slide-actions horizontal">
                <button
                  type="button"
                  class="prev-button"
                  phx-click="prev_slide"
                  phx-target={@myself}
                  data-testid="back-step"
                  disabled={assigns[:submitting]}
                  style="flex: 1;"
                >
                  ← {gettext("back")}
                </button>
                <button
                  type="submit"
                  class="submit-button"
                  data-testid="submit-booking"
                  disabled={assigns[:submitting]}
                  style="flex: 1; display: flex; align-items: center; justify-content: center; gap: 0.5rem;"
                >
                  <%= if assigns[:submitting] do %>
                    <svg
                      class="animate-spin h-4 w-4"
                      xmlns="http://www.w3.org/2000/svg"
                      fill="none"
                      viewBox="0 0 24 24"
                    >
                      <circle
                        class="opacity-25"
                        cx="12"
                        cy="12"
                        r="10"
                        stroke="currentColor"
                        stroke-width="4"
                      >
                      </circle>
                      <path
                        class="opacity-75"
                        fill="currentColor"
                        d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                      >
                      </path>
                    </svg>
                    <span>{gettext("Verifying...")}</span>
                  <% else %>
                    {gettext("submit")}
                  <% end %>
                </button>
              </div>
            </form>
          </div>
        </div>
      </div>
    </div>
    """
  end

  # Helpers
  defp get_error(nil, _field), do: nil
  defp get_error([], _field), do: nil

  defp get_error(errors, field) when is_list(errors) do
    case Keyword.get(errors, field) do
      nil -> nil
      error -> error
    end
  end

  defp error_class(nil, _field), do: ""
  defp error_class([], _field), do: ""

  defp error_class(errors, field) when is_list(errors) do
    if Keyword.has_key?(errors, field) do
      "error"
    else
      ""
    end
  end
end
