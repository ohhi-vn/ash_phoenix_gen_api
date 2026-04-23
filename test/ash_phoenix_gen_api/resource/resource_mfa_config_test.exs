
defmodule AshPhoenixGenApi.Resource.MfaConfigTest do
  use ExUnit.Case

  alias AshPhoenixGenApi.Resource.MfaConfig

  describe "effective_timeout/2" do
    test "returns explicit timeout when set" do
      config = %MfaConfig{timeout: 10_000}
      assert MfaConfig.effective_timeout(config, 5_000) == 10_000
    end

    test "returns default when timeout is nil" do
      config = %MfaConfig{timeout: nil}
      assert MfaConfig.effective_timeout(config, 5_000) == 5_000
    end

    test "supports :infinity timeout" do
      config = %MfaConfig{timeout: :infinity}
      assert MfaConfig.effective_timeout(config, 5_000) == :infinity
    end
  end

  describe "effective_response_type/2" do
    test "returns explicit response_type when set" do
      config = %MfaConfig{response_type: :sync}
      assert MfaConfig.effective_response_type(config, :async) == :sync
    end

    test "returns default when response_type is nil" do
      config = %MfaConfig{response_type: nil}
      assert MfaConfig.effective_response_type(config, :async) == :async
    end
  end

  describe "effective_request_info/2" do
    test "returns explicit request_info when set" do
      config = %MfaConfig{request_info: false}
      assert MfaConfig.effective_request_info(config, true) == false
    end

    test "returns default when request_info is nil" do
      config = %MfaConfig{request_info: nil}
      assert MfaConfig.effective_request_info(config, true) == true
    end
  end

  describe "effective_check_permission/2" do
    test "returns explicit check_permission when set" do
      config = %MfaConfig{check_permission: {:arg, "user_id"}}
      assert MfaConfig.effective_check_permission(config, false) == {:arg, "user_id"}
    end

    test "returns default when check_permission is nil" do
      config = %MfaConfig{check_permission: nil}
      assert MfaConfig.effective_check_permission(config, false) == false
    end
  end

  describe "effective_permission_callback/2" do
    test "returns explicit permission_callback when set" do
      config = %MfaConfig{permission_callback: {MyModule, :check, []}}
      assert MfaConfig.effective_permission_callback(config, nil) == {MyModule, :check, []}
    end

    test "returns default when permission_callback is nil" do
      config = %MfaConfig{permission_callback: nil}
      assert MfaConfig.effective_permission_callback(config, {MyModule, :check, []}) == {MyModule, :check, []}
    end

    test "returns nil when both are nil" do
      config = %MfaConfig{permission_callback: nil}
      assert MfaConfig.effective_permission_callback(config, nil) == nil
    end
  end

  describe "effective_choose_node_mode/2" do
    test "returns explicit choose_node_mode when set" do
      config = %MfaConfig{choose_node_mode: :hash}
      assert MfaConfig.effective_choose_node_mode(config, :random) == :hash
    end

    test "returns default when choose_node_mode is nil" do
      config = %MfaConfig{choose_node_mode: nil}
      assert MfaConfig.effective_choose_node_mode(config, :random) == :random
    end
  end

  describe "effective_nodes/2" do
    test "returns explicit nodes when set" do
      config = %MfaConfig{nodes: [:"node1@host"]}
      assert MfaConfig.effective_nodes(config, :local) == [:"node1@host"]
    end

    test "returns default when nodes is nil" do
      config = %MfaConfig{nodes: nil}
      assert MfaConfig.effective_nodes(config, :local) == :local
    end
  end

  describe "effective_retry/2" do
    test "returns explicit retry when set" do
      config = %MfaConfig{retry: {:all_nodes, 3}}
      assert MfaConfig.effective_retry(config, nil) == {:all_nodes, 3}
    end

    test "returns default when retry is nil" do
      config = %MfaConfig{retry: nil}
      assert MfaConfig.effective_retry(config, nil) == nil
    end
  end

  describe "effective_version/2" do
    test "returns explicit version when set" do
      config = %MfaConfig{version: "2.0.0"}
      assert MfaConfig.effective_version(config, "0.0.1") == "2.0.0"
    end

    test "returns default when version is nil" do
      config = %MfaConfig{version: nil}
      assert MfaConfig.effective_version(config, "0.0.1") == "0.0.1"
    end
  end

  describe "has_explicit_arg_types?/1" do
    test "returns true when arg_types has entries" do
      config = %MfaConfig{arg_types: %{"user_id" => :string}}
      assert MfaConfig.has_explicit_arg_types?(config) == true
    end

    test "returns false when arg_types is nil" do
      config = %MfaConfig{arg_types: nil}
      assert MfaConfig.has_explicit_arg_types?(config) == false
    end

    test "returns false when arg_types is empty map" do
      config = %MfaConfig{arg_types: %{}}
      assert MfaConfig.has_explicit_arg_types?(config) == false
    end
  end

  describe "has_explicit_arg_orders?/1" do
    test "returns true when arg_orders has entries" do
      config = %MfaConfig{arg_orders: ["user_id", "content"]}
      assert MfaConfig.has_explicit_arg_orders?(config) == true
    end

    test "returns false when arg_orders is :map (default)" do
      config = %MfaConfig{arg_orders: :map}
      assert MfaConfig.has_explicit_arg_orders?(config) == false
    end

    test "returns false when arg_orders is nil" do
      config = %MfaConfig{arg_orders: nil}
      assert MfaConfig.has_explicit_arg_orders?(config) == false
    end

    test "returns false when arg_orders is empty list" do
      config = %MfaConfig{arg_orders: []}
      assert MfaConfig.has_explicit_arg_orders?(config) == false
    end
  end

  describe "enabled?/1" do
    test "returns true when disabled is false" do
      config = %MfaConfig{disabled: false}
      assert MfaConfig.enabled?(config) == true
    end

    test "returns false when disabled is true" do
      config = %MfaConfig{disabled: true}
      assert MfaConfig.enabled?(config) == false
    end
  end
end
