
defmodule AshPhoenixGenApi.Resource.ResultEncoderTest do
  use ExUnit.Case

  @moduletag timeout: 60_000


  alias AshPhoenixGenApi.Resource.Info

  defmodule StructDefaultResource do
    use Ash.Resource,
      domain: AshPhoenixGenApi.Resource.ResultEncoderTest.TestDomain,
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
      service "result_encoder_test"
      result_encoder :struct

      action :create
      action :read
    end
  end

  defmodule MapDefaultResource do
    use Ash.Resource,
      domain: AshPhoenixGenApi.Resource.ResultEncoderTest.TestDomain,
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
      service "result_encoder_test"
      result_encoder :map

      action :create
      action :read
    end
  end

  defmodule ActionOverrideResource do
    use Ash.Resource,
      domain: AshPhoenixGenApi.Resource.ResultEncoderTest.TestDomain,
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

      destroy :destroy
    end

    gen_api do
      service "result_encoder_test"
      result_encoder :struct

      action :create do
        result_encoder :map
      end

      action :read
      action :update do
        result_encoder :map
      end
      action :destroy
    end
  end

  defmodule TestDomain do
    use Ash.Domain

    resources do
      resource StructDefaultResource
      resource MapDefaultResource
      resource ActionOverrideResource
    end
  end

  describe "result_encoder DSL option" do
    test "gen_api_result_encoder returns {:ok, :struct} for struct default resource" do
      assert {:ok, :struct} = Info.gen_api_result_encoder(StructDefaultResource)
    end

    test "gen_api_result_encoder returns {:ok, :map} for map default resource" do
      assert {:ok, :map} = Info.gen_api_result_encoder(MapDefaultResource)
    end

    test "gen_api_result_encoder returns {:ok, :struct} for action override resource" do
      assert {:ok, :struct} = Info.gen_api_result_encoder(ActionOverrideResource)
    end
  end

  describe "effective_result_encoder/2" do
    test "returns section-level default :struct for struct default resource" do
      assert Info.effective_result_encoder(StructDefaultResource, :create) == :struct
    end

    test "returns section-level default :map for map default resource" do
      assert Info.effective_result_encoder(MapDefaultResource, :create) == :map
    end

    test "returns action-level :map override for action override resource create" do
      assert Info.effective_result_encoder(ActionOverrideResource, :create) == :map
    end

    test "returns section-level :struct for action override resource read" do
      assert Info.effective_result_encoder(ActionOverrideResource, :read) == :struct
    end

    test "returns action-level :map override for action override resource update" do
      assert Info.effective_result_encoder(ActionOverrideResource, :update) == :map
    end

    test "returns section-level :struct for action override resource destroy" do
      assert Info.effective_result_encoder(ActionOverrideResource, :destroy) == :struct
    end
  end

  describe "code interface with result_encoder :struct (default)" do
    test "create returns struct" do
      assert {:ok, record} = StructDefaultResource.create(%{name: "struct_test"})
      assert %StructDefaultResource{} = record
      assert record.name == "struct_test"
    end

    test "create! returns struct" do
      record = StructDefaultResource.create!(%{name: "struct_test2"})
      assert %StructDefaultResource{} = record
    end

    test "read returns list of structs" do
      StructDefaultResource.create!(%{name: "read_struct"})
      assert {:ok, records} = StructDefaultResource.read()
      assert is_list(records)
      Enum.each(records, fn r -> assert %StructDefaultResource{} = r end)
    end

    test "read! returns list of structs" do
      records = StructDefaultResource.read!()
      assert is_list(records)
    end
  end

  describe "code interface with result_encoder :map" do
    test "create returns map" do
      assert {:ok, result} = MapDefaultResource.create(%{name: "map_test"})
      assert is_map(result)
      refute Map.has_key?(result, :__struct__)
      assert result.name == "map_test"
    end

    test "create! returns map" do
      result = MapDefaultResource.create!(%{name: "map_test2"})
      assert is_map(result)
      refute Map.has_key?(result, :__struct__)
    end

    test "read returns list of maps" do
      MapDefaultResource.create!(%{name: "read_map"})
      assert {:ok, results} = MapDefaultResource.read()
      assert is_list(results)
      Enum.each(results, fn r ->
        assert is_map(r)
        refute Map.has_key?(r, :__struct__)
      end)
    end

    test "read! returns list of maps" do
      results = MapDefaultResource.read!()
      assert is_list(results)
      Enum.each(results, fn r ->
        assert is_map(r)
        refute Map.has_key?(r, :__struct__)
      end)
    end
  end

  describe "code interface with action-level result_encoder override" do
    test "create with :map override returns map" do
      assert {:ok, result} = ActionOverrideResource.create(%{name: "override_test"})
      assert is_map(result)
      refute Map.has_key?(result, :__struct__)
      assert result.name == "override_test"
    end

    test "create! with :map override returns map" do
      result = ActionOverrideResource.create!(%{name: "override_test2"})
      assert is_map(result)
      refute Map.has_key?(result, :__struct__)
    end

    test "read with :struct default returns struct" do
      assert {:ok, records} = ActionOverrideResource.read()
      assert is_list(records)
      Enum.each(records, fn r -> assert %ActionOverrideResource{} = r end)
    end

    test "update with :map override returns map" do
      # Create record directly via Ash to get a struct (create! returns a map
      # due to result_encoder: :map, but update requires a struct as first arg)
      record =
        Ash.Changeset.for_create(ActionOverrideResource, :create, %{name: "to_update"})
        |> Ash.create!()

      assert {:ok, result} = ActionOverrideResource.update(record, %{name: "updated"})
      assert is_map(result)
      refute Map.has_key?(result, :__struct__)
      assert result.name == "updated"
    end

    test "update! with :map override returns map" do
      # Create record directly via Ash to get a struct (create! returns a map
      # due to result_encoder: :map, but update requires a struct as first arg)
      record =
        Ash.Changeset.for_create(ActionOverrideResource, :create, %{name: "to_update2"})
        |> Ash.create!()

      result = ActionOverrideResource.update!(record, %{name: "updated2"})
      assert is_map(result)
      refute Map.has_key?(result, :__struct__)
    end

    test "destroy with :struct default returns :ok" do
      # Create record directly via Ash to get a struct (create! returns a map
      # due to result_encoder: :map, but destroy requires a struct as first arg)
      record =
        Ash.Changeset.for_create(ActionOverrideResource, :create, %{name: "to_delete"})
        |> Ash.create!()

      assert :ok = ActionOverrideResource.destroy(record)
    end

    test "destroy! with :struct default returns :ok" do
      # Create record directly via Ash to get a struct (create! returns a map
      # due to result_encoder: :map, but destroy requires a struct as first arg)
      record =
        Ash.Changeset.for_create(ActionOverrideResource, :create, %{name: "to_delete2"})
        |> Ash.create!()

      assert :ok = ActionOverrideResource.destroy!(record)
    end
  end
end
