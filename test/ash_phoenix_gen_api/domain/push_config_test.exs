defmodule AshPhoenixGenApi.Domain.PushConfigTest do
  use ExUnit.Case

  @moduletag timeout: 60_000

  alias AshPhoenixGenApi.Domain.Info
  alias MfaSupporter
  alias NoPushSupporter
  alias Supporter

  defmodule PushTestDomain do
    use Ash.Domain,
      extensions: [AshPhoenixGenApi.Domain]

    gen_api do
      service "push_test"
      nodes [:storage@host, :storage2@host]
      supporter_module Supporter
      version "1.0.0"
      push_nodes([:gateway1@host, :gateway2@host])
    end

    resources do
    end
  end

  defmodule PushMfaDomain do
    use Ash.Domain,
      extensions: [AshPhoenixGenApi.Domain]

    gen_api do
      service "push_mfa_test"
      nodes {__MODULE__, :get_service_nodes, []}
      supporter_module MfaSupporter
      version "2.0.0"
      push_nodes({__MODULE__, :get_gateway_nodes, []})
    end

    resources do
    end

    def get_service_nodes, do: [:storage_mfa@host]
    def get_gateway_nodes, do: [:mfa_gateway@host]
  end

  defmodule NoPushDomain do
    use Ash.Domain,
      extensions: [AshPhoenixGenApi.Domain]

    gen_api do
      service "no_push_test"
      nodes [:storage@host]
      supporter_module NoPushSupporter
      version "1.0.0"
    end

    resources do
    end
  end

  describe "push_nodes configuration" do
    test "gen_api_push_nodes returns {:ok, configured list}" do
      result = Info.gen_api_push_nodes(PushTestDomain)
      assert result == {:ok, [:gateway1@host, :gateway2@host]}
    end

    test "push_nodes helper returns configured list" do
      result = Info.push_nodes(PushTestDomain)
      assert result == [:gateway1@host, :gateway2@host]
    end

    test "push_nodes returns nil when not configured" do
      result = Info.push_nodes(NoPushDomain)
      assert result == nil
    end

    test "push_nodes returns MFA tuple when configured" do
      result = Info.push_nodes(PushMfaDomain)
      assert result == {PushMfaDomain, :get_gateway_nodes, []}
    end
  end

  describe "push_on_startup configuration" do
    test "gen_api_push_on_startup returns {:ok, false} by default" do
      result = Info.gen_api_push_on_startup(PushTestDomain)
      assert result == {:ok, false}
    end

    test "push_on_startup? helper returns false by default" do
      result = Info.push_on_startup?(PushTestDomain)
      assert result == false
    end
  end

  describe "generated supporter module push functions" do
    test "build_push_config/0 returns a PushConfig struct" do
      alias PhoenixGenApi.Structs.PushConfig

      push_config = Supporter.build_push_config()
      assert %PushConfig{} = push_config
      assert push_config.service == "push_test"
      assert push_config.config_version == "1.0.0"
      assert push_config.module == Supporter
      assert push_config.function == :get_config
      assert push_config.args == [:api_gateway]
      assert push_config.version_module == Supporter
      assert push_config.version_function == :get_config_version
      assert push_config.version_args == [:api_gateway]
    end

    test "build_push_config/0 resolves service nodes from gen_api nodes" do
      alias PhoenixGenApi.Structs.PushConfig

      push_config = Supporter.build_push_config()
      assert push_config.nodes == [:storage@host, :storage2@host]
    end

    test "build_push_config/0 passes through MFA service nodes tuple for gateway runtime resolution" do
      alias PhoenixGenApi.Structs.PushConfig

      push_config = MfaSupporter.build_push_config()
      assert push_config.nodes == {PushMfaDomain, :get_service_nodes, []}
    end

    test "resolve_push_nodes/0 returns configured list" do
      result = Supporter.resolve_push_nodes()
      assert result == [:gateway1@host, :gateway2@host]
    end

    test "build_push_config/0 resolves MFA push_nodes at runtime" do
      result = MfaSupporter.resolve_push_nodes()
      assert result == [:"mfa_gateway@host"]
    end

    test "resolve_push_nodes/0 returns nil when not configured" do
      result = NoPushSupporter.resolve_push_nodes()
      assert result == nil
    end

    test "push_to_configured_nodes/1 returns error when no push_nodes" do
      result = NoPushSupporter.push_to_configured_nodes()
      assert result == {:error, :no_push_nodes_configured}
    end

    test "verify_on_gateway/2 is exported" do
      assert function_exported?(
               Supporter,
               :verify_on_gateway,
               2
             )
    end

    test "push_to_gateway/2 is exported" do
      assert function_exported?(
               Supporter,
               :push_to_gateway,
               2
             )
    end

    test "push_on_startup/2 is exported" do
      assert function_exported?(
               Supporter,
               :push_on_startup,
               2
             )
    end
  end

  describe "domain summary includes push config" do
    test "summary includes push_nodes" do
      summary = Info.summary(PushTestDomain)
      assert summary.push_nodes == [:"gateway1@host", :"gateway2@host"]
    end

    test "summary includes push_on_startup" do
      summary = Info.summary(PushTestDomain)
      assert summary.push_on_startup == false
    end
  end
end
