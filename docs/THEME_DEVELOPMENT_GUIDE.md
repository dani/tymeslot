# Theme Development Guide

This guide explains how to create new themes for Tymeslot.

## Architecture Overview

The theme system uses a centralized registry pattern that eliminates magic strings and provides type-safe theme access.

### Key Components

1. **Theme Registry** (`TymeslotWeb.Themes.Core.Registry`) - Central source of truth for all themes
2. **Theme Behaviour** (`TymeslotWeb.Themes.Core.Behaviour`) - Interface that all themes must implement
3. **Shared Context** (`TymeslotWeb.Themes.Shared.*`) - Shared helpers, handlers, and components
4. **Capability System** (`Tymeslot.ThemeCustomizations.Capability`) - Capability-based customization logic
5. **Dispatcher & Loader** - Systems for dynamically loading and dispatching theme actions

## Quick Start

### 1. Generate Theme Files (Preview)

```elixir
# This previews what files would be created (doesn't actually create them)
Tymeslot.ThemeTestHelpers.generate_theme_skeleton("aurora", "Aurora Theme")
```

### 2. Register Your Theme

Add to `apps/tymeslot/lib/tymeslot_web/themes/core/registry.ex`:

```elixir
aurora: %{
  id: "3",
  key: :aurora,
  name: "Aurora", 
  description: "Beautiful northern lights theme",
  module: TymeslotWeb.Themes.Aurora.Theme,
  css_file: "/assets/scheduling-theme-aurora.css",
  preview_image: "/images/themes/aurora-preview.png",
  features: %{
    supports_video_background: true,
    supports_image_background: true,
    supports_gradient_background: true,
    supports_custom_colors: true,
    flow_type: :multi_step,
    step_count: 4
  },
  status: :active
}
```

### 3. Implement Required Functions

Your theme module must implement the `TymeslotWeb.Themes.Core.Behaviour`:

```elixir
defmodule TymeslotWeb.Themes.Aurora.Theme do
  @behaviour TymeslotWeb.Themes.Core.Behaviour
  
  # Define your theme states (typically 4 steps)
  @impl true
  def states do
    %{
      overview: %{step: 1, next: :schedule, prev: nil},
      schedule: %{step: 2, next: :booking, prev: :overview},
      booking: %{step: 3, next: :confirmation, prev: :schedule},
      confirmation: %{step: 4, prev: nil}
    }
  end
  
  @impl true
  def css_file, do: "/assets/scheduling-theme-aurora.css"
  
  @impl true
  def components do
    %{
      overview: Aurora.OverviewComponent,
      schedule: Aurora.ScheduleComponent,
      booking: Aurora.BookingComponent,
      confirmation: Aurora.ConfirmationComponent
    }
  end
  
  @impl true
  def live_view_module, do: TymeslotWeb.Themes.Aurora.Scheduling.Live
  
  @impl true
  def theme_config, do: %{name: "Aurora", description: "Beautiful theme"}
  
  @impl true
  def validate_theme, do: :ok
  
  @impl true
  def initial_state_for_action(_), do: :overview
  
  @impl true
  def supports_feature?(_), do: true

  @impl true
  def render_meeting_action(assigns, action) do
    case action do
      :reschedule -> Aurora.Meeting.Reschedule.render(assigns)
      :cancel -> Aurora.Meeting.Cancel.render(assigns)
      :cancel_confirmed -> Aurora.Meeting.CancelConfirmed.render(assigns)
    end
  end
end
```

### 4. Test It Works

The production checklist automatically tests all registered themes:

```bash
# Run the production checklist
mix test test/tymeslot_web/live/themes/theme_production_checklist_test.exs
```

This will verify:
- All meeting types are displayed
- Theme handles edge cases (no meetings, long names)
- Basic mobile responsiveness
- Acceptable load times

## CSS Architecture

### New Modular Structure

Starting with the current codebase, themes now use a **modular CSS architecture** located in `assets/css/scheduling/themes/`:

```
assets/css/scheduling/themes/
├── shared/                    # Shared utilities
│   ├── reset.css             # CSS reset
│   ├── variables.css         # CSS custom properties
│   └── utilities.css         # Utility classes
├── quill/                     # Quill theme (glassmorphism)
│   ├── modules/
│   │   ├── foundation.css    # Base styles and typography
│   │   ├── glass-components.css # Glass morphism components
│   │   ├── scheduling-ui.css # Scheduling interface
│   │   ├── booking-flow.css  # Booking flow specific styles
│   │   └── responsive.css    # Responsive breakpoints
│   └── theme.css             # Main theme entry point
└── rhythm/                    # Rhythm theme (video backgrounds)
    ├── modules/
    │   ├── variables.css      # Theme-specific variables
    │   ├── base.css           # Base layout and typography
    │   ├── video.css          # Video background handling
    │   ├── slides.css         # Sliding interface
    │   ├── components.css     # UI components
    │   └── responsive.css     # Mobile responsive styles
    └── theme.css              # Main theme entry point
```

### Theme CSS Structure

Each theme's main CSS file (`theme.css`) follows this pattern:

```css
/* Import shared utilities */
@import "../../shared/reset.css";
@import "../../shared/variables.css";
@import "../../shared/utilities.css";

/* Import theme modules in dependency order */
@import "./modules/foundation.css";
@import "./modules/components.css";
@import "./modules/responsive.css";
```

### Creating Theme CSS

1. **Create theme directory**: `assets/css/scheduling/themes/your-theme/`
2. **Create main theme.css** that imports shared utilities and your modules
3. **Create modular CSS files** in a `modules/` subdirectory

**Note**: Theme CSS is completely separate from global app styles and uses only the modular architecture in `assets/css/scheduling/themes/`.

## Theme Requirements

### Must Have
- LiveView that renders without crashing
- CSS file in `assets/css/scheduling/themes/your-theme/theme.css`
- All 4 booking flow states: overview, calendar, booking_form, confirmation

### Nice to Have
- Mobile responsive design
- Smooth transitions
- Accessibility features

## Using Shared Logic and Helpers

The theme system provides centralized handlers and helpers in `TymeslotWeb.Themes.Shared.*` to ensure consistency and reduce duplication.

### LiveHelpers

`TymeslotWeb.Themes.Shared.LiveHelpers` provides common mounting and parameter handling logic:

```elixir
defmodule TymeslotWeb.Themes.MyTheme.Scheduling.Live do
  use TymeslotWeb, :live_view
  import TymeslotWeb.Themes.Shared.LiveHelpers

  @impl true
  def mount(params, session, socket) do
    socket = mount_scheduling_view(socket, params, :overview, &assign_initial_state/1, &setup_initial_state/3)
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    handle_scheduling_params(socket, params, :overview, &handle_param_updates/2, &handle_state_entry/3)
  end
end
```

### EventHandlers

`TymeslotWeb.Themes.Shared.EventHandlers` handles common UI events:

```elixir
@impl true
def handle_event("change_locale", %{"locale" => locale}, socket) do
  EventHandlers.handle_change_locale(socket, locale, PathHandlers)
end

@impl true
def handle_event("step_event", %{"step" => "overview", "event" => event, "data" => data}, socket) do
  EventHandlers.handle_overview_events(socket, String.to_existing_atom(event), data, callbacks(socket))
end
```

### InfoHandlers

`TymeslotWeb.Themes.Shared.InfoHandlers` handles async tasks like availability fetching:

```elixir
@impl true
def handle_info({:fetch_available_slots, date, duration, timezone}, socket) do
  InfoHandlers.handle_fetch_available_slots(socket, date, duration, timezone)
end

@impl true
def handle_info({ref, {:ok, availability_map}}, socket) when is_reference(ref) do
  InfoHandlers.handle_availability_ok(socket, ref, availability_map)
end
```

### LocalizationHelpers

Always use `TymeslotWeb.Themes.Shared.LocalizationHelpers` for formatting dates, times, and durations to ensure they respect the user's locale:

```elixir
alias TymeslotWeb.Themes.Shared.LocalizationHelpers

# Result: "Wednesday, 15 March 2024 at 14:30 EST"
LocalizationHelpers.format_booking_datetime(@date, @time, @timezone)

# Result: "30 minutes" or "1 hour"
LocalizationHelpers.format_duration("30min")
```

### PathHandlers

Use `TymeslotWeb.Themes.Shared.PathHandlers` for internal navigation to preserve locale and theme settings:

```elixir
# Build a path that includes ?locale=... and ?theme=...
back_path = PathHandlers.build_path_with_locale(socket, socket.assigns.locale)
```

## CSS Architecture

Themes use a **modular CSS architecture** located in `assets/css/scheduling/themes/`.

### Shared Utilities
- `assets/css/scheduling/shared/reset.css`
- `assets/css/scheduling/shared/variables.css`
- `assets/css/scheduling/shared/utilities.css`

### Theme Structure
Each theme should have its own directory with a `theme.css` entry point and a `modules/` subdirectory for specific styles (foundation, components, responsive, etc.).

## Theme Customization & Capabilities

Themes define their capabilities in the registry, which are then used by the `Tymeslot.ThemeCustomizations.Capability` module to provide valid customization options.

### Supported Features
- `supports_video_background`
- `supports_image_background`
- `supports_gradient_background`
- `supports_custom_colors`

The capability system automatically generates the necessary CSS variables based on these flags and user selections.

## Meeting Management Integration

Each theme must implement `render_meeting_action/2` to provide its own UI for:
- `:reschedule`
- `:cancel`
- `:cancel_confirmed`

These components should reside in `lib/tymeslot_web/themes/[theme_name]/meeting/`.

## Common Patterns

### Modular LiveView
Keep the theme LiveView thin by using:
1. **StateMachine**: To manage state transitions and validation.
2. **Wrapper**: A functional component that provides the common layout (background, language switcher, etc.).
3. **Step Components**: Separate LiveComponents for `overview`, `schedule`, `booking`, and `confirmation`.


## Theme Customization System

### Background Options

Themes can offer users four types of backgrounds:

1. **Gradients** - CSS gradients defined in `ThemeCustomizationSchema.gradient_presets/0`
2. **Solid Colors** - User-selected hex colors
3. **Preset Images/Videos** - Pre-defined options stored in `/priv/static/`
4. **Custom Uploads** - User-uploaded images or videos

### Preset Assets Structure

Preset assets are organized in the static directory:

```
priv/static/
├── images/ui/backgrounds/       # Preset background images
│   ├── artistic-studio.webp
│   ├── ocean-sunset.webp
│   └── ...
├── videos/backgrounds/          # Preset background videos
│   ├── blue-wave-desktop.webm   # Desktop WebM
│   ├── blue-wave-desktop.mp4    # Desktop MP4
│   ├── blue-wave-mobile.mp4     # Mobile optimized
│   ├── blue-wave-low.mp4        # Low bandwidth
│   └── ...
└── images/ui/posters/           # Video posters (thumbnails)
    ├── blue-wave-thumbnail.jpg
    └── rhythm-background-poster.webp
```

### Defining Presets

Presets are defined in `database_schemas/theme_customization_schema.ex`.

**Available Video Presets**:
- `"preset:rhythm-default"`
- `"preset:blue-wave"`
- `"preset:dancing-girl"`
- `"preset:leaves"`
- `"preset:light-green"`
- `"preset:space"`

**Available Image Presets**:
- `"preset:artistic-studio"`
- `"preset:ocean-sunset"`
- `"preset:elegant-still-life"`

## Advanced Video Features

### Video Container Rendering

For themes with video backgrounds, use `TymeslotWeb.Themes.Shared.Customization.Video` to render an optimized video container:

```elixir
alias TymeslotWeb.Themes.Shared.Customization.Video

# In your theme wrapper
<div class="video-container">
  <%= Video.render_video_container(@theme_key, assigns) %>
</div>
```

This helper automatically handles:
- **Responsive Sources**: Loading different qualities based on screen size
- **Crossfading**: Smooth transitions for themes that support it
- **Fallbacks**: Displaying a gradient while the video is loading

### Multi-Quality Video System

The video system automatically selects the best quality based on the filename suffix:
- `-desktop.webm`: Best quality for modern browsers
- `-desktop.mp4`: Standard desktop quality
- `-mobile.mp4`: Optimized for tablets and phones
- `-low.mp4`: Low bandwidth fallback

## Multi-Lingual Support

### Overview

Tymeslot booking pages support internationalization (i18n) with automatic browser language detection.

**Supported Languages:**
- 🇬🇧 English (`en`)
- 🇩🇪 German (`de`)
- 🇺🇦 Ukrainian (`uk`)

### Language Switcher Integration

The language switcher is typically integrated via the theme's wrapper:

```heex
<.language_switcher
  locale={@locale}
  locales={TymeslotWeb.Themes.Shared.LocaleHandler.get_locales_with_metadata()}
  dropdown_open={@language_dropdown_open}
  theme={@theme_key}
/>
```

### Path Generation & Localization

Always use `PathHandlers` for internal links to preserve the user's locale:

```elixir
# Path with current locale and theme preserved
path = PathHandlers.build_path_with_locale(socket, @locale)
```

Use `LocalizationHelpers` for all date and time formatting:

```elixir
# Localized: "Wednesday, 15 March 2024"
LocalizationHelpers.format_date(@selected_date)
```


## Don't Over-Engineer

- Start with the simplest theme that works
- Copy from existing themes
- Focus on user experience, not code perfection
- The production checklist tells you if it's ready