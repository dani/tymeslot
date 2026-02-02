# Tymeslot Test Suite Guide

A comprehensive guide to writing and maintaining tests in the Tymeslot project.

## Table of Contents

- [Quick Start](#quick-start)
- [Test Infrastructure](#test-infrastructure)
- [Common Patterns](#common-patterns)
- [Best Practices](#best-practices)
- [Core vs SaaS Testing](#core-vs-saas-testing)
- [Running Tests](#running-tests)
- [Troubleshooting](#troubleshooting)

## Quick Start

### Writing Your First Test

1. **Choose the appropriate case template:**

   ```elixir
   # For business logic tests with database access
   use Tymeslot.DataCase, async: true

   # For HTTP controller tests
   use TymeslotWeb.ConnCase, async: false

   # For LiveView tests
   use TymeslotWeb.LiveCase, async: false

   # For OAuth integration tests (needs RateLimiter)
   use Tymeslot.OAuthIntegrationCase, async: false
   ```

2. **Import test helpers:**

   ```elixir
   # One-stop import for all common helpers
   use Tymeslot.TestHelpers

   # Or with domain-specific helpers
   use Tymeslot.TestHelpers, payment: true, email: true
   ```

3. **Set up mocks:**

   ```elixir
   setup :verify_on_exit!

   setup do
     setup_all_mocks()  # Happy path defaults for all services
   end
   ```

### Complete Example

```elixir
defmodule Tymeslot.BookingFlowTest do
  use Tymeslot.DataCase, async: true
  use Tymeslot.TestHelpers, email: true

  setup :verify_on_exit!
  setup do
    setup_all_mocks()
  end

  test "creates booking with video link and sends email" do
    user = create_user_fixture(%{email: "organizer@example.com"})
    profile = insert(:profile, user: user)

    attrs = %{
      attendee_email: "attendee@example.com",
      start_time: DateTime.add(DateTime.utc_now(), 3600, :second),
      duration_minutes: 30
    }

    assert {:ok, meeting} = create_meeting(profile, attrs)
    assert meeting.video_link =~ "mirotalk.com"

    eventually(fn ->
      assert_email_sent(to: "attendee@example.com")
    end)
  end
end
```

## Test Infrastructure

### Case Templates

#### DataCase (`test/support/data_case.ex`)

For tests requiring database access. Sets up:
- Ecto Sandbox for test isolation
- Circuit breaker resets
- Availability cache clearing
- Rate limiter clearing

```elixir
use Tymeslot.DataCase, async: true
```

**When to use:** Business logic tests, context module tests, schema tests.

#### ConnCase (`test/support/conn_case.ex`)

For HTTP controller tests. Provides:
- Phoenix.ConnTest helpers
- Session setup
- Sandbox integration

```elixir
use TymeslotWeb.ConnCase, async: false  # Usually sync for session state
```

**When to use:** Controller tests, plug tests, HTTP endpoint tests.

#### LiveCase (`test/support/live_case.ex`)

For LiveView tests. Includes:
- Phoenix.LiveViewTest helpers
- Polling utilities with `eventually/2`

```elixir
use TymeslotWeb.LiveCase, async: false
```

**When to use:** LiveView component tests, real-time UI tests.

#### OAuthIntegrationCase (`test/support/oauth_integration_case.ex`)

For OAuth flow tests. Manages:
- RateLimiter process lifecycle
- AccountLockout process lifecycle
- Automatic cleanup on test exit

```elixir
use Tymeslot.OAuthIntegrationCase, async: false
```

**When to use:** OAuth callback tests, authentication flow tests.

### Test Helpers

The test suite includes **22 helper modules** with over **2,500 lines** of utilities.

#### Centralized Import

```elixir
use Tymeslot.TestHelpers

# This imports:
# - Factory (ExMachina)
# - TestFixtures (complex scenarios)
# - TestMocks (Mox setup)
# - ConfigTestHelpers (config management)
# - Eventually (polling helper)
# - TestAssertions (behavioral checks)
# - AuthTestHelpers (by default)
```

**Optional domain helpers:**

```elixir
use Tymeslot.TestHelpers, [
  auth: true,           # Default: true
  payment: true,        # Opt-in
  email: true,          # Opt-in
  availability: true,   # Opt-in
  theme: true,          # Opt-in
  worker: true          # Opt-in
]
```

### Factory vs Fixtures

**Use Factory** for simple data creation without side effects:

```elixir
# Factory (ExMachina) - fast, no database triggers
user = insert(:user)
meeting = build(:meeting, user: user)
```

**Use Fixtures** for complex scenarios with business logic:

```elixir
# Fixture - runs full domain logic, sets up associations
user = create_user_fixture(%{email: "test@example.com"})
meeting = create_meeting_fixture(%{user_id: user.id})
```

**Available factories** (`test/support/factory.ex`):
- `:user`, `:unverified_user`
- `:meeting`, `:past_meeting`, `:future_meeting`, `:cancelled_meeting`
- `:profile`, `:availability_profile`, `:availability_day`
- `:calendar_integration`, `:video_integration`
- `:session`, `:webhook_event`

**Available fixtures** (`test/support/test_fixtures.ex`):
- `create_user_fixture/1`
- `create_meeting_fixture/1`
- `create_session_fixture/1`
- `create_calendar_scenario/2`
- `create_timezone_test_fixtures/0`
- `create_conflicting_meetings/1`
- `create_rescheduling_fixture/0`

## Common Patterns

### 1. Testing Async Operations

**❌ DON'T:** Use fixed sleeps

```elixir
# Brittle: might be too short or unnecessarily long
test "updates state" do
  trigger_update()
  Process.sleep(100)
  assert updated?()
end
```

**✅ DO:** Use `eventually/2` helper

```elixir
# Reliable: polls until condition is true or timeout
test "updates state" do
  trigger_update()
  eventually(fn -> assert updated?() end, timeout: 1000)
end
```

**`eventually/2` options:**
- `:timeout` - Max wait time in ms (default: 1000)
- `:interval` - Polling interval in ms (default: 50)
- `:message` - Custom error message on timeout

### 2. Managing Config Changes

**❌ DON'T:** Manually save and restore config

```elixir
test "with feature disabled" do
  prev = Application.get_env(:tymeslot, :feature_flag)
  Application.put_env(:tymeslot, :feature_flag, false)

  on_exit(fn ->
    Application.put_env(:tymeslot, :feature_flag, prev)
  end)

  # test logic
end
```

**✅ DO:** Use `with_config/3` helper

```elixir
test "with feature disabled" do
  with_config(:tymeslot, feature_flag: false)
  # test logic - automatic cleanup
end

# Multiple config values
test "with custom settings" do
  with_config(:tymeslot, [
    feature_flag: false,
    api_key: "test_key",
    timeout: 5000
  ])
  # test logic
end
```

### 3. Setting Up Mocks

**For complete booking flows:**

```elixir
setup do
  setup_all_mocks()  # Video, calendar, email all succeed
end
```

**For specific services:**

```elixir
setup do
  setup_calendar_mocks(
    events: [
      mock_calendar_event(
        summary: "Existing Meeting",
        start_time: ~U[2024-01-15 10:00:00Z],
        end_time: ~U[2024-01-15 10:30:00Z]
      )
    ]
  )
end
```

**For error scenarios:**

```elixir
setup do
  setup_error_mocks(:mirotalk_failure)
end

test "handles video provider failure gracefully" do
  assert {:error, _} = create_meeting_with_video()
  # Meeting should still be created, just without video
end
```

**Combining default mocks with overrides:**

```elixir
setup do
  setup_all_mocks()  # Start with happy path

  # Override specific service for this test suite
  setup_calendar_mocks(result: {:error, "Calendar unavailable"})
end
```

### 4. Behavioral Assertions

**❌ DON'T:** Assert on exact UI text (brittle)

```elixir
assert render(view) =~ "Meeting Successfully Created"
```

**✅ DO:** Assert on behavior and data presence

```elixir
assert_meeting_created(attendee_email: "test@example.com")
assert_email_sent(to: "test@example.com", subject: "Appointment Confirmed")
assert_form_has_fields(view, "form", ["name", "email", "phone"])
```

### 5. Testing LiveView Updates

```elixir
test "shows success message after form submission" do
  {:ok, view, _html} = live(conn, "/path")

  view
  |> element("form")
  |> render_submit(%{field: "value"})

  eventually(fn ->
    assert render(view) =~ "Success"
  end)
end
```

### 6. Testing with User Authentication

```elixir
test "authenticated user can access dashboard", %{conn: conn} do
  user = create_user_fixture()

  conn =
    conn
    |> log_in_user(user)
    |> get("/dashboard")

  assert html_response(conn, 200)
end
```

## Best Practices

### Do's

✅ **Use async: true** when possible for faster test suites
✅ **Import only what you need** or use `use Tymeslot.TestHelpers`
✅ **Set up mocks in setup blocks** for consistency
✅ **Use `verify_on_exit!`** to catch unexpected mock calls
✅ **Test behavior, not implementation** details
✅ **Use factories** for simple data, **fixtures** for complex scenarios
✅ **Document intentional `Process.sleep`** in concurrency tests
✅ **Use `eventually/2`** for async operations
✅ **Use `with_config/3`** for temporary config changes

### Don'ts

❌ **Don't use `Process.sleep`** except in concurrency/robustness tests
❌ **Don't manually save/restore config** - use `with_config/3`
❌ **Don't assert on exact UI text** - test behavior instead
❌ **Don't create unnecessary test data** - use minimal fixtures
❌ **Don't use `:meck`** - use Mox for consistency
❌ **Don't test implementation details** - test public APIs
❌ **Don't forget `on_exit` cleanup** - or better, use helpers that do it

### Process.sleep Guidelines

**When Process.sleep IS appropriate:**

1. **Concurrency tests** - Creating race conditions
2. **Lock tests** - Holding locks to test serialization
3. **Expiration tests** - Testing time-based expiration
4. **Robustness tests** - Testing cleanup after crashes

**Always document why:**

```elixir
# Intentional sleep: Hold lock to simulate long-running operation
# and verify that concurrent access is properly serialized
Process.sleep(100)
```

**When to use `eventually/2` instead:**

- Waiting for database updates
- Waiting for cache updates
- Waiting for LiveView renders
- Waiting for background jobs
- Waiting for email delivery

## Core vs SaaS Testing

### Architectural Boundary

**Core (`apps/tymeslot`) is standalone:**
- Core tests must NOT import `TymeslotSaas.*` modules
- Core tests must NOT depend on SaaS-specific config
- Core tests must NOT assume subscription features exist

**SaaS (`apps/tymeslot_saas`) wraps Core:**
- SaaS tests CAN import Core helpers
- SaaS tests CAN use Core mocks
- SaaS tests CAN configure Core via feature flags

### SaaS Test Configuration

SaaS tests automatically configure Core features:

```elixir
# apps/tymeslot_saas/test/support/conn_case.ex
setup do
  # Uses ConfigTestHelpers for automatic cleanup
  setup_config(:tymeslot, [
    show_marketing_links: true,
    logo_links_to_marketing: true,
    router: TymeslotSaasWeb.Router
  ])
end
```

### Testing Core in Isolation

```bash
# Run only Core tests
mix test apps/tymeslot

# Verify Core has no SaaS dependencies
grep -r "TymeslotSaas" apps/tymeslot/test/
# Should return no matches (except in comments)
```

### Testing SaaS with Core

```elixir
# SaaS tests can use Core factories
use Tymeslot.TestHelpers

test "subscription portal" do
  user = create_user_fixture()  # From Core
  # ... SaaS-specific logic
end
```

## Running Tests

### All Tests

```bash
mix test
```

### Specific App

```bash
mix test apps/tymeslot
mix test apps/tymeslot_saas
```

### Specific File

```bash
mix test apps/tymeslot/test/tymeslot/auth_test.exs
```

### Specific Test

```bash
mix test apps/tymeslot/test/tymeslot/auth_test.exs:42
```

### With Coverage

```bash
mix coveralls.html
open cover/excoveralls.html
```

### Excluding Slow Tests

```bash
# Exclude integration tests
mix test --exclude calendar_integration

# Exclude OAuth tests
mix test --exclude oauth_integration
```

### Parallel Execution

Tests with `async: true` run in parallel. Control max parallel cases:

```bash
# Limit to 4 parallel test cases
MIX_TEST_PARTITION=4 mix test
```

### Database Pool Size

For CI or parallel testing:

```bash
# Increase pool size for better concurrency
TEST_DB_POOL_SIZE=10 mix test
```

## Troubleshooting

### Test Flakiness

**Symptom:** Test passes sometimes, fails other times

**Common Causes:**

1. **Using `Process.sleep` instead of `eventually/2`**
   - Fix: Replace sleeps with `eventually(fn -> assert condition end)`

2. **Shared state between tests**
   - Fix: Ensure `async: false` or proper cleanup in `on_exit`

3. **Race conditions in setup**
   - Fix: Use `eventually/2` in setup blocks too

4. **Process leakage**
   - Fix: Use `start_supervised!` instead of manual `start_link`

### Mock Verification Failures

**Symptom:** `Mox.UnexpectedCallError` or `Mox.VerificationError`

**Solutions:**

1. **Add `setup :verify_on_exit!`** at top of test module
2. **Use `stub` instead of `expect`** if calls are optional
3. **Check call count** in `expect(Mock, :func, 2, fn -> ... end)`

### Database Connection Errors

**Symptom:** "Could not checkout connection" or "connection not available"

**Solutions:**

1. **Use `async: false`** if tests share state
2. **Increase pool size:** `TEST_DB_POOL_SIZE=10 mix test`
3. **Check for connection leaks** - ensure `Repo.checkout` is wrapped

### Config Not Resetting

**Symptom:** Config changes persist between tests

**Solution:**

Use `ConfigTestHelpers`:

```elixir
# ❌ Before (manual)
previous = Application.get_env(:tymeslot, :key)
Application.put_env(:tymeslot, :key, value)
on_exit(fn -> Application.put_env(:tymeslot, :key, previous) end)

# ✅ After (automatic)
with_config(:tymeslot, key: value)
```

### Slow Test Suite

**Strategies:**

1. **Use `async: true`** where possible
2. **Minimize factory usage** - use `build` instead of `insert`
3. **Use `setup_all_mocks()`** instead of individual setups
4. **Avoid unnecessary database queries** in setup
5. **Profile slow tests:** Look for tests >1 second

---

## Quick Reference

### Import Shortcuts

```elixir
use Tymeslot.TestHelpers                    # Everything
use Tymeslot.TestHelpers, payment: true     # + Payment helpers
use Tymeslot.TestHelpers, email: true       # + Email helpers
```

### Mock Setup

```elixir
setup_all_mocks()                           # Happy path
setup_error_mocks(:mirotalk_failure)        # Error scenario
setup_calendar_mocks(events: [...])         # Custom events
```

### Config Management

```elixir
with_config(:tymeslot, key: value)          # Single value
with_config(:tymeslot, [key1: v1, key2: v2]) # Multiple values
```

### Async Operations

```elixir
eventually(fn -> assert condition end)                      # Default 1s
eventually(fn -> assert condition end, timeout: 5000)       # Custom timeout
eventually(fn -> assert condition end, message: "Error")    # Custom message
```

### Data Creation

```elixir
insert(:user)                               # Factory (fast)
create_user_fixture(%{email: "x@y.com"})    # Fixture (complete)
```

---

**Last updated:** 2025-01-15

**Maintainers:** For questions or improvements, please open an issue or PR.
