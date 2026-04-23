

defmodule AshPhoenixGenApi.Resource.ActionConfig.CodeInterfaceTest do
  use ExUnit.Case

  alias AshPhoenixGenApi.Resource.ActionConfig

  describe "effective_code_interface?/2" do
    test "returns explicit code_interface? when set to true" do
      config = %ActionConfig{code_interface?: true}
      assert ActionConfig.effective_code_interface?(config, false) == true
    end

    test "returns explicit code_interface? when set to false" do
      config = %ActionConfig{code_interface?: false}
      assert ActionConfig.effective_code_interface?(config, true) == false
    end

    test "returns default when code_interface? is nil" do
      config = %ActionConfig{code_interface?: nil}
      assert ActionConfig.effective_code_interface?(config, true) == true
      assert ActionConfig.effective_code_interface?(config, false) == false
    end
  end
end
