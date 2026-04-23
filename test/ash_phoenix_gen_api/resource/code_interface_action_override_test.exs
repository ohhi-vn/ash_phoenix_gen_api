

defmodule AshPhoenixGenApi.Resource.CodeInterfaceActionOverrideTest do
  use ExUnit.Case

  @moduletag timeout: 60_000


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
