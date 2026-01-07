defmodule TymeslotWeb.Components.CoreComponents.Containers do
  @moduledoc "Container and display components extracted from CoreComponents."
  use Phoenix.Component

  # ========== CARDS & CONTAINERS ==========

  @doc """
  Renders a brand-styled card container.
  """
  attr :class, :string, default: ""
  slot :inner_block, required: true
  @spec brand_card(map()) :: Phoenix.LiveView.Rendered.t()
  def brand_card(assigns) do
    ~H"""
    <div class={["brand-card", @class]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Renders a glass-morphism card container.
  """
  attr :class, :string, default: ""
  slot :inner_block, required: true
  @spec glass_morphism_card(map()) :: Phoenix.LiveView.Rendered.t()
  def glass_morphism_card(assigns) do
    ~H"""
    <div class={["glass-morphism-card", @class]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Renders a generic detail card with consistent styling.
  """
  attr :title, :string, default: nil
  attr :class, :string, default: ""
  slot :inner_block, required: true
  @spec detail_card(map()) :: Phoenix.LiveView.Rendered.t()
  def detail_card(assigns) do
    ~H"""
    <div class={["meeting-details-card", @class]}>
      <%= if @title do %>
        <h3 class="text-xl font-black mb-4 text-slate-900 tracking-tight">{@title}</h3>
      <% end %>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Renders an icon badge with gradient background.
  """
  attr :color_from, :string, default: "#10b981"
  attr :color_to, :string, default: "#059669"
  attr :size, :atom, default: :medium, values: [:small, :medium, :large]
  attr :class, :string, default: ""
  slot :inner_block, required: true
  @spec icon_badge(map()) :: Phoenix.LiveView.Rendered.t()
  def icon_badge(assigns) do
    size_classes =
      case assigns.size do
        :small -> "h-12 w-12"
        :large -> "h-24 w-24"
        _ -> "h-16 w-16"
      end

    icon_size =
      case assigns.size do
        :small -> "h-6 w-6"
        :large -> "h-12 w-12"
        _ -> "h-8 w-8"
      end

    assigns = assigns |> assign(:size_classes, size_classes) |> assign(:icon_size, icon_size)

    ~H"""
    <div
      class={["mx-auto flex items-center justify-center #{@size_classes} rounded-3xl mb-6 bg-gradient-to-br from-turquoise-600 to-cyan-600 shadow-xl shadow-turquoise-500/20 border-4 border-white transform transition-transform hover:scale-110", @class]}
    >
      <svg class={"#{@icon_size} text-white"} fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="2.5">
        {render_slot(@inner_block)}
      </svg>
    </div>
    """
  end

  @doc """
  Renders a section header with consistent styling.
  """
  attr :level, :integer, default: 1
  attr :class, :string, default: ""
  slot :inner_block, required: true
  @spec section_header(map()) :: Phoenix.LiveView.Rendered.t()
  def section_header(assigns) do
    size_class =
      case assigns.level do
        1 -> "text-4xl"
        2 -> "text-3xl"
        3 -> "text-2xl"
        _ -> "text-xl"
      end

    assigns = assign(assigns, :size_class, size_class)

    ~H"""
    <h1 class={["font-black tracking-tight mb-4 text-slate-900", @size_class, @class]}>
      {render_slot(@inner_block)}
    </h1>
    """
  end

  @doc """
  Renders an info/alert box.
  """
  attr :variant, :atom, default: :info, values: [:info, :success, :warning, :error]
  attr :class, :string, default: ""
  slot :inner_block, required: true
  @spec info_box(map()) :: Phoenix.LiveView.Rendered.t()
  def info_box(assigns) do
    classes =
      case assigns.variant do
        :success -> "bg-emerald-50 border-emerald-200 text-emerald-800"
        :warning -> "bg-amber-50 border-amber-200 text-amber-800"
        :error -> "bg-red-50 border-red-200 text-red-800"
        :info -> "bg-sky-50 border-sky-200 text-sky-800"
        _ -> "bg-slate-50 border-slate-200 text-slate-800"
      end

    assigns = assign(assigns, :classes, classes)

    ~H"""
    <div class={["rounded-2xl p-6 mb-8 border-2", @classes, @class]}>
      <p class="font-medium">
        {render_slot(@inner_block)}
      </p>
    </div>
    """
  end
end
