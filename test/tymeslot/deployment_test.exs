defmodule Tymeslot.DeploymentTest do
  use ExUnit.Case
  alias Tymeslot.Deployment

  describe "type/0" do
    test "returns :cloudron when DEPLOYMENT_TYPE is set to cloudron" do
      System.put_env("DEPLOYMENT_TYPE", "cloudron")
      assert Deployment.type() == :cloudron
    end

    test "returns :docker when DEPLOYMENT_TYPE is set to docker" do
      System.put_env("DEPLOYMENT_TYPE", "docker")
      assert Deployment.type() == :docker
    end

    test "defaults to nil when DEPLOYMENT_TYPE is not set" do
      System.delete_env("DEPLOYMENT_TYPE")
      assert Deployment.type() == nil
    end

    test "defaults to nil for unknown DEPLOYMENT_TYPE values" do
      System.put_env("DEPLOYMENT_TYPE", "unknown")
      assert Deployment.type() == nil
    end
  end

  describe "deployment type checking functions" do
    test "cloudron?/0 returns true only for cloudron deployment" do
      System.put_env("DEPLOYMENT_TYPE", "cloudron")
      assert Deployment.cloudron?() == true

      System.put_env("DEPLOYMENT_TYPE", "docker")
      assert Deployment.cloudron?() == false
    end

    test "docker?/0 returns true for docker deployment and defaults" do
      System.put_env("DEPLOYMENT_TYPE", "docker")
      assert Deployment.docker?() == true

      System.delete_env("DEPLOYMENT_TYPE")
      assert Deployment.docker?() == true

      System.put_env("DEPLOYMENT_TYPE", "cloudron")
      assert Deployment.docker?() == false
    end
  end
end
