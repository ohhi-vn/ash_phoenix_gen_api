defmodule AshPhoenixGenApi.Resource.InfoAccessorsTest do
  use ExUnit.Case, async: true

  alias AshPhoenixGenApi.InfoFixtures
  alias AshPhoenixGenApi.Resource.Info

  describe "has_gen_api?/1" do
    test "returns false for a module that cannot be compiled" do
      refute Info.has_gen_api?(NoSuchModuleAnywhere)
    end

    test "returns false for a resource without the extension" do
      refute Info.has_gen_api?(InfoFixtures.PlainResource)
    end
  end

  describe "service/1" do
    test "returns configured service" do
      assert Info.service(InfoFixtures.HookedResource) == "hooked_service"
    end

    test "returns nil for a resource without gen_api" do
      assert Info.service(InfoFixtures.PlainResource) == nil
    end
  end

  describe "effective_* accessors with unconfigured action fall back to section defaults" do
    test "effective_timeout" do
      assert Info.effective_timeout(InfoFixtures.HookedResource, :missing_action) == 9_000
      assert Info.effective_timeout(InfoFixtures.PlainResource, :create) == 5_000
    end

    test "effective_response_type" do
      assert Info.effective_response_type(InfoFixtures.HookedResource, :missing_action) == :async
      assert Info.effective_response_type(InfoFixtures.PlainResource, :create) == :async
    end

    test "effective_request_info" do
      assert Info.effective_request_info(InfoFixtures.HookedResource, :missing_action) == false
      assert Info.effective_request_info(InfoFixtures.PlainResource, :create) == true
    end

    test "effective_permission_callback" do
      assert Info.effective_permission_callback(InfoFixtures.HookedResource, :missing_action) ==
               nil
    end

    test "effective_choose_node_mode" do
      assert Info.effective_choose_node_mode(InfoFixtures.HookedResource, :missing_action) == :hash
      assert Info.effective_choose_node_mode(InfoFixtures.PlainResource, :create) == :random
    end

    test "effective_nodes" do
      assert Info.effective_nodes(InfoFixtures.HookedResource, :missing_action) == [
               :"hooked@node"
             ]

      assert Info.effective_nodes(InfoFixtures.PlainResource, :create) == :local
    end

    test "effective_version" do
      assert Info.effective_version(InfoFixtures.HookedResource, :missing_action) == "2.0.0"
      assert Info.effective_version(InfoFixtures.PlainResource, :create) == "0.0.1"
    end

    test "effective_retry" do
      assert Info.effective_retry(InfoFixtures.HookedResource, :missing_action) == {:same_node, 2}
      assert Info.effective_retry(InfoFixtures.PlainResource, :create) == nil
    end

    test "effective_code_interface?" do
      assert Info.effective_code_interface?(InfoFixtures.HookedResource, :missing_action) == true
      assert Info.effective_code_interface?(InfoFixtures.PlainResource, :create) == true
    end

    test "effective_result_encoder" do
      assert Info.effective_result_encoder(InfoFixtures.HookedResource, :missing_action) == :map
      assert Info.effective_result_encoder(InfoFixtures.PlainResource, :create) == :struct
    end

    test "effective_before_execute and effective_after_execute" do
      assert Info.effective_before_execute(InfoFixtures.HookedResource, :missing_action) ==
               {AshPhoenixGenApi.InfoFixtures.Hooks, :before}

      assert Info.effective_after_execute(InfoFixtures.HookedResource, :missing_action) ==
               {AshPhoenixGenApi.InfoFixtures.Hooks, :after}

      assert Info.effective_before_execute(InfoFixtures.PlainResource, :create) == nil
      assert Info.effective_after_execute(InfoFixtures.PlainResource, :create) == nil
    end

    test "effective_hook_timeout" do
      assert Info.effective_hook_timeout(InfoFixtures.HookedResource, :missing_action) == 7_000
      assert Info.effective_hook_timeout(InfoFixtures.PlainResource, :create) == 5_000
    end
  end

  describe "effective_mfa/2" do
    test "returns nil when the action is not configured" do
      assert Info.effective_mfa(InfoFixtures.HookedResource, :missing_action) == nil
    end

    test "auto-generates mfa from resource and action name" do
      assert Info.effective_mfa(InfoFixtures.HookedResource, :create) ==
               {InfoFixtures.HookedResource, :create, []}
    end
  end

  describe "action_request_type/2" do
    test "returns nil for an action not configured in gen_api" do
      assert Info.action_request_type(InfoFixtures.HookedResource, :missing_action) == nil
    end

    test "derives request type from action name" do
      assert Info.action_request_type(InfoFixtures.HookedResource, :create) == "create"
    end
  end

  describe "effective_* accessors resolve configured action values" do
    test "check_permission from action entity" do
      assert Info.effective_check_permission(InfoFixtures.HookedResource, :create) == false

      assert Info.effective_check_permission(InfoFixtures.HookedResource, :list_items) ==
               :any_authenticated
    end

    test "request_info falls back through action to section default" do
      assert Info.effective_request_info(InfoFixtures.HookedResource, :create) == false
    end

    test "choose_node_mode, nodes, version and retry from section defaults" do
      assert Info.effective_choose_node_mode(InfoFixtures.HookedResource, :create) == :hash
      assert Info.effective_nodes(InfoFixtures.HookedResource, :create) == [:"hooked@node"]
      assert Info.effective_version(InfoFixtures.HookedResource, :create) == "2.0.0"
      assert Info.effective_retry(InfoFixtures.HookedResource, :create) == {:same_node, 2}
    end
  end
end
