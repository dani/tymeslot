defmodule Tymeslot.Payments.Pricing do
  @moduledoc """
  Helper functions for pricing display and calculations.
  """

  @doc """
  Formats a price in cents to a currency string.
  """
  @spec format_price(integer()) :: String.t()
  def format_price(cents) when is_integer(cents) do
    currency = Application.get_env(:tymeslot, :currency, "eur")
    symbol = currency_symbol(currency)

    sign = if cents < 0, do: "-", else: ""
    abs_cents = abs(cents)
    major = div(abs_cents, 100)
    minor = abs_cents |> rem(100) |> Integer.to_string() |> String.pad_leading(2, "0")

    "#{sign}#{symbol}#{major}.#{minor}"
  end

  defp currency_symbol(currency) when is_atom(currency) do
    currency_symbol(Atom.to_string(currency))
  end

  defp currency_symbol(currency) when is_binary(currency) do
    case String.downcase(String.trim(currency)) do
      "eur" -> "€"
      "usd" -> "$"
      "gbp" -> "GBP "
      code -> "#{String.upcase(code)} "
    end
  end

  @doc """
  Gets the Pro monthly price in cents.
  """
  @spec pro_monthly_cents() :: integer()
  def pro_monthly_cents do
    Application.get_env(:tymeslot, :pricing)[:pro_monthly_cents]
  end

  @doc """
  Gets the Pro annual price in cents.
  """
  @spec pro_annual_cents() :: integer()
  def pro_annual_cents do
    Application.get_env(:tymeslot, :pricing)[:pro_annual_cents]
  end

  @doc """
  Calculates annual savings.
  """
  @spec annual_savings_cents() :: integer()
  def annual_savings_cents do
    monthly = pro_monthly_cents()
    annual = pro_annual_cents()
    monthly * 12 - annual
  end
end
