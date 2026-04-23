
defmodule AshPhoenixGenApi.Domain.ResultEncoderTest do
  use ExUnit.Case

  @moduletag timeout: 60_000


  alias AshPhoenixGenApi.Domain.Info

  defmodule StructEncoderDomain do
    use Ash.Domain,
      extensions: [AshPhoenixGenApi.Domain]

    gen_api do
      service "struct_encoder_domain"
      supporter_module AshPhoenixGenApi.Domain.ResultEncoderTest.StructSupporter
      result_encoder :struct
    end

    resources do
    end
  end

  defmodule MapEncoderDomain do
    use Ash.Domain,
      extensions: [AshPhoenixGenApi.Domain]

    gen_api do
      service "map_encoder_domain"
      supporter_module AshPhoenixGenApi.Domain.ResultEncoderTest.MapSupporter
      result_encoder :map
    end

    resources do
    end
  end

  defmodule CustomMfaEncoderDomain do
    use Ash.Domain,
      extensions: [AshPhoenixGenApi.Domain]

    gen_api do
      service "custom_mfa_encoder_domain"
      supporter_module AshPhoenixGenApi.Domain.ResultEncoderTest.CustomMfaSupporter
      result_encoder {MyEncoder, :encode, []}
    end

    resources do
    end
  end

  defmodule DefaultEncoderDomain do
    use Ash.Domain,
      extensions: [AshPhoenixGenApi.Domain]

    gen_api do
      service "default_encoder_domain"
      supporter_module AshPhoenixGenApi.Domain.ResultEncoderTest.DefaultSupporter
    end

    resources do
    end
  end

  describe "domain result_encoder configuration" do
    test "gen_api_result_encoder returns {:ok, :struct} for struct encoder domain" do
      assert {:ok, :struct} = Info.gen_api_result_encoder(StructEncoderDomain)
    end

    test "gen_api_result_encoder returns {:ok, :map} for map encoder domain" do
      assert {:ok, :map} = Info.gen_api_result_encoder(MapEncoderDomain)
    end

    test "gen_api_result_encoder returns {:ok, mfa} for custom MFA encoder domain" do
      assert {:ok, {MyEncoder, :encode, []}} = Info.gen_api_result_encoder(CustomMfaEncoderDomain)
    end

    test "gen_api_result_encoder returns {:ok, :struct} by default" do
      assert {:ok, :struct} = Info.gen_api_result_encoder(DefaultEncoderDomain)
    end
  end

  describe "result_encoder/1 helper" do
    test "returns :struct for struct encoder domain" do
      assert Info.result_encoder(StructEncoderDomain) == :struct
    end

    test "returns :map for map encoder domain" do
      assert Info.result_encoder(MapEncoderDomain) == :map
    end

    test "returns custom MFA for custom MFA encoder domain" do
      assert Info.result_encoder(CustomMfaEncoderDomain) == {MyEncoder, :encode, []}
    end

    test "returns :struct by default" do
      assert Info.result_encoder(DefaultEncoderDomain) == :struct
    end
  end

  describe "domain summary includes result_encoder" do
    test "summary includes result_encoder :struct" do
      summary = Info.summary(StructEncoderDomain)
      assert summary.result_encoder == :struct
    end

    test "summary includes result_encoder :map" do
      summary = Info.summary(MapEncoderDomain)
      assert summary.result_encoder == :map
    end

    test "summary includes result_encoder custom MFA" do
      summary = Info.summary(CustomMfaEncoderDomain)
      assert summary.result_encoder == {MyEncoder, :encode, []}
    end
  end
end
