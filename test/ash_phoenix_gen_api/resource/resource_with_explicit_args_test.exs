
defmodule AshPhoenixGenApi.ResourceWithExplicitArgsTest do
  use ExUnit.Case

  @moduletag timeout: 60_000


  defmodule ExplicitArgsResource do
    use Ash.Resource,
      extensions: [AshPhoenixGenApi.Resource]

    attributes do
      uuid_primary_key :id
      attribute :user_id, :uuid do
        public? true
      end
      attribute :content, :string do
        public? true
        allow_nil? true
      end
    end

    actions do
      create :create do
        accept [:user_id, :content]
      end
    end

    gen_api do
      service "explicit_args"
      action :create do
        request_type "send_message"
        arg_types %{"user_id" => :string, "content" => :string, "tags" => {:list_string, 100, 20}}
        arg_orders ["user_id", "content", "tags"]
      end
    end
  end

  describe "resource with explicit arg_types and arg_orders" do
    test "uses explicit arg_types and arg_orders" do
      fc = AshPhoenixGenApi.Resource.Info.fun_config(ExplicitArgsResource, "send_message")
      assert fc != nil
      assert fc.arg_types == %{"user_id" => :string, "content" => :string, "tags" => {:list_string, 100, 20}}
      assert fc.arg_orders == ["user_id", "content", "tags"]
    end
  end
end
