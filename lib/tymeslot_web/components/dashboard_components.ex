defmodule TymeslotWeb.Components.DashboardComponents do
  @moduledoc """
  Shared UI components for the dashboard interface.
  Provides reusable form inputs, cards, modals, and other UI elements.
  """

  use Phoenix.Component
  alias Phoenix.LiveView.JS
  alias TymeslotWeb.Components.CoreComponents
  alias TymeslotWeb.Components.Icons.IconComponents

  @doc """
  Renders a form input with consistent styling.
  """
  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :type, :string, default: "text"
  attr :value, :any, required: true
  attr :placeholder, :string, default: ""
  attr :help, :string, default: nil
  attr :rest, :global

  @spec form_input(map()) :: Phoenix.LiveView.Rendered.t()
  def form_input(assigns) do
    ~H"""
    <div>
      <label for={@id} class="label">
        {@label}
      </label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={@value}
        placeholder={@placeholder}
        class="input"
        {@rest}
      />
      <%= if @help do %>
        <p class="mt-2 text-sm text-slate-500 font-bold">{@help}</p>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a select dropdown with consistent styling.
  """
  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :label, :string, required: true
  attr :value, :any, required: true
  attr :options, :list, required: true
  attr :help, :string, default: nil
  attr :rest, :global

  @spec form_select(map()) :: Phoenix.LiveView.Rendered.t()
  def form_select(assigns) do
    ~H"""
    <div>
      <label for={@id} class="label">
        {@label}
      </label>
      <div class="relative">
        <select
          id={@id}
          name={@name}
          class="input appearance-none"
          {@rest}
        >
          <%= for {label, value} <- @options do %>
            <option value={value} selected={value == @value}>
              {label}
            </option>
          <% end %>
        </select>
      </div>
      <%= if @help do %>
        <p class="mt-2 text-sm text-slate-500 font-bold">{@help}</p>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders an integration card (used in calendar and video integrations).
  """
  attr :title, :string, required: true
  attr :subtitle, :string, required: true
  attr :details, :list, default: []
  slot :action, required: true

  @spec integration_card(map()) :: Phoenix.LiveView.Rendered.t()
  def integration_card(assigns) do
    ~H"""
    <div class="bg-white border-2 border-slate-50 rounded-2xl p-5 shadow-sm hover:border-turquoise-100 hover:shadow-md transition-all group">
      <div class="flex items-start justify-between gap-4">
        <div class="flex-1">
          <h3 class="font-black text-slate-900 tracking-tight group-hover:text-turquoise-700 transition-colors">{@title}</h3>
          <p class="text-sm text-slate-500 font-bold mt-1">{@subtitle}</p>
          <%= if @details != [] do %>
            <div class="mt-3 space-y-1">
              <%= for detail <- @details do %>
                <p class="text-xs text-slate-400 font-medium">{detail}</p>
              <% end %>
            </div>
          <% end %>
        </div>
        <div class="flex items-center gap-2">
          {render_slot(@action)}
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders an empty state with icon and optional action.
  """
  attr :message, :string, required: true
  attr :icon_title, :string, default: nil
  slot :icon, required: true
  slot :action

  @spec empty_state(map()) :: Phoenix.LiveView.Rendered.t()
  def empty_state(assigns) do
    assigns = assign(assigns, :action, assigns |> Map.get(:action) |> List.wrap())

    ~H"""
    <div class="text-center py-20 bg-slate-50/50 rounded-[2.5rem] border-2 border-dashed border-slate-100">
      <div class="w-24 h-24 bg-white rounded-3xl flex items-center justify-center mx-auto mb-8 shadow-sm border border-slate-50">
        <svg
          class="w-12 h-12 text-slate-300"
          fill="none"
          stroke="currentColor"
          viewBox="0 0 24 24"
          role={if @icon_title, do: "img", else: nil}
          aria-label={@icon_title}
          aria-hidden={if is_nil(@icon_title), do: "true", else: nil}
        >
          <%= if @icon_title do %>
            <title>{@icon_title}</title>
          <% end %>
          {render_slot(@icon)}
        </svg>
      </div>
      <p class="text-xl text-slate-900 font-black tracking-tight mb-2">{@message}</p>
      <%= if @action != [] do %>
        <div class="mt-8">
          {render_slot(@action)}
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a confirmation modal using CoreComponents.modal.
  """
  attr :id, :string, required: true
  attr :show, :boolean, required: true
  attr :title, :string, required: true
  attr :message, :string, required: true
  attr :on_cancel, JS, default: %JS{}
  attr :on_confirm, :string, required: true
  attr :confirm_text, :string, default: "Confirm"
  attr :confirm_variant, :atom, default: :danger

  @spec confirmation_modal(map()) :: Phoenix.LiveView.Rendered.t()
  def confirmation_modal(assigns) do
    ~H"""
    <CoreComponents.modal id={@id} show={@show} on_cancel={@on_cancel} size={:medium}>
      <:header>
        <div class="flex items-center gap-3">
          <div class={[
            "w-10 h-10 rounded-xl flex items-center justify-center border",
            if(@confirm_variant == :danger, do: "bg-red-50 border-red-100", else: "bg-turquoise-50 border-turquoise-100")
          ]}>
            <svg class={["w-6 h-6", if(@confirm_variant == :danger, do: "text-red-500", else: "text-turquoise-600")]} fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z" />
            </svg>
          </div>
          <span class="text-2xl font-black text-slate-900 tracking-tight">{@title}</span>
        </div>
      </:header>

      <p class="text-slate-600 font-medium text-lg leading-relaxed">{@message}</p>

      <:footer>
        <div class="flex gap-4">
          <button
            type="button"
            phx-click={@on_cancel}
            class="btn-secondary flex-1 py-4"
          >
            Cancel
          </button>
          <button
            type="button"
            phx-click={@on_confirm}
            class={[
              "flex-1 py-4",
              if(@confirm_variant == :danger, do: "btn-danger", else: "btn-primary")
            ]}
          >
            {@confirm_text}
          </button>
        </div>
      </:footer>
    </CoreComponents.modal>
    """
  end

  @doc """
  Renders a button with consistent styling.
  """
  attr :type, :string, default: "button"
  attr :variant, :atom, default: :primary
  attr :class, :string, default: ""
  attr :rest, :global
  slot :inner_block, required: true

  @spec button(map()) :: Phoenix.LiveView.Rendered.t()
  def button(assigns) do
    ~H"""
    <button type={@type} class={[button_classes(@variant), @class]} {@rest}>
      {render_slot(@inner_block)}
    </button>
    """
  end

  @doc """
  Renders a stat card for dashboard overview.
  """
  attr :title, :string, required: true
  attr :value, :integer, required: true
  attr :icon, :string, required: true
  attr :link, :string, required: true
  attr :description, :string, required: true

  @spec stat_card(map()) :: Phoenix.LiveView.Rendered.t()
  def stat_card(assigns) do
    ~H"""
    <.link patch={@link} class="block group">
      <div class="card-glass hover:bg-white hover:border-turquoise-100 hover:shadow-2xl hover:shadow-turquoise-500/5 transition-all">
        <div class="flex items-center gap-6">
          <div class="flex-shrink-0">
            <div class="w-16 h-16 bg-turquoise-50 rounded-2xl flex items-center justify-center border border-turquoise-100 group-hover:scale-110 transition-transform">
              <IconComponents.icon name={@icon} class="w-8 h-8 text-turquoise-600" />
            </div>
          </div>
          <div class="flex-1">
            <div class="text-3xl font-black text-slate-900 tracking-tight mb-1">{@value}</div>
            <div class="text-sm font-black text-slate-400 uppercase tracking-widest mb-1 group-hover:text-turquoise-600 transition-colors">{@title}</div>
            <div class="text-sm text-slate-500 font-medium">{@description}</div>
          </div>
        </div>
      </div>
    </.link>
    """
  end

  @doc """
  Reusable section header with icon, title, optional count badge and optional saving indicator.
  """
  attr :icon, :atom, required: true
  attr :title, :string, required: true
  attr :count, :integer, default: nil
  attr :saving, :boolean, default: false
  attr :title_class, :string, default: "text-4xl font-black text-slate-900 tracking-tight"
  attr :class, :string, default: "flex items-center mb-12"

  @spec section_header(map()) :: Phoenix.LiveView.Rendered.t()
  def section_header(assigns) do
    ~H"""
    <div class={@class}>
      <div class="w-14 h-14 bg-white rounded-2xl flex items-center justify-center mr-5 shadow-sm border border-slate-100">
        <IconComponents.icon name={@icon} class="w-8 h-8 text-turquoise-600" />
      </div>
      <h1 class={@title_class}>{@title}</h1>
      <%= if @count do %>
        <span class="ml-4 bg-turquoise-100 text-turquoise-700 text-xs font-black px-3 py-1 rounded-full uppercase tracking-wider">
          {@count}
        </span>
      <% end %>
      <%= if @saving do %>
        <div class="ml-auto bg-emerald-50 text-emerald-700 px-4 py-2 rounded-full font-black text-xs uppercase tracking-wider border-2 border-emerald-100 flex items-center">
          <svg class="animate-spin h-4 w-4 mr-2" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          Saving...
        </div>
      <% end %>
    </div>
    """
  end

  # Private helpers

  defp button_classes(:primary), do: "btn-primary"
  defp button_classes(:secondary), do: "btn-secondary"
  defp button_classes(:danger), do: "btn-danger"
  defp button_classes(:ghost), do: "btn-ghost"
  defp button_classes(_), do: "btn-primary"
end
