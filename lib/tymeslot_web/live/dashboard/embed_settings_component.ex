defmodule TymeslotWeb.Live.Dashboard.EmbedSettingsComponent do
  @moduledoc """
  Dashboard component for embedding options.
  Shows users different ways to embed their booking page with live previews.
  """
  use TymeslotWeb, :live_component

  alias Ecto.Changeset
  alias Tymeslot.Profiles
  alias Tymeslot.Scheduling.LinkAccessPolicy
  alias Tymeslot.Security.RateLimiter
  alias TymeslotWeb.Endpoint
  alias TymeslotWeb.Live.Dashboard.EmbedSettings.Helpers
  alias TymeslotWeb.Live.Dashboard.EmbedSettings.LivePreview
  alias TymeslotWeb.Live.Dashboard.EmbedSettings.OptionsGrid
  alias TymeslotWeb.Live.Dashboard.EmbedSettings.SecuritySection

  require Logger

  @impl true
  def update(assigns, socket) do
    # Extract props from parent
    profile = assigns.profile
    integration_status = assigns[:integration_status] || %{}
    base_url = Endpoint.url()
    username = profile.username
    theme_id = profile.booking_theme || "1"

    # Check if user is ready for scheduling using cached integration status when available
    is_ready = Map.get(integration_status, :has_calendar, false)

    # Use LinkAccessPolicy only for error reasons or if status is unknown
    error_reason =
      if is_ready do
        nil
      else
        scheduling_readiness = LinkAccessPolicy.check_public_readiness(profile)

        if match?({:ok, :ready}, scheduling_readiness),
          do: nil,
          else: elem(scheduling_readiness, 1)
      end

    # Format allowed domains for display
    allowed_domains_str = domains_to_string(profile.allowed_embed_domains)

    socket =
      socket
      |> assign(:id, assigns.id)
      |> assign(:profile, profile)
      |> assign(:current_user, assigns.current_user)
      |> assign(:base_url, base_url)
      |> assign(:username, username)
      |> assign(:theme_id, theme_id)
      |> assign(:booking_url, "#{base_url}/#{username}")
      |> assign(:is_ready, is_ready)
      |> assign(:error_reason, error_reason)
      |> assign(:allowed_domains_str, allowed_domains_str)
      |> assign_new(:selected_embed_type, fn -> "inline" end)
      |> assign_new(:embed_script_url, fn -> ~p"/embed.js" end)
      |> assign_new(:active_tab, fn -> "options" end)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-10 pb-20">
      <!-- Header -->
      <.section_header
        icon={:code}
        title="Embed & Share"
        class="mb-4"
      />

      <p class="text-tymeslot-600 mb-6">
        Add your booking page to any website. Choose the option that works best for you.
      </p>

      <!-- Tabbed Interface -->
      <.tabs active_tab={@active_tab} target={@myself}>
        <:tab id="options" label="Embed Options" icon={:code}>
          <OptionsGrid.options_grid
            selected_embed_type={@selected_embed_type}
            username={@username}
            base_url={@base_url}
            booking_url={@booking_url}
            myself={@myself}
          />
        </:tab>

        <:tab id="security" label="Security" icon={:lock}>
          <SecuritySection.security_section
            allowed_domains_str={@allowed_domains_str}
            myself={@myself}
          />
        </:tab>

        <:tab id="preview" label="Live Preview" icon={:video}>
          <LivePreview.live_preview
            selected_embed_type={@selected_embed_type}
            username={@username}
            base_url={@base_url}
            embed_script_url={@embed_script_url}
            is_ready={@is_ready}
            error_reason={@error_reason}
            myself={@myself}
          />
        </:tab>
      </.tabs>
    </div>
    """
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, tab)}
  end

  def handle_event("copy_code", %{"type" => type}, socket) do
    code = Helpers.embed_code(type, socket.assigns)

    {:noreply,
     socket
     |> push_event("copy-to-clipboard", %{text: code})
     |> then(fn s ->
       Flash.info("Code copied to clipboard!")
       s
     end)}
  end

  def handle_event("select_embed_type", %{"type" => type}, socket) do
    {:noreply, assign(socket, :selected_embed_type, type)}
  end

  def handle_event("save_embed_domains", %{"allowed_domains" => domains_str}, socket) do
    perform_domain_update(socket, domains_str, "Security settings saved successfully!")
  end

  def handle_event("clear_embed_domains", _params, socket) do
    perform_domain_update(socket, ["none"], "Embedding is now disabled")
  end

  defp perform_domain_update(socket, domains_payload, success_message) do
    user_id = socket.assigns.current_user.id

    # Rate limit: 10 updates per hour per user
    case RateLimiter.check_rate(
           "embed_domain_update:#{user_id}",
           60_000 * 60,
           10
         ) do
      {:allow, _count} ->
        case Profiles.update_allowed_embed_domains(socket.assigns.profile, domains_payload) do
          {:ok, updated_profile} ->
            # Notify parent of profile update
            send(self(), {:profile_updated, updated_profile})

            # Format the domains for display
            allowed_domains_str = domains_to_string(updated_profile.allowed_embed_domains)

            {:noreply,
             socket
             |> assign(:profile, updated_profile)
             |> assign(:allowed_domains_str, allowed_domains_str)
             |> then(fn s ->
               Flash.info(success_message)
               s
             end)}

          {:error, %Changeset{} = changeset} ->
            errors =
              Enum.map_join(
                Changeset.traverse_errors(changeset, fn {msg, _opts} -> msg end),
                "; ",
                fn
                  {:allowed_embed_domains, messages} -> Enum.join(messages, ", ")
                  {field, messages} -> "#{field}: #{Enum.join(messages, ", ")}"
                end
              )

            Flash.error("Failed to save: #{errors}")
            {:noreply, socket}
        end

      {:deny, _limit} ->
        Logger.warning("Embed domain update rate limit exceeded", user_id: user_id)

        Flash.error("Too many updates. Please wait a moment before trying again.")
        {:noreply, socket}
    end
  end

  defp domains_to_string(nil), do: ""
  defp domains_to_string([]), do: ""
  defp domains_to_string(["none"]), do: ""
  defp domains_to_string(domains), do: Enum.join(domains, ", ")
end
