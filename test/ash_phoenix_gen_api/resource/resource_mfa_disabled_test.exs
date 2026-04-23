
defmodule AshPhoenixGenApi.Resource.MfaDisabledTest do
  use ExUnit.Case

  @moduletag timeout: 60_000


  alias AshPhoenixGenApi.Resource.Info

  defmodule DisabledMfaResource do
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

      mfa :active_mfa do
        request_type "active_mfa"
        mfa {SomeModule, :handler, []}
        arg_types %{}
      end

      mfa :disabled_mfa do
        request_type "disabled_mfa"
        mfa {SomeModule, :handler, []}
        arg_types %{}
        disabled true
      end
    end
  end

  test "enabled_mfas excludes disabled mfas" do
    mfas = Info.enabled_mfas(DisabledMfaResource)
    assert length(mfas) == 1
    assert hd(mfas).name == :active_mfa
  end

  test "fun_configs excludes disabled mfas" do
    fun_configs = Info.fun_configs(DisabledMfaResource)
    request_types = Enum.map(fun_configs, & &1.request_type)
    assert "active_mfa" in request_types
    refute "disabled_mfa" in request_types
  end

  test "request_types excludes disabled mfas" do
    types = Info.request_types(DisabledMfaResource)
    assert "active_mfa" in types
    refute "disabled_mfa" in types
  end
end
