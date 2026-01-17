defmodule TymeslotWeb.Components.CoreComponents.Forms do
  @moduledoc "Form components extracted from CoreComponents."
  use Phoenix.Component

  # ========== FORM ELEMENTS ==========

  @doc """
  Renders a form field with label and error handling.
  """
  attr :form, :any, required: true
  attr :field, :atom, required: true
  attr :label, :string, required: true
  attr :type, :string, default: "text"
  attr :placeholder, :string, default: ""
  attr :required, :boolean, default: false
  attr :touched_fields, :any, default: []
  attr :rest, :global

  @spec form_field(map()) :: Phoenix.LiveView.Rendered.t()
  def form_field(assigns) do
    field_errors = get_field_errors(assigns.form, assigns.field, assigns.touched_fields)

    assigns = assign(assigns, :field_errors, field_errors)

    ~H"""
    <div class="form-field">
      <label for={Phoenix.HTML.Form.input_id(@form, @field)} class="form-field__label">
        {@label}
        <%= if @required do %>
          <span class="text-red-500">*</span>
        <% end %>
      </label>

      <input
        type={@type}
        id={Phoenix.HTML.Form.input_id(@form, @field)}
        name={Phoenix.HTML.Form.input_name(@form, @field)}
        value={Phoenix.HTML.Form.input_value(@form, @field)}
        placeholder={@placeholder}
        class={[
          "form-field__input",
          @field_errors != [] && "form-field__input--error"
        ]}
        {@rest}
      />

      <.field_error errors={@field_errors} field={@field} />
    </div>
    """
  end

  @doc """
  Renders a textarea field with label and error handling.
  """
  attr :form, :any, required: true
  attr :field, :atom, required: true
  attr :label, :string, required: true
  attr :placeholder, :string, default: ""
  attr :rows, :integer, default: 4
  attr :required, :boolean, default: false
  attr :touched_fields, :any, default: []
  attr :rest, :global

  @spec form_textarea(map()) :: Phoenix.LiveView.Rendered.t()
  def form_textarea(assigns) do
    field_errors = get_field_errors(assigns.form, assigns.field, assigns.touched_fields)

    assigns = assign(assigns, :field_errors, field_errors)

    ~H"""
    <div class="form-field">
      <label for={Phoenix.HTML.Form.input_id(@form, @field)} class="form-field__label">
        {@label}
        <%= if @required do %>
          <span class="text-red-500">*</span>
        <% end %>
      </label>

      <textarea
        id={Phoenix.HTML.Form.input_id(@form, @field)}
        name={Phoenix.HTML.Form.input_name(@form, @field)}
        placeholder={@placeholder}
        rows={@rows}
        class={[
          "form-field__input",
          @field_errors != [] && "form-field__input--error"
        ]}
        {@rest}
      ><%= Phoenix.HTML.Form.input_value(@form, @field) %></textarea>

      <.field_error errors={@field_errors} field={@field} />
    </div>
    """
  end

  @doc """
  Renders a field error message.
  """
  attr :errors, :list, default: []
  attr :field, :atom, required: true

  @spec field_error(map()) :: Phoenix.LiveView.Rendered.t()
  def field_error(assigns) do
    ~H"""
    <%= if Enum.any?(@errors) do %>
      <div class="field-error">
        {Enum.join(@errors, ", ")}
      </div>
    <% end %>
    """
  end

  defp get_field_errors(form, field, touched_fields) do
    if field in touched_fields do
      form.errors
      |> Keyword.get_values(field)
      |> Enum.map(fn
        {msg, _opts} -> msg
        msg when is_binary(msg) -> msg
        other -> inspect(other)
      end)
    else
      []
    end
  end
end
