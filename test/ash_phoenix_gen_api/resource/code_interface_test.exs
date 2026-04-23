

defmodule AshPhoenixGenApi.Resource.CodeInterfaceTest do
  use ExUnit.Case

  @moduletag timeout: 60_000


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
