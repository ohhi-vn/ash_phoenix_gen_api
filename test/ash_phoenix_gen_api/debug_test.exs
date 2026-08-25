defmodule AshPhoenixGenApi.DebugTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureIO

  alias AshPhoenixGenApi.Debug

  defmodule DebugTestResource do
    use Ash.Resource,
      domain: nil,
      extensions: [AshPhoenixGenApi.Resource]

    attributes do
      uuid_primary_key(:id)
      attribute(:name, :string, allow_nil?: false)
    end

    actions do
      defaults([:create, :read])
    end

    gen_api do
      service "debug_test"

      action :create do
        request_type "create"
      end
    end
  end

  defmodule DebugTestDomain do
    use Ash.Domain,
      extensions: [AshPhoenixGenApi.Domain]

    gen_api do
      service "debug_test"
      supporter_module DebugTestDomain.Supporter
      version "1.0.0"
    end

    resources do
      resource(DebugTestResource)
    end
  end

  describe "inspect_resource_sources/1" do
    test "returns section and entity locations for a resource with gen_api" do
      result = Debug.inspect_resource_sources(DebugTestResource)
      assert is_map(result)
      assert result.resource == DebugTestResource
      assert is_list(result.entities)
      refute result.entities == []
    end

    test "returns error for resource without gen_api" do
      result = Debug.inspect_resource_sources(String)
      assert result == {:error, :no_gen_api}
    end
  end

  describe "inspect_domain_sources/1" do
    test "returns section and entity locations for a domain with gen_api" do
      result = Debug.inspect_domain_sources(DebugTestDomain)
      assert is_map(result)
      assert result.domain == DebugTestDomain
      assert is_list(result.entities)
    end

    test "returns error for domain without gen_api" do
      result = Debug.inspect_domain_sources(String)
      assert result == {:error, :no_gen_api}
    end
  end

  describe "print_resource_sources/1" do
    test "prints source locations without crashing" do
      assert capture_io(fn ->
               Debug.print_resource_sources(DebugTestResource)
             end) =~ "Source locations"
    end

    test "prints message for resource without gen_api" do
      assert capture_io(fn ->
               Debug.print_resource_sources(String)
             end) =~ "does not have gen_api configured"
    end
  end

  describe "print_domain_sources/1" do
    test "prints source locations without crashing" do
      assert capture_io(fn ->
               Debug.print_domain_sources(DebugTestDomain)
             end) =~ "Source locations"
    end

    test "prints message for domain without gen_api" do
      assert capture_io(fn ->
               Debug.print_domain_sources(String)
             end) =~ "does not have gen_api configured"
    end
  end
end
