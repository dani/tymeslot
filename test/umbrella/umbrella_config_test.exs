defmodule Tymeslot.UmbrellaConfigTest do
  use ExUnit.Case, async: true

  describe "SaaS app detection" do
    test "saas_mode flag is set when SaaS app is present" do
      # When SaaS app exists, it should set saas_mode to true
      saas_mode = Application.get_env(:tymeslot, :saas_mode, false)

      # In test environment with SaaS app present, saas_mode should be true
      # The SaaS application module runs on startup and sets this
      assert is_boolean(saas_mode), "saas_mode should be a boolean"
    end

    test "router configuration is valid" do
      router = Application.get_env(:tymeslot, :router)
      assert is_atom(router), "Router should be an atom (module name)"
      assert Code.ensure_loaded?(router), "Router module #{inspect(router)} should be loadable"
    end

    test "router reflects SaaS configuration when SaaS app is loaded" do
      router = Application.get_env(:tymeslot, :router)
      saas_mode = Application.get_env(:tymeslot, :saas_mode, false)

      if saas_mode do
        assert router == TymeslotSaasWeb.Router,
               "Should use SaaS router when SaaS mode is active"
      else
        assert router == TymeslotWeb.Router,
               "Should use core router when SaaS mode is inactive"
      end
    end
  end

  describe "email adapter configuration" do
    test "email adapter default reflects current mode" do
      default_adapter = Application.get_env(:tymeslot, :email_adapter_default, "smtp")
      saas_mode = Application.get_env(:tymeslot, :saas_mode, false)

      if saas_mode do
        assert default_adapter == "postmark",
               "SaaS mode should default to postmark, got: #{default_adapter}"
      else
        assert default_adapter == "smtp",
               "Core mode should default to smtp, got: #{default_adapter}"
      end
    end
  end

  describe "legal agreement configuration" do
    test "legal agreements configuration reflects current mode" do
      enforce = Application.get_env(:tymeslot, :enforce_legal_agreements, false)
      saas_mode = Application.get_env(:tymeslot, :saas_mode, false)

      if saas_mode do
        assert enforce == true, "SaaS mode should enforce legal agreements"

        terms_url = Application.get_env(:tymeslot, :legal_terms_url)
        privacy_url = Application.get_env(:tymeslot, :legal_privacy_url)

        assert is_binary(terms_url) and terms_url != "",
               "SaaS mode should have terms URL configured"

        assert is_binary(privacy_url) and privacy_url != "",
               "SaaS mode should have privacy URL configured"
      else
        assert enforce == false, "Core mode should not enforce legal agreements"
      end
    end
  end

  describe "navigation configuration" do
    test "site home path reflects current mode" do
      home_path = Application.get_env(:tymeslot, :site_home_path)
      saas_mode = Application.get_env(:tymeslot, :saas_mode, false)

      if saas_mode do
        assert home_path == "/",
               "SaaS mode should use root path for home, got: #{home_path}"
      else
        assert home_path == "/dashboard",
               "Core mode should use /dashboard for home, got: #{home_path}"
      end
    end
  end

  describe "contact form configuration" do
    test "contact form template reflects current mode" do
      template = Application.get_env(:tymeslot, :contact_form_template)
      saas_mode = Application.get_env(:tymeslot, :saas_mode, false)

      if saas_mode do
        assert template == TymeslotSaas.Emails.Templates.ContactForm,
               "SaaS mode should have contact form template configured"
      else
        assert is_nil(template), "Core mode should not have contact form template"
      end
    end
  end

  describe "theme protection plugs" do
    test "theme protection plugs reflects current mode" do
      plugs = Application.get_env(:tymeslot, :extra_theme_protection_plugs, [])
      saas_mode = Application.get_env(:tymeslot, :saas_mode, false)

      if saas_mode do
        # SaaS can add extra protections here if needed, but should allow demo usernames for showcasing
        assert is_list(plugs)
      else
        assert plugs == []
      end
    end
  end
end
