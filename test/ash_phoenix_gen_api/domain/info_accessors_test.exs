defmodule AshPhoenixGenApi.Domain.InfoAccessorsTest do
  use ExUnit.Case, async: true

  alias AshPhoenixGenApi.Domain.Info
  alias AshPhoenixGenApi.InfoFixtures

  describe "accessors on a domain without the gen_api extension" do
    test "has_gen_api? is false" do
      refute Info.has_gen_api?(InfoFixtures.PlainDomain)
    end

    test "supporter_module/1 returns nil" do
      assert Info.supporter_module(InfoFixtures.PlainDomain) == nil
    end

    test "service/1 returns nil" do
      assert Info.service(InfoFixtures.PlainDomain) == nil
    end

    test "version/1 returns built-in default" do
      assert Info.version(InfoFixtures.PlainDomain) == "0.0.1"
    end

    test "define_supporter?/1 returns false without gen_api" do
      assert Info.define_supporter?(InfoFixtures.PlainDomain) == false
    end

    test "timeout/1 returns built-in default" do
      assert Info.timeout(InfoFixtures.PlainDomain) == 5_000
    end

    test "response_type/1 returns built-in default" do
      assert Info.response_type(InfoFixtures.PlainDomain) == :async
    end

    test "request_info/1 returns built-in default" do
      assert Info.request_info(InfoFixtures.PlainDomain) == true
    end

    test "nodes/1 returns :local" do
      assert Info.nodes(InfoFixtures.PlainDomain) == :local
    end

    test "choose_node_mode/1 returns :random" do
      assert Info.choose_node_mode(InfoFixtures.PlainDomain) == :random
    end

    test "check_permission/1 returns false" do
      assert Info.check_permission(InfoFixtures.PlainDomain) == false
    end

    test "permission_callback/1 returns nil" do
      assert Info.permission_callback(InfoFixtures.PlainDomain) == nil
    end

    test "retry/1 returns nil" do
      assert Info.retry(InfoFixtures.PlainDomain) == nil
    end

    test "push_nodes/1 returns nil" do
      assert Info.push_nodes(InfoFixtures.PlainDomain) == nil
    end

    test "push_on_startup?/1 returns false" do
      assert Info.push_on_startup?(InfoFixtures.PlainDomain) == false
    end

    test "result_encoder/1 returns :struct" do
      assert Info.result_encoder(InfoFixtures.PlainDomain) == :struct
    end

    test "config_argument/1 returns :api_gateway" do
      assert Info.config_argument(InfoFixtures.PlainDomain) == :api_gateway
    end

    test "summary/1 builds a summary with defaults" do
      summary = Info.summary(InfoFixtures.PlainDomain)

      assert summary.service == nil
      assert summary.version == "0.0.1"
      assert summary.total_fun_configs == 0
      assert summary.push_nodes == nil
      assert summary.push_on_startup == false
      assert summary.result_encoder == :struct
    end
  end

  describe "accessors on non-domain modules (rescue arms)" do
    test "resources_with_gen_api/1 returns [] for a module that is not a domain" do
      assert Info.resources_with_gen_api(String) == []
    end

    test "fun_configs/1 and fun_config/2 return empty results for plain domains" do
      assert Info.fun_configs(InfoFixtures.PlainDomain) == []
      assert Info.fun_config(InfoFixtures.PlainDomain, "anything") == nil
      assert Info.all_request_types(InfoFixtures.PlainDomain) == []
    end
  end

  describe "define_supporter?/1 with gen_api configured" do
    test "honors define_supporter? false" do
      assert Info.define_supporter?(InfoFixtures.DisabledSupporterDomain) == false
      assert Info.supporter_module(InfoFixtures.DisabledSupporterDomain) ==
               AshPhoenixGenApi.InfoFixtures.DisabledSupporter
    end

    test "retry/1 honors configured value" do
      assert Info.retry(InfoFixtures.DisabledSupporterDomain) == {:same_node, 2}
    end
  end
end
