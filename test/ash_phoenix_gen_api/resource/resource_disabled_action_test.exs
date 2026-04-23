

defmodule AshPhoenixGenApi.ResourceDisabledActionTest do
  use ExUnit.Case

  @moduletag timeout: 60_000


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
