defmodule TymeslotWeb.Dashboard.ProfileSettingsComponent do
  @moduledoc """
  LiveView component for managing user profile settings including timezone,
  display name, scheduling preferences, and username configuration.
  """
  use TymeslotWeb, :live_component

  alias Tymeslot.Bookings.Policy
  alias Tymeslot.{Profiles, Utils.TimezoneUtils}
  alias Tymeslot.Security.SettingsInputProcessor
  alias Tymeslot.Utils.ChangesetUtils
  alias TymeslotWeb.Components.{CoreComponents, FormSystem}
  alias TymeslotWeb.Components.TimezoneDropdown
  alias TymeslotWeb.Hooks.ModalHook
  alias TymeslotWeb.Live.Dashboard.Shared.DashboardHelpers
  alias TymeslotWeb.Live.Shared.Flash
  require Logger

  @impl true
  def mount(socket) do
    {:ok, socket}
  end

  @impl true
  def update(assigns, socket) do
    timezone_options = TimezoneUtils.get_all_timezone_options()

    socket =
      socket
      |> assign(assigns)
      |> assign(timezone_options: timezone_options)
      |> assign(username_check: nil)
      |> assign(username_available: nil)
      |> assign(saving: false)
      |> assign(timezone_dropdown_open: false)
      |> assign(timezone_search: "")
      |> assign(:form_errors, %{})

    socket =
      if socket.assigns[:uploads] && socket.assigns.uploads[:avatar] do
        socket
      else
        allow_upload(socket, :avatar,
          accept: ~w(.jpg .jpeg .png .gif .webp),
          max_entries: 1,
          max_file_size: 10_000_000,
          auto_upload: true,
          progress: &handle_avatar_progress/3
        )
      end

    socket = ModalHook.mount_modal(socket, [{:delete_avatar, false}])

    {:ok, socket}
  end

  # Validation event handlers
  @impl true
  def handle_event("validate_full_name", %{"full_name" => full_name}, socket) do
    metadata = DashboardHelpers.get_security_metadata(socket)

    case SettingsInputProcessor.validate_full_name_update(full_name, metadata: metadata) do
      {:ok, sanitized_name} ->
        # Clear any previous error for this field
        socket = assign(socket, :form_errors, Map.delete(socket.assigns.form_errors, :full_name))
        maybe_update_full_name(socket, sanitized_name)

      {:error, error} ->
        errors = Map.put(socket.assigns.form_errors, :full_name, error)
        {:noreply, assign(socket, :form_errors, errors)}
    end
  end

  def handle_event("validate_username", %{"username" => username}, socket) do
    metadata = DashboardHelpers.get_security_metadata(socket)

    case SettingsInputProcessor.validate_username_update(username, metadata: metadata) do
      {:ok, _sanitized_username} ->
        {:noreply,
         assign(socket, :form_errors, Map.delete(socket.assigns.form_errors, :username))}

      {:error, error} ->
        errors = Map.put(socket.assigns.form_errors, :username, error)
        {:noreply, assign(socket, :form_errors, errors)}
    end
  end

  def handle_event("check_username_availability", %{"username" => username}, socket) do
    metadata = DashboardHelpers.get_security_metadata(socket)

    socket = update_username_availability(socket, username, metadata)

    {:noreply, socket}
  end

  def handle_event("update_username", %{"username" => username}, socket) do
    metadata = DashboardHelpers.get_security_metadata(socket)
    perform_username_update(socket, username, metadata)
  end

  def handle_event("validate_avatar", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("upload_avatar", _params, socket) do
    metadata = DashboardHelpers.get_security_metadata(socket)
    {:noreply, consume_avatar_upload(socket, metadata)}
  end

  def handle_event("show_delete_avatar_modal", _params, socket) do
    {:noreply, ModalHook.show_modal(socket, :delete_avatar)}
  end

  def handle_event("hide_delete_avatar_modal", _params, socket) do
    {:noreply, ModalHook.hide_modal(socket, :delete_avatar)}
  end

  def handle_event("delete_avatar", _params, socket) do
    profile = socket.assigns.profile
    socket = ModalHook.hide_modal(socket, :delete_avatar)

    case Profiles.delete_avatar(profile) do
      {:ok, updated_profile} ->
        send(self(), {:profile_updated, updated_profile})
        Flash.info("Avatar deleted successfully")

        # Reset the upload configuration locally after avatar deletion
        socket =
          socket
          |> disallow_upload(:avatar)
          |> allow_upload(:avatar,
            accept: ~w(.jpg .jpeg .png .gif .webp),
            max_entries: 1,
            max_file_size: 10_000_000,
            auto_upload: true,
            progress: &handle_avatar_progress/3
          )

        # Push event to clear the file input in JavaScript
        socket = push_event(socket, "avatar-upload-complete", %{})

        {:noreply, assign(socket, profile: updated_profile)}

      {:error, reason} ->
        error_msg = "Failed to delete avatar: #{inspect(reason)}"
        Flash.error(error_msg)
        {:noreply, socket}
    end
  end

  def handle_event("toggle_timezone_dropdown", _params, socket) do
    {:noreply, assign(socket, timezone_dropdown_open: !socket.assigns.timezone_dropdown_open)}
  end

  def handle_event("close_timezone_dropdown", _params, socket) do
    {:noreply, assign(socket, timezone_dropdown_open: false)}
  end

  def handle_event("search_timezone", %{"search" => search}, socket) do
    {:noreply, assign(socket, timezone_search: search)}
  end

  def handle_event("search_timezone", %{"value" => search}, socket) do
    {:noreply, assign(socket, timezone_search: search)}
  end

  def handle_event("change_timezone", %{"timezone" => timezone}, socket) do
    metadata = DashboardHelpers.get_security_metadata(socket)
    socket = assign(socket, timezone_dropdown_open: false, timezone_search: "")

    # First validate the timezone
    case SettingsInputProcessor.validate_timezone_update(timezone, metadata: metadata) do
      {:ok, sanitized_timezone} ->
        handle_profile_update(
          socket,
          fn profile -> Profiles.update_timezone(profile, sanitized_timezone) end,
          fn updated_profile ->
            label = label_for_timezone(socket, updated_profile.timezone)
            "Timezone updated to #{label}"
          end
        )

      {:error, validation_error} ->
        errors = Map.put(socket.assigns.form_errors, :timezone, validation_error)
        socket = assign(socket, :form_errors, errors)
        {:noreply, socket}
    end
  end

  # Private helpers

  defp perform_username_update(socket, username, metadata) do
    profile = socket.assigns.profile
    user_id = socket.assigns.current_user.id

    socket = assign(socket, :saving, true)

    with {:ok, sanitized_username} <-
           SettingsInputProcessor.validate_username_update(username, metadata: metadata),
         {:ok, updated_profile} <-
           Profiles.update_username(profile, sanitized_username, user_id) do
      handle_successful_username_update(socket, updated_profile, sanitized_username)
    else
      error -> handle_username_update_error(socket, error)
    end
  end

  defp handle_successful_username_update(socket, updated_profile, sanitized_username) do
    base_url = Policy.app_url()
    display_url = String.replace(base_url, ~r/^https?:\/\//, "")

    send(self(), {:profile_updated, updated_profile})

    send(
      self(),
      {:flash,
       {:info, "Username updated! Your booking page: #{display_url}/#{sanitized_username}"}}
    )

    {:noreply,
     socket
     |> assign(profile: updated_profile)
     |> assign(saving: false)
     |> assign(:form_errors, Map.delete(socket.assigns.form_errors, :username))}
  end

  defp handle_username_update_error(socket, error) do
    case error do
      {:error, %Ecto.Changeset{} = changeset} ->
        Flash.error(ChangesetUtils.get_first_error(changeset))
        {:noreply, assign(socket, saving: false)}

      {:error, message} when is_binary(message) ->
        Flash.error(message)
        {:noreply, assign(socket, saving: false)}
    end
  end

  defp handle_profile_update(socket, update_fn, success_msg) do
    profile = socket.assigns.profile
    socket = assign(socket, :saving, true)

    case update_fn.(profile) do
      {:ok, updated_profile} ->
        msg = if is_function(success_msg), do: success_msg.(updated_profile), else: success_msg

        send(self(), {:profile_updated, updated_profile})
        Flash.info(msg)

        {:noreply,
         socket
         |> assign(profile: updated_profile)
         |> assign(saving: false)}

      other ->
        Flash.error(error_to_message(other))
        {:noreply, assign(socket, saving: false)}
    end
  end

  defp error_to_message({:error, %Ecto.Changeset{} = changeset}) do
    ChangesetUtils.get_first_error(changeset)
  end

  defp error_to_message({:error, message}) do
    "#{message}"
  end

  defp handle_avatar_progress(_config, entry, socket) do
    if entry.done? do
      metadata = DashboardHelpers.get_security_metadata(socket)
      {:noreply, consume_avatar_upload(socket, metadata)}
    else
      {:noreply, socket}
    end
  end

  defp consume_avatar_upload(socket, metadata) do
    profile = socket.assigns.profile

    results =
      consume_uploaded_entries(
        socket,
        :avatar,
        &Profiles.consume_avatar_upload(profile, &1, &2, metadata)
      )

    case results do
      [{:ok, updated_profile}] ->
        handle_successful_avatar_upload(updated_profile, socket)

      [%{__struct__: _} = updated_profile] ->
        handle_successful_avatar_upload(updated_profile, socket)

      [{:error, _} = error | _] ->
        handle_avatar_upload_error(error, socket)

      [] ->
        socket

      [error_message] when is_binary(error_message) ->
        Flash.error(error_message)
        socket

      error_messages when is_list(error_messages) ->
        error_msg = List.first(error_messages) || "Upload failed"
        Flash.error(error_msg)
        socket
    end
  end

  defp handle_successful_avatar_upload(updated_profile, socket) do
    send(self(), {:profile_updated, updated_profile})
    Flash.info("Avatar updated successfully")

    # Push event to clear the file input in JavaScript
    socket = push_event(socket, "avatar-upload-complete", %{})

    assign(socket, profile: updated_profile)
  end

  defp handle_avatar_upload_error(error, socket) do
    error_msg = format_upload_error(error)
    Flash.error(error_msg)
    socket
  end

  # Helpers to reduce nesting
  defp maybe_update_full_name(socket, sanitized_name) do
    profile = socket.assigns.profile

    if profile && sanitized_name != profile.full_name do
      handle_profile_update(
        socket,
        fn p -> Profiles.update_full_name(p, sanitized_name) end,
        "Display name updated"
      )
    else
      {:noreply, socket}
    end
  end

  defp update_username_availability(socket, username, metadata) do
    cond do
      username == "" ->
        assign(socket, username_check: nil, username_available: nil)

      socket.assigns.profile && username == socket.assigns.profile.username ->
        assign(socket, username_check: username, username_available: :current)

      true ->
        case SettingsInputProcessor.validate_username_update(username, metadata: metadata) do
          {:ok, sanitized_username} ->
            available = Profiles.username_available?(sanitized_username)
            assign(socket, username_check: sanitized_username, username_available: available)

          {:error, message} ->
            assign(socket, username_check: username, username_available: {:error, message})
        end
    end
  end

  defp label_for_timezone(socket, timezone_value) do
    case Enum.find(socket.assigns.timezone_options, fn {_label, value} ->
           value == timezone_value
         end) do
      {label, _value} -> label
      _ -> timezone_value
    end
  end

  defp format_upload_error({:error, %Ecto.Changeset{} = changeset}) do
    ChangesetUtils.get_first_error(changeset)
  end

  defp format_upload_error({:error, reason}) do
    "Upload failed: #{inspect(reason)}"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-10 pb-20">
      <.section_header icon={:user} title="Profile Settings" saving={@saving} />

      <div class="max-w-5xl mx-auto">
        <div class="card-glass relative overflow-hidden">
          
          <div class="relative z-10 grid grid-cols-1 lg:grid-cols-3 gap-12 items-start">
            <!-- Left Side: Avatar Upload -->
            <div class="lg:col-span-1 space-y-8 text-center pt-4">
              <.section_header
                level={3}
                title="Profile Picture"
              />
              
              <div class="relative inline-block mb-8" phx-hook="AutoUpload" id="avatar-upload-section">
                <div class="w-40 h-40 rounded-[2.5rem] overflow-hidden bg-tymeslot-100 border-4 border-white shadow-2xl relative z-10 mx-auto">
                  <img
                    src={Profiles.avatar_url(@profile, :thumb)}
                    alt={Profiles.avatar_alt_text(@profile)}
                    class="w-full h-full object-cover"
                  />
                </div>
                <div class="absolute inset-0 bg-turquoise-400 blur-2xl opacity-20 rounded-full scale-75 transition-opacity"></div>
              </div>

              <div class="space-y-4 max-w-[240px] mx-auto">
                <form
                  id="avatar-upload-form"
                  phx-submit="upload_avatar"
                  phx-change="validate_avatar"
                  phx-target={@myself}
                  data-auto-upload="true"
                  class="flex flex-col items-center gap-4"
                >
                  <div class="w-full">
                    <%= if @uploads && @uploads[:avatar] do %>
                      <div class="relative group/input">
                        <.live_file_input
                          upload={@uploads.avatar}
                          class="absolute inset-0 w-full h-full opacity-0 cursor-pointer z-20"
                        />
                      <div class="btn-primary w-full flex items-center justify-center gap-2 py-4 whitespace-nowrap">
                        <svg class="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12" />
                        </svg>
                        <span><%= if @uploads.avatar.entries != [], do: "Uploading...", else: "Upload New" %></span>
                      </div>
                      </div>
                    <% else %>
                      <div class="btn-primary w-full opacity-50 cursor-not-allowed py-4">
                        Upload New
                      </div>
                    <% end %>
                  </div>

                  <%= if @profile.avatar do %>
                    <button
                      type="button"
                      phx-click="show_delete_avatar_modal"
                      phx-target={@myself}
                      class="btn-danger w-full py-4 flex items-center justify-center gap-2 whitespace-nowrap"
                    >
                      <svg class="w-5 h-5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                      </svg>
                      <span>Delete Photo</span>
                    </button>
                  <% end %>
                  
                  <button type="submit" id="avatar-submit-btn" class="hidden">Upload</button>
                </form>

                <p class="text-[10px] text-tymeslot-400 font-bold uppercase tracking-widest pt-2">
                  JPG, PNG, GIF or WebP. Max 10MB.
                </p>

                <!-- Upload progress -->
                <%= if @uploads && @uploads[:avatar] do %>
                  <%= for err <- upload_errors(@uploads.avatar) do %>
                    <div class="mt-4 p-3 bg-red-50 border border-red-100 rounded-token-xl text-red-600 text-xs font-bold flex items-center gap-2 animate-in slide-in-from-top-1">
                      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                      </svg>
                      {Phoenix.Naming.humanize(err)}
                    </div>
                  <% end %>

                  <%= for entry <- @uploads.avatar.entries do %>
                    <div class="mt-6 p-4 bg-turquoise-50 rounded-token-2xl border-2 border-turquoise-100 animate-in fade-in zoom-in">
                      <div class="flex items-center justify-between mb-2">
                        <span class="text-turquoise-700 font-black text-xs uppercase tracking-wider">
                          <%= if entry.progress == 100, do: "Processing...", else: "Uploading..." %>
                        </span>
                        <span class="text-turquoise-600 font-black text-xs">{entry.progress}%</span>
                      </div>
                      <div class="bg-white rounded-full h-2 overflow-hidden shadow-inner">
                        <div
                          class="bg-gradient-to-r from-turquoise-500 to-cyan-500 h-full transition-all duration-300"
                          style={"width: #{entry.progress}%"}
                        ></div>
                      </div>
                    </div>

                    <%= for err <- upload_errors(@uploads.avatar, entry) do %>
                      <div class="mt-2 p-3 bg-red-50 border border-red-100 rounded-token-xl text-red-600 text-xs font-bold flex items-center gap-2 animate-in slide-in-from-top-1">
                        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                        </svg>
                        {Phoenix.Naming.humanize(err)}
                      </div>
                    <% end %>
                  <% end %>
                <% end %>
              </div>
            </div>

            <!-- Right Side: Basic Info Forms -->
            <div class="lg:col-span-2 space-y-10 lg:border-l-2 lg:border-tymeslot-50 lg:pl-12 pt-4">
              <div class="flex items-center gap-4 mb-2">
                <div class="w-12 h-12 bg-cyan-50 rounded-token-xl flex items-center justify-center border border-cyan-100 shadow-sm">
                  <svg class="w-6 h-6 text-cyan-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                  </svg>
                </div>
                <h3 class="text-2xl font-black text-tymeslot-900 tracking-tight">Basic Information</h3>
              </div>

              <div class="space-y-10">
                <.full_name_setting profile={@profile} myself={@myself} form_errors={@form_errors} />
                
                <div class="border-t-2 border-tymeslot-50 pt-10">
                  <.username_setting
                    profile={@profile}
                    username_check={@username_check}
                    username_available={@username_available}
                    myself={@myself}
                    form_errors={@form_errors}
                  />
                </div>

                <div class="border-t-2 border-tymeslot-50 pt-10">
                  <.timezone_setting
                    profile={@profile}
                    timezone_options={@timezone_options}
                    timezone_dropdown_open={@timezone_dropdown_open}
                    timezone_search={@timezone_search}
                    myself={@myself}
                    form_errors={@form_errors}
                  />
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
      
    <!-- Delete Avatar Modal -->
      <CoreComponents.modal
        id="delete-avatar-modal"
        show={@show_delete_avatar_modal}
        on_cancel={Phoenix.LiveView.JS.push("hide_delete_avatar_modal", target: @myself)}
        size={:medium}
      >
        <:header>
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 bg-red-50 rounded-token-xl flex items-center justify-center border border-red-100">
              <svg class="w-6 h-6 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
              </svg>
            </div>
            <span class="text-2xl font-black text-tymeslot-900 tracking-tight">Delete Avatar</span>
          </div>
        </:header>
        <p class="text-tymeslot-600 font-medium text-lg leading-relaxed">
          Are you sure you want to delete your profile picture? This action cannot be undone.
        </p>
        <:footer>
          <div class="flex gap-4">
            <CoreComponents.action_button
              variant={:secondary}
              phx-click={Phoenix.LiveView.JS.push("hide_delete_avatar_modal", target: @myself)}
              class="flex-1 py-4"
            >
              Cancel
            </CoreComponents.action_button>
            <CoreComponents.action_button
              variant={:danger}
              phx-click={Phoenix.LiveView.JS.push("delete_avatar", target: @myself)}
              class="flex-1 py-4"
            >
              Delete Avatar
            </CoreComponents.action_button>
          </div>
        </:footer>
      </CoreComponents.modal>
    </div>
    """
  end

  # Component functions
  defp full_name_setting(assigns) do
    ~H"""
    <FormSystem.form_wrapper for={%{}} phx_change="validate_full_name" phx_target={@myself}>
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
    """
  end

  defp timezone_setting(assigns) do
    ~H"""
    <div>
      <TimezoneDropdown.timezone_dropdown
        profile={@profile}
        timezone_options={@timezone_options}
        timezone_dropdown_open={@timezone_dropdown_open}
        timezone_search={@timezone_search}
        target={@myself}
        safe_flags={false}
      />
      <%= if @form_errors[:timezone] do %>
        <p class="text-token-sm text-red-400 mt-1">{@form_errors[:timezone]}</p>
      <% end %>
    </div>
    """
  end

  defp username_setting(assigns) do
    ~H"""
    <form phx-submit="update_username" phx-change="check_username_availability" phx-target={@myself} class="space-y-4">
      <div>
        <label for="username" class="label">
          Your Custom URL
        </label>
        <div class="flex flex-col sm:flex-row items-stretch gap-4">
          <div class={[
            "flex-1 flex items-center input group focus-within:border-turquoise-400 focus-within:bg-white focus-within:shadow-xl focus-within:shadow-turquoise-500/10 transition-all duration-300",
            if(@form_errors[:username], do: "input-error focus-within:border-red-400 focus-within:bg-white focus-within:shadow-red-500/10", else: "")
          ]}>
            <% base_url = Policy.app_url() %>
            <% display_url = String.replace(base_url, ~r/^https?:\/\//, "") %>
            <span class="text-tymeslot-400 font-bold text-token-sm tracking-tight whitespace-nowrap">{display_url}/</span>
            <input
              type="text"
              id="username"
              name="username"
              value={if @profile, do: @profile.username || "", else: ""}
              placeholder="yourname"
              pattern="[a-z0-9][a-z0-9-]{2,29}"
              minlength="3"
              maxlength="30"
              phx-debounce="500"
              class="flex-1 bg-transparent border-none focus:ring-0 p-0 ml-1 text-tymeslot-900 font-medium text-token-sm"
            />
          </div>
          <button type="submit" class="btn-primary px-8 whitespace-nowrap" phx-disable-with="Saving...">
            Update URL
          </button>
        </div>
        
        <div class="mt-4">
          <%= if @form_errors[:username] do %>
            <div class="p-3 bg-red-50 border border-red-100 rounded-token-xl text-red-600 text-token-sm font-bold flex items-center gap-2 animate-in slide-in-from-top-1">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              {@form_errors[:username]}
            </div>
          <% end %>

          <%= if @profile && @profile.username do %>
            <% base_url = Policy.app_url() %>
            <% display_url = String.replace(base_url, ~r/^https?:\/\//, "") %>
            <div class="flex items-center gap-2 text-token-sm font-bold text-tymeslot-500">
              <svg class="w-4 h-4 text-emerald-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M5 13l4 4L19 7" />
              </svg>
              Live at: 
              <a
                href={"#{base_url}/#{if @profile, do: @profile.username, else: ""}"}
                target="_blank"
                class="text-turquoise-600 hover:text-turquoise-700 underline decoration-2 decoration-turquoise-100 underline-offset-4 transition-colors"
              >
                {display_url}/{if @profile, do: @profile.username, else: ""}
              </a>
            </div>
          <% else %>
            <p class="text-token-sm text-tymeslot-500 font-medium">
              Choose a unique username for your personal booking page.
            </p>
          <% end %>

          <%= if @username_check && (!@profile || @username_check != @profile.username) do %>
            <div class="mt-3">
              <%= case @username_available do %>
                <% true -> %>
                  <div class="inline-flex items-center px-3 py-1 rounded-token-lg bg-emerald-50 text-emerald-700 text-xs font-black uppercase tracking-wider border border-emerald-100 animate-in zoom-in">
                    <svg class="w-3 h-3 mr-1.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7" />
                    </svg>
                    Available!
                  </div>
                <% false -> %>
                  <div class="inline-flex items-center px-3 py-1 rounded-token-lg bg-red-50 text-red-700 text-xs font-black uppercase tracking-wider border border-red-100 animate-in zoom-in">
                    <svg class="w-3 h-3 mr-1.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M6 18L18 6M6 6l12 12" />
                    </svg>
                    Already taken
                  </div>
                <% {:error, message} -> %>
                  <p class="text-xs text-amber-600 font-bold uppercase tracking-wider">
                    {message}
                  </p>
                <% _ -> %>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </form>
    """
  end
end
