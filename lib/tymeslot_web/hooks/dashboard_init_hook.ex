defmodule TymeslotWeb.Hooks.DashboardInitHook do
  @moduledoc """
  Consolidated hook for dashboard initialization.
  Handles onboarding checks, profile loading, and common dashboard state.
  """
  import Phoenix.LiveView
  import Phoenix.Component
  alias Tymeslot.Auth
  alias Tymeslot.Profiles
  alias Tymeslot.Dashboard.DashboardContext

  def on_mount(:default, _params, _session, socket) do
    user = socket.assigns[:current_user]

    cond do
      is_nil(user) ->
        # Let authentication hooks handle missing user
        {:cont, socket}

      !Auth.onboarding_completed?(user) ->
        {:halt, redirect(socket, to: "/onboarding")}

      true ->
        profile = Profiles.get_profile(user.id) || %Tymeslot.DatabaseSchemas.ProfileSchema{user_id: user.id}
        integration_status = DashboardContext.get_integration_status(user.id)

        socket =
          socket
          |> assign(:profile, profile)
          |> assign(:integration_status, integration_status)
          |> assign_new(:saving, fn -> false end)

        {:cont, socket}
    end
  end
end
