defmodule AshPhoenixGenApi.Codec.MfaResultEncoderTest do
  use ExUnit.Case

  alias AshPhoenixGenApi.Codec
  alias AshPhoenixGenApi.Resource.Info
  alias AshPhoenixGenApi.Resource.MfaConfig
  alias AshPhoenixGenApi.Transformers.DefineFunConfigs

  defmodule EncoderTestResource do
    use Ash.Resource,
      domain: nil,
      extensions: [AshPhoenixGenApi.Resource]

    attributes do
      uuid_primary_key :id
    end

    actions do
      read :read do
        primary? true
      end
    end

    gen_api do
      service "test_service"

      mfa :explicit_map do
        request_type "explicit_map"
        mfa({__MODULE__, :handler, []})
        arg_types %{}
        result_encoder(:map)
      end

      mfa :explicit_struct do
        request_type "explicit_struct"
        mfa({__MODULE__, :handler, []})
        arg_types %{}
        result_encoder(:struct)
      end

      mfa :custom_encoder do
        request_type "custom_encoder"
        mfa({__MODULE__, :handler, []})
        arg_types %{}
        result_encoder({MyEncoder, :encode, []})
      end

      mfa :inherited do
        request_type "inherited"
        mfa({__MODULE__, :handler, []})
        arg_types %{}
      end
    end
  end

  describe "fun_config_encoder/1" do
    test ":struct translates to nil (no encoder)" do
      assert Codec.fun_config_encoder(:struct) == nil
    end

    test ":map translates to the encode_result MFA" do
      assert Codec.fun_config_encoder(:map) == {Codec, :encode_result, [:map]}
    end

    test "custom MFA passes through verbatim" do
      assert Codec.fun_config_encoder({MyEncoder, :encode, []}) == {MyEncoder, :encode, []}
    end

    test "nil translates to nil" do
      assert Codec.fun_config_encoder(nil) == nil
    end
  end

  describe "mfa_result_encoder/2 resolution chain" do
    test "explicit :map on the mfa wins" do
      config = Info.mfa(EncoderTestResource, :explicit_map)
      defaults = %{result_encoder: :struct}
      assert DefineFunConfigs.mfa_result_encoder(config, defaults) == {Codec, :encode_result, [:map]}
    end

    test "explicit :struct translates to nil" do
      config = Info.mfa(EncoderTestResource, :explicit_struct)
      defaults = %{result_encoder: :map}
      assert DefineFunConfigs.mfa_result_encoder(config, defaults) == nil
    end

    test "custom MFA passes through verbatim" do
      config = Info.mfa(EncoderTestResource, :custom_encoder)
      defaults = %{result_encoder: :struct}
      assert DefineFunConfigs.mfa_result_encoder(config, defaults) == {MyEncoder, :encode, []}
    end

    test "mfa without result_encoder inherits the section default" do
      config = Info.mfa(EncoderTestResource, :inherited)

      assert DefineFunConfigs.mfa_result_encoder(config, %{result_encoder: :struct}) == nil

      assert DefineFunConfigs.mfa_result_encoder(config, %{result_encoder: :map}) ==
               {Codec, :encode_result, [:map]}
    end

    test "mfa configs compile with a result_encoder field defaulting to nil" do
      assert %MfaConfig{result_encoder: nil} = Info.mfa(EncoderTestResource, :inherited)
      assert Info.mfa(EncoderTestResource, :explicit_map).result_encoder == :map
    end

    test "generated FunConfigs carry the translated encoder MFA" do
      fun_configs = EncoderTestResource.__ash_phoenix_gen_api_fun_configs__()

      assert %{result_encoder: {Codec, :encode_result, [:map]}} =
               Enum.find(fun_configs, &(&1.request_type == "explicit_map"))

      assert %{result_encoder: nil} =
               Enum.find(fun_configs, &(&1.request_type == "explicit_struct"))

      assert %{result_encoder: nil} =
               Enum.find(fun_configs, &(&1.request_type == "inherited"))

      assert %{result_encoder: {MyEncoder, :encode, []}} =
               Enum.find(fun_configs, &(&1.request_type == "custom_encoder"))
    end
  end

  describe "encode_result/2 for mfa return shapes" do
    defmodule Club do
      use Ash.Resource, domain: nil

      attributes do
        uuid_primary_key :id
        attribute :name, :string do
          public? true
        end
        attribute :secret, :string
      end

      actions do
        read :read do
          primary? true
        end
      end
    end

    test "converts {:ok, list of structs} preserving the format" do
      result =
        Codec.encode_result({:ok, [%Club{id: "1", name: "a", secret: "s"}]}, :map)

      assert result == {:ok, [%{id: "1", name: "a"}]}
    end

    test "passes {:error, reason} through unchanged" do
      assert Codec.encode_result({:error, :not_found}, :map) == {:error, :not_found}
    end

    test "passes :ok through unchanged" do
      assert Codec.encode_result(:ok, :map) == :ok
    end
  end
end
