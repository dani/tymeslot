defmodule TymeslotWeb.Components.Icons.IconComponents do
  @moduledoc """
  Shared icon components for consistent SVG icon rendering across the application.
  """

  use Phoenix.Component

  @doc """
  Renders an SVG icon with consistent styling and attributes.

  ## Examples

      <.icon name="home" class="w-5 h-5" />
      <.icon name="user" class="w-6 h-6 text-blue-500" />

  """
  attr :name, :atom, required: true, doc: "The name of the icon to render"
  attr :class, :string, default: "w-5 h-5", doc: "CSS classes to apply to the SVG"
  attr :rest, :global, doc: "Additional HTML attributes"

  @spec icon(map()) :: Phoenix.LiveView.Rendered.t()
  def icon(%{name: :home} = assigns) do
    ~H"""
    <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24" {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6"
      />
    </svg>
    """
  end

  def icon(%{name: :user} = assigns) do
    ~H"""
    <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24" {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"
      />
    </svg>
    """
  end

  def icon(%{name: :grid} = assigns) do
    ~H"""
    <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24" {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z"
      />
    </svg>
    """
  end

  def icon(%{name: :calendar} = assigns) do
    ~H"""
    <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24" {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"
      />
    </svg>
    """
  end

  def icon(%{name: :video} = assigns) do
    ~H"""
    <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24" {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"
      />
    </svg>
    """
  end

  def icon(%{name: :clock} = assigns) do
    ~H"""
    <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24" {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"
      />
    </svg>
    """
  end

  def icon(%{name: :lock} = assigns) do
    ~H"""
    <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24" {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"
      />
    </svg>
    """
  end

  def icon(%{name: :credit_card} = assigns) do
    ~H"""
    <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24" {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M3 10h18M7 15h1m4 0h1m-7 4h12a3 3 0 003-3V8a3 3 0 00-3-3H5a3 3 0 00-3 3v8a3 3 0 003 3z"
      />
    </svg>
    """
  end

  def icon(%{name: :arrow_left} = assigns) do
    ~H"""
    <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24" {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M10 19l-7-7m0 0l7-7m-7 7h18"
      />
    </svg>
    """
  end

  def icon(%{name: :bell} = assigns) do
    ~H"""
    <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24" {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9"
      />
    </svg>
    """
  end

  def icon(%{name: :webhook} = assigns) do
    ~H"""
    <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24" {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M13 10V3L4 14h7v7l9-11h-7z"
      />
    </svg>
    """
  end

  def icon(%{name: :puzzle} = assigns) do
    ~H"""
    <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24" {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M11 4a2 2 0 114 0v1a1 1 0 001 1h3a1 1 0 011 1v3a1 1 0 01-1 1h-1a2 2 0 100 4h1a1 1 0 011 1v3a1 1 0 01-1 1h-3a1 1 0 01-1-1v-1a2 2 0 10-4 0v1a1 1 0 01-1 1H7a1 1 0 01-1-1v-3a1 1 0 00-1-1H4a2 2 0 110-4h1a1 1 0 001-1V7a1 1 0 011-1h3a1 1 0 001-1V4z"
      />
    </svg>
    """
  end

  # Fallback for unknown icons
  def icon(assigns) do
    ~H"""
    <svg class={@class} fill="none" stroke="currentColor" viewBox="0 0 24 24" {@rest}>
      <path
        stroke-linecap="round"
        stroke-linejoin="round"
        stroke-width="2"
        d="M8.228 9c.549-1.165 2.03-2 3.772-2 2.21 0 4 1.343 4 3 0 1.4-1.278 2.575-3.006 2.907-.542.104-.994.54-.994 1.093m0 3h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
      />
    </svg>
    """
  end
end
