
defmodule AshPhoenixGenApi.Resource.CodeInterfaceInfoTest do
  use ExUnit.Case

  @moduletag timeout: 60_000


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
