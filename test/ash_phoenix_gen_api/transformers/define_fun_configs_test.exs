defmodule AshPhoenixGenApi.Transformers.DefineFunConfigsTest do
  use ExUnit.Case

  @moduletag timeout: 60_000

  defmodule TestResource do
    use Ash.Resource,
      domain: nil,
      extensions: [AshPhoenixGenApi.Resource]

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, allow_nil?: false)
      attribute(:age, :integer, allow_nil?: true)
      attribute(:active, :boolean, allow_nil?: false, default: true)
    end

    actions do
      create :create do
        accept([:name])
      end

      defaults([:read, :update, :destroy])
    end

    gen_api do
      service "test_service"

      action :create do
        request_type "create_thing"
      end
    end
  end

  describe "DefineFunConfigs transformer" do
    test "generates __ash_phoenix_gen_api_fun_configs__/0 on the resource" do
      assert function_exported?(TestResource, :__ash_phoenix_gen_api_fun_configs__, 0)
    end

    test "generated fun_configs returns a list of FunConfig structs" do
      configs = TestResource.__ash_phoenix_gen_api_fun_configs__()
      assert is_list(configs)
      assert length(configs) > 0
    end

    test "fun_config has correct request_type" do
      configs = TestResource.__ash_phoenix_gen_api_fun_configs__()
      create_config = Enum.find(configs, &(&1.request_type == "create_thing"))
      assert create_config != nil
      assert create_config.request_type == "create_thing"
    end

    test "fun_config has correct service" do
      configs = TestResource.__ash_phoenix_gen_api_fun_configs__()
      create_config = Enum.find(configs, &(&1.request_type == "create_thing"))
      assert create_config.service == "test_service"
    end

    test "fun_config has correct MFA" do
      configs = TestResource.__ash_phoenix_gen_api_fun_configs__()
      create_config = Enum.find(configs, &(&1.request_type == "create_thing"))
      assert create_config.mfa == {TestResource, :create, []}
    end

    test "fun_config has auto-derived arg_types from action" do
      configs = TestResource.__ash_phoenix_gen_api_fun_configs__()
      create_config = Enum.find(configs, &(&1.request_type == "create_thing"))
      assert is_map(create_config.arg_types)
      assert Map.has_key?(create_config.arg_types, "name")
    end
  end
end
