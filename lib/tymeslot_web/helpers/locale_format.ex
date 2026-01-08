defmodule TymeslotWeb.Helpers.LocaleFormat do
  @moduledoc """
  Provides locale-aware formatting for dates, times, and durations.
  Handles different formatting conventions for different languages.
  """

  @doc """
  Formats a date according to locale conventions.
  - en: January 15, 2026
  - de: 15. Januar 2026
  - uk: 15 січня 2026
  """
  def format_date(date, locale) do
    case locale do
      "en" -> Calendar.strftime(date, "%B %d, %Y")
      "de" -> Calendar.strftime(date, "%d. %B %Y")
      "uk" -> Calendar.strftime(date, "%d %B %Y")
      _ -> Calendar.strftime(date, "%B %d, %Y")
    end
  end

  @doc """
  Formats time according to locale conventions.
  - en: 02:30 PM (12-hour)
  - de: 14:30 (24-hour)
  - uk: 14:30 (24-hour)
  """
  def format_time(time, locale) do
    case locale do
      "en" -> Calendar.strftime(time, "%I:%M %p")
      "de" -> Calendar.strftime(time, "%H:%M")
      "uk" -> Calendar.strftime(time, "%H:%M")
      _ -> Calendar.strftime(time, "%I:%M %p")
    end
  end

  @doc """
  Returns localized month names (full).
  """
  def get_month_names(locale) do
    case locale do
      "de" ->
        [
          "Januar",
          "Februar",
          "März",
          "April",
          "Mai",
          "Juni",
          "Juli",
          "August",
          "September",
          "Oktober",
          "November",
          "Dezember"
        ]

      "uk" ->
        [
          "Січень",
          "Лютий",
          "Березень",
          "Квітень",
          "Травень",
          "Червень",
          "Липень",
          "Серпень",
          "Вересень",
          "Жовтень",
          "Листопад",
          "Грудень"
        ]

      _ ->
        [
          "January",
          "February",
          "March",
          "April",
          "May",
          "June",
          "July",
          "August",
          "September",
          "October",
          "November",
          "December"
        ]
    end
  end

  @doc """
  Returns localized weekday names.
  Format can be :full, :short, or :narrow.
  """
  def get_weekday_names(locale, format \\ :short) do
    case {locale, format} do
      {"de", :full} ->
        ["Sonntag", "Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag"]

      {"de", :short} ->
        ["So", "Mo", "Di", "Mi", "Do", "Fr", "Sa"]

      {"de", :narrow} ->
        ["S", "M", "D", "M", "D", "F", "S"]

      {"uk", :full} ->
        ["Неділя", "Понеділок", "Вівторок", "Середа", "Четвер", "П'ятниця", "Субота"]

      {"uk", :short} ->
        ["Нд", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"]

      {"uk", :narrow} ->
        ["Н", "П", "В", "С", "Ч", "П", "С"]

      {_, :full} ->
        ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

      {_, :short} ->
        ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

      {_, :narrow} ->
        ["S", "M", "T", "W", "T", "F", "S"]
    end
  end

  @doc """
  Formats a month name based on month number (1-12) and locale.
  """
  def format_month_name(month_num, locale) when month_num in 1..12 do
    month_names = get_month_names(locale)
    Enum.at(month_names, month_num - 1)
  end

  def format_month_name(_, _locale), do: ""

  @doc """
  Formats a weekday name based on weekday number (1=Monday, 7=Sunday) and locale.
  """
  def format_weekday_name(weekday_num, locale, format \\ :short)

  def format_weekday_name(weekday_num, locale, format)
      when weekday_num in 1..7 do
    weekday_names = get_weekday_names(locale, format)
    # Convert ISO weekday (1=Monday) to index (0=Sunday)
    index = if weekday_num == 7, do: 0, else: weekday_num
    Enum.at(weekday_names, index)
  end

  def format_weekday_name(_, _locale, _format), do: ""
end
