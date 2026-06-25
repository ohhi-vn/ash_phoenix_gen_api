defmodule AshPhoenixGenApi.Transformers.DefineDomainSupporterTest do
  use ExUnit.Case

  @moduletag timeout: 60_000

  defmodule SupporterTestDomain do
    use Ash.Domain,
      extensions: [AshPhoenixGenApi.Domain]

    gen_api do
      service "supporter_test"

      supporter_module AshPhoenixGenApi.Transformers.DefineDomainSupporterTest.SupporterTestDomain.Supporter

      version "1.0.0"
    end

    resources do
    end
  end

  defmodule PushSupporterDomain do
    use Ash.Domain,
      extensions: [AshPhoenixGenApi.Domain]

    gen_api do
      service "push_supporter_test"

      supporter_module AshPhoenixGenApi.Transformers.DefineDomainSupporterTest.PushSupporterDomain.Supporter

      version "1.0.0"
      push_nodes([:gateway@host])
    end

    resources do
    end
  end

  defmodule NoPushSupporterDomain do
    use Ash.Domain,
      extensions: [AshPhoenixGenApi.Domain]

    gen_api do
      service "no_push_supporter_test"

      supporter_module AshPhoenixGenApi.Transformers.DefineDomainSupporterTest.NoPushSupporterDomain.Supporter

      version "1.0.0"
    end

    resources do
    end
  end

  describe "DefineDomainSupporter transformer" do
    test "generates supporter module with get_config/1" do
      assert function_exported?(SupporterTestDomain.Supporter, :get_config, 1)
    end

    test "generates supporter module with get_config_version/1" do
      assert function_exported?(SupporterTestDomain.Supporter, :get_config_version, 1)
    end

    test "generates supporter module with fun_configs/0" do
      assert function_exported?(SupporterTestDomain.Supporter, :fun_configs, 0)
    end

    test "generates supporter module with list_request_types/0" do
      assert function_exported?(SupporterTestDomain.Supporter, :list_request_types, 0)
    end

    test "generates supporter module with get_fun_config/1" do
      assert function_exported?(SupporterTestDomain.Supporter, :get_fun_config, 1)
    end

    test "get_config/1 returns {:ok, fun_configs}" do
      {:ok, configs} = SupporterTestDomain.Supporter.get_config("test_remote")
      assert is_list(configs)
    end

    test "get_config_version/1 returns {:ok, version}" do
      {:ok, version} = SupporterTestDomain.Supporter.get_config_version("test_remote")
      assert version == "1.0.0"
    end
  end

  describe "push configuration" do
    test "generates push functions when push_nodes is configured" do
      assert function_exported?(PushSupporterDomain.Supporter, :build_push_config, 0)
      assert function_exported?(PushSupporterDomain.Supporter, :push_to_gateway, 2)
      assert function_exported?(PushSupporterDomain.Supporter, :push_on_startup, 2)
      assert function_exported?(PushSupporterDomain.Supporter, :resolve_push_nodes, 0)
    end

    test "push functions are always generated regardless of push_nodes" do
      # build_push_config is always generated; push_nodes only affects its runtime return value
      assert function_exported?(NoPushSupporterDomain.Supporter, :build_push_config, 0)
    end
  end
end
