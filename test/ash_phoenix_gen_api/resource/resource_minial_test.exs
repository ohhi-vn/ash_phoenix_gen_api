
defmodule AshPhoenixGenApi.ResourceMinimalTest do
  use ExUnit.Case

  @moduletag timeout: 60_000


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
