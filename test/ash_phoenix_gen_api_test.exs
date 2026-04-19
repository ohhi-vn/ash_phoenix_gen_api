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
      assert defaults.permission_callback == nil
      assert defaults.choose_node_mode == :random
      assert defaults.nodes == :local
      assert defaults.version == "0.0.1"
      assert defaults.retry == nil
      assert defaults.code_interface? == true
      assert defaults.push_nodes == nil
      assert defaults.push_on_startup == false
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

defmodule AshPhoenixGenApi.Resource.CodeInterfaceTest do
  use ExUnit.Case

  defmodule CodeInterfaceResource do
    use Ash.Resource,
      domain: AshPhoenixGenApi.Resource.CodeInterfaceTest.TestDomain,
      extensions: [AshPhoenixGenApi.Resource],
      data_layer: Ash.DataLayer.Ets

    attributes do
      uuid_primary_key :id
      attribute :name, :string do
        public? true
      end
      attribute :content, :string do
        public? true
        allow_nil? true
      end
    end

    actions do
      create :create do
        accept [:name, :content]
      end

      read :read do
        primary? true
      end

      update :update do
        accept [:name, :content]
      end

      destroy :destroy

      action :greet, :string do
        argument :name, :string do
          allow_nil? false
        end

        run fn input, _ ->
          {:ok, "Hello, #{input.arguments.name}!"}
        end
      end
    end

    gen_api do
      service "code_interface_test"
      code_interface? true

      action :create
      action :read
      action :update
      action :destroy
      action :greet
    end
  end

  defmodule TestDomain do
    use Ash.Domain

    resources do
      resource CodeInterfaceResource
    end
  end

  describe "code interface function generation" do
    test "create action generates name/2 and name!/2 functions" do
      assert function_exported?(CodeInterfaceResource, :create, 2)
      assert function_exported?(CodeInterfaceResource, :create!, 2)
    end

    test "read action generates name/2 and name!/2 functions" do
      assert function_exported?(CodeInterfaceResource, :read, 2)
      assert function_exported?(CodeInterfaceResource, :read!, 2)
    end

    test "update action generates name/3 and name!/3 functions" do
      assert function_exported?(CodeInterfaceResource, :update, 3)
      assert function_exported?(CodeInterfaceResource, :update!, 3)
    end

    test "destroy action generates name/3 and name!/3 functions" do
      assert function_exported?(CodeInterfaceResource, :destroy, 3)
      assert function_exported?(CodeInterfaceResource, :destroy!, 3)
    end

    test "generic action generates name/2 and name!/2 functions" do
      assert function_exported?(CodeInterfaceResource, :greet, 2)
      assert function_exported?(CodeInterfaceResource, :greet!, 2)
    end
  end

  describe "code interface function execution" do
    test "create action function creates a record" do
      assert {:ok, record} = CodeInterfaceResource.create(%{name: "test"})
      assert %CodeInterfaceResource{} = record
      assert record.name == "test"
    end

    test "create! action function creates a record and returns it" do
      record = CodeInterfaceResource.create!(%{name: "test2"})
      assert %CodeInterfaceResource{} = record
      assert record.name == "test2"
    end

    test "read action function returns records" do
      CodeInterfaceResource.create!(%{name: "read_test"})
      assert {:ok, records} = CodeInterfaceResource.read()
      assert is_list(records)
    end

    test "read! action function returns records" do
      CodeInterfaceResource.create!(%{name: "read_test2"})
      records = CodeInterfaceResource.read!()
      assert is_list(records)
    end

    test "update action function updates a record" do
      record = CodeInterfaceResource.create!(%{name: "original"})
      assert {:ok, updated} = CodeInterfaceResource.update(record, %{name: "updated"})
      assert updated.name == "updated"
    end

    test "update! action function updates a record and returns it" do
      record = CodeInterfaceResource.create!(%{name: "original2"})
      updated = CodeInterfaceResource.update!(record, %{name: "updated2"})
      assert updated.name == "updated2"
    end

    test "destroy action function destroys a record" do
      record = CodeInterfaceResource.create!(%{name: "to_delete"})
      assert :ok = CodeInterfaceResource.destroy(record)
    end

    test "destroy! action function destroys a record" do
      record = CodeInterfaceResource.create!(%{name: "to_delete2"})
      assert :ok = CodeInterfaceResource.destroy!(record)
    end

    test "generic action function runs the action" do
      assert {:ok, "Hello, World!"} = CodeInterfaceResource.greet(%{name: "World"})
    end

    test "generic action bang function runs the action" do
      assert "Hello, World!" = CodeInterfaceResource.greet!(%{name: "World"})
    end
  end

  describe "code interface with actor option" do
    test "create action accepts actor option" do
      assert {:ok, _record} = CodeInterfaceResource.create(%{name: "with_actor"}, actor: nil)
    end

    test "read action accepts actor option" do
      assert {:ok, _records} = CodeInterfaceResource.read(actor: nil)
    end

    test "update action accepts actor option" do
      record = CodeInterfaceResource.create!(%{name: "actor_test"})
      assert {:ok, _updated} = CodeInterfaceResource.update(record, %{name: "new"}, actor: nil)
    end

    test "destroy action accepts actor option" do
      record = CodeInterfaceResource.create!(%{name: "actor_destroy"})
      assert :ok = CodeInterfaceResource.destroy(record, actor: nil)
    end

    test "generic action accepts actor option" do
      assert {:ok, _result} = CodeInterfaceResource.greet(%{name: "Actor"}, actor: nil)
    end
  end
end

defmodule AshPhoenixGenApi.Resource.CodeInterfaceDisabledTest do
  use ExUnit.Case

  defmodule CodeInterfaceDisabledResource do
    use Ash.Resource,
      domain: AshPhoenixGenApi.Resource.CodeInterfaceDisabledTest.TestDomain,
      extensions: [AshPhoenixGenApi.Resource],
      data_layer: Ash.DataLayer.Ets

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
      code_interface? false

      action :create
      action :read
    end
  end

  defmodule TestDomain do
    use Ash.Domain

    resources do
      resource CodeInterfaceDisabledResource
    end
  end

  describe "code_interface? false at section level" do
    test "does not generate code interface functions" do
      refute function_exported?(CodeInterfaceDisabledResource, :create, 2)
      refute function_exported?(CodeInterfaceDisabledResource, :create!, 2)
      refute function_exported?(CodeInterfaceDisabledResource, :read, 2)
      refute function_exported?(CodeInterfaceDisabledResource, :read!, 2)
    end

    test "still generates fun_configs" do
      fun_configs = AshPhoenixGenApi.Resource.Info.fun_configs(CodeInterfaceDisabledResource)
      assert length(fun_configs) == 2
    end
  end
end

defmodule AshPhoenixGenApi.Resource.CodeInterfaceActionOverrideTest do
  use ExUnit.Case

  defmodule CodeInterfaceActionOverrideResource do
    use Ash.Resource,
      domain: AshPhoenixGenApi.Resource.CodeInterfaceActionOverrideTest.TestDomain,
      extensions: [AshPhoenixGenApi.Resource],
      data_layer: Ash.DataLayer.Ets

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

      update :update do
        accept [:name]
      end
    end

    gen_api do
      service "action_override_test"
      code_interface? true

      action :create do
        code_interface? false
      end

      action :read

      action :update do
        code_interface? false
      end
    end
  end

  defmodule TestDomain do
    use Ash.Domain

    resources do
      resource CodeInterfaceActionOverrideResource
    end
  end

  describe "code_interface? false at action level overrides section level" do
    test "does not generate code interface for action with code_interface? false" do
      refute function_exported?(CodeInterfaceActionOverrideResource, :create, 2)
      refute function_exported?(CodeInterfaceActionOverrideResource, :create!, 2)
      refute function_exported?(CodeInterfaceActionOverrideResource, :update, 3)
      refute function_exported?(CodeInterfaceActionOverrideResource, :update!, 3)
    end

    test "generates code interface for action without override" do
      assert function_exported?(CodeInterfaceActionOverrideResource, :read, 2)
      assert function_exported?(CodeInterfaceActionOverrideResource, :read!, 2)
    end

    test "still generates fun_configs for all enabled actions" do
      fun_configs = AshPhoenixGenApi.Resource.Info.fun_configs(CodeInterfaceActionOverrideResource)
      assert length(fun_configs) == 3
    end
  end
end

defmodule AshPhoenixGenApi.Resource.CodeInterfaceActionEnableTest do
  use ExUnit.Case

  defmodule CodeInterfaceActionEnableResource do
    use Ash.Resource,
      domain: AshPhoenixGenApi.Resource.CodeInterfaceActionEnableTest.TestDomain,
      extensions: [AshPhoenixGenApi.Resource],
      data_layer: Ash.DataLayer.Ets

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
      service "action_enable_test"
      code_interface? false

      action :create do
        code_interface? true
      end

      action :read
    end
  end

  defmodule TestDomain do
    use Ash.Domain

    resources do
      resource CodeInterfaceActionEnableResource
    end
  end

  describe "code_interface? true at action level overrides section level false" do
    test "generates code interface for action with code_interface? true" do
      assert function_exported?(CodeInterfaceActionEnableResource, :create, 2)
      assert function_exported?(CodeInterfaceActionEnableResource, :create!, 2)
    end

    test "does not generate code interface for action inheriting section-level false" do
      refute function_exported?(CodeInterfaceActionEnableResource, :read, 2)
      refute function_exported?(CodeInterfaceActionEnableResource, :read!, 2)
    end
  end
end

defmodule AshPhoenixGenApi.Resource.CodeInterfaceInfoTest do
  use ExUnit.Case

  defmodule InfoTestResource do
    use Ash.Resource,
      domain: AshPhoenixGenApi.Resource.CodeInterfaceInfoTest.TestDomain,
      extensions: [AshPhoenixGenApi.Resource],
      data_layer: Ash.DataLayer.Ets

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
      service "info_test"
      code_interface? true

      action :create do
        code_interface? false
      end

      action :read
    end
  end

  defmodule TestDomain do
    use Ash.Domain

    resources do
      resource InfoTestResource
    end
  end

  describe "gen_api_code_interface?/1" do
    test "returns section-level code_interface? setting" do
      # Predicate functions (ending with ?) return the value directly, not {:ok, value}
      assert AshPhoenixGenApi.Resource.Info.gen_api_code_interface?(InfoTestResource) == true
    end
  end

  describe "effective_code_interface?/2" do
    test "returns action-level override when set" do
      assert AshPhoenixGenApi.Resource.Info.effective_code_interface?(InfoTestResource, :create) == false
    end

    test "returns section-level default when action-level not set" do
      assert AshPhoenixGenApi.Resource.Info.effective_code_interface?(InfoTestResource, :read) == true
    end
  end
end

defmodule AshPhoenixGenApi.Resource.ActionConfig.CodeInterfaceTest do
  use ExUnit.Case

  alias AshPhoenixGenApi.Resource.ActionConfig

  describe "effective_code_interface?/2" do
    test "returns explicit code_interface? when set to true" do
      config = %ActionConfig{code_interface?: true}
      assert ActionConfig.effective_code_interface?(config, false) == true
    end

    test "returns explicit code_interface? when set to false" do
      config = %ActionConfig{code_interface?: false}
      assert ActionConfig.effective_code_interface?(config, true) == false
    end

    test "returns default when code_interface? is nil" do
      config = %ActionConfig{code_interface?: nil}
      assert ActionConfig.effective_code_interface?(config, true) == true
      assert ActionConfig.effective_code_interface?(config, false) == false
    end
  end
end

defmodule AshPhoenixGenApi.Resource.PermissionCallbackTest do
  use ExUnit.Case

  alias AshPhoenixGenApi.Resource.ActionConfig

  defmodule TestPermissionChecker do
    @moduledoc false
    def check_permission(request_type, args) do
      case request_type do
        "admin_action" -> Map.get(args, "role") == "admin"
        "user_action" -> Map.get(args, "user_id") != nil
        _ -> true
      end
    end

    def deny_all(_request_type, _args), do: false
    def allow_all(_request_type, _args), do: true
  end

  defmodule PermissionCallbackResource do
    use Ash.Resource,
      domain: AshPhoenixGenApi.Resource.PermissionCallbackTest.TestDomain,
      extensions: [AshPhoenixGenApi.Resource],
      data_layer: Ash.DataLayer.Ets

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
      service "permission_callback_test"
      permission_callback {TestPermissionChecker, :check_permission, []}

      action :create do
        request_type "admin_action"
      end

      action :read do
        request_type "user_action"
      end
    end
  end

  defmodule TestDomain do
    use Ash.Domain

    resources do
      resource PermissionCallbackResource
    end
  end

  describe "permission_callback in ActionConfig" do
    test "effective_permission_callback returns action-level callback" do
      config = %ActionConfig{permission_callback: {TestPermissionChecker, :deny_all, []}}
      assert ActionConfig.effective_permission_callback(config, nil) ==
               {TestPermissionChecker, :deny_all, []}
    end

    test "effective_permission_callback falls back to section default" do
      config = %ActionConfig{permission_callback: nil}
      assert ActionConfig.effective_permission_callback(config, {TestPermissionChecker, :allow_all, []}) ==
               {TestPermissionChecker, :allow_all, []}
    end

    test "effective_permission_callback returns nil when both nil" do
      config = %ActionConfig{permission_callback: nil}
      assert ActionConfig.effective_permission_callback(config, nil) == nil
    end
  end

  describe "permission_callback in FunConfig generation" do
    test "permission_callback is stored as {:callback, mfa} in FunConfig check_permission" do
      fun_configs = AshPhoenixGenApi.Resource.Info.fun_configs(PermissionCallbackResource)

      for config <- fun_configs do
        assert config.check_permission == {:callback, {TestPermissionChecker, :check_permission, []}}
      end
    end

    test "action-level permission_callback overrides section-level" do
      # Test with a resource that has action-level override
      defmodule ActionOverrideResource do
        use Ash.Resource,
          domain: AshPhoenixGenApi.Resource.PermissionCallbackTest.TestDomain2,
          extensions: [AshPhoenixGenApi.Resource],
          data_layer: Ash.DataLayer.Ets

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
          service "action_override_cb_test"
          permission_callback {TestPermissionChecker, :check_permission, []}

          action :create do
            permission_callback {TestPermissionChecker, :deny_all, []}
          end

          action :read
        end
      end

      defmodule TestDomain2 do
        use Ash.Domain

        resources do
          resource ActionOverrideResource
        end
      end

      fun_configs = AshPhoenixGenApi.Resource.Info.fun_configs(ActionOverrideResource)
      create_config = Enum.find(fun_configs, &(&1.request_type == "create"))
      read_config = Enum.find(fun_configs, &(&1.request_type == "read"))

      assert create_config.check_permission == {:callback, {TestPermissionChecker, :deny_all, []}}
      assert read_config.check_permission == {:callback, {TestPermissionChecker, :check_permission, []}}
    end

    test "check_permission is used when permission_callback is nil" do
      defmodule NoCallbackResource do
        use Ash.Resource,
          domain: AshPhoenixGenApi.Resource.PermissionCallbackTest.TestDomain3,
          extensions: [AshPhoenixGenApi.Resource],
          data_layer: Ash.DataLayer.Ets

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
          service "no_callback_test"
          check_permission :any_authenticated

          action :create
        end
      end

      defmodule TestDomain3 do
        use Ash.Domain

        resources do
          resource NoCallbackResource
        end
      end

      fun_configs = AshPhoenixGenApi.Resource.Info.fun_configs(NoCallbackResource)
      create_config = Enum.find(fun_configs, &(&1.request_type == "create"))
      assert create_config.check_permission == :any_authenticated
    end
  end

  describe "permission_callback introspection" do
    test "gen_api_permission_callback returns {:ok, section-level setting}" do
      result = AshPhoenixGenApi.Resource.Info.gen_api_permission_callback(PermissionCallbackResource)
      assert result == {:ok, {TestPermissionChecker, :check_permission, []}}
    end

    test "effective_permission_callback resolves correctly" do
      assert AshPhoenixGenApi.Resource.Info.effective_permission_callback(PermissionCallbackResource, :create) ==
               {TestPermissionChecker, :check_permission, []}
    end
  end
end

defmodule AshPhoenixGenApi.Domain.PermissionCallbackTest do
  use ExUnit.Case

  defmodule DomainCallbackChecker do
    @moduledoc false
    def check_permission(_request_type, _args), do: true
  end

  defmodule DomainPermissionCallbackDomain do
    use Ash.Domain,
      extensions: [AshPhoenixGenApi.Domain]

    gen_api do
      service "domain_cb_test"
      supporter_module AshPhoenixGenApi.Domain.PermissionCallbackTest.Supporter
      permission_callback {DomainCallbackChecker, :check_permission, []}
      version "1.0.0"
    end

    resources do
    end
  end

  describe "domain-level permission_callback" do
    test "gen_api_permission_callback returns {:ok, configured callback}" do
      result = AshPhoenixGenApi.Domain.Info.gen_api_permission_callback(DomainPermissionCallbackDomain)
      assert result == {:ok, {DomainCallbackChecker, :check_permission, []}}
    end

    test "permission_callback helper returns configured callback" do
      result = AshPhoenixGenApi.Domain.Info.permission_callback(DomainPermissionCallbackDomain)
      assert result == {DomainCallbackChecker, :check_permission, []}
    end
  end
end

defmodule AshPhoenixGenApi.Domain.PushConfigTest do
  use ExUnit.Case

  defmodule PushTestDomain do
    use Ash.Domain,
      extensions: [AshPhoenixGenApi.Domain]

    gen_api do
      service "push_test"
      supporter_module AshPhoenixGenApi.Domain.PushConfigTest.Supporter
      version "1.0.0"
      push_nodes [:"gateway1@host", :"gateway2@host"]
    end

    resources do
    end
  end

  defmodule PushMfaDomain do
    use Ash.Domain,
      extensions: [AshPhoenixGenApi.Domain]

    gen_api do
      service "push_mfa_test"
      supporter_module AshPhoenixGenApi.Domain.PushConfigTest.MfaSupporter
      version "2.0.0"
      push_nodes {__MODULE__, :get_nodes, []}
    end

    resources do
    end

    def get_nodes, do: [:"mfa_gateway@host"]
  end

  defmodule NoPushDomain do
    use Ash.Domain,
      extensions: [AshPhoenixGenApi.Domain]

    gen_api do
      service "no_push_test"
      supporter_module AshPhoenixGenApi.Domain.PushConfigTest.NoPushSupporter
      version "1.0.0"
    end

    resources do
    end
  end

  describe "push_nodes configuration" do
    test "gen_api_push_nodes returns {:ok, configured list}" do
      result = AshPhoenixGenApi.Domain.Info.gen_api_push_nodes(PushTestDomain)
      assert result == {:ok, [:"gateway1@host", :"gateway2@host"]}
    end

    test "push_nodes helper returns configured list" do
      result = AshPhoenixGenApi.Domain.Info.push_nodes(PushTestDomain)
      assert result == [:"gateway1@host", :"gateway2@host"]
    end

    test "push_nodes returns nil when not configured" do
      result = AshPhoenixGenApi.Domain.Info.push_nodes(NoPushDomain)
      assert result == nil
    end

    test "push_nodes returns MFA tuple when configured" do
      result = AshPhoenixGenApi.Domain.Info.push_nodes(PushMfaDomain)
      assert result == {PushMfaDomain, :get_nodes, []}
    end
  end

  describe "push_on_startup configuration" do
    test "gen_api_push_on_startup returns {:ok, false} by default" do
      result = AshPhoenixGenApi.Domain.Info.gen_api_push_on_startup(PushTestDomain)
      assert result == {:ok, false}
    end

    test "push_on_startup? helper returns false by default" do
      result = AshPhoenixGenApi.Domain.Info.push_on_startup?(PushTestDomain)
      assert result == false
    end
  end

  describe "generated supporter module push functions" do
    test "build_push_config/0 returns a PushConfig struct" do
      alias PhoenixGenApi.Structs.PushConfig

      push_config = AshPhoenixGenApi.Domain.PushConfigTest.Supporter.build_push_config()
      assert %PushConfig{} = push_config
      assert push_config.service == "push_test"
      assert push_config.config_version == "1.0.0"
      assert push_config.module == AshPhoenixGenApi.Domain.PushConfigTest.Supporter
      assert push_config.function == :get_config
      assert push_config.version_module == AshPhoenixGenApi.Domain.PushConfigTest.Supporter
      assert push_config.version_function == :get_config_version
    end

    test "build_push_config/0 resolves push_nodes list" do
      alias PhoenixGenApi.Structs.PushConfig

      push_config = AshPhoenixGenApi.Domain.PushConfigTest.Supporter.build_push_config()
      assert push_config.nodes == [:"gateway1@host", :"gateway2@host"]
    end

    test "build_push_config/0 resolves MFA push_nodes at runtime" do
      alias PhoenixGenApi.Structs.PushConfig

      push_config = AshPhoenixGenApi.Domain.PushConfigTest.MfaSupporter.build_push_config()
      assert push_config.nodes == [:"mfa_gateway@host"]
    end

    test "resolve_push_nodes/0 returns configured list" do
      result = AshPhoenixGenApi.Domain.PushConfigTest.Supporter.resolve_push_nodes()
      assert result == [:"gateway1@host", :"gateway2@host"]
    end

    test "resolve_push_nodes/0 resolves MFA at runtime" do
      result = AshPhoenixGenApi.Domain.PushConfigTest.MfaSupporter.resolve_push_nodes()
      assert result == [:"mfa_gateway@host"]
    end

    test "resolve_push_nodes/0 returns nil when not configured" do
      result = AshPhoenixGenApi.Domain.PushConfigTest.NoPushSupporter.resolve_push_nodes()
      assert result == nil
    end

    test "push_to_configured_nodes/1 returns error when no push_nodes" do
      result = AshPhoenixGenApi.Domain.PushConfigTest.NoPushSupporter.push_to_configured_nodes()
      assert result == {:error, :no_push_nodes_configured}
    end

    test "verify_on_gateway/2 is exported" do
      assert function_exported?(AshPhoenixGenApi.Domain.PushConfigTest.Supporter, :verify_on_gateway, 2)
    end

    test "push_to_gateway/2 is exported" do
      assert function_exported?(AshPhoenixGenApi.Domain.PushConfigTest.Supporter, :push_to_gateway, 2)
    end

    test "push_on_startup/2 is exported" do
      assert function_exported?(AshPhoenixGenApi.Domain.PushConfigTest.Supporter, :push_on_startup, 2)
    end
  end

  describe "domain summary includes push config" do
    test "summary includes push_nodes" do
      summary = AshPhoenixGenApi.Domain.Info.summary(PushTestDomain)
      assert summary.push_nodes == [:"gateway1@host", :"gateway2@host"]
    end

    test "summary includes push_on_startup" do
      summary = AshPhoenixGenApi.Domain.Info.summary(PushTestDomain)
      assert summary.push_on_startup == false
    end
  end
end
