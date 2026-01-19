defmodule TymeslotWeb.Dashboard.ProfileSettings.DisplayNameFormComponent do
  use TymeslotWeb, :live_component

  alias Tymeslot.Profiles
  alias Tymeslot.Security.SettingsInputProcessor
  alias TymeslotWeb.Components.FormSystem

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:form_errors, %{})}
  end

  @impl true
  def handle_event("validate_full_name", %{"full_name" => full_name}, socket) do
    metadata = DashboardHelpers.get_security_metadata(socket)

    case SettingsInputProcessor.validate_full_name_update(full_name, metadata: metadata) do
      {:ok, sanitized_name} ->
        socket = assign(socket, :form_errors, Map.delete(socket.assigns.form_errors, :full_name))
        maybe_update_full_name(socket, sanitized_name)

      {:error, error} ->
        errors = Map.put(socket.assigns.form_errors, :full_name, error)
        {:noreply, assign(socket, :form_errors, errors)}
    end
  end

  defp maybe_update_full_name(socket, sanitized_name) do
    profile = socket.assigns.profile

    if profile && sanitized_name != profile.full_name do
      case Profiles.update_full_name(profile, sanitized_name) do
        {:ok, updated_profile} ->
          send(self(), {:profile_updated, updated_profile})
          Flash.info("Display name updated")
          {:noreply, assign(socket, profile: updated_profile)}

        {:error, _reason} ->
          Flash.error("Failed to update display name")
          {:noreply, socket}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="display-name-form-container">
      <FormSystem.form_wrapper
        for={%{}}
        phx_change="validate_full_name"
        phx_target={@myself}
        id="display-name-form"
      >
        <FormSystem.text_field
          name="full_name"
          value={if @profile, do: @profile.full_name || "", else: ""}
          label="Display Name"
          placeholder="Enter your full name"
          help="This name will appear to visitors when they book meetings with you. Changes are saved automatically."
          errors={if @form_errors[:full_name], do: [@form_errors[:full_name]], else: []}
          phx-debounce="500"
        />
      </FormSystem.form_wrapper>
    </div>
    """
  end
end
