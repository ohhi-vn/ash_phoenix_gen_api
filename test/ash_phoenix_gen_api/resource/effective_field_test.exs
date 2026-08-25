defmodule AshPhoenixGenApi.Resource.EffectiveFieldTest do
  use ExUnit.Case, async: true

  alias AshPhoenixGenApi.Resource.ActionConfig
  alias AshPhoenixGenApi.Resource.MfaConfig

  describe "effective_timeout/2" do
    test "returns entity timeout when set" do
      config = %ActionConfig{name: :create_post, timeout: 10_000}
      assert ActionConfig.effective_timeout(config, 5_000) == 10_000
    end

    test "falls back to default when nil" do
      config = %ActionConfig{name: :create_post, timeout: nil}
      assert ActionConfig.effective_timeout(config, 5_000) == 5_000
    end

    test "works on MfaConfig too" do
      config = %MfaConfig{name: :ping, request_type: "ping", arg_types: %{}, timeout: nil}
      assert MfaConfig.effective_timeout(config, 5_000) == 5_000
    end

    test "passes through :infinity" do
      config = %ActionConfig{name: :create_post, timeout: :infinity}
      assert ActionConfig.effective_timeout(config, 5_000) == :infinity
    end
  end

  describe "effective_response_type/2" do
    test "returns entity value when set" do
      config = %ActionConfig{name: :read_posts, response_type: :sync}
      assert ActionConfig.effective_response_type(config, :async) == :sync
    end

    test "falls back to default when nil" do
      config = %ActionConfig{name: :read_posts, response_type: nil}
      assert ActionConfig.effective_response_type(config, :async) == :async
    end
  end

  describe "effective_request_info/2" do
    test "returns entity value when set" do
      config = %ActionConfig{name: :read_posts, request_info: false}
      assert ActionConfig.effective_request_info(config, true) == false
    end

    test "falls back to default when nil" do
      config = %ActionConfig{name: :read_posts, request_info: nil}
      assert ActionConfig.effective_request_info(config, true) == true
    end
  end

  describe "effective_check_permission/2" do
    test "returns entity value when set" do
      config = %ActionConfig{name: :delete_post, check_permission: :any_authenticated}
      assert ActionConfig.effective_check_permission(config, false) == :any_authenticated
    end

    test "falls back to default when nil" do
      config = %ActionConfig{name: :delete_post, check_permission: nil}
      assert ActionConfig.effective_check_permission(config, false) == false
    end
  end

  describe "effective_permission_callback/2" do
    test "returns entity callback when set" do
      mfa = {MyApp.Permissions, :check, []}
      config = %ActionConfig{name: :delete_post, permission_callback: mfa}
      assert ActionConfig.effective_permission_callback(config, nil) == mfa
    end

    test "falls back to section-level default" do
      mfa = {MyApp.Permissions, :check, []}
      config = %ActionConfig{name: :delete_post, permission_callback: nil}
      assert ActionConfig.effective_permission_callback(config, mfa) == mfa
    end

    test "returns nil default when neither set" do
      config = %MfaConfig{name: :ping, request_type: "ping", arg_types: %{}}
      assert MfaConfig.effective_permission_callback(config, nil) == nil
    end
  end

  describe "effective_choose_node_mode/2" do
    test "returns entity value when set" do
      config = %ActionConfig{name: :read_posts, choose_node_mode: :hash}
      assert ActionConfig.effective_choose_node_mode(config, :random) == :hash
    end

    test "falls back to default when nil" do
      config = %ActionConfig{name: :read_posts, choose_node_mode: nil}
      assert ActionConfig.effective_choose_node_mode(config, :random) == :random
    end
  end

  describe "effective_nodes/2" do
    test "returns entity nodes when set" do
      nodes = [:"gateway@host"]
      config = %ActionConfig{name: :read_posts, nodes: nodes}
      assert ActionConfig.effective_nodes(config, :local) == nodes
    end

    test "falls back to default when nil" do
      config = %ActionConfig{name: :read_posts, nodes: nil}
      assert ActionConfig.effective_nodes(config, :local) == :local
    end
  end

  describe "effective_retry/2" do
    test "returns entity retry when set" do
      config = %ActionConfig{name: :read_posts, retry: {:same_node, 3}}
      assert ActionConfig.effective_retry(config, nil) == {:same_node, 3}
    end

    test "falls back to default when nil" do
      config = %ActionConfig{name: :read_posts, retry: nil}
      assert ActionConfig.effective_retry(config, nil) == nil
    end
  end

  describe "effective_version/2" do
    test "returns entity version when set" do
      config = %ActionConfig{name: :read_posts, version: "1.2.3"}
      assert ActionConfig.effective_version(config, "0.0.1") == "1.2.3"
    end

    test "falls back to default when nil" do
      config = %ActionConfig{name: :read_posts, version: nil}
      assert ActionConfig.effective_version(config, "0.0.1") == "0.0.1"
    end
  end

  describe "effective_before_execute/2 and effective_after_execute/2" do
    test "returns hook when set" do
      hook = {MyApp.Hooks, :before}
      config = %ActionConfig{name: :read_posts, before_execute: hook}
      assert ActionConfig.effective_before_execute(config, nil) == hook
    end

    test "falls back to default when nil" do
      config = %ActionConfig{name: :read_posts, after_execute: nil}
      assert ActionConfig.effective_after_execute(config, {MyApp.Hooks, :after}) ==
               {MyApp.Hooks, :after}
    end
  end

  describe "effective_hook_timeout/2" do
    test "returns entity value when set" do
      config = %ActionConfig{name: :read_posts, hook_timeout: 30_000}
      assert ActionConfig.effective_hook_timeout(config, 5_000) == 30_000
    end

    test "falls back to default when nil" do
      config = %ActionConfig{name: :read_posts, hook_timeout: nil}
      assert ActionConfig.effective_hook_timeout(config, 5_000) == 5_000
    end
  end

  describe "has_explicit_arg_types?/1" do
    test "false when nil" do
      assert ActionConfig.has_explicit_arg_types?(%ActionConfig{name: :a, arg_types: nil}) ==
               false
    end

    test "false when empty map" do
      assert ActionConfig.has_explicit_arg_types?(%ActionConfig{name: :a, arg_types: %{}}) ==
               false
    end

    test "true when non-empty map" do
      config = %ActionConfig{name: :a, arg_types: %{"title" => :string}}
      assert ActionConfig.has_explicit_arg_types?(config) == true
    end
  end

  describe "has_explicit_arg_orders?/1" do
    test "false for :map" do
      assert ActionConfig.has_explicit_arg_orders?(%ActionConfig{name: :a, arg_orders: :map}) ==
               false
    end

    test "false for nil and empty list" do
      assert ActionConfig.has_explicit_arg_orders?(%ActionConfig{name: :a, arg_orders: nil}) ==
               false

      assert ActionConfig.has_explicit_arg_orders?(%ActionConfig{name: :a, arg_orders: []}) ==
               false
    end

    test "true for non-empty list" do
      config = %ActionConfig{name: :a, arg_orders: ["title"]}
      assert ActionConfig.has_explicit_arg_orders?(config) == true
    end
  end

  describe "enabled?/1" do
    test "true by default" do
      assert ActionConfig.enabled?(%ActionConfig{name: :a, disabled: false}) == true
    end

    test "false when disabled" do
      assert MfaConfig.enabled?(%MfaConfig{
               name: :ping,
               request_type: "ping",
               arg_types: %{},
               disabled: true
             }) == false
    end
  end
end
