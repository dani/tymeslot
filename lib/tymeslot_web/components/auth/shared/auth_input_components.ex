defmodule TymeslotWeb.Shared.Auth.InputComponents do
  @moduledoc """
  Input components and helpers for authentication forms.
  """

  use TymeslotWeb, :html

  @spec auth_text_input(map()) :: Phoenix.LiveView.Rendered.t()
  def auth_text_input(assigns) do
    assigns =
      assigns
      |> assign_new(:type, fn -> "text" end)
      |> assign_new(:placeholder, fn -> nil end)
      |> assign_new(:required, fn -> false end)
      |> assign_new(:icon, fn -> nil end)
      |> assign_new(:icon_position, fn -> "right" end)
      |> assign_new(:class, fn -> "" end)
      |> assign_new(:autocomplete, fn -> get_autocomplete_for_input(assigns) end)
      |> assign_new(:validate_on_blur, fn -> false end)
      |> Map.put_new(:errors, [])

    ~H"""
    <div class="relative group">
      <input
        id={@id}
        name={@name}
        type={@type}
        class={[
          "input",
          if(@errors != [], do: "input-error", else: ""),
          if(@icon && @icon_position == "left", do: "pl-12", else: ""),
          if(@icon && @icon_position == "right", do: "pr-12", else: ""),
          @class
        ]}
        placeholder={@placeholder}
        required={@required}
        value={assigns[:value]}
        autocomplete={@autocomplete}
        readonly={assigns[:readonly]}
        disabled={assigns[:disabled]}
        tabindex={assigns[:tabindex]}
        aria-describedby={assigns[:"aria-describedby"]}
        aria-label={assigns[:"aria-label"]}
        aria-invalid={assigns[:"aria-invalid"]}
        data-testid={assigns[:"data-testid"]}
        phx-change={if @validate_on_blur, do: nil, else: assigns[:"phx-change"]}
        phx-blur={if @validate_on_blur, do: assigns[:"phx-change"], else: assigns[:"phx-blur"]}
        phx-focus={assigns[:"phx-focus"]}
        phx-keydown={assigns[:"phx-keydown"]}
        phx-keyup={assigns[:"phx-keyup"]}
      />
      <%= if @icon do %>
        <div class={"absolute #{if @icon_position == "left", do: "left-4", else: "right-4"} top-1/2 -translate-y-1/2 text-slate-400 group-hover:text-turquoise-600 transition-colors duration-300 pointer-events-none"}>
          {render_slot(@icon)}
        </div>
      <% end %>
      <%= if assigns[:inner_block] do %>
        {render_slot(@inner_block)}
      <% end %>
      <%= if @errors != [] do %>
        <div class="mt-2 flex items-center gap-2 text-red-600 font-bold text-sm animate-in slide-in-from-top-1">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <%= for error <- @errors do %>
            <span>{error}</span>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  @spec password_requirements(map()) :: Phoenix.LiveView.Rendered.t()
  def password_requirements(assigns) do
    ~H"""
    <div id="password-requirements" class="mt-2 text-xs sm:text-sm space-y-1.5 password-requirements">
      <p class="text-slate-500 font-bold uppercase tracking-wider text-[10px]">Password must contain:</p>
      <div class="grid grid-cols-1 sm:grid-cols-2 gap-2 sm:gap-x-4">
        <ul class="space-y-1">
          <li id="req-length" class="flex items-center text-slate-600 font-medium">
            <svg
              class="w-3.5 h-3.5 mr-1.5 flex-shrink-0"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <circle cx="12" cy="12" r="10" stroke-width="2.5" />
            </svg>
            <span class="text-xs">At least 8 characters</span>
          </li>
          <li id="req-lowercase" class="flex items-center text-slate-600 font-medium">
            <svg
              class="w-3.5 h-3.5 mr-1.5 flex-shrink-0"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <circle cx="12" cy="12" r="10" stroke-width="2.5" />
            </svg>
            <span class="text-xs">One lowercase letter</span>
          </li>
        </ul>
        <ul class="space-y-1">
          <li id="req-uppercase" class="flex items-center text-slate-600 font-medium">
            <svg
              class="w-3.5 h-3.5 mr-1.5 flex-shrink-0"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <circle cx="12" cy="12" r="10" stroke-width="2.5" />
            </svg>
            <span class="text-xs">One uppercase letter</span>
          </li>
          <li id="req-number" class="flex items-center text-slate-600 font-medium">
            <svg
              class="w-3.5 h-3.5 mr-1.5 flex-shrink-0"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <circle cx="12" cy="12" r="10" stroke-width="2.5" />
            </svg>
            <span class="text-xs">One number</span>
          </li>
        </ul>
      </div>
    </div>
    """
  end

  @spec standard_email_input(map()) :: Phoenix.LiveView.Rendered.t()
  def standard_email_input(assigns) do
    assigns = assign_new(assigns, :name, fn -> "email" end)
    assigns = assign_new(assigns, :placeholder, fn -> "you@example.com" end)
    assigns = assign_new(assigns, :required, fn -> true end)
    assigns = assign_new(assigns, :class, fn -> "" end)
    assigns = assign_new(assigns, :validate_on_blur, fn -> true end)
    assigns = assign_new(assigns, :value, fn -> "" end)
    assigns = Map.put_new(assigns, :errors, [])

    ~H"""
    <div>
      <TymeslotWeb.Shared.Auth.FormComponents.form_label for="email" text="Email Address" />
      <.auth_text_input
        id="email"
        name={@name}
        type="email"
        placeholder={@placeholder}
        required={@required}
        class={@class}
        errors={@errors}
        validate_on_blur={@validate_on_blur}
        value={@value}
        phx-change={assigns[:"phx-change"]}
        phx-blur={assigns[:"phx-blur"]}
        icon_position="right"
      >
        <:icon>
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M16 12a4 4 0 10-8 0 4 4 0 008 0zm0 0v1.5a2.5 2.5 0 005 0V12a9 9 0 10-9 9m4.5-1.206a8.959 8.959 0 01-4.5 1.206" />
          </svg>
        </:icon>
      </.auth_text_input>
    </div>
    """
  end

  # Helper function to determine appropriate autocomplete attribute
  defp get_autocomplete_for_input(assigns) do
    type = assigns[:type]
    name = assigns[:name]

    case type do
      "email" -> "email"
      "password" -> get_password_autocomplete(name)
      "text" -> get_text_autocomplete(name)
      _ -> "off"
    end
  end

  defp get_password_autocomplete(name) when is_binary(name) do
    cond do
      String.contains?(name, "current") -> "current-password"
      String.contains?(name, "password") -> "new-password"
      true -> "new-password"
    end
  end

  defp get_password_autocomplete(_), do: "new-password"

  defp get_text_autocomplete(name) when is_binary(name) do
    cond do
      String.contains?(name, "email") -> "email"
      String.contains?(name, "name") -> "name"
      String.contains?(name, "username") -> "username"
      true -> "off"
    end
  end

  defp get_text_autocomplete(_), do: "off"
end
