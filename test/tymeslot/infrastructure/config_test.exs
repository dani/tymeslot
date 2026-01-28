defmodule Tymeslot.Infrastructure.ConfigTest do
  use ExUnit.Case, async: true

  alias Tymeslot.Infrastructure.Config
  alias Tymeslot.Infrastructure.AppConfig

  describe "app_config_module/0" do
    test "returns default module when not configured" do
      assert Config.app_config_module() == AppConfig
    end

    test "returns default module when configured module is not loaded" do
      Application.put_env(:tymeslot, :app_config_module, NonExistentModule)
      on_exit(fn -> Application.delete_env(:tymeslot, :app_config_module) end)

      assert Config.app_config_module() == AppConfig
    end
  end

  describe "AppConfig default values" do
    test "saas_mode? returns configured value" do
      # In test environment, this might be true or false depending on config/test.exs
      expected = Application.get_env(:tymeslot, :saas_mode, false)
      assert AppConfig.saas_mode?() == expected
    end

    test "enforce_legal_agreements? returns configured value" do
      expected = Application.get_env(:tymeslot, :enforce_legal_agreements, false)
      assert AppConfig.enforce_legal_agreements?() == expected
    end

    test "site_home_path returns configured value" do
      expected = Application.get_env(:tymeslot, :site_home_path, "/dashboard")
      assert AppConfig.site_home_path() == expected
    end
  end

  describe "Config delegation" do
    test "saas_mode? delegates to app_config_module" do
      # Since we can't easily mock the module without Mox or similar, 
      # and we've verified app_config_module returns AppConfig,
      # we just verify it returns the expected default.
      assert Config.saas_mode?() == AppConfig.saas_mode?()
    end

    test "enforce_legal_agreements? delegates to app_config_module" do
      assert Config.enforce_legal_agreements?() == AppConfig.enforce_legal_agreements?()
    end

    test "site_home_path delegates to app_config_module" do
      assert Config.site_home_path() == AppConfig.site_home_path()
    end
  end
end
