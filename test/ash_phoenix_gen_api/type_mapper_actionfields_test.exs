defmodule AshPhoenixGenApi.TypeMapper.ActionFieldsTest do
  use ExUnit.Case, async: true

  alias AshPhoenixGenApi.TypeMapper

  describe "build_arg_config/1" do
    test "builds arg_types map and arg_orders list from fields" do
      fields = [
        {:user_id, :string, false, nil},
        {:count, :num, true, 0},
        {:tags, {:list_string, 100, 20}, true, []}
      ]

      {arg_types, arg_orders} = TypeMapper.build_arg_config(fields)

      assert arg_types == %{
               "user_id" => :string,
               "count" => [type: :num, default_value: 0, allow_nil?: true],
               "tags" => [type: :list_string, max_items: 100, max_item_bytes: 20, default_value: [], allow_nil?: true]
             }

      assert arg_orders == ["user_id", "count", "tags"]
    end

    test "handles empty fields" do
      {arg_types, arg_orders} = TypeMapper.build_arg_config([])
      assert arg_types == %{}
      assert arg_orders == []
    end
  end
end
