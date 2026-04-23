

defmodule AshPhoenixGenApi.DomainTest do
  use ExUnit.Case

  @moduletag timeout: 60_000


  defmodule TestDomain do
    use Ash.Domain,
      extensions: [AshPhoenixGenApi.Domain]

    resources do
      resource AshPhoenixGenApi.ResourceTest.TestResource
    end

    gen_api do
      service "chat"
      nodes {TestCluster, :get_nodes, [:chat]}
      choose_node_mode :random
      timeout 5_000
      response_type :async
      request_info true
      version "0.0.1"
      supporter_module AshPhoenixGenApi.DomainTest.TestDomain.GenApiSupporter
    end
  end

  describe "domain DSL" do
    test "domain compiles with gen_api extension" do
      assert Ash.Domain.Info.extensions(TestDomain) |> Enum.any?(&(&1 == AshPhoenixGenApi.Domain))
    end

    test "has_gen_api? returns true" do
      assert AshPhoenixGenApi.Domain.Info.has_gen_api?(TestDomain) == true
    end

    test "gen_api_service returns configured service" do
      assert AshPhoenixGenApi.Domain.Info.gen_api_service!(TestDomain) == "chat"
    end

    test "gen_api_nodes returns configured nodes" do
      assert AshPhoenixGenApi.Domain.Info.gen_api_nodes!(TestDomain) == {TestCluster, :get_nodes, [:chat]}
    end

    test "gen_api_timeout returns configured timeout" do
      assert AshPhoenixGenApi.Domain.Info.gen_api_timeout!(TestDomain) == 5_000
    end

    test "gen_api_response_type returns configured response type" do
      assert AshPhoenixGenApi.Domain.Info.gen_api_response_type!(TestDomain) == :async
    end

    test "gen_api_supporter_module returns configured module" do
      assert AshPhoenixGenApi.Domain.Info.gen_api_supporter_module!(TestDomain) ==
               AshPhoenixGenApi.DomainTest.TestDomain.GenApiSupporter
    end

    test "gen_api_define_supporter? returns true by default" do
      assert AshPhoenixGenApi.Domain.Info.gen_api_define_supporter?(TestDomain) == true
    end
  end

  describe "domain info helpers" do
    test "service returns configured service" do
      assert AshPhoenixGenApi.Domain.Info.service(TestDomain) == "chat"
    end

    test "supporter_module returns configured module" do
      assert AshPhoenixGenApi.Domain.Info.supporter_module(TestDomain) ==
               AshPhoenixGenApi.DomainTest.TestDomain.GenApiSupporter
    end

    test "version returns configured version" do
      assert AshPhoenixGenApi.Domain.Info.version(TestDomain) == "0.0.1"
    end

    test "timeout returns configured timeout" do
      assert AshPhoenixGenApi.Domain.Info.timeout(TestDomain) == 5_000
    end

    test "response_type returns configured response type" do
      assert AshPhoenixGenApi.Domain.Info.response_type(TestDomain) == :async
    end

    test "request_info returns configured request_info" do
      assert AshPhoenixGenApi.Domain.Info.request_info(TestDomain) == true
    end

    test "nodes returns configured nodes" do
      assert AshPhoenixGenApi.Domain.Info.nodes(TestDomain) == {TestCluster, :get_nodes, [:chat]}
    end

    test "choose_node_mode returns configured mode" do
      assert AshPhoenixGenApi.Domain.Info.choose_node_mode(TestDomain) == :random
    end

    test "check_permission returns configured value" do
      assert AshPhoenixGenApi.Domain.Info.check_permission(TestDomain) == false
    end

    test "resources_with_gen_api returns resources with the extension" do
      resources = AshPhoenixGenApi.Domain.Info.resources_with_gen_api(TestDomain)
      assert AshPhoenixGenApi.ResourceTest.TestResource in resources
    end

    test "fun_configs returns aggregated FunConfigs" do
      fun_configs = AshPhoenixGenApi.Domain.Info.fun_configs(TestDomain)
      assert is_list(fun_configs)
      assert length(fun_configs) > 0
    end

    test "all_request_types returns all request types" do
      request_types = AshPhoenixGenApi.Domain.Info.all_request_types(TestDomain)
      assert is_list(request_types)
      assert "send_message" in request_types
    end

    test "fun_config finds specific config by request_type" do
      fc = AshPhoenixGenApi.Domain.Info.fun_config(TestDomain, "send_message")
      assert fc != nil
      assert fc.request_type == "send_message"
    end

    test "summary returns configuration summary" do
      summary = AshPhoenixGenApi.Domain.Info.summary(TestDomain)
      assert summary.service == "chat"
      assert summary.version == "0.0.1"
      assert is_list(summary.resources)
      assert is_integer(summary.total_fun_configs)
    end
  end

  describe "supporter module" do
    test "supporter module is generated" do
      supporter = AshPhoenixGenApi.DomainTest.TestDomain.GenApiSupporter
      assert function_exported?(supporter, :get_config, 1)
      assert function_exported?(supporter, :get_config_version, 1)
      assert function_exported?(supporter, :fun_configs, 0)
      assert function_exported?(supporter, :list_request_types, 0)
      assert function_exported?(supporter, :get_fun_config, 1)
    end

    test "get_config returns {:ok, fun_configs}" do
      {:ok, configs} = AshPhoenixGenApi.DomainTest.TestDomain.GenApiSupporter.get_config("test_remote")
      assert is_list(configs)
    end

    test "get_config_version returns {:ok, version}" do
      {:ok, version} = AshPhoenixGenApi.DomainTest.TestDomain.GenApiSupporter.get_config_version("test_remote")
      assert version == "0.0.1"
    end

    test "resource fun_configs function is available" do
      # Debug: check if the resource's fun_configs function exists and returns data
      resource = AshPhoenixGenApi.ResourceTest.TestResource
      assert function_exported?(resource, :__ash_phoenix_gen_api_fun_configs__, 0),
        "Resource #{inspect(resource)} does not export __ash_phoenix_gen_api_fun_configs__/0"

      resource_configs = resource.__ash_phoenix_gen_api_fun_configs__()
      assert is_list(resource_configs),
        "Resource fun_configs returned non-list: #{inspect(resource_configs)}"
      assert length(resource_configs) > 0,
        "Resource fun_configs returned empty list. Available functions: #{inspect(resource.__info__(:functions) |> Enum.filter(fn {name, _} -> String.contains?(to_string(name), "gen_api") end))}"
    end

    test "fun_configs returns list of FunConfig structs" do
      # Debug: first check the resource directly
      resource = AshPhoenixGenApi.ResourceTest.TestResource
      resource_configs = resource.__ash_phoenix_gen_api_fun_configs__()

      # If the resource returns empty, the supporter will too
      if length(resource_configs) == 0 do
        flunk(
          "Resource fun_configs is empty - supporter will also be empty. " <>
            "Resource module: #{inspect(resource)}, " <>
            "Resource has function? #{function_exported?(resource, :__ash_phoenix_gen_api_fun_configs__, 0)}, " <>
            "Resource gen_api extension? #{AshPhoenixGenApi.Resource.Info.has_gen_api?(resource)}, " <>
            "Resource gen_api actions: #{inspect(AshPhoenixGenApi.Resource.Info.gen_api(resource))}"
        )
      end

      # Debug: check what the supporter module's fun_configs actually calls
      supporter = AshPhoenixGenApi.DomainTest.TestDomain.GenApiSupporter
      configs = supporter.fun_configs()

      if length(configs) == 0 do
        # Try to diagnose: is the resource even in the domain's resource list?
        domain_resources = Ash.Domain.Info.resources(AshPhoenixGenApi.DomainTest.TestDomain)
        resources_with_gen_api = AshPhoenixGenApi.Domain.Info.resources_with_gen_api(AshPhoenixGenApi.DomainTest.TestDomain)

        flunk(
          "Supporter fun_configs is empty. " <>
            "Domain resources: #{inspect(domain_resources)}, " <>
            "Resources with gen_api: #{inspect(resources_with_gen_api)}, " <>
            "Resource fun_configs count: #{length(resource_configs)}, " <>
            "Supporter module: #{inspect(supporter)}, " <>
            "Supporter module functions: #{inspect(supporter.__info__(:functions) |> Enum.filter(fn {name, _} -> String.contains?(to_string(name), "fun") end))}"
        )
      end

      assert is_list(configs)
      assert length(configs) > 0
    end

    test "list_request_types returns list of strings" do
      request_types = AshPhoenixGenApi.DomainTest.TestDomain.GenApiSupporter.list_request_types()
      assert is_list(request_types)
      assert Enum.all?(request_types, &is_binary/1)
    end

    test "get_fun_config finds config by request_type" do
      fc = AshPhoenixGenApi.DomainTest.TestDomain.GenApiSupporter.get_fun_config("send_message")
      assert fc != nil
      assert fc.request_type == "send_message"
    end

    test "get_fun_config returns nil for unknown request_type" do
      fc = AshPhoenixGenApi.DomainTest.TestDomain.GenApiSupporter.get_fun_config("nonexistent")
      assert fc == nil
    end
  end
end
