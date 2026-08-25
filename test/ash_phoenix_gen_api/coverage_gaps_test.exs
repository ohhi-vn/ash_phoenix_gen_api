defmodule AshPhoenixGenApi.CoverageGapsTest do
  use ExUnit.Case, async: false

  alias AshPhoenixGenApi.Codec
  alias AshPhoenixGenApi.InfoFixtures

  describe "Codec.encode_value/2 with malformed structs" do
    test "falls back to Map.from_struct when __struct__ is not a real module" do
      bogus = %{__struct__: DefinitelyNotAModuleAnywhere, id: "1", __meta__: :meta}

      assert Codec.encode_value(bogus, :map) == %{id: "1", __meta__: :meta}
    end
  end

  describe "AshPhoenixGenApi main module" do
    test "extract_spark_opt/2 unwraps :error to the default" do
      assert AshPhoenixGenApi.extract_spark_opt(:error, :fallback) == :fallback
      assert AshPhoenixGenApi.extract_spark_opt({:ok, :value}, :fallback) == :value
    end

    test "version/0 returns the mix project version" do
      assert AshPhoenixGenApi.version() == "1.3.1"
    end
  end

  describe "Debug.print_*_sources/1" do
    test "prints resource section and entity locations" do
      import ExUnit.CaptureIO

      output =
        capture_io(fn ->
          AshPhoenixGenApi.Debug.print_resource_sources(InfoFixtures.HookedResource)
        end)

      assert output =~ "Source locations"
      assert output =~ "Entity"
    end

    test "prints a friendly message for resources without gen_api" do
      import ExUnit.CaptureIO

      output =
        capture_io(fn ->
          AshPhoenixGenApi.Debug.print_resource_sources(InfoFixtures.PlainResource)
        end)

      assert output =~ "does not have gen_api"
    end

    test "prints a friendly message for domains without gen_api" do
      import ExUnit.CaptureIO

      output =
        capture_io(fn ->
          AshPhoenixGenApi.Debug.print_domain_sources(String)
        end)

      assert output =~ "does not have gen_api"
    end
  end

  describe "DefineDomainSupporter define_supporter? false" do
    test "does not generate the supporter module" do
      assert {:error, _} = Code.ensure_loaded(InfoFixtures.DisabledSupporter)

      assert InfoFixtures.DisabledSupporterDomain
             |> AshPhoenixGenApi.Domain.Info.supporter_module() ==
               InfoFixtures.DisabledSupporter
    end
  end

  describe "transformer edge paths" do
    test "extension-only resource exposes an empty fun_configs list" do
      # Compiling this fixture exercised the empty-entities transformer branch.
      assert Code.ensure_loaded!(AshPhoenixGenApi.InfoFixtures.EmptyGenApiResource)
      assert AshPhoenixGenApi.Resource.Info.fun_configs(
               AshPhoenixGenApi.InfoFixtures.EmptyGenApiResource
             ) == []
    end

    test "mfa with permission_callback compiles and keeps callback in FunConfig" do
      assert Code.ensure_loaded!(AshPhoenixGenApi.InfoFixtures.MfaWithCallbackResource)

      config =
        AshPhoenixGenApi.Resource.Info.fun_configs(
          AshPhoenixGenApi.InfoFixtures.MfaWithCallbackResource
        )
        |> Enum.find(&(&1.request_type == "with_callback"))

      assert config.permission_callback ==
               {AshPhoenixGenApi.InfoFixtures.Hooks, :after, []}

      # permission_callback set means check_permission is forced off
      assert config.check_permission == false
    end
  end
end
