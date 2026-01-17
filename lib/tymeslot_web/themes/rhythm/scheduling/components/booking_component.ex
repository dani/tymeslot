defmodule TymeslotWeb.Themes.Rhythm.Scheduling.Components.BookingComponent do
  @moduledoc """
  Rhythm theme component for the booking/contact form step.
  Updated to use form struct and shared patterns.
  """
  use TymeslotWeb, :live_component
  use Gettext, backend: TymeslotWeb.Gettext

  alias Tymeslot.Demo
  alias Tymeslot.Profiles
  alias Tymeslot.Utils.TimezoneUtils
  alias TymeslotWeb.Live.Scheduling.Helpers
  alias TymeslotWeb.Themes.Shared.LocalizationHelpers

  @impl true
  def update(assigns, socket) do
    filtered_assigns = Map.drop(assigns, [:flash, :socket])
    {:ok, assign(socket, filtered_assigns)}
  end

  @impl true
  def handle_event("validate", %{"booking" => booking_params}, socket) do
    send(self(), {:step_event, :booking, :validate, booking_params})
    {:noreply, socket}
  end

  @impl true
  def handle_event("field_blur", %{"field" => field_name}, socket) do
    send(self(), {:step_event, :booking, :field_blur, field_name})
    {:noreply, socket}
  end

  @impl true
  def handle_event("submit", %{"booking" => booking_params}, socket) do
    # Set submitting state immediately for instant UI feedback
    socket = assign(socket, :submitting, true)
    send(self(), {:step_event, :booking, :submit, booking_params})
    {:noreply, socket}
  end

  @impl true
  def handle_event("prev_slide", _params, socket) do
    send(self(), {:step_event, :booking, :back_step, nil})
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
                  <div class="meeting-duration">
                    <%= if @meeting_type do %>
                      {LocalizationHelpers.format_duration(@meeting_type.duration_minutes)}
                    <% else %>
                      {LocalizationHelpers.format_duration(@duration)}
                    <% end %>
                  </div>
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
                    <div class="summary-label">
                      <%= if @meeting_type do %>
                        {LocalizationHelpers.format_duration(@meeting_type.duration_minutes)} {gettext("meeting")}
                      <% else %>
                        {LocalizationHelpers.format_duration(@selected_duration)} {gettext("meeting")}
                      <% end %>
                    </div>
                  </div>
                </div>
              </div>
            </div>

    <!-- Contact Form -->
            <.form
              for={@form}
              phx-submit="submit"
              phx-change="validate"
              phx-target={@myself}
              data-testid="booking-form"
              class="booking-form"
              style="flex: 1;"
              as={:booking}
            >
              <div class="form-group compact">
                <label for="name" class="form-group label">
                  {gettext("name")}
                </label>
                <input
                  type="text"
                  id="name"
                  name="booking[name]"
                  class={["form-input", Helpers.field_error_class(@form, :name)]}
                  placeholder={gettext("enter_full_name")}
                  value={@form[:name].value || ""}
                  phx-blur="field_blur"
                  phx-value-field="name"
                  phx-target={@myself}
                />
                <%= for error <- Helpers.get_field_errors(@form, :name) do %>
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
                  name="booking[email]"
                  class={["form-input", Helpers.field_error_class(@form, :email)]}
                  placeholder={gettext("enter_email")}
                  value={@form[:email].value || ""}
                  phx-blur="field_blur"
                  phx-value-field="email"
                  phx-target={@myself}
                />
                <%= for error <- Helpers.get_field_errors(@form, :email) do %>
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
                  name="booking[message]"
                  rows="4"
                  class={["form-textarea", Helpers.field_error_class(@form, :message)]}
                  placeholder={gettext("add_details")}
                  phx-blur="field_blur"
                  phx-value-field="message"
                  phx-target={@myself}
                >{@form[:message].value || ""}</textarea>
                <%= for error <- Helpers.get_field_errors(@form, :message) do %>
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
                  disabled={@submitting}
                  style="flex: 1;"
                >
                  ← {gettext("back")}
                </button>
                <button
                  type="submit"
                  class="submit-button"
                  data-testid="submit-booking"
                  disabled={@submitting || !Helpers.form_valid?(@form)}
                  style="flex: 1; display: flex; align-items: center; justify-content: center; gap: 0.5rem;"
                >
                  <%= if @submitting do %>
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
                    {if @is_rescheduling, do: gettext("reschedule_meeting"), else: gettext("submit")}
                  <% end %>
                </button>
              </div>
            </.form>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
