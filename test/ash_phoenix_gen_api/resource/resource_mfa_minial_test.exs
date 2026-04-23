

defmodule AshPhoenixGenApi.Resource.MfaMinimalTest do
  use ExUnit.Case

  @moduletag timeout: 60_000


  alias AshPhoenixGenApi.Resource.Info

  defmodule MinimalMfaResource do
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

      mfa :health_check do
        request_type "health_check"
        mfa {HealthChecker, :check, []}
        arg_types %{}
      end
    end
  end

  test "minimal mfa config with empty arg_types" do
    config = Info.fun_config(MinimalMfaResource, "health_check")
    assert config != nil
    assert config.request_type == "health_check"
    assert config.mfa == {HealthChecker, :check, []}
    assert config.arg_types == nil
    assert config.arg_orders == nil
  end

  test "minimal mfa uses section-level defaults" do
    config = Info.fun_config(MinimalMfaResource, "health_check")
    assert config.service == "test_service"
    assert config.timeout == 5_000
    assert config.response_type == :async
    assert config.request_info == true
    assert config.version == "0.0.1"
    assert config.check_permission == false
  end
end
