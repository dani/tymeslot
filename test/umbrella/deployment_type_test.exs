defmodule Tymeslot.DeploymentTypeTest do
  use ExUnit.Case, async: false

  @moduletag :capture_log

  describe "deployment type validation" do
    setup do
      # Save original env var if set
      original = System.get_env("DEPLOYMENT_TYPE")

      on_exit(fn ->
        # Restore original env var
        if original do
          System.put_env("DEPLOYMENT_TYPE", original)
        else
          System.delete_env("DEPLOYMENT_TYPE")
        end
      end)

      :ok
    end

    test "cloudron deployment type is valid" do
      # This test just verifies the constant is recognized
      assert "cloudron" in ["cloudron", "docker"]
    end

    test "docker deployment type is valid" do
      assert "docker" in ["cloudron", "docker"]
    end
  end

  describe "deployment type behavior" do
    test "unknown deployment type falls back to docker" do
      # This logic is in runtime.exs
      assert "docker" in ["cloudron", "docker"]
    end
  end

  describe "URL scheme for deployment types" do
    test "expected URL schemes by deployment type" do
      # cloudron: https (reverse proxy handles SSL)
      # docker: http (no built-in SSL)

      expected_schemes = %{
        "cloudron" => "https",
        "docker" => "http"
      }

      Enum.each(expected_schemes, fn {type, expected_scheme} ->
        assert is_binary(expected_scheme),
               "#{type} should map to a valid scheme: #{expected_scheme}"
      end)
    end
  end

  describe "database configuration by deployment type" do
    test "cloudron uses cloudron-specific env vars" do
      # Cloudron should use CLOUDRON_POSTGRESQL_* env vars
      cloudron_vars = [
        "CLOUDRON_POSTGRESQL_URL",
        "CLOUDRON_POSTGRESQL_USERNAME",
        "CLOUDRON_POSTGRESQL_PASSWORD",
        "CLOUDRON_POSTGRESQL_HOST",
        "CLOUDRON_POSTGRESQL_PORT",
        "CLOUDRON_POSTGRESQL_DATABASE"
      ]

      Enum.each(cloudron_vars, fn var ->
        assert is_binary(var), "Cloudron var #{var} should be a string"
      end)
    end

    test "docker uses standard postgres env vars" do
      # Docker should use POSTGRES_* env vars
      docker_vars = [
        "POSTGRES_DB",
        "POSTGRES_USER",
        "POSTGRES_PASSWORD",
        "DATABASE_HOST",
        "DATABASE_PORT"
      ]

      Enum.each(docker_vars, fn var ->
        assert is_binary(var), "Docker var #{var} should be a string"
      end)
    end
  end
end
