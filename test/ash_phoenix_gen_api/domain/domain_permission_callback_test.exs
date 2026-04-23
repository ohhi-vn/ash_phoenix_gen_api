
defmodule AshPhoenixGenApi.Domain.PermissionCallbackTest do
  use ExUnit.Case

  @moduletag timeout: 60_000


  defmodule DomainCallbackChecker do
    @moduledoc false
    def check_permission(_request_type, _args), do: true
  end

  defmodule DomainPermissionCallbackDomain do
    use Ash.Domain,
      extensions: [AshPhoenixGenApi.Domain]

    gen_api do
      service "domain_cb_test"
      supporter_module AshPhoenixGenApi.Domain.PermissionCallbackTest.Supporter
      permission_callback {DomainCallbackChecker, :check_permission, []}
      version "1.0.0"
    end

    resources do
    end
  end

  describe "domain-level permission_callback" do
    test "gen_api_permission_callback returns {:ok, configured callback}" do
      result = AshPhoenixGenApi.Domain.Info.gen_api_permission_callback(DomainPermissionCallbackDomain)
      assert result == {:ok, {DomainCallbackChecker, :check_permission, []}}
    end

    test "permission_callback helper returns configured callback" do
      result = AshPhoenixGenApi.Domain.Info.permission_callback(DomainPermissionCallbackDomain)
      assert result == {DomainCallbackChecker, :check_permission, []}
    end
  end
end
