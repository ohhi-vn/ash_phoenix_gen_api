

defmodule AshPhoenixGenApi.Resource.ResultEncoderCustomMfaTest do
  use ExUnit.Case

  @moduletag timeout: 60_000


  defmodule MyEncoder do
    def to_json(value) when is_list(value) do
      Enum.map(value, &to_json/1)
    end

    def to_json(%{__struct__: _} = value) do
      value
      |> Map.from_struct()
      |> Map.put(:encoded_by, :my_encoder)
    end

    def to_json(value) do
      value
    end

    def add_timestamp(value, suffix) do
      value
      |> Map.from_struct()
      |> Map.put(:suffix, suffix)
    end
  end

  defmodule CustomMfaResource do
    use Ash.Resource,
      domain: AshPhoenixGenApi.Resource.ResultEncoderCustomMfaTest.TestDomain,
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
      service "custom_mfa_test"
      result_encoder {AshPhoenixGenApi.Resource.ResultEncoderCustomMfaTest.MyEncoder, :to_json, []}

      action :create
      action :read
    end
  end

  defmodule TestDomain do
    use Ash.Domain

    resources do
      resource CustomMfaResource
    end
  end

  describe "code interface with custom MFA result_encoder" do
    test "create applies custom encoder" do
      assert {:ok, result} = CustomMfaResource.create(%{name: "custom_test"})
      assert is_map(result)
      refute Map.has_key?(result, :__struct__)
      assert result.name == "custom_test"
      assert result.encoded_by == :my_encoder
    end

    test "create! applies custom encoder" do
      result = CustomMfaResource.create!(%{name: "custom_test2"})
      assert is_map(result)
      assert result.encoded_by == :my_encoder
    end

    test "read applies custom encoder to each item" do
      CustomMfaResource.create!(%{name: "read_custom"})
      assert {:ok, results} = CustomMfaResource.read()
      assert is_list(results)
      Enum.each(results, fn r ->
        assert is_map(r)
        assert r.encoded_by == :my_encoder
      end)
    end

    test "read! applies custom encoder to each item" do
      results = CustomMfaResource.read!()
      assert is_list(results)
      Enum.each(results, fn r ->
        assert is_map(r)
        assert r.encoded_by == :my_encoder
      end)
    end
  end
end
