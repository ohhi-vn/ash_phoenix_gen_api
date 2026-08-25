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

  # ---------------------------------------------------------------------------
  # Exhaustive type-mapping coverage
  # ---------------------------------------------------------------------------

  describe "to_gen_api_type/2 — full clause coverage" do
    test "ci_string maps to :string, with and without max_length" do
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(:ci_string, []) == :string

      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(Ash.Type.CiString, max_length: 10) == [
               type: :string,
               max_bytes: 10
             ]
    end

    test "string max_length falls back to :string for invalid values" do
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(:string, max_length: "bad") == :string
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(:string, max_length: -1) == :string
    end

    test "float and decimal map to :num (atom and module forms)" do
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(:float) == :num
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(Ash.Type.Float) == :num
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(:decimal) == :num
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(Ash.Type.Decimal) == :num
    end

    test "uuid_v7 maps to :uuid (atom and module forms)" do
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(:uuid_v7) == :uuid
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(Ash.Type.UUIDv7) == :uuid
    end

    test "date/time/duration types map to :string" do
      atom_types = [:date, :time, :time_usec, :duration, :duration_name]

      module_types = [
        Ash.Type.Date,
        Ash.Type.Time,
        Ash.Type.TimeUsec,
        Ash.Type.Duration,
        Ash.Type.DurationName
      ]

      for type <- atom_types ++ module_types do
        assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(type) == :string
      end
    end

    test "utc_datetime_usec maps to :datetime" do
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(:utc_datetime_usec) == :datetime
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(Ash.Type.UtcDateTimeUsec) == :datetime
    end

    test "naive_datetime variants map to :naive_datetime" do
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(:naive_datetime) == :naive_datetime

      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(Ash.Type.NaiveDateTime) ==
               :naive_datetime

      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(:naive_datetime_usec) == :naive_datetime

      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(Ash.Type.NaiveDateTimeUsec) ==
               :naive_datetime
    end

    test "map with max_items constraint" do
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(:map, max_items: 5) == [
               type: :map,
               max_items: 5
             ]

      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(Ash.Type.Map, max_items: 5) == [
               type: :map,
               max_items: 5
             ]

      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(Ash.Type.Map, max_items: "bad") == :map
    end

    test "json/struct/keyword map to :map" do
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(Ash.Type.Json) == :map
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(:struct) == :map
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(Ash.Type.Struct) == :map
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(:keyword) == :map
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(Ash.Type.Keyword) == :map
    end

    test "binary/term/tuple/vector map to :string" do
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(:binary) == :string
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(Ash.Type.Binary) == :string
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(:term) == :string
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(Ash.Type.Term) == :string
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(:tuple) == :string
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(Ash.Type.Tuple) == :string
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(Ash.Type.Vector) == :string
    end

    test "union maps to :string" do
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(:union) == :string
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(Ash.Type.Union) == :string
    end

    test "file maps to :string" do
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(:file) == :string
    end

    test "array of decimal maps to list_num" do
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type({:array, :decimal}, []) == [
               type: :list_num,
               max_items: 1000
             ]
    end

    test "Ash.Type.Array uses items constraint for inner type" do
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(Ash.Type.Array, items: :integer) == [
               type: :list_num,
               max_items: 1000
             ]
    end

    test "unknown atom without type/1 defaults to :string" do
      refute function_exported?(:totally_unknown_type, :type, 1)
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(:totally_unknown_type, []) == :string
    end

    test "non-atom input defaults to :string" do
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type({:weird, :tuple}) == :string
    end

    test "custom NewType without type/1 export falls back to :string" do
      defmodule TestNewType do
        use Ash.Type.NewType, subtype_of: :uuid, constraints: []
      end

      # NewTypes delegate via storage_type/1 rather than exporting type/1,
      # so the resolution path cannot see through them today.
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(TestNewType, []) == :string
    end
  end

  describe "list_type?/1" do
    test "true for array tuples and Ash.Type.Array" do
      assert AshPhoenixGenApi.TypeMapper.list_type?({:array, :string}) == true
      assert AshPhoenixGenApi.TypeMapper.list_type?(Ash.Type.Array) == true
    end

    test "false for other types" do
      assert AshPhoenixGenApi.TypeMapper.list_type?(:string) == false
      assert AshPhoenixGenApi.TypeMapper.list_type?(:map) == false
    end
  end

  describe "defaults" do
    test "default_max_list_items/0 is a positive integer" do
      assert AshPhoenixGenApi.TypeMapper.default_max_list_items() > 0
    end

    test "default_max_string_item_length/0 is a positive integer" do
      assert AshPhoenixGenApi.TypeMapper.default_max_string_item_length() > 0
    end

    test "default_max_map_items/0 is a positive integer" do
      assert AshPhoenixGenApi.TypeMapper.default_max_map_items() > 0
    end
  end

  describe "attribute/argument helpers" do
    test "attribute_to_gen_api_type maps boolean and uuid attributes" do
      attr = %{type: :boolean, constraints: []}
      assert AshPhoenixGenApi.TypeMapper.attribute_to_gen_api_type(attr) == :boolean

      attr = %{type: Ash.Type.UUID, constraints: []}
      assert AshPhoenixGenApi.TypeMapper.attribute_to_gen_api_type(attr) == :uuid
    end

    test "argument_to_gen_api_type maps string argument with constraint" do
      arg = %{type: :string, constraints: [max_length: 20]}

      assert AshPhoenixGenApi.TypeMapper.argument_to_gen_api_type(arg) == [
               type: :string,
               max_bytes: 20
             ]
    end
  end

  # ---------------------------------------------------------------------------
  # Remaining clause coverage (arrays, defaults, runtime action fields)
  # ---------------------------------------------------------------------------

  describe "to_gen_api_type/2 — remaining branches" do
    test "ci_string falls back to :string for invalid max_length" do
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(:ci_string, max_length: -1) == :string
    end

    test "Ash.Type.DateTime and UtcDateTime module forms map to :datetime" do
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(Ash.Type.DateTime) == :datetime
      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(Ash.Type.UtcDateTime) == :datetime
    end

    test "legacy type modules exporting type/1 resolve through the underlying type" do
      defmodule LegacyTypeModule do
        def type(_constraints), do: :integer
      end

      assert AshPhoenixGenApi.TypeMapper.to_gen_api_type(LegacyTypeModule, []) == :num
    end

    test "arrays of datetime/naive_datetime/boolean/map types" do
      mapper = AshPhoenixGenApi.TypeMapper

      list_config = [type: :list, max_items: 1000]

      assert mapper.to_gen_api_type({:array, :datetime}, []) == list_config
      assert mapper.to_gen_api_type({:array, :naive_datetime}, []) == list_config
      assert mapper.to_gen_api_type({:array, :boolean}, []) == list_config
      assert mapper.to_gen_api_type({:array, :map}, []) == list_config
    end

    test "array of unknown type falls back to string items" do
      result = AshPhoenixGenApi.TypeMapper.to_gen_api_type({:array, :totally_unknown}, [])
      assert result == [type: :list_string, max_items: 1000, max_item_bytes: 50]
    end

    test "array of constrained string uses keyword compat path" do
      result =
        AshPhoenixGenApi.TypeMapper.to_gen_api_type({:array, :string}, items: [max_length: 10])

      assert result == [type: :list_string, max_items: 1000, max_item_bytes: 10]
    end

    test "array over a custom mapping that returns a tuple type" do
      AshPhoenixGenApi.TypeMapper.register(:coverage_capped_str, {:string, 42})

      try do
        result =
          AshPhoenixGenApi.TypeMapper.to_gen_api_type({:array, :coverage_capped_str}, [])

        # the {:string, _} clause re-reads max_length from item constraints only
        assert result == [type: :list_string, max_items: 1000, max_item_bytes: 50]
      after
        AshPhoenixGenApi.TypeMapper.unregister(:coverage_capped_str)
      end
    end
  end

  describe "get_action_fields/2 at runtime" do
    test "returns accepted attribute fields ordered first" do
      fields =
        AshPhoenixGenApi.TypeMapper.get_action_fields(
          AshPhoenixGenApi.InfoFixtures.AcceptListResource,
          :update_name
        )

      # accepted attributes first, then action arguments
      assert Enum.map(fields, &elem(&1, 0)) == [:name, :reason]
      assert Enum.all?(fields, fn {_n, _t, allow_nil?, _d} -> is_boolean(allow_nil?) end)
    end

    test "returns empty field list when nothing is accepted and no arguments exist" do
      assert AshPhoenixGenApi.TypeMapper.get_action_fields(
               AshPhoenixGenApi.InfoFixtures.HookedResource,
               :create
             ) == []

      assert AshPhoenixGenApi.TypeMapper.get_action_fields(
               AshPhoenixGenApi.InfoFixtures.HookedResource,
               :list_items
             ) == []
    end

    test "returns [] for a nonexistent action" do
      assert AshPhoenixGenApi.TypeMapper.get_action_fields(
               AshPhoenixGenApi.InfoFixtures.HookedResource,
               :nonexistent_action
             ) == []
    end
  end

  describe "build_arg_config/1 with legacy 3-tuples" do
    test "treats missing default as nil" do
      {arg_types, arg_orders} =
        AshPhoenixGenApi.TypeMapper.build_arg_config([{:title, :string, true}])

      assert arg_orders == ["title"]
      assert arg_types["title"] == [type: :string, allow_nil?: true]
    end
  end

  describe "get_ash_default_value/1" do
    test "returns nil for function defaults (cannot call at compile time)" do
      value = AshPhoenixGenApi.TypeMapper.get_ash_default_value(%{default: fn -> "x" end})
      assert value == nil
    end

    test "returns nil for inputs without a default key" do
      assert AshPhoenixGenApi.TypeMapper.get_ash_default_value(%{nope: 1}) == nil
    end
  end

  describe "build_type_config/3 tuple forms" do
    test "builds extended keyword config for tuple types" do
      mapper = AshPhoenixGenApi.TypeMapper

      assert mapper.build_type_config({:string, 255}, true, nil) ==
               [type: :string, max_bytes: 255, allow_nil?: true]

      assert mapper.build_type_config({:map, 5}, true, "d") ==
               [type: :map, max_items: 5, default_value: "d", allow_nil?: true]

      assert mapper.build_type_config({:list_num, 3}, true, nil) ==
               [type: :list_num, max_items: 3, allow_nil?: true]

      assert mapper.build_type_config({:list, 7}, true, nil) ==
               [type: :list, max_items: 7, allow_nil?: true]
    end
  end

  describe "wrap_nil_type/1" do
    test "wraps atoms and tuples" do
      mapper = AshPhoenixGenApi.TypeMapper
      assert mapper.wrap_nil_type(:string) == {nil, :string}
      assert mapper.wrap_nil_type({:string, 255}) == {nil, {:string, 255}}
    end
  end
end
