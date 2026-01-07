defmodule Tymeslot.Deployment do
  @moduledoc """
  Module for handling self-hosted deployment types.

  This module provides functions to check the deployment type:
  - Cloudron: Managed self-hosting platform
  - Docker: Standard containerized deployment (default)
  """

  @doc """
  Gets the current deployment type from environment variable.

  Returns :cloudron or :docker (default if not set).
  """
  @spec type() :: :cloudron | :docker | nil
  def type do
    case System.get_env("DEPLOYMENT_TYPE") do
      "cloudron" -> :cloudron
      "docker" -> :docker
      _ -> nil
    end
  end

  @doc """
  Legacy alias for type/0.
  """
  @spec environment() :: :cloudron | :docker | nil
  def environment, do: type()

  @doc """
  Checks if the current environment is Cloudron.
  """
  @spec cloudron?() :: boolean()
  def cloudron?, do: type() == :cloudron

  @doc """
  Checks if the current environment is Docker.
  """
  @spec docker?() :: boolean()
  def docker?, do: is_nil(type()) or type() == :docker
end
