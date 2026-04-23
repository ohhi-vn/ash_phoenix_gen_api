


defmodule AshPhoenixGenApi.DefaultsTest do
  use ExUnit.Case, async: true

  describe "AshPhoenixGenApi.defaults/0" do
    test "returns expected default values" do
      defaults = AshPhoenixGenApi.defaults()

      assert defaults.timeout == 5_000
      assert defaults.response_type == :async
      assert defaults.request_info == true
      assert defaults.check_permission == false
      assert defaults.permission_callback == nil
      assert defaults.choose_node_mode == :random
      assert defaults.nodes == :local
      assert defaults.version == "0.0.1"
      assert defaults.retry == nil
      assert defaults.code_interface? == true
      assert defaults.push_nodes == nil
      assert defaults.push_on_startup == false
    end
  end

  describe "AshPhoenixGenApi.extensions/0" do
    test "returns list of extension modules" do
      extensions = AshPhoenixGenApi.extensions()

      assert AshPhoenixGenApi.Resource in extensions
      assert AshPhoenixGenApi.Domain in extensions
    end
  end

  describe "AshPhoenixGenApi.modules/0" do
    test "returns list of all modules" do
      modules = AshPhoenixGenApi.modules()

      assert AshPhoenixGenApi.Resource in modules
      assert AshPhoenixGenApi.Resource.Info in modules
      assert AshPhoenixGenApi.Resource.ActionConfig in modules
      assert AshPhoenixGenApi.Domain in modules
      assert AshPhoenixGenApi.Domain.Info in modules
      assert AshPhoenixGenApi.TypeMapper in modules
    end
  end
end
