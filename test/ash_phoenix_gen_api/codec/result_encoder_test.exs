defmodule AshPhoenixGenApi.Resource.ActionConfig.ResultEncoderTest do
  use ExUnit.Case

  alias AshPhoenixGenApi.Resource.ActionConfig

  describe "effective_result_encoder/2" do
    test "returns explicit result_encoder when set to :map" do
      config = %ActionConfig{result_encoder: :map}
      assert ActionConfig.effective_result_encoder(config, :struct) == :map
    end

    test "returns explicit result_encoder when set to :struct" do
      config = %ActionConfig{result_encoder: :struct}
      assert ActionConfig.effective_result_encoder(config, :map) == :struct
    end

    test "returns explicit result_encoder when set to custom MFA" do
      mfa = {MyEncoder, :encode, []}
      config = %ActionConfig{result_encoder: mfa}
      assert ActionConfig.effective_result_encoder(config, :struct) == mfa
    end

    test "returns default when result_encoder is nil" do
      config = %ActionConfig{result_encoder: nil}
      assert ActionConfig.effective_result_encoder(config, :struct) == :struct
      assert ActionConfig.effective_result_encoder(config, :map) == :map
    end
  end
end
