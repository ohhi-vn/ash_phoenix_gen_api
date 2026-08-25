defmodule AshPhoenixGenApi.UtilsTest do
  use ExUnit.Case, async: true

  alias AshPhoenixGenApi.Utils

  describe "extract_opt/2" do
    test "unwraps {:ok, value}" do
      assert Utils.extract_opt({:ok, :configured}, :default) == :configured
    end

    test "returns default on :error" do
      assert Utils.extract_opt(:error, :default) == :default
    end

    test "passes through non-tuple values (predicate results)" do
      assert Utils.extract_opt(true, false) == true
      assert Utils.extract_opt("direct", nil) == "direct"
      assert Utils.extract_opt(nil, :default) == nil
    end
  end

  describe "valid_mfa?/1" do
    test "true for {atom, atom, list}" do
      assert Utils.valid_mfa?({MyMod, :fun, []}) == true
      assert Utils.valid_mfa?({MyMod, :fun, [1, 2]}) == true
    end

    test "false for malformed tuples" do
      assert Utils.valid_mfa?({"mod", :fun, []}) == false
      assert Utils.valid_mfa?({MyMod, "fun", []}) == false
      assert Utils.valid_mfa?({MyMod, :fun, :not_a_list}) == false
    end

    test "false for non-tuples" do
      assert Utils.valid_mfa?(nil) == false
      assert Utils.valid_mfa?(:local) == false
      assert Utils.valid_mfa?([MyMod, :fun]) == false
    end
  end

  describe "mfa_errors/1" do
    test "empty list for valid MFA" do
      assert Utils.mfa_errors({MyMod, :fun, []}) == []
    end

    test "reports invalid parts" do
      errors = Utils.mfa_errors({"mod", 42, :oops})

      assert errors == [
               "  Module must be an atom, got: \"mod\"",
               "  Function must be an atom, got: 42",
               "  Args must be a list, got: :oops"
             ]
    end

    test "reports non-tuple input" do
      assert Utils.mfa_errors(:nope) == [
               "  Expected an MFA tuple {module, function, args}, got: :nope"
             ]
    end
  end

  describe "format_source_location/1" do
    test "empty string for nil" do
      assert Utils.format_source_location(nil) == ""
    end

    test "empty string for unknown annotation shapes" do
      assert Utils.format_source_location(:garbage) == ""
      assert Utils.format_source_location(42) == ""
    end

    test "formats file and line when available (property-list anno)" do
      anno = :erl_anno.set_file(String.to_charlist("/tmp/lib/foo.ex"), :erl_anno.new({12, 3}))

      formatted = Utils.format_source_location(anno)
      assert formatted =~ "\n  Defined at"
      assert formatted =~ "foo.ex:12"
    end

    test "omits source when file is undefined (tuple anno)" do
      assert Utils.format_source_location({12, 3}) == "\n  Defined at"
    end

    test "handles property-list anno without file" do
      assert Utils.format_source_location(location: {7, 1}) == "\n  Defined at"
    end

    test "omits source when file is :undefined in a property-list anno" do
      assert Utils.format_source_location(location: {7, 1}, file: :undefined) ==
               "\n  Defined at"
    end

    test "omits source when a property-list anno has no location" do
      assert Utils.format_source_location(file: String.to_charlist("/tmp/x.ex")) ==
               "\n  Defined at"
    end
  end
end
