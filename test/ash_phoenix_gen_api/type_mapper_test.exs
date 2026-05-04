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

    test "string types maps :string with max_length constraint to [type: :string, max_bytes: 255]" do
      assert TypeMapper.to_gen_api_type(:string, max_length: 255) ==
               [type: :string, max_bytes: 255]
    end

    test "string types maps Ash.Type.String with max_length constraint to [type: :string, max_bytes: 100]" do
      assert TypeMapper.to_gen_api_type(Ash.Type.String, max_length: 100) ==
               [type: :string, max_bytes: 100]
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
    test "maps :uuid to :uuid" do
      assert TypeMapper.to_gen_api_type(:uuid) == :uuid
    end

    test "maps Ash.Type.UUID to :uuid" do
      assert TypeMapper.to_gen_api_type(Ash.Type.UUID) == :uuid
    end

    test "maps :uuid_v7 to :uuid" do
      assert TypeMapper.to_gen_api_type(:uuid_v7) == :uuid
    end
  end

  describe "to_gen_api_type/1 - date/time types" do
    test "maps :date to :string" do
      assert TypeMapper.to_gen_api_type(:date) == :string
    end

    test "maps :time to :string" do
      assert TypeMapper.to_gen_api_type(:time) == :string
    end

    test "maps :datetime to :datetime" do
      assert TypeMapper.to_gen_api_type(:datetime) == :datetime
    end

    test "maps :utc_datetime to :datetime" do
      assert TypeMapper.to_gen_api_type(:utc_datetime) == :datetime
    end

    test "maps :utc_datetime_usec to :datetime" do
      assert TypeMapper.to_gen_api_type(:utc_datetime_usec) == :datetime
    end

    test "maps :naive_datetime to :naive_datetime" do
      assert TypeMapper.to_gen_api_type(:naive_datetime) == :naive_datetime
    end

    test "maps :naive_datetime_usec to :naive_datetime" do
      assert TypeMapper.to_gen_api_type(:naive_datetime_usec) == :naive_datetime
    end

    test "maps Ash.Type.DateTime to :datetime" do
      assert TypeMapper.to_gen_api_type(Ash.Type.DateTime) == :datetime
    end

    test "maps Ash.Type.UtcDateTime to :datetime" do
      assert TypeMapper.to_gen_api_type(Ash.Type.UtcDateTime) == :datetime
    end

    test "maps Ash.Type.UtcDateTimeUsec to :datetime" do
      assert TypeMapper.to_gen_api_type(Ash.Type.UtcDateTimeUsec) == :datetime
    end

    test "maps Ash.Type.NaiveDateTime to :naive_datetime" do
      assert TypeMapper.to_gen_api_type(Ash.Type.NaiveDateTime) == :naive_datetime
    end

    test "maps Ash.Type.NaiveDateTimeUsec to :naive_datetime" do
      assert TypeMapper.to_gen_api_type(Ash.Type.NaiveDateTimeUsec) == :naive_datetime
    end

    test "maps :duration to :string" do
      assert TypeMapper.to_gen_api_type(:duration) == :string
    end

    test "maps :duration_name to :string" do
      assert TypeMapper.to_gen_api_type(:duration_name) == :string
    end
  end

  describe "to_gen_api_type/1 - boolean type" do
    test "maps :boolean to :boolean" do
      assert TypeMapper.to_gen_api_type(:boolean) == :boolean
    end

    test "maps Ash.Type.Boolean to :boolean" do
      assert TypeMapper.to_gen_api_type(Ash.Type.Boolean) == :boolean
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
    test "maps :map to :map" do
      assert TypeMapper.to_gen_api_type(:map) == :map
    end

    test "maps :map with max_items constraint to [type: :map, max_items: 50]" do
      assert TypeMapper.to_gen_api_type(:map, max_items: 50) ==
               [type: :map, max_items: 50]
    end

    test "maps Ash.Type.Map to :map" do
      assert TypeMapper.to_gen_api_type(Ash.Type.Map) == :map
    end

    test "maps Ash.Type.Json to :map" do
      assert TypeMapper.to_gen_api_type(Ash.Type.Json) == :map
    end

    test "maps :struct to :map" do
      assert TypeMapper.to_gen_api_type(:struct) == :map
    end

    test "maps Ash.Type.Struct to :map" do
      assert TypeMapper.to_gen_api_type(Ash.Type.Struct) == :map
    end

    test "maps :keyword to :map" do
      assert TypeMapper.to_gen_api_type(:keyword) == :map
    end

    test "maps Ash.Type.Keyword to :map" do
      assert TypeMapper.to_gen_api_type(Ash.Type.Keyword) == :map
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
    test "maps {:array, :string} to [type: :list_string, max_items: 1000, max_item_bytes: 50]" do
      assert TypeMapper.to_gen_api_type({:array, :string}) ==
               [type: :list_string, max_items: 1000, max_item_bytes: 50]
    end

    test "maps {:array, :integer} to [type: :list_num, max_items: 1000]" do
      assert TypeMapper.to_gen_api_type({:array, :integer}) ==
               [type: :list_num, max_items: 1000]
    end

    test "maps {:array, :uuid} to [type: :list_string, max_items: 1000, max_item_bytes: 50]" do
      assert TypeMapper.to_gen_api_type({:array, :uuid}) ==
               [type: :list_string, max_items: 1000, max_item_bytes: 50]
    end

    test "maps {:array, :float} to [type: :list_num, max_items: 1000]" do
      assert TypeMapper.to_gen_api_type({:array, :float}) ==
               [type: :list_num, max_items: 1000]
    end

    test "maps {:array, :boolean} to [type: :list, max_items: 1000]" do
      assert TypeMapper.to_gen_api_type({:array, :boolean}) ==
               [type: :list, max_items: 1000]
    end

    test "maps {:array, :map} to [type: :list, max_items: 1000]" do
      assert TypeMapper.to_gen_api_type({:array, :map}) ==
               [type: :list, max_items: 1000]
    end

    test "maps {:array, :datetime} to [type: :list, max_items: 1000]" do
      assert TypeMapper.to_gen_api_type({:array, :datetime}) ==
               [type: :list, max_items: 1000]
    end

    test "maps {:array, :naive_datetime} to [type: :list, max_items: 1000]" do
      assert TypeMapper.to_gen_api_type({:array, :naive_datetime}) ==
               [type: :list, max_items: 1000]
    end

    test "respects max_items constraint" do
      assert TypeMapper.to_gen_api_type({:array, :string}, max_items: 500) ==
               [type: :list_string, max_items: 500, max_item_bytes: 50]
    end

    test "respects max_item_length constraint for string arrays" do
      assert TypeMapper.to_gen_api_type({:array, :string}, items: [max_length: 100]) ==
               [type: :list_string, max_items: 1000, max_item_bytes: 100]
    end

    test "respects max_items constraint for list type" do
      assert TypeMapper.to_gen_api_type({:array, :map}, max_items: 200) ==
               [type: :list, max_items: 200]
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

  describe "build_type_config/3" do
    test "returns simple type when allow_nil? is false" do
      assert TypeMapper.build_type_config(:string, false, nil) == :string
      assert TypeMapper.build_type_config(:uuid, false, nil) == :uuid
      assert TypeMapper.build_type_config(:num, false, nil) == :num
    end

    test "returns keyword list with allow_nil? when allow_nil? is true and no default" do
      assert TypeMapper.build_type_config(:string, true, nil) == [type: :string, allow_nil?: true]
      assert TypeMapper.build_type_config(:uuid, true, nil) == [type: :uuid, allow_nil?: true]
    end

    test "returns keyword list with type tuple and constraints for string with max_bytes" do
      # When type is a keyword list like [type: :string, max_bytes: 5000], it should be properly handled
      result = TypeMapper.build_type_config([type: :string, max_bytes: 5000], true, nil)
      assert result == [type: :string, max_bytes: 5000, allow_nil?: true]
    end

    test "returns keyword list with default_value when allow_nil? is true and default exists" do
      result = TypeMapper.build_type_config(:string, true, "default")
      assert result == [type: :string, default_value: "default", allow_nil?: true]
    end

    test "handles string type with max_length constraint and allow_nil? true - reproduces nested type bug" do
      # This test reproduces the issue where content field with max_length: 5000
      # and allow_nil? true should generate:
      # [type: :string, max_bytes: 5000, allow_nil?: true]
      # NOT:
      # [type: [type: :string, max_bytes: 5000], allow_nil?: true]

      # Simulate what happens when we have a string attribute with max_length: 5000
      gen_api_type = TypeMapper.to_gen_api_type(:string, max_length: 5000)
      assert gen_api_type == [type: :string, max_bytes: 5000]

      # Now build the type config with allow_nil? true
      result = TypeMapper.build_type_config(gen_api_type, true, nil)

      # The expected result should be a flat keyword list
      expected = [type: :string, max_bytes: 5000, allow_nil?: true]
      assert result == expected

      # Verify type is an atom, not a nested keyword list
      type_value = Keyword.get(result, :type)
      assert is_atom(type_value)
      assert type_value == :string
    end
  end
end
