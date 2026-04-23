
defmodule AshPhoenixGenApi.Resource.ActionConfigTest do
  use ExUnit.Case, async: true

  alias AshPhoenixGenApi.Resource.ActionConfig

  describe "effective_request_type/1" do
    test "returns explicit request_type when set" do
      config = %ActionConfig{name: :send_message, request_type: "send_msg"}
      assert ActionConfig.effective_request_type(config) == "send_msg"
    end

    test "derives request_type from action name when not set" do
      config = %ActionConfig{name: :send_message, request_type: nil}
      assert ActionConfig.effective_request_type(config) == "send_message"
    end
  end

  describe "effective_timeout/2" do
    test "returns explicit timeout when set" do
      config = %ActionConfig{timeout: 10_000}
      assert ActionConfig.effective_timeout(config, 5_000) == 10_000
    end

    test "returns default when timeout is nil" do
      config = %ActionConfig{timeout: nil}
      assert ActionConfig.effective_timeout(config, 5_000) == 5_000
    end

    test "supports :infinity timeout" do
      config = %ActionConfig{timeout: :infinity}
      assert ActionConfig.effective_timeout(config, 5_000) == :infinity
    end
  end

  describe "effective_response_type/2" do
    test "returns explicit response_type when set" do
      config = %ActionConfig{response_type: :sync}
      assert ActionConfig.effective_response_type(config, :async) == :sync
    end

    test "returns default when response_type is nil" do
      config = %ActionConfig{response_type: nil}
      assert ActionConfig.effective_response_type(config, :async) == :async
    end
  end

  describe "effective_request_info/2" do
    test "returns explicit request_info when set" do
      config = %ActionConfig{request_info: false}
      assert ActionConfig.effective_request_info(config, true) == false
    end

    test "returns default when request_info is nil" do
      config = %ActionConfig{request_info: nil}
      assert ActionConfig.effective_request_info(config, true) == true
    end
  end

  describe "effective_check_permission/2" do
    test "returns explicit check_permission when set" do
      config = %ActionConfig{check_permission: {:arg, "user_id"}}
      assert ActionConfig.effective_check_permission(config, false) == {:arg, "user_id"}
    end

    test "returns default when check_permission is nil" do
      config = %ActionConfig{check_permission: nil}
      assert ActionConfig.effective_check_permission(config, false) == false
    end
  end

  describe "effective_choose_node_mode/2" do
    test "returns explicit choose_node_mode when set" do
      config = %ActionConfig{choose_node_mode: :round_robin}
      assert ActionConfig.effective_choose_node_mode(config, :random) == :round_robin
    end

    test "returns default when choose_node_mode is nil" do
      config = %ActionConfig{choose_node_mode: nil}
      assert ActionConfig.effective_choose_node_mode(config, :random) == :random
    end
  end

  describe "effective_nodes/2" do
    test "returns explicit nodes when set" do
      nodes = {ClusterHelper, :get_nodes, [:chat]}
      config = %ActionConfig{nodes: nodes}
      assert ActionConfig.effective_nodes(config, :local) == nodes
    end

    test "returns default when nodes is nil" do
      config = %ActionConfig{nodes: nil}
      assert ActionConfig.effective_nodes(config, :local) == :local
    end
  end

  describe "effective_retry/2" do
    test "returns explicit retry when set" do
      config = %ActionConfig{retry: {:all_nodes, 3}}
      assert ActionConfig.effective_retry(config, nil) == {:all_nodes, 3}
    end

    test "returns default when retry is nil" do
      config = %ActionConfig{retry: nil}
      assert ActionConfig.effective_retry(config, nil) == nil
    end
  end

  describe "effective_version/2" do
    test "returns explicit version when set" do
      config = %ActionConfig{version: "1.0.0"}
      assert ActionConfig.effective_version(config, "0.0.1") == "1.0.0"
    end

    test "returns default when version is nil" do
      config = %ActionConfig{version: nil}
      assert ActionConfig.effective_version(config, "0.0.1") == "0.0.1"
    end
  end

  describe "effective_mfa/2" do
    test "returns explicit mfa when set" do
      mfa = {MyApp.Api, :send_message, []}
      config = %ActionConfig{mfa: mfa, name: :send_message}
      assert ActionConfig.effective_mfa(config, MyApp.Resource) == mfa
    end

    test "generates mfa from resource module and action name when not set" do
      config = %ActionConfig{mfa: nil, name: :send_message}
      assert ActionConfig.effective_mfa(config, MyApp.Resource) == {MyApp.Resource, :send_message, []}
    end
  end

  describe "has_explicit_arg_types?/1" do
    test "returns true when arg_types has entries" do
      config = %ActionConfig{arg_types: %{"user_id" => :string}}
      assert ActionConfig.has_explicit_arg_types?(config) == true
    end

    test "returns false when arg_types is nil" do
      config = %ActionConfig{arg_types: nil}
      assert ActionConfig.has_explicit_arg_types?(config) == false
    end

    test "returns false when arg_types is empty map" do
      config = %ActionConfig{arg_types: %{}}
      assert ActionConfig.has_explicit_arg_types?(config) == false
    end
  end

  describe "has_explicit_arg_orders?/1" do
    test "returns true when arg_orders has entries" do
      config = %ActionConfig{arg_orders: ["user_id", "content"]}
      assert ActionConfig.has_explicit_arg_orders?(config) == true
    end

    test "returns false when arg_orders is :map (default)" do
      config = %ActionConfig{arg_orders: :map}
      assert ActionConfig.has_explicit_arg_orders?(config) == false
    end

    test "returns false when arg_orders is nil" do
      config = %ActionConfig{arg_orders: nil}
      assert ActionConfig.has_explicit_arg_orders?(config) == false
    end

    test "returns false when arg_orders is empty list" do
      config = %ActionConfig{arg_orders: []}
      assert ActionConfig.has_explicit_arg_orders?(config) == false
    end
  end

  describe "enabled?/1" do
    test "returns true when disabled is false" do
      config = %ActionConfig{disabled: false}
      assert ActionConfig.enabled?(config) == true
    end

    test "returns false when disabled is true" do
      config = %ActionConfig{disabled: true}
      assert ActionConfig.enabled?(config) == false
    end
  end
end
