defmodule Tymeslot.CoreSaasSeparationTest do
  use ExUnit.Case, async: true

  @moduledoc """
  Ensures the core application maintains one-way visibility with the SaaS overlay.
  Core must be blind to SaaS - it should have zero knowledge of the tymeslot_saas application.
  """

  describe "core production code isolation" do
    test "lib files have no TymeslotSaas module references" do
      lib_path = "apps/tymeslot/lib"

      for source <- Path.wildcard("#{lib_path}/**/*.ex") do
        content = File.read!(source)

        assert not String.contains?(content, "TymeslotSaas"),
               "Found TymeslotSaas reference in core: #{source}\n" <>
                 "Core must be blind to SaaS implementation. Use feature flags instead."
      end
    end

    test "config files have no hardcoded TymeslotSaas worker references" do
      config_path = "config"

      for source <- Path.wildcard("#{config_path}/**/*.exs") do
        content = File.read!(source)

        # We allow TymeslotSaas in tests and comments, but not in actual config
        lines = String.split(content, "\n")

        lines
        |> Enum.with_index(1)
        |> Enum.each(fn {line, index} ->
          # Skip test files and comment lines
          unless String.contains?(source, "test.exs") or
                   String.starts_with?(String.trim_leading(line), "#") do
            # Check for direct module references (not in strings)
            if String.contains?(line, "TymeslotSaas.Workers") and not String.contains?(line, "\"") do
              raise """
              Found hardcoded TymeslotSaas.Workers reference in config: #{source}:#{index}
              #{line}

              SaaS-specific Oban jobs should be configured in the SaaS app's runtime config,
              not in the core config. Use Oban config merging to add SaaS jobs.
              """
            end
          end
        end)
      end
    end

    test ":tymeslot_saas atom is not referenced in core code" do
      lib_path = "apps/tymeslot/lib"

      for source <- Path.wildcard("#{lib_path}/**/*.ex") do
        content = File.read!(source)

        # Check for :tymeslot_saas atoms (excluding comments and strings)
        assert not String.contains?(content, ":tymeslot_saas"),
               "Found :tymeslot_saas atom reference in core: #{source}\n" <>
                 "Core must not reference the SaaS application directly."
      end
    end
  end

  describe "SaaS integration points" do
    test "SaaS-to-core dependency is allowed in integration tests" do
      # This test documents that SaaS CAN reference core via configuration
      # Core configuration can be overridden by SaaS via feature flags and config merging
      saas_mode = Application.get_env(:tymeslot, :saas_mode, false)

      # In test environment with SaaS loaded, this should be true
      if saas_mode do
        router = Application.get_env(:tymeslot, :router)

        assert router == TymeslotSaasWeb.Router,
               "Router should be SaaS router when SaaS mode is active"
      end
    end
  end
end
