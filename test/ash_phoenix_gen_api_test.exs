defmodule AshPhoenixGenApi.TypeMapperTest do
  use ExUnit.Case, async: true

  alias AshPhoenixGenApi.TypeMapper

  describe "to_gen_api_type/1 - string types" do
    test "maps :string to :string" do
      assert TypeMapper.to_gen_api_type(:string) == :string
    end

    test "maps Ash.Type.String to :string" do
      assert TypeMapper.to_gen_api_type(Ash.Type.String) == :string
    end

    test "maps :ci_string to :string" do
      assert TypeMapper.to_gen_api_type(:ci_string) == :string
    end

    test "maps Ash.Type.CiString to :string" do
      assert TypeMapper.to_gen_api_type(Ash.Type.CiString) == :string
    end
  end

  describe "to_gen_api_type/1 - numeric types" do
    test "maps :integer to :num" do
      assert TypeMapper.to_gen_api_type(:integer) == :num
    end

    test "maps Ash.Type.Integer to :num" do
      assert TypeMapper.to_gen_api_type(Ash.Type.Integer) == :num
    end

    test "maps :float to :num" do
      assert TypeMapper.to_gen_api_type(:float) == :num
    end

    test "maps Ash.Type.Float to :num" do
      assert TypeMapper.to_gen_api_type(Ash.Type.Float) == :num
    end

    test "maps :decimal to :num" do
      assert TypeMapper.to_gen_api_type(:decimal) == :num
    end

    test "maps Ash.Type.Decimal to :num" do
      assert TypeMapper.to_gen_api_type(Ash.Type.Decimal) == :num
    end
  end

  describe "to_gen_api_type/1 - UUID types" do
    test "maps :uuid to :string" do
      assert TypeMapper.to_gen_api_type(:uuid) == :string
    end

    test "maps Ash.Type.UUID to :string" do
      assert TypeMapper.to_gen_api_type(Ash.Type.UUID) == :string
    end

    test "maps :uuid_v7 to :string" do
      assert TypeMapper.to_gen_api_type(:uuid_v7) == :string
    end
  end

  describe "to_gen_api_type/1 - date/time types" do
    test "maps :date to :string" do
      assert TypeMapper.to_gen_api_type(:date) == :string
    end

    test "maps :time to :string" do
      assert TypeMapper.to_gen_api_type(:time) == :string
    end

    test "maps :datetime to :string" do
      assert TypeMapper.to_gen_api_type(:datetime) == :string
    end

    test "maps :utc_datetime to :string" do
      assert TypeMapper.to_gen_api_type(:utc_datetime) == :string
    end

    test "maps :naive_datetime to :string" do
      assert TypeMapper.to_gen_api_type(:naive_datetime) == :string
    end

    test "maps Ash.Type.UtcDateTime to :string" do
      assert TypeMapper.to_gen_api_type(Ash.Type.UtcDateTime) == :string
    end

    test "maps Ash.Type.NaiveDateTime to :string" do
      assert TypeMapper.to_gen_api_type(Ash.Type.NaiveDateTime) == :string
    end
  end

  describe "to_gen_api_type/1 - boolean type" do
    test "maps :boolean to :string" do
      assert TypeMapper.to_gen_api_type(:boolean) == :string
    end

    test "maps Ash.Type.Boolean to :string" do
      assert TypeMapper.to_gen_api_type(Ash.Type.Boolean) == :string
    end
  end

  describe "to_gen_api_type/1 - atom type" do
    test "maps :atom to :string" do
      assert TypeMapper.to_gen_api_type(:atom) == :string
    end

    test "maps Ash.Type.Atom to :string" do
      assert TypeMapper.to_gen_api_type(Ash.Type.Atom) == :string
    end
  end

  describe "to_gen_api_type/1 - map/json/struct types" do
    test "maps :map to :string" do
      assert TypeMapper.to_gen_api_type(:map) == :string
    end

    test "maps Ash.Type.Map to :string" do
      assert TypeMapper.to_gen_api_type(Ash.Type.Map) == :string
    end

    test "maps Ash.Type.Json to :string" do
      assert TypeMapper.to_gen_api_type(Ash.Type.Json) == :string
    end

    test "maps :struct to :string" do
      assert TypeMapper.to_gen_api_type(:struct) == :string
    end

    test "maps :keyword to :string" do
      assert TypeMapper.to_gen_api_type(:keyword) == :string
    end
  end

  describe "to_gen_api_type/1 - binary type" do
    test "maps :binary to :string" do
      assert TypeMapper.to_gen_api_type(:binary) == :string
    end

    test "maps Ash.Type.Binary to :string" do
      assert TypeMapper.to_gen_api_type(Ash.Type.Binary) == :string
    end
  end

  describe "to_gen_api_type/1 - term/tuple types" do
    test "maps :term to :string" do
      assert TypeMapper.to_gen_api_type(:term) == :string
    end

    test "maps :tuple to :string" do
      assert TypeMapper.to_gen_api_type(:tuple) == :string
    end
  end

  describe "to_gen_api_type/1 - array types" do
    test "maps {:array, :string} to {:list_string, max_items, max_item_length}" do
      assert TypeMapper.to_gen_api_type({:array, :string}) ==
               {:list_string, 1000, 50}
    end

    test "maps {:array, :integer} to {:list_num, max_items}" do
      assert TypeMapper.to_gen_api_type({:array, :integer}) ==
               {:list_num, 1000}
    end

    test "maps {:array, :uuid} to {:list_string, max_items, max_item_length}" do
      assert TypeMapper.to_gen_api_type({:array, :uuid}) ==
               {:list_string, 1000, 50}
    end

    test "maps {:array, :float} to {:list_num, max_items}" do
      assert TypeMapper.to_gen_api_type({:array, :float}) ==
               {:list_num, 1000}
    end

    test "maps {:array, :boolean} to {:list_string, max_items, max_item_length}" do
      # boolean maps to :string, so array of boolean maps to list_string
      assert TypeMapper.to_gen_api_type({:array, :boolean}) ==
               {:list_string, 1000, 50}
    end

    test "maps {:array, :map} to {:list_string, max_items, max_item_length}" do
      # map maps to :string, so array of map maps to list_string
      assert TypeMapper.to_gen_api_type({:array, :map}) ==
               {:list_string, 1000, 50}
    end

    test "respects max_items constraint" do
      assert TypeMapper.to_gen_api_type({:array, :string}, max_items: 500) ==
               {:list_string, 500, 50}
    end

    test "respects max_item_length constraint for string arrays" do
      assert TypeMapper.to_gen_api_type({:array, :string}, items: [max_length: 100]) ==
               {:list_string, 1000, 100}
    end
  end

  describe "to_gen_api_type/1 - unknown types" do
    test "maps unknown atoms to :string" do
      assert TypeMapper.to_gen_api_type(:some_unknown_type) == :string
    end

    test "maps unknown tuples to :string" do
      assert TypeMapper.to_gen_api_type({:custom, :thing}) == :string
    end
  end

  describe "list_type?/1" do
    test "returns true for array types" do
      assert TypeMapper.list_type?({:array, :string}) == true
      assert TypeMapper.list_type?({:array, :integer}) == true
    end

    test "returns true for Ash.Type.Array" do
      assert TypeMapper.list_type?(Ash.Type.Array) == true
    end

    test "returns false for non-array types" do
      assert TypeMapper.list_type?(:string) == false
      assert TypeMapper.list_type?(:integer) == false
      assert TypeMapper.list_type?(:uuid) == false
    end
  end

  describe "default constants" do
    test "default_max_list_items returns 1000" do
      assert TypeMapper.default_max_list_items() == 1000
    end

    test "default_max_string_item_length returns 50" do
      assert TypeMapper.default_max_string_item_length() == 50
    end
  end
end

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

defmodule AshPhoenixGenApi.ResourceTest do
  use ExUnit.Case

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
      assert is_list(fc.arg_orders)
      assert Map.has_key?(fc.arg_types, "from_user_id")
      assert Map.has_key?(fc.arg_types, "content")
    end
  end
end

defmodule AshPhoenixGenApi.ResourceMinimalTest do
  use ExUnit.Case

  defmodule MinimalResource do
    use Ash.Resource,
      extensions: [AshPhoenixGenApi.Resource]

    attributes do
      uuid_primary_key :id
      attribute :name, :string do
        public? true
      end
    end

    actions do
      create :create do
        accept [:name]
      end
    end

    gen_api do
      service "minimal"
      action :create
    end
  end

  describe "minimal resource config" do
    test "compiles with minimal gen_api config" do
      assert AshPhoenixGenApi.Resource.Info.has_gen_api?(MinimalResource) == true
    end

    test "uses defaults for unspecified options" do
      assert AshPhoenixGenApi.Resource.Info.gen_api_timeout!(MinimalResource) == 5_000
      assert AshPhoenixGenApi.Resource.Info.gen_api_response_type!(MinimalResource) == :async
      assert AshPhoenixGenApi.Resource.Info.gen_api_request_info!(MinimalResource) == true
      assert AshPhoenixGenApi.Resource.Info.gen_api_check_permission!(MinimalResource) == false
      assert AshPhoenixGenApi.Resource.Info.gen_api_choose_node_mode!(MinimalResource) == :random
      assert AshPhoenixGenApi.Resource.Info.gen_api_nodes!(MinimalResource) == :local
      assert AshPhoenixGenApi.Resource.Info.gen_api_version!(MinimalResource) == "0.0.1"
    end

    test "auto-derives request_type from action name" do
      action_config = AshPhoenixGenApi.Resource.Info.action(MinimalResource, :create)
      assert action_config != nil
      assert AshPhoenixGenApi.Resource.ActionConfig.effective_request_type(action_config) == "create"
    end

    test "generates fun_config with defaults" do
      fc = AshPhoenixGenApi.Resource.Info.fun_config(MinimalResource, "create")
      assert fc != nil
      assert fc.request_type == "create"
      assert fc.service == "minimal"
      assert fc.nodes == :local
      assert fc.choose_node_mode == :random
      assert fc.timeout == 5_000
      assert fc.response_type == :async
      assert fc.request_info == true
      assert fc.check_permission == false
      assert fc.version == "0.0.1"
    end
  end
end

defmodule AshPhoenixGenApi.ResourceWithExplicitArgsTest do
  use ExUnit.Case

  defmodule ExplicitArgsResource do
    use Ash.Resource,
      extensions: [AshPhoenixGenApi.Resource]

    attributes do
      uuid_primary_key :id
      attribute :user_id, :uuid do
        public? true
      end
      attribute :content, :string do
        public? true
        allow_nil? true
      end
    end

    actions do
      create :create do
        accept [:user_id, :content]
      end
    end

    gen_api do
      service "explicit_args"
      action :create do
        request_type "send_message"
        arg_types %{"user_id" => :string, "content" => :string, "tags" => {:list_string, 100, 20}}
        arg_orders ["user_id", "content", "tags"]
      end
    end
  end

  describe "resource with explicit arg_types and arg_orders" do
    test "uses explicit arg_types and arg_orders" do
      fc = AshPhoenixGenApi.Resource.Info.fun_config(ExplicitArgsResource, "send_message")
      assert fc != nil
      assert fc.arg_types == %{"user_id" => :string, "content" => :string, "tags" => {:list_string, 100, 20}}
      assert fc.arg_orders == ["user_id", "content", "tags"]
    end
  end
end

defmodule AshPhoenixGenApi.ResourceDisabledActionTest do
  use ExUnit.Case

  defmodule DisabledActionResource do
    use Ash.Resource,
      extensions: [AshPhoenixGenApi.Resource]

    attributes do
      uuid_primary_key :id
      attribute :name, :string do
        public? true
      end
    end

    actions do
      create :create do
        accept [:name]
      end
      read :read do
        primary? true
      end
    end

    gen_api do
      service "disabled_test"
      action :create
      action :read do
        disabled true
      end
    end
  end

  describe "resource with disabled action" do
    test "enabled_actions excludes disabled actions" do
      enabled = AshPhoenixGenApi.Resource.Info.enabled_actions(DisabledActionResource)
      assert length(enabled) == 1
      assert hd(enabled).name == :create
    end

    test "fun_configs excludes disabled actions" do
      fun_configs = AshPhoenixGenApi.Resource.Info.fun_configs(DisabledActionResource)
      assert length(fun_configs) == 1
      assert hd(fun_configs).request_type == "create"
    end

    test "request_types excludes disabled actions" do
      request_types = AshPhoenixGenApi.Resource.Info.request_types(DisabledActionResource)
      assert request_types == ["create"]
    end
  end
end

defmodule AshPhoenixGenApi.DomainTest do
  use ExUnit.Case

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

defmodule AshPhoenixGenApi.TypeMapper.ActionFieldsTest do
  use ExUnit.Case, async: true

  alias AshPhoenixGenApi.TypeMapper

  describe "build_arg_config/1" do
    test "builds arg_types map and arg_orders list from fields" do
      fields = [
        {:user_id, :string, false},
        {:count, :num, true},
        {:tags, {:list_string, 100, 20}, true}
      ]

      {arg_types, arg_orders} = TypeMapper.build_arg_config(fields)

      assert arg_types == %{
               "user_id" => :string,
               "count" => :num,
               "tags" => {:list_string, 100, 20}
             }

      assert arg_orders == ["user_id", "count", "tags"]
    end

    test "handles empty fields" do
      {arg_types, arg_orders} = TypeMapper.build_arg_config([])
      assert arg_types == %{}
      assert arg_orders == []
    end
  end
end

defmodule AshPhoenixGenApi.DefaultsTest do
  use ExUnit.Case, async: true

  describe "AshPhoenixGenApi.defaults/0" do
    test "returns expected default values" do
      defaults = AshPhoenixGenApi.defaults()

      assert defaults.timeout == 5_000
      assert defaults.response_type == :async
      assert defaults.request_info == true
      assert defaults.check_permission == false
      assert defaults.choose_node_mode == :random
      assert defaults.nodes == :local
      assert defaults.version == "0.0.1"
      assert defaults.retry == nil
    end
  end

  describe "AshPhoenixGenApi.extensions/0" do
    test "returns list of extension modules" do
      extensions = AshPhoenixGenApi.extensions()

      assert AshPhoenixGenApi.Resource in extensions
      assert AshPhoenixGenApi.Domain in extensions
    end
  end

  describe "AshPhoenixGenApi.modules/0" do
    test "returns list of all modules" do
      modules = AshPhoenixGenApi.modules()

      assert AshPhoenixGenApi.Resource in modules
      assert AshPhoenixGenApi.Resource.Info in modules
      assert AshPhoenixGenApi.Resource.ActionConfig in modules
      assert AshPhoenixGenApi.Domain in modules
      assert AshPhoenixGenApi.Domain.Info in modules
      assert AshPhoenixGenApi.TypeMapper in modules
    end
  end
end
