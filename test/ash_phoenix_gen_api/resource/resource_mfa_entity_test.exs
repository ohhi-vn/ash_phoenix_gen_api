
defmodule AshPhoenixGenApi.Resource.MfaEntityTest do
  use ExUnit.Case

  @moduletag timeout: 60_000


  alias AshPhoenixGenApi.Resource.Info
  alias AshPhoenixGenApi.Resource.MfaConfig

  defmodule MfaTestResource do
    use Ash.Resource,
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

      read :read do
        primary? true
      end
    end

    gen_api do
      service "test_service"
      timeout 5_000
      response_type :async
      request_info true
      version "1.0.0"

      action :create do
        request_type "create_item"
      end

      action :read do
        request_type "list_items"
      end

      mfa :ping do
        request_type "ping"
        mfa {MfaTestResource, :ping_handler, []}
        arg_types %{}
        timeout 3_000
      end

      mfa :custom_op do
        request_type "custom_operation"
        mfa {MyApp.CustomHandler, :run, [:extra_arg]}
        arg_types %{"user_id" => :string, "count" => :num}
        arg_orders ["user_id", "count"]
        response_type :sync
        request_info false
        check_permission {:arg, "user_id"}
      end
    end

    def ping_handler(args, request_info) do
      {:ok, %{args: args, request_info: request_info}}
    end
  end

  describe "mfa entity DSL" do
    test "resource compiles with mfa entities in gen_api section" do
      assert Ash.Resource.Info.extensions(MfaTestResource)
             |> Enum.any?(&(&1 == AshPhoenixGenApi.Resource))
    end

    test "mfas returns all MFA configs" do
      mfas = Info.mfas(MfaTestResource)
      assert length(mfas) == 2
      assert Enum.all?(mfas, &match?(%MfaConfig{}, &1))
    end

    test "mfa returns specific MFA config by name" do
      ping = Info.mfa(MfaTestResource, :ping)
      assert %MfaConfig{} = ping
      assert ping.name == :ping
      assert ping.request_type == "ping"
      assert ping.mfa == {MfaTestResource, :ping_handler, []}
    end

    test "mfa returns nil for unknown name" do
      assert Info.mfa(MfaTestResource, :nonexistent) == nil
    end

    test "enabled_mfas returns only enabled MFA configs" do
      mfas = Info.enabled_mfas(MfaTestResource)
      assert length(mfas) == 2
      assert Enum.all?(mfas, &MfaConfig.enabled?/1)
    end
  end

  describe "mfa entity FunConfig generation" do
    test "fun_configs includes both action and mfa FunConfigs" do
      fun_configs = Info.fun_configs(MfaTestResource)
      # 2 actions + 2 mfas = 4
      assert length(fun_configs) == 4
    end

    test "mfa FunConfig has correct basic fields" do
      ping_config = Info.fun_config(MfaTestResource, "ping")
      assert ping_config != nil
      assert ping_config.request_type == "ping"
      assert ping_config.service == "test_service"
      assert ping_config.mfa == {MfaTestResource, :ping_handler, []}
      assert ping_config.timeout == 3_000
    end

    test "mfa FunConfig with empty arg_types has nil arg_types and arg_orders" do
      ping_config = Info.fun_config(MfaTestResource, "ping")
      assert ping_config.arg_types == nil
      assert ping_config.arg_orders == nil
    end

    test "mfa FunConfig with explicit arg_types and arg_orders" do
      custom_config = Info.fun_config(MfaTestResource, "custom_operation")
      assert custom_config != nil
      assert custom_config.arg_types == %{"user_id" => :string, "count" => :num}
      assert custom_config.arg_orders == ["user_id", "count"]
    end

    test "mfa FunConfig inherits section-level defaults" do
      ping_config = Info.fun_config(MfaTestResource, "ping")
      # ping only overrides timeout, others come from section defaults
      assert ping_config.service == "test_service"
      assert ping_config.response_type == :async
      assert ping_config.request_info == true
      assert ping_config.version == "1.0.0"
    end

    test "mfa FunConfig overrides section-level defaults" do
      custom_config = Info.fun_config(MfaTestResource, "custom_operation")
      assert custom_config.response_type == :sync
      assert custom_config.request_info == false
    end

    test "mfa FunConfig with check_permission" do
      custom_config = Info.fun_config(MfaTestResource, "custom_operation")
      assert custom_config.check_permission == {:arg, "user_id"}
    end

    test "mfa FunConfig with predefined args in MFA tuple" do
      custom_config = Info.fun_config(MfaTestResource, "custom_operation")
      assert custom_config.mfa == {MyApp.CustomHandler, :run, [:extra_arg]}
    end
  end

  describe "request_types includes mfa entities" do
    test "request_types returns types from both actions and mfas" do
      types = Info.request_types(MfaTestResource)
      assert "create_item" in types
      assert "list_items" in types
      assert "ping" in types
      assert "custom_operation" in types
      assert length(types) == 4
    end
  end

  describe "action and mfa coexistence" do
    test "action returns only ActionConfig entities" do
      alias AshPhoenixGenApi.Resource.ActionConfig
      action = Info.action(MfaTestResource, :create)
      assert %ActionConfig{} = action
    end

    test "mfa returns only MfaConfig entities" do
      mfa = Info.mfa(MfaTestResource, :ping)
      assert %MfaConfig{} = mfa
    end

    test "enabled_actions returns only ActionConfig entities" do
      alias AshPhoenixGenApi.Resource.ActionConfig
      actions = Info.enabled_actions(MfaTestResource)
      assert length(actions) == 2
      assert Enum.all?(actions, &match?(%ActionConfig{}, &1))
    end

    test "enabled_mfas returns only MfaConfig entities" do
      mfas = Info.enabled_mfas(MfaTestResource)
      assert length(mfas) == 2
      assert Enum.all?(mfas, &match?(%MfaConfig{}, &1))
    end
  end
end
