
defmodule AshPhoenixGenApi.Resource.CodeInterfaceActionEnableTest do
  use ExUnit.Case

  @moduletag timeout: 60_000


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
