
defmodule AshPhoenixGenApi.CodecTest do
  use ExUnit.Case

  describe "encode_result/2 with :struct encoder" do
    test "returns {:ok, struct} unchanged" do
      struct = %{__struct__: FakeResource, id: "1", name: "test"}
      assert AshPhoenixGenApi.Codec.encode_result({:ok, struct}, :struct) == {:ok, struct}
    end

    test "returns {:error, error} unchanged" do
      assert AshPhoenixGenApi.Codec.encode_result({:error, :not_found}, :struct) == {:error, :not_found}
    end

    test "returns :ok unchanged for destroy actions" do
      assert AshPhoenixGenApi.Codec.encode_result(:ok, :struct) == :ok
    end
  end

  describe "encode_result/2 with :map encoder" do
    test "converts {:ok, struct} to {:ok, map}" do
      struct = %{__struct__: FakeResource, id: "1", name: "test"}
      {:ok, result} = AshPhoenixGenApi.Codec.encode_result({:ok, struct}, :map)
      assert is_map(result)
      refute Map.has_key?(result, :__struct__)
      assert result.id == "1"
      assert result.name == "test"
    end

    test "converts {:ok, list of structs} to {:ok, list of maps}" do
      structs = [
        %{__struct__: FakeResource, id: "1", name: "a"},
        %{__struct__: FakeResource, id: "2", name: "b"}
      ]
      {:ok, results} = AshPhoenixGenApi.Codec.encode_result({:ok, structs}, :map)
      assert is_list(results)
      assert length(results) == 2
      Enum.each(results, fn r ->
        assert is_map(r)
        refute Map.has_key?(r, :__struct__)
      end)
    end

    test "returns {:error, error} unchanged" do
      assert AshPhoenixGenApi.Codec.encode_result({:error, :not_found}, :map) == {:error, :not_found}
    end

    test "returns :ok unchanged for destroy actions" do
      assert AshPhoenixGenApi.Codec.encode_result(:ok, :map) == :ok
    end

    test "passes through non-struct values in {:ok, value}" do
      assert AshPhoenixGenApi.Codec.encode_result({:ok, "hello"}, :map) == {:ok, "hello"}
      assert AshPhoenixGenApi.Codec.encode_result({:ok, 42}, :map) == {:ok, 42}
    end
  end

  describe "encode_result/2 with custom MFA encoder" do
    test "applies custom encoder to {:ok, value}" do
      encoder = {__MODULE__, :upcase_name, []}
      struct = %{__struct__: FakeResource, id: "1", name: "test"}
      {:ok, result} = AshPhoenixGenApi.Codec.encode_result({:ok, struct}, encoder)
      assert result.name == "TEST"
    end

    test "returns {:error, error} unchanged with custom encoder" do
      encoder = {__MODULE__, :upcase_name, []}
      assert AshPhoenixGenApi.Codec.encode_result({:error, :not_found}, encoder) == {:error, :not_found}
    end
  end

  describe "encode_value/2 with :struct encoder" do
    test "returns value unchanged" do
      struct = %{__struct__: FakeResource, id: "1", name: "test"}
      assert AshPhoenixGenApi.Codec.encode_value(struct, :struct) == struct
    end
  end

  describe "encode_value/2 with :map encoder" do
    test "converts single struct to map" do
      struct = %{__struct__: FakeResource, id: "1", name: "test"}
      result = AshPhoenixGenApi.Codec.encode_value(struct, :map)
      assert is_map(result)
      refute Map.has_key?(result, :__struct__)
      assert result.id == "1"
      assert result.name == "test"
    end

    test "converts list of structs to list of maps" do
      structs = [
        %{__struct__: FakeResource, id: "1", name: "a"},
        %{__struct__: FakeResource, id: "2", name: "b"}
      ]
      results = AshPhoenixGenApi.Codec.encode_value(structs, :map)
      assert is_list(results)
      assert length(results) == 2
      Enum.each(results, fn r ->
        assert is_map(r)
        refute Map.has_key?(r, :__struct__)
      end)
    end

    test "returns :ok unchanged" do
      assert AshPhoenixGenApi.Codec.encode_value(:ok, :map) == :ok
    end

    test "passes through non-struct values" do
      assert AshPhoenixGenApi.Codec.encode_value("hello", :map) == "hello"
      assert AshPhoenixGenApi.Codec.encode_value(42, :map) == 42
    end
  end

  describe "encode_value/2 with custom MFA encoder" do
    test "applies custom encoder to value" do
      encoder = {__MODULE__, :upcase_name, []}
      struct = %{__struct__: FakeResource, id: "1", name: "test"}
      result = AshPhoenixGenApi.Codec.encode_value(struct, encoder)
      assert result.name == "TEST"
    end

    test "passes extra args to custom encoder" do
      encoder = {__MODULE__, :prefix_name, ["mr_"]}
      struct = %{__struct__: FakeResource, id: "1", name: "test"}
      result = AshPhoenixGenApi.Codec.encode_value(struct, encoder)
      assert result.name == "mr_test"
    end
  end

  describe "encode_value/2 fallback" do
    test "returns value unchanged for nil encoder" do
      struct = %{__struct__: FakeResource, id: "1", name: "test"}
      assert AshPhoenixGenApi.Codec.encode_value(struct, nil) == struct
    end

    test "returns value unchanged for unrecognized encoder" do
      struct = %{__struct__: FakeResource, id: "1", name: "test"}
      assert AshPhoenixGenApi.Codec.encode_value(struct, :unknown) == struct
    end
  end

  # Test helper functions for custom encoders
  def upcase_name(value) do
    %{value | name: String.upcase(value.name)}
  end

  def prefix_name(value, prefix) do
    %{value | name: prefix <> value.name}
  end
end
