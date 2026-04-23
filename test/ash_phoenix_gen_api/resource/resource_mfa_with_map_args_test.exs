

defmodule AshPhoenixGenApi.Resource.MfaWithMapArgsTest do
  use ExUnit.Case

  @moduletag timeout: 60_000


  alias AshPhoenixGenApi.Resource.Info

  defmodule MapArgsResource do
    use Ash.Resource,
      extensions: [AshPhoenixGenApi.Resource]

    attributes do
      uuid_primary_key :id
    end

    actions do
      create :create do
        accept []
      end
    end

    gen_api do
      service "test_service"

      action :create do
        request_type "create_item"
      end

      mfa :search do
        request_type "search"
        mfa {SearchHandler, :search, []}
        arg_types %{"query" => :string, "limit" => :num}
        # arg_orders defaults to :map
      end
    end
  end

  test "mfa with arg_orders :map (default) passes args as map" do
    search_config = Info.fun_config(MapArgsResource, "search")
    assert search_config.arg_types == %{"query" => :string, "limit" => :num}
    assert search_config.arg_orders == :map
  end
end
