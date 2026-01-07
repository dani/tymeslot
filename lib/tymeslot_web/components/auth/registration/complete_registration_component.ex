defmodule TymeslotWeb.Registration.CompleteRegistrationComponent do
  @moduledoc """
  OAuth registration completion component.

  Provides the UI for users to complete their registration
  after OAuth authentication when additional information is required.
  """

  use TymeslotWeb, :html
  import TymeslotWeb.Shared.Auth.LayoutComponents
  import TymeslotWeb.Shared.Auth.FormComponents
  import TymeslotWeb.Shared.Auth.InputComponents
  import TymeslotWeb.Shared.Auth.ButtonComponents

  @doc """
  Renders the complete registration form using shared auth components.
  """
  @spec complete_registration_form(map()) :: Phoenix.LiveView.Rendered.t()
  def complete_registration_form(assigns) do
    ~H"""
    <.auth_card_layout
      title="Complete Your Registration"
      subtitle="Thank you for signing up! Let's finish setting up your account."
    >
      <:form>
        <.auth_form
          id="complete-registration-form"
          class="space-y-3 sm:space-y-4"
          action="/auth/complete"
        >
          <!-- Hidden OAuth fields -->
          <.oauth_hidden_fields temp_user={@temp_user} />

          <.full_name_input />
          <.email_input email_required={@email_required} temp_user={@temp_user} />
          <%= if Application.get_env(:tymeslot, :enforce_legal_agreements, false) do %>
            <.terms_checkbox name="auth[terms_accepted]" style={:complex} />
          <% end %>
          <.auth_button type="submit" class="mt-4 sm:mt-6">
            Complete Registration
          </.auth_button>
        </.auth_form>
      </:form>
      <:footer>
        <.auth_footer prompt="Want to start over?" href="/auth/login" link_text="Return to login" />
      </:footer>
    </.auth_card_layout>
    """
  end

  # Private function components
  defp full_name_input(assigns) do
    ~H"""
    <div>
      <.form_label for="full-name" text="Display Name" />
      <.auth_text_input
        id="full-name"
        name="profile[full_name]"
        type="text"
        placeholder="e.g. John Doe"
        required={true}
        icon_position="left"
      >
        <:icon>
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
          </svg>
        </:icon>
      </.auth_text_input>
    </div>
    """
  end

  defp email_input(assigns) do
    ~H"""
    <%= if @email_required do %>
      <div>
        <.form_label for="email" text="Email Address" />
        <.auth_text_input
          id="email"
          name="auth[email]"
          type="email"
          placeholder="your.email@example.com"
          required={true}
          icon_position="right"
        >
          <:icon>
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M16 12a4 4 0 10-8 0 4 4 0 008 0zm0 0v1.5a2.5 2.5 0 005 0V12a9 9 0 10-9 9m4.5-1.206a8.959 8.959 0 01-4.5 1.206" />
            </svg>
          </:icon>
        </.auth_text_input>
      </div>
    <% else %>
      <input type="hidden" name="auth[email]" value={@temp_user.email} />
    <% end %>
    """
  end

  defp oauth_hidden_fields(assigns) do
    ~H"""
    <div>
      <input type="hidden" name="oauth_provider" value={@temp_user.provider} />
      <input type="hidden" name="oauth_verified" value={to_string(@temp_user.verified_email)} />
      <input type="hidden" name="oauth_email" value={@temp_user.email} />
      <input type="hidden" name="oauth_email_from_provider" value="true" />
      <%= if @temp_user[:name] do %>
        <input type="hidden" name="oauth_name" value={@temp_user.name} />
      <% end %>
      <%= if @temp_user.github_user_id do %>
        <input type="hidden" name="oauth_github_id" value={@temp_user.github_user_id} />
      <% end %>
      <%= if @temp_user.google_user_id do %>
        <input type="hidden" name="oauth_google_id" value={@temp_user.google_user_id} />
      <% end %>
    </div>
    """
  end
end
