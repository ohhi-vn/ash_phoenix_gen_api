
defmodule AshPhoenixGenApi.Domain.MfaAggregationTest do
  use ExUnit.Case

  @moduletag timeout: 60_000


  alias AshPhoenixGenApi.Domain.Info

  defmodule MfaAggResource do
    use Ash.Resource,
      domain: AshPhoenixGenApi.Domain.MfaAggregationTest.MfaAggDomain,
      extensions: [AshPhoenixGenApi.Resource]

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
    end

    gen_api do
      service "agg_service"

      action :create do
        request_type "create_item"
      end

      mfa :ping do
        request_type "ping"
        mfa {MfaAggResource, :ping_handler, []}
        arg_types %{}
      end
    end

    def ping_handler(_args, _request_info) do
      {:ok, :pong}
    end
  end

  defmodule MfaAggDomain do
    use Ash.Domain,
      extensions: [AshPhoenixGenApi.Domain]

    gen_api do
      service "agg_service"
      supporter_module AshPhoenixGenApi.Domain.MfaAggregationTest.MfaAggSupporter
      version "1.0.0"
    end

    resources do
      resource MfaAggResource
    end
  end

  describe "domain supporter aggregates MFA FunConfigs" do
    test "fun_configs includes both action and mfa endpoints" do
      supporter = AshPhoenixGenApi.Domain.MfaAggregationTest.MfaAggSupporter
      configs = supporter.fun_configs()
      request_types = Enum.map(configs, & &1.request_type)

      assert "create_item" in request_types
      assert "ping" in request_types
      assert length(configs) == 2
    end

    test "list_request_types includes mfa request types" do
      supporter = AshPhoenixGenApi.Domain.MfaAggregationTest.MfaAggSupporter
      types = supporter.list_request_types()

      assert "create_item" in types
      assert "ping" in types
    end

    test "get_fun_config finds mfa endpoint by request_type" do
      supporter = AshPhoenixGenApi.Domain.MfaAggregationTest.MfaAggSupporter
      config = supporter.get_fun_config("ping")

      assert config != nil
      assert config.request_type == "ping"
      assert config.mfa == {MfaAggResource, :ping_handler, []}
    end

    test "domain Info.fun_configs includes mfa endpoints" do
      configs = Info.fun_configs(MfaAggDomain)
      request_types = Enum.map(configs, & &1.request_type)

      assert "create_item" in request_types
      assert "ping" in request_types
    end

    test "domain Info.all_request_types includes mfa request types" do
      types = Info.all_request_types(MfaAggDomain)

      assert "create_item" in types
      assert "ping" in types
    end
  end
end
