

defmodule AshPhoenixGenApi.Resource.PermissionCallbackTest do
  use ExUnit.Case

  @moduletag timeout: 60_000


  alias AshPhoenixGenApi.Resource.ActionConfig

  defmodule TestPermissionChecker do
    @moduledoc false
    def check_permission(request_type, args) do
      case request_type do
        "admin_action" -> Map.get(args, "role") == "admin"
        "user_action" -> Map.get(args, "user_id") != nil
        _ -> true
      end
    end

    def deny_all(_request_type, _args), do: false
    def allow_all(_request_type, _args), do: true
  end

  defmodule PermissionCallbackResource do
    use Ash.Resource,
      domain: AshPhoenixGenApi.Resource.PermissionCallbackTest.TestDomain,
      extensions: [AshPhoenixGenApi.Resource],
      data_layer: Ash.DataLayer.Ets

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
      service "permission_callback_test"
      permission_callback {TestPermissionChecker, :check_permission, []}

      action :create do
        request_type "admin_action"
      end

      action :read do
        request_type "user_action"
      end
    end
  end

  defmodule TestDomain do
    use Ash.Domain

    resources do
      resource PermissionCallbackResource
    end
  end

  describe "permission_callback in ActionConfig" do
    test "effective_permission_callback returns action-level callback" do
      config = %ActionConfig{permission_callback: {TestPermissionChecker, :deny_all, []}}
      assert ActionConfig.effective_permission_callback(config, nil) ==
               {TestPermissionChecker, :deny_all, []}
    end

    test "effective_permission_callback falls back to section default" do
      config = %ActionConfig{permission_callback: nil}
      assert ActionConfig.effective_permission_callback(config, {TestPermissionChecker, :allow_all, []}) ==
               {TestPermissionChecker, :allow_all, []}
    end

    test "effective_permission_callback returns nil when both nil" do
      config = %ActionConfig{permission_callback: nil}
      assert ActionConfig.effective_permission_callback(config, nil) == nil
    end
  end

  describe "permission_callback in FunConfig generation" do
    test "permission_callback is stored as {:callback, mfa} in FunConfig check_permission" do
      fun_configs = AshPhoenixGenApi.Resource.Info.fun_configs(PermissionCallbackResource)

      for config <- fun_configs do
        assert config.check_permission == {:callback, {TestPermissionChecker, :check_permission, []}}
      end
    end

    test "action-level permission_callback overrides section-level" do
      # Test with a resource that has action-level override
      defmodule ActionOverrideResource do
        use Ash.Resource,
          domain: AshPhoenixGenApi.Resource.PermissionCallbackTest.TestDomain2,
          extensions: [AshPhoenixGenApi.Resource],
          data_layer: Ash.DataLayer.Ets

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
          service "action_override_cb_test"
          permission_callback {TestPermissionChecker, :check_permission, []}

          action :create do
            permission_callback {TestPermissionChecker, :deny_all, []}
          end

          action :read
        end
      end

      defmodule TestDomain2 do
        use Ash.Domain

        resources do
          resource ActionOverrideResource
        end
      end

      fun_configs = AshPhoenixGenApi.Resource.Info.fun_configs(ActionOverrideResource)
      create_config = Enum.find(fun_configs, &(&1.request_type == "create"))
      read_config = Enum.find(fun_configs, &(&1.request_type == "read"))

      assert create_config.check_permission == {:callback, {TestPermissionChecker, :deny_all, []}}
      assert read_config.check_permission == {:callback, {TestPermissionChecker, :check_permission, []}}
    end

    test "check_permission is used when permission_callback is nil" do
      defmodule NoCallbackResource do
        use Ash.Resource,
          domain: AshPhoenixGenApi.Resource.PermissionCallbackTest.TestDomain3,
          extensions: [AshPhoenixGenApi.Resource],
          data_layer: Ash.DataLayer.Ets

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
          service "no_callback_test"
          check_permission :any_authenticated

          action :create
        end
      end

      defmodule TestDomain3 do
        use Ash.Domain

        resources do
          resource NoCallbackResource
        end
      end

      fun_configs = AshPhoenixGenApi.Resource.Info.fun_configs(NoCallbackResource)
      create_config = Enum.find(fun_configs, &(&1.request_type == "create"))
      assert create_config.check_permission == :any_authenticated
    end
  end

  describe "permission_callback introspection" do
    test "gen_api_permission_callback returns {:ok, section-level setting}" do
      result = AshPhoenixGenApi.Resource.Info.gen_api_permission_callback(PermissionCallbackResource)
      assert result == {:ok, {TestPermissionChecker, :check_permission, []}}
    end

    test "effective_permission_callback resolves correctly" do
      assert AshPhoenixGenApi.Resource.Info.effective_permission_callback(PermissionCallbackResource, :create) ==
               {TestPermissionChecker, :check_permission, []}
    end
  end
end
