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
    test "maps :uuid to :string" do
      assert TypeMapper.to_gen_api_type(:uuid) == :string
    end

    test "maps Ash.Type.UUID to :string" do
      assert TypeMapper.to_gen_api_type(Ash.Type.UUID) == :string
    end

    test "maps :uuid_v7 to :string" do
      assert TypeMapper.to_gen_api_type(:uuid_v7) == :string
    end
  end

  describe "to_gen_api_type/1 - date/time types" do
    test "maps :date to :string" do
      assert TypeMapper.to_gen_api_type(:date) == :string
    end

    test "maps :time to :string" do
      assert TypeMapper.to_gen_api_type(:time) == :string
    end

    test "maps :datetime to :string" do
      assert TypeMapper.to_gen_api_type(:datetime) == :string
    end

    test "maps :utc_datetime to :string" do
      assert TypeMapper.to_gen_api_type(:utc_datetime) == :string
    end

    test "maps :naive_datetime to :string" do
      assert TypeMapper.to_gen_api_type(:naive_datetime) == :string
    end

    test "maps Ash.Type.UtcDateTime to :string" do
      assert TypeMapper.to_gen_api_type(Ash.Type.UtcDateTime) == :string
    end

    test "maps Ash.Type.NaiveDateTime to :string" do
      assert TypeMapper.to_gen_api_type(Ash.Type.NaiveDateTime) == :string
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
    test "maps :map to :string" do
      assert TypeMapper.to_gen_api_type(:map) == :string
    end

    test "maps Ash.Type.Map to :string" do
      assert TypeMapper.to_gen_api_type(Ash.Type.Map) == :string
    end

    test "maps Ash.Type.Json to :string" do
      assert TypeMapper.to_gen_api_type(Ash.Type.Json) == :string
    end

    test "maps :struct to :string" do
      assert TypeMapper.to_gen_api_type(:struct) == :string
    end

    test "maps :keyword to :string" do
      assert TypeMapper.to_gen_api_type(:keyword) == :string
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

    test "maps {:array, :boolean} to {:list_string, max_items, max_item_length}" do
      # boolean maps to :string, so array of boolean maps to list_string
      assert TypeMapper.to_gen_api_type({:array, :boolean}) ==
               {:list_string, 1000, 50}
    end

    test "maps {:array, :map} to {:list_string, max_items, max_item_length}" do
      # map maps to :string, so array of map maps to list_string
      assert TypeMapper.to_gen_api_type({:array, :map}) ==
               {:list_string, 1000, 50}
    end

    test "respects max_items constraint" do
      assert TypeMapper.to_gen_api_type({:array, :string}, max_items: 500) ==
               {:list_string, 500, 50}
    end

    test "respects max_item_length constraint for string arrays" do
      assert TypeMapper.to_gen_api_type({:array, :string}, items: [max_length: 100]) ==
               {:list_string, 1000, 100}
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
  end
end
