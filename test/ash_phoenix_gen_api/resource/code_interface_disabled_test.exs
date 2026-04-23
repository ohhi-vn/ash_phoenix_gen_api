
defmodule AshPhoenixGenApi.Resource.CodeInterfaceDisabledTest do
  use ExUnit.Case

  @moduletag timeout: 60_000


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
