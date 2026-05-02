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

    test "maps :string with max_length constraint to {:string, max_bytes}" do
      assert TypeMapper.to_gen_api_type(:string, max_length: 255) == {:string, 255}
    end

    test "maps Ash.Type.String with max_length constraint to {:string, max_bytes}" do
      assert TypeMapper.to_gen_api_type(Ash.Type.String, max_length: 100) == {:string, 100}
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

    test "maps :map with max_items constraint to {:map, max_items}" do
      assert TypeMapper.to_gen_api_type(:map, max_items: 50) == {:map, 50}
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
    test "maps {:array, :string} to {:list_string, max_items, max_item_length}" do
      assert TypeMapper.to_gen_api_type({:array, :string}) ==
               {:list_string, 1000, 50}
    end

    test "maps {:array, :integer} to {:list_num, max_items}" do
      assert TypeMapper.to_gen_api_type({:array, :integer}) ==
               {:list_num, 1000}
    end

    test "maps {:array, :uuid} to {:list_string, max_items, max_item_length}" do
      assert TypeMapper.to_gen_api_type({:array, :uuid}) ==
               {:list_string, 1000, 50}
    end

    test "maps {:array, :float} to {:list_num, max_items}" do
      assert TypeMapper.to_gen_api_type({:array, :float}) ==
               {:list_num, 1000}
    end

    test "maps {:array, :boolean} to {:list, max_items}" do
      # boolean maps to :boolean, so array of boolean maps to {:list, max_items}
      assert TypeMapper.to_gen_api_type({:array, :boolean}) ==
               {:list, 1000}
    end

    test "maps {:array, :map} to {:list, max_items}" do
      # map maps to :map, so array of map maps to {:list, max_items}
      assert TypeMapper.to_gen_api_type({:array, :map}) ==
               {:list, 1000}
    end

    test "maps {:array, :datetime} to {:list, max_items}" do
      assert TypeMapper.to_gen_api_type({:array, :datetime}) ==
               {:list, 1000}
    end

    test "maps {:array, :naive_datetime} to {:list, max_items}" do
      assert TypeMapper.to_gen_api_type({:array, :naive_datetime}) ==
               {:list, 1000}
    end

    test "respects max_items constraint" do
      assert TypeMapper.to_gen_api_type({:array, :string}, max_items: 500) ==
               {:list_string, 500, 50}
    end

    test "respects max_item_length constraint for string arrays" do
      assert TypeMapper.to_gen_api_type({:array, :string}, items: [max_length: 100]) ==
               {:list_string, 1000, 100}
    end

    test "respects max_items constraint for list type" do
      assert TypeMapper.to_gen_api_type({:array, :map}, max_items: 200) ==
               {:list, 200}
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

  describe "default constants" do
    test "default_max_list_items returns 1000" do
      assert TypeMapper.default_max_list_items() == 1000
    end

    test "default_max_string_item_length returns 50" do
      assert TypeMapper.default_max_string_item_length() == 50
    end

    test "default_max_map_items returns 1000" do
      assert TypeMapper.default_max_map_items() == 1000
    end
  end
end
