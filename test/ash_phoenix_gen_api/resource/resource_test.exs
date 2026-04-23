

defmodule AshPhoenixGenApi.ResourceTest do
  use ExUnit.Case

  @moduletag timeout: 60_000


  defmodule TestResource do
    use Ash.Resource,
      extensions: [AshPhoenixGenApi.Resource]

    attributes do
      uuid_primary_key :id
      attribute :from_user_id, :uuid do
        public? true
      end
      attribute :to_user_id, :uuid do
        public? true
      end
      attribute :content, :string do
        public? true
        allow_nil? true
      end
      attribute :reply_to_id, :uuid do
        public? true
        allow_nil? true
      end
      attribute :file_id, :uuid do
        public? true
        allow_nil? true
      end
      attribute :order, :integer do
        public? true
      end
    end

    actions do
      create :create do
        accept [:from_user_id, :to_user_id, :content, :reply_to_id, :file_id]
      end

      read :read do
        primary? true
      end

      update :update_content do
        accept [:content]
      end

      destroy :destroy
    end

    gen_api do
      service "test_service"
      nodes {TestCluster, :get_nodes, [:test]}
      choose_node_mode :random
      timeout 5_000
      response_type :async
      request_info true
      version "1.0.0"

      action :create do
        request_type "send_message"
        timeout 10_000
        check_permission {:arg, "from_user_id"}
      end

      action :read do
        request_type "get_messages"
        timeout 3_000
      end

      action :update_content do
        request_type "update_content"
        response_type :sync
      end
    end
  end

  describe "resource DSL" do
    test "resource compiles with gen_api extension" do
      assert Ash.Resource.Info.extensions(TestResource) |> Enum.any?(&(&1 == AshPhoenixGenApi.Resource))
    end

    test "resource has gen_api section configured" do
      assert AshPhoenixGenApi.Resource.Info.has_gen_api?(TestResource) == true
    end

    test "gen_api_service returns configured service" do
      assert AshPhoenixGenApi.Resource.Info.gen_api_service!(TestResource) == "test_service"
    end

    test "gen_api_nodes returns configured nodes" do
      assert AshPhoenixGenApi.Resource.Info.gen_api_nodes!(TestResource) == {TestCluster, :get_nodes, [:test]}
    end

    test "gen_api_choose_node_mode returns configured mode" do
      assert AshPhoenixGenApi.Resource.Info.gen_api_choose_node_mode!(TestResource) == :random
    end

    test "gen_api_timeout returns configured timeout" do
      assert AshPhoenixGenApi.Resource.Info.gen_api_timeout!(TestResource) == 5_000
    end

    test "gen_api_response_type returns configured response type" do
      assert AshPhoenixGenApi.Resource.Info.gen_api_response_type!(TestResource) == :async
    end

    test "gen_api_request_info returns configured request_info" do
      assert AshPhoenixGenApi.Resource.Info.gen_api_request_info!(TestResource) == true
    end

    test "gen_api_version returns configured version" do
      assert AshPhoenixGenApi.Resource.Info.gen_api_version!(TestResource) == "1.0.0"
    end

    test "gen_api_actions returns configured actions" do
      actions = AshPhoenixGenApi.Resource.Info.gen_api(TestResource)
      assert length(actions) == 3

      action_names = Enum.map(actions, & &1.name)
      assert :create in action_names
      assert :read in action_names
      assert :update_content in action_names
    end

    test "action returns specific action config" do
      action_config = AshPhoenixGenApi.Resource.Info.action(TestResource, :create)
      assert action_config.name == :create
      assert action_config.request_type == "send_message"
      assert action_config.timeout == 10_000
      assert action_config.check_permission == {:arg, "from_user_id"}
    end

    test "enabled_actions returns only enabled actions" do
      enabled = AshPhoenixGenApi.Resource.Info.enabled_actions(TestResource)
      assert length(enabled) == 3
    end

    test "action_request_type returns effective request type" do
      assert AshPhoenixGenApi.Resource.Info.action_request_type(TestResource, :create) == "send_message"
      assert AshPhoenixGenApi.Resource.Info.action_request_type(TestResource, :read) == "get_messages"
    end

    test "request_types returns all request type strings" do
      request_types = AshPhoenixGenApi.Resource.Info.request_types(TestResource)
      assert "send_message" in request_types
      assert "get_messages" in request_types
      assert "update_content" in request_types
    end
  end

  describe "effective value resolution" do
    test "effective_timeout resolves action-level over section-level" do
      # create action has timeout 10_000, section default is 5_000
      assert AshPhoenixGenApi.Resource.Info.effective_timeout(TestResource, :create) == 10_000
    end

    test "effective_timeout falls back to section-level default" do
      # update_content action has no explicit timeout, falls back to section default 5_000
      assert AshPhoenixGenApi.Resource.Info.effective_timeout(TestResource, :update_content) == 5_000
    end

    test "effective_response_type resolves action-level over section-level" do
      # update_content has response_type :sync, section default is :async
      assert AshPhoenixGenApi.Resource.Info.effective_response_type(TestResource, :update_content) == :sync
    end

    test "effective_response_type falls back to section-level default" do
      # create action has no explicit response_type, falls back to :async
      assert AshPhoenixGenApi.Resource.Info.effective_response_type(TestResource, :create) == :async
    end

    test "effective_mfa generates from resource and action name" do
      assert AshPhoenixGenApi.Resource.Info.effective_mfa(TestResource, :create) ==
               {TestResource, :create, []}
    end
  end

  describe "fun_configs generation" do
    test "fun_configs returns list of FunConfig structs" do
      fun_configs = AshPhoenixGenApi.Resource.Info.fun_configs(TestResource)
      assert is_list(fun_configs)
      assert length(fun_configs) == 3
    end

    test "fun_configs have correct service" do
      fun_configs = AshPhoenixGenApi.Resource.Info.fun_configs(TestResource)
      Enum.each(fun_configs, fn fc ->
        assert fc.service == "test_service"
      end)
    end

    test "fun_configs have correct nodes" do
      fun_configs = AshPhoenixGenApi.Resource.Info.fun_configs(TestResource)
      Enum.each(fun_configs, fn fc ->
        assert fc.nodes == {TestCluster, :get_nodes, [:test]}
      end)
    end

    test "fun_config by request_type" do
      fc = AshPhoenixGenApi.Resource.Info.fun_config(TestResource, "send_message")
      assert fc != nil
      assert fc.request_type == "send_message"
      assert fc.timeout == 10_000
      assert fc.check_permission == {:arg, "from_user_id"}
      assert fc.response_type == :async
      assert fc.request_info == true
      assert fc.version == "1.0.0"
    end

    test "fun_config with auto-derived args" do
      fc = AshPhoenixGenApi.Resource.Info.fun_config(TestResource, "send_message")
      assert fc != nil
      # The create action accepts [:from_user_id, :to_user_id, :content, :reply_to_id, :file_id]
      # UUIDs map to :string, :string maps to :string
      assert is_map(fc.arg_types)
      assert fc.arg_orders == :map
      assert Map.has_key?(fc.arg_types, "from_user_id")
      assert Map.has_key?(fc.arg_types, "content")
    end
  end
end
