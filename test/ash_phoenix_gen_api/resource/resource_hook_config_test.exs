defmodule AshPhoenixGenApi.Resource.HookConfigTest do
  use ExUnit.Case

  @moduletag timeout: 60_000

  alias AshPhoenixGenApi.Resource.ActionConfig
  alias AshPhoenixGenApi.Resource.Info
  alias AshPhoenixGenApi.Resource.MfaConfig

  defmodule TestHookModule do
    @moduledoc false
    def before_hook(request, fun_config), do: {:ok, request, fun_config}
    def after_hook(request, fun_config, result), do: result
    def custom_before(request, fun_config, extra), do: {:ok, request, fun_config}
    def custom_after(request, fun_config, result, extra), do: result
  end

  # ---------------------------------------------------------------------------
  # ActionConfig effective hook functions
  # ---------------------------------------------------------------------------

  describe "ActionConfig effective_before_execute/2" do
    test "returns explicit before_execute when set" do
      config = %ActionConfig{before_execute: {TestHookModule, :before_hook}}
      assert ActionConfig.effective_before_execute(config, nil) == {TestHookModule, :before_hook}
    end

    test "returns explicit before_execute with extra args" do
      config = %ActionConfig{before_execute: {TestHookModule, :custom_before, [:extra]}}
      assert ActionConfig.effective_before_execute(config, nil) == {TestHookModule, :custom_before, [:extra]}
    end

    test "returns default when before_execute is nil" do
      config = %ActionConfig{before_execute: nil}
      assert ActionConfig.effective_before_execute(config, {TestHookModule, :before_hook}) ==
               {TestHookModule, :before_hook}
    end

    test "returns nil when both are nil" do
      config = %ActionConfig{before_execute: nil}
      assert ActionConfig.effective_before_execute(config, nil) == nil
    end
  end

  describe "ActionConfig effective_after_execute/2" do
    test "returns explicit after_execute when set" do
      config = %ActionConfig{after_execute: {TestHookModule, :after_hook}}
      assert ActionConfig.effective_after_execute(config, nil) == {TestHookModule, :after_hook}
    end

    test "returns explicit after_execute with extra args" do
      config = %ActionConfig{after_execute: {TestHookModule, :custom_after, [:extra]}}
      assert ActionConfig.effective_after_execute(config, nil) == {TestHookModule, :custom_after, [:extra]}
    end

    test "returns default when after_execute is nil" do
      config = %ActionConfig{after_execute: nil}
      assert ActionConfig.effective_after_execute(config, {TestHookModule, :after_hook}) ==
               {TestHookModule, :after_hook}
    end

    test "returns nil when both are nil" do
      config = %ActionConfig{after_execute: nil}
      assert ActionConfig.effective_after_execute(config, nil) == nil
    end
  end

  describe "ActionConfig effective_hook_timeout/2" do
    test "returns explicit hook_timeout when set" do
      config = %ActionConfig{hook_timeout: 10_000}
      assert ActionConfig.effective_hook_timeout(config, 5_000) == 10_000
    end

    test "returns default when hook_timeout is nil" do
      config = %ActionConfig{hook_timeout: nil}
      assert ActionConfig.effective_hook_timeout(config, 5_000) == 5_000
    end
  end

  # ---------------------------------------------------------------------------
  # MfaConfig effective hook functions
  # ---------------------------------------------------------------------------

  describe "MfaConfig effective_before_execute/2" do
    test "returns explicit before_execute when set" do
      config = %MfaConfig{before_execute: {TestHookModule, :before_hook}}
      assert MfaConfig.effective_before_execute(config, nil) == {TestHookModule, :before_hook}
    end

    test "returns default when before_execute is nil" do
      config = %MfaConfig{before_execute: nil}
      assert MfaConfig.effective_before_execute(config, {TestHookModule, :before_hook}) ==
               {TestHookModule, :before_hook}
    end

    test "returns nil when both are nil" do
      config = %MfaConfig{before_execute: nil}
      assert MfaConfig.effective_before_execute(config, nil) == nil
    end
  end

  describe "MfaConfig effective_after_execute/2" do
    test "returns explicit after_execute when set" do
      config = %MfaConfig{after_execute: {TestHookModule, :after_hook}}
      assert MfaConfig.effective_after_execute(config, nil) == {TestHookModule, :after_hook}
    end

    test "returns default when after_execute is nil" do
      config = %MfaConfig{after_execute: nil}
      assert MfaConfig.effective_after_execute(config, {TestHookModule, :after_hook}) ==
               {TestHookModule, :after_hook}
    end

    test "returns nil when both are nil" do
      config = %MfaConfig{after_execute: nil}
      assert MfaConfig.effective_after_execute(config, nil) == nil
    end
  end

  describe "MfaConfig effective_hook_timeout/2" do
    test "returns explicit hook_timeout when set" do
      config = %MfaConfig{hook_timeout: 15_000}
      assert MfaConfig.effective_hook_timeout(config, 5_000) == 15_000
    end

    test "returns default when hook_timeout is nil" do
      config = %MfaConfig{hook_timeout: nil}
      assert MfaConfig.effective_hook_timeout(config, 5_000) == 5_000
    end
  end

  # ---------------------------------------------------------------------------
  # FunConfig generation with section-level hooks
  # ---------------------------------------------------------------------------

  defmodule TestDomainSectionHooks do
    use Ash.Domain
  end

  defmodule SectionHookResource do
    use Ash.Resource,
      domain: AshPhoenixGenApi.Resource.HookConfigTest.TestDomainSectionHooks,
      extensions: [AshPhoenixGenApi.Resource],
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    attributes do
      uuid_primary_key(:id)

      attribute :name, :string do
        public?(true)
      end
    end

    actions do
      create :create do
        accept([:name])
      end

      read :read do
        primary?(true)
      end
    end

    gen_api do
      service "section_hook_test"
      before_execute({TestHookModule, :before_hook})
      after_execute({TestHookModule, :after_hook})
      hook_timeout 10_000

      action :create do
        request_type "create_hooked"
      end

      action :read do
        request_type "read_hooked"
      end
    end
  end

  describe "section-level hooks in FunConfig" do
    test "section-level before_execute flows to all action FunConfigs" do
      fun_configs = Info.fun_configs(SectionHookResource)

      for config <- fun_configs do
        assert config.before_execute == {TestHookModule, :before_hook}
      end
    end

    test "section-level after_execute flows to all action FunConfigs" do
      fun_configs = Info.fun_configs(SectionHookResource)

      for config <- fun_configs do
        assert config.after_execute == {TestHookModule, :after_hook}
      end
    end

    test "section-level hook_timeout flows to all action FunConfigs" do
      fun_configs = Info.fun_configs(SectionHookResource)

      for config <- fun_configs do
        assert config.hook_timeout == 10_000
      end
    end

    test "section-level hooks default to nil/5000 when not configured" do
      defmodule NoHookResource do
        use Ash.Resource,
          domain: nil,
          extensions: [AshPhoenixGenApi.Resource],
          data_layer: Ash.DataLayer.Ets

        attributes do
          uuid_primary_key(:id)

          attribute :name, :string do
            public?(true)
          end
        end

        actions do
          create :create do
            accept([:name])
          end
        end

        gen_api do
          service "no_hook_test"

          action :create do
            request_type "create_no_hook"
          end
        end
      end

      fun_configs = Info.fun_configs(NoHookResource)
      config = Enum.find(fun_configs, &(&1.request_type == "create_no_hook"))

      assert config.before_execute == nil
      assert config.after_execute == nil
      assert config.hook_timeout == 5_000
    end
  end

  # ---------------------------------------------------------------------------
  # FunConfig generation with action-level hook overrides
  # ---------------------------------------------------------------------------

  defmodule TestDomainActionHooks do
    use Ash.Domain
  end

  defmodule ActionHookOverrideResource do
    use Ash.Resource,
      domain: AshPhoenixGenApi.Resource.HookConfigTest.TestDomainActionHooks,
      extensions: [AshPhoenixGenApi.Resource],
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    attributes do
      uuid_primary_key(:id)

      attribute :name, :string do
        public?(true)
      end
    end

    actions do
      create :create do
        accept([:name])
      end

      read :read do
        primary?(true)
      end
    end

    gen_api do
      service "action_hook_override_test"
      before_execute({TestHookModule, :before_hook})
      after_execute({TestHookModule, :after_hook})
      hook_timeout 10_000

      action :create do
        request_type "create_override"
        before_execute({TestHookModule, :custom_before, [:create_extra]})
        after_execute({TestHookModule, :custom_after, [:create_extra]})
        hook_timeout 20_000
      end

      action :read do
        request_type "read_inherit"
      end
    end
  end

  describe "action-level hook overrides in FunConfig" do
    test "action-level before_execute overrides section-level" do
      fun_configs = Info.fun_configs(ActionHookOverrideResource)
      create_config = Enum.find(fun_configs, &(&1.request_type == "create_override"))
      read_config = Enum.find(fun_configs, &(&1.request_type == "read_inherit"))

      assert create_config.before_execute == {TestHookModule, :custom_before, [:create_extra]}
      assert read_config.before_execute == {TestHookModule, :before_hook}
    end

    test "action-level after_execute overrides section-level" do
      fun_configs = Info.fun_configs(ActionHookOverrideResource)
      create_config = Enum.find(fun_configs, &(&1.request_type == "create_override"))
      read_config = Enum.find(fun_configs, &(&1.request_type == "read_inherit"))

      assert create_config.after_execute == {TestHookModule, :custom_after, [:create_extra]}
      assert read_config.after_execute == {TestHookModule, :after_hook}
    end

    test "action-level hook_timeout overrides section-level" do
      fun_configs = Info.fun_configs(ActionHookOverrideResource)
      create_config = Enum.find(fun_configs, &(&1.request_type == "create_override"))
      read_config = Enum.find(fun_configs, &(&1.request_type == "read_inherit"))

      assert create_config.hook_timeout == 20_000
      assert read_config.hook_timeout == 10_000
    end
  end

  # ---------------------------------------------------------------------------
  # FunConfig generation with MFA entity hooks
  # ---------------------------------------------------------------------------

  defmodule TestDomainMfaHooks do
    use Ash.Domain
  end

  defmodule MfaHookResource do
    use Ash.Resource,
      domain: AshPhoenixGenApi.Resource.HookConfigTest.TestDomainMfaHooks,
      extensions: [AshPhoenixGenApi.Resource],
      data_layer: Ash.DataLayer.Ets,
      validate_domain_inclusion?: false

    attributes do
      uuid_primary_key(:id)
    end

    actions do
      defaults([:read])
    end

    gen_api do
      service "mfa_hook_test"
      before_execute({TestHookModule, :before_hook})
      after_execute({TestHookModule, :after_hook})
      hook_timeout 10_000

      mfa :ping do
        request_type "ping"
        mfa {TestHookModule, :before_hook, []}
        arg_types %{}
      end

      mfa :ping_with_hooks do
        request_type "ping_with_hooks"
        mfa {TestHookModule, :before_hook, []}
        arg_types %{}
        before_execute({TestHookModule, :custom_before, [:mfa_extra]})
        after_execute({TestHookModule, :custom_after, [:mfa_extra]})
        hook_timeout 30_000
      end
    end
  end

  describe "MFA entity hooks in FunConfig" do
    test "MFA entity inherits section-level hooks" do
      fun_configs = Info.fun_configs(MfaHookResource)
      ping_config = Enum.find(fun_configs, &(&1.request_type == "ping"))

      assert ping_config.before_execute == {TestHookModule, :before_hook}
      assert ping_config.after_execute == {TestHookModule, :after_hook}
      assert ping_config.hook_timeout == 10_000
    end

    test "MFA entity can override section-level hooks" do
      fun_configs = Info.fun_configs(MfaHookResource)
      ping_config = Enum.find(fun_configs, &(&1.request_type == "ping_with_hooks"))

      assert ping_config.before_execute == {TestHookModule, :custom_before, [:mfa_extra]}
      assert ping_config.after_execute == {TestHookModule, :custom_after, [:mfa_extra]}
      assert ping_config.hook_timeout == 30_000
    end
  end

  # ---------------------------------------------------------------------------
  # Introspection helpers
  # ---------------------------------------------------------------------------

  describe "introspection helpers" do
    test "gen_api_before_execute returns section-level setting" do
      assert Info.gen_api_before_execute(SectionHookResource) ==
               {:ok, {TestHookModule, :before_hook}}
    end

    test "gen_api_after_execute returns section-level setting" do
      assert Info.gen_api_after_execute(SectionHookResource) ==
               {:ok, {TestHookModule, :after_hook}}
    end

    test "gen_api_hook_timeout returns section-level setting" do
      assert Info.gen_api_hook_timeout(SectionHookResource) == {:ok, 10_000}
    end

    test "effective_before_execute resolves action-level override" do
      assert Info.effective_before_execute(
               ActionHookOverrideResource,
               :create
             ) == {TestHookModule, :custom_before, [:create_extra]}
    end

    test "effective_before_execute falls back to section-level" do
      assert Info.effective_before_execute(
               ActionHookOverrideResource,
               :read
             ) == {TestHookModule, :before_hook}
    end

    test "effective_after_execute resolves action-level override" do
      assert Info.effective_after_execute(
               ActionHookOverrideResource,
               :create
             ) == {TestHookModule, :custom_after, [:create_extra]}
    end

    test "effective_after_execute falls back to section-level" do
      assert Info.effective_after_execute(
               ActionHookOverrideResource,
               :read
             ) == {TestHookModule, :after_hook}
    end

    test "effective_hook_timeout resolves action-level override" do
      assert Info.effective_hook_timeout(
               ActionHookOverrideResource,
               :create
             ) == 20_000
    end

    test "effective_hook_timeout falls back to section-level" do
      assert Info.effective_hook_timeout(
               ActionHookOverrideResource,
               :read
             ) == 10_000
    end

    test "effective_before_execute returns section default for nonexistent action" do
      assert Info.effective_before_execute(
               SectionHookResource,
               :nonexistent
             ) == {TestHookModule, :before_hook}
    end
  end
end
