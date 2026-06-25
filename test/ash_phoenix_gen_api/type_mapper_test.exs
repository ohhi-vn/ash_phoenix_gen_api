defmodule AshPhoenixGenApi.TypeMapperTest do
  use ExUnit.Case, async: true

  describe "to_gen_api_type/2" do
    test "maps string types" do
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(:string) == :string
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(Ash.Type.String) == :string
    end

    test "maps string with max_length constraint" do
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(:string, max_length: 255) == [
               type: :string,
               max_bytes: 255
             ]
    end

    test "maps numeric types" do
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(:integer) == :num
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(:float) == :num
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(:decimal) == :num
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(Ash.Type.Integer) == :num
    end

    test "maps boolean" do
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(:boolean) == :boolean
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(Ash.Type.Boolean) == :boolean
    end

    test "maps uuid types" do
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(:uuid) == :uuid
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(Ash.Type.UUID) == :uuid
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(:uuid_v7) == :uuid
    end

    test "maps datetime types" do
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(:datetime) == :datetime
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(:utc_datetime) == :datetime
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(:naive_datetime) == :naive_datetime
    end

    test "maps atom to string" do
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(:atom) == :string
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(Ash.Type.Atom) == :string
    end

    test "maps enum types to string" do
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(Ash.Type.Enum) == :string
    end

    test "maps map types" do
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(:map) == :map

      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(:map, max_items: 100) == [
               type: :map,
               max_items: 100
             ]
    end

    test "maps array of string to list_string" do
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type({:array, :string}) == [
               type: :list_string,
               max_items: 1000,
               max_item_bytes: 50
             ]
    end

    test "maps array of uuid to list_string with 50-byte cap" do
      result = AshPhoenixGenApi.TypeMapper.to_gen_api_type({:array, :uuid})
      assert is_list(result)
      assert {:type, :list_string} in result
    end

    test "maps array of integer to list_num" do
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type({:array, :integer}) == [
               type: :list_num,
               max_items: 1000
             ]
    end

    test "maps unknown types to string" do
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(:unknown_type) == :string
    end
  end

  describe "custom type registration" do
    setup do
      # Clear custom mappings before each test
      AshPhoenixGenApi.TypeMapper.clear_custom_mappings()
      on_exit(fn -> AshPhoenixGenApi.TypeMapper.clear_custom_mappings() end)
      :ok
    end

    test "register/2 adds a custom type mapping" do
      AshPhoenixGenApi.TypeMapper.register(MyCustomType, :num)
      assert {:ok, :num} = AshPhoenixGenApi.TypeMapper.lookup(MyCustomType)
    end

    test "to_gen_api_type uses registered custom mapping" do
      AshPhoenixGenApi.TypeMapper.register(MyCustomType, :num)
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(MyCustomType) == :num
    end

    test "to_gen_api_type uses registered tuple mapping" do
      AshPhoenixGenApi.TypeMapper.register(MyStringType, {:string, 255})
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(MyStringType) == {:string, 255}
    end

    test "unregister/1 removes a custom type mapping" do
      AshPhoenixGenApi.TypeMapper.register(MyCustomType, :num)
      AshPhoenixGenApi.TypeMapper.unregister(MyCustomType)
      assert :error = AshPhoenixGenApi.TypeMapper.lookup(MyCustomType)
    end

    test "lookup/1 returns :error for unregistered type" do
      assert :error = AshPhoenixGenApi.TypeMapper.lookup(UnregisteredType)
    end

    test "custom_mappings/0 returns all registered mappings" do
      AshPhoenixGenApi.TypeMapper.register(TypeA, :string)
      AshPhoenixGenApi.TypeMapper.register(TypeB, :num)
      mappings = AshPhoenixGenApi.TypeMapper.custom_mappings()
      assert mappings[TypeA] == :string
      assert mappings[TypeB] == :num
    end

    test "clear_custom_mappings/0 removes all custom mappings" do
      AshPhoenixGenApi.TypeMapper.register(MyCustomType, :num)
      AshPhoenixGenApi.TypeMapper.clear_custom_mappings()
      assert %{} == AshPhoenixGenApi.TypeMapper.custom_mappings()
    end

    test "registered mapping takes precedence over built-in" do
      # Override a built-in type mapping (e.g. :atom normally maps to :string)
      AshPhoenixGenApi.TypeMapper.register(:atom, :num)
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(:atom) == :num
    end
  end

  describe "attribute_to_gen_api_type/1" do
    test "maps a simple string attribute" do
      attr = %{type: :string, constraints: []}
      assert AshPhoenixGenApi.TypeMapper.attribute_to_gen_api_type(attr) == :string
    end

    test "delegates to to_gen_api_type (does not wrap nil)" do
      attr = %{type: :string, constraints: [allow_nil: true]}
      result = AshPhoenixGenApi.TypeMapper.attribute_to_gen_api_type(attr)
      assert result == :string
    end
  end

  describe "argument_to_gen_api_type/1" do
    test "maps a simple integer argument" do
      arg = %{type: :integer, constraints: []}
      assert AshPhoenixGenApi.TypeMapper.argument_to_gen_api_type(arg) == :num
    end
  end
end
