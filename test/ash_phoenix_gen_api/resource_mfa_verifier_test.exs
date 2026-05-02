

defmodule AshPhoenixGenApi.Resource.MfaVerifierTest do
  use ExUnit.Case

  @moduletag timeout: 60_000

  alias AshPhoenixGenApi.Resource.MfaConfig

  describe "mfa entity verifier - required fields (validated by Spark at compile time)" do
    test "raises when mfa entity is missing request_type" do
      assert_raise Spark.Error.DslError, ~r/required :request_type option not found/, fn ->
        defmodule MissingRequestTypeResource do
          use Ash.Resource,
            extensions: [AshPhoenixGenApi.Resource]

          attributes do
            uuid_primary_key :id
          end

          actions do
            create :create do
              accept []
            end
          end

          gen_api do
            service "test_service"

            mfa :bad_mfa do
              mfa {SomeModule, :handler, []}
              arg_types %{}
            end
          end
        end
      end
    end

    test "raises when mfa entity is missing mfa tuple" do
      assert_raise Spark.Error.DslError, ~r/required :mfa option not found/, fn ->
        defmodule MissingMfaTupleResource do
          use Ash.Resource,
            extensions: [AshPhoenixGenApi.Resource]

          attributes do
            uuid_primary_key :id
          end

          actions do
            create :create do
              accept []
            end
          end

          gen_api do
            service "test_service"

            mfa :bad_mfa do
              request_type "bad_mfa"
              arg_types %{}
            end
          end
        end
      end
    end

    test "raises when mfa entity is missing arg_types" do
      assert_raise Spark.Error.DslError, ~r/required :arg_types option not found/, fn ->
        defmodule MissingArgTypesResource do
          use Ash.Resource,
            extensions: [AshPhoenixGenApi.Resource]

          attributes do
            uuid_primary_key :id
          end

          actions do
            create :create do
              accept []
            end
          end

          gen_api do
            service "test_service"

            mfa :bad_mfa do
              request_type "bad_mfa"
              mfa {SomeModule, :handler, []}
            end
          end
        end
      end
    end
  end

  describe "MfaConfig verifier logic (unit tests)" do
    test "detects invalid MFA tuple structure" do
      config = %MfaConfig{
        name: :bad_mfa,
        request_type: "bad_mfa",
        mfa: "not_a_tuple",
        arg_types: %{}
      }

      errors = collect_mfa_mfa_errors(config)
      assert length(errors) == 1
      assert hd(errors) =~ ~r/invalid MFA tuple/
    end

    test "detects MFA tuple with non-atom module" do
      config = %MfaConfig{
        name: :bad_mfa,
        request_type: "bad_mfa",
        mfa: {"not_a_module", :function, []},
        arg_types: %{}
      }

      errors = collect_mfa_mfa_errors(config)
      assert length(errors) == 1
    end

    test "detects MFA tuple with non-atom function" do
      config = %MfaConfig{
        name: :bad_mfa,
        request_type: "bad_mfa",
        mfa: {SomeModule, "not_a_function", []},
        arg_types: %{}
      }

      errors = collect_mfa_mfa_errors(config)
      assert length(errors) == 1
    end

    test "detects MFA tuple with non-list args" do
      config = %MfaConfig{
        name: :bad_mfa,
        request_type: "bad_mfa",
        mfa: {SomeModule, :function, "not_a_list"},
        arg_types: %{}
      }

      errors = collect_mfa_mfa_errors(config)
      assert length(errors) == 1
    end

    test "valid MFA tuple produces no errors" do
      config = %MfaConfig{
        name: :good_mfa,
        request_type: "good_mfa",
        mfa: {SomeModule, :handler, []},
        arg_types: %{}
      }

      errors = collect_mfa_mfa_errors(config)
      assert errors == []
    end

    test "detects arg_orders with keys missing from arg_types" do
      config = %MfaConfig{
        name: :bad_args,
        request_type: "bad_args",
        mfa: {SomeModule, :handler, []},
        arg_types: %{"user_id" => :string},
        arg_orders: ["user_id", "extra_field"]
      }

      errors = collect_mfa_arg_consistency_errors(config)
      assert length(errors) == 1
      assert hd(errors) =~ ~r/arg_orders has keys.*missing from arg_types/
    end

    test "detects arg_types with keys missing from arg_orders" do
      config = %MfaConfig{
        name: :bad_args,
        request_type: "bad_args",
        mfa: {SomeModule, :handler, []},
        arg_types: %{"user_id" => :string, "name" => :string},
        arg_orders: ["user_id"]
      }

      errors = collect_mfa_arg_consistency_errors(config)
      assert length(errors) == 1
      assert hd(errors) =~ ~r/arg_types has keys.*missing from arg_orders/
    end

    test "matching arg_types and arg_orders produces no errors" do
      config = %MfaConfig{
        name: :good_args,
        request_type: "good_args",
        mfa: {SomeModule, :handler, []},
        arg_types: %{"user_id" => :string, "name" => :string},
        arg_orders: ["user_id", "name"]
      }

      errors = collect_mfa_arg_consistency_errors(config)
      assert errors == []
    end

    test "arg_orders :map with arg_types produces no errors" do
      config = %MfaConfig{
        name: :map_args,
        request_type: "map_args",
        mfa: {SomeModule, :handler, []},
        arg_types: %{"user_id" => :string},
        arg_orders: :map
      }

      errors = collect_mfa_arg_consistency_errors(config)
      assert errors == []
    end

    test "detects check_permission referencing arg not in arg_types" do
      config = %MfaConfig{
        name: :bad_perm,
        request_type: "bad_perm",
        mfa: {SomeModule, :handler, []},
        arg_types: %{"user_id" => :string},
        check_permission: {:arg, "nonexistent_field"}
      }

      errors = collect_mfa_permission_arg_errors(config)
      assert length(errors) == 1
      assert hd(errors) =~ ~r/check_permission references arg.*not found in arg_types/
    end

    test "check_permission with valid arg produces no errors" do
      config = %MfaConfig{
        name: :good_perm,
        request_type: "good_perm",
        mfa: {SomeModule, :handler, []},
        arg_types: %{"user_id" => :string},
        check_permission: {:arg, "user_id"}
      }

      errors = collect_mfa_permission_arg_errors(config)
      assert errors == []
    end

    test "detects invalid permission_callback structure" do
      config = %MfaConfig{
        name: :bad_callback,
        request_type: "bad_callback",
        mfa: {SomeModule, :handler, []},
        arg_types: %{},
        permission_callback: "not_a_tuple"
      }

      errors = collect_mfa_permission_callback_errors(config)
      assert length(errors) == 1
      assert hd(errors) =~ ~r/invalid permission_callback/
    end

    test "valid permission_callback produces no errors" do
      config = %MfaConfig{
        name: :good_callback,
        request_type: "good_callback",
        mfa: {SomeModule, :handler, []},
        arg_types: %{},
        permission_callback: {MyChecker, :check, []}
      }

      errors = collect_mfa_permission_callback_errors(config)
      assert errors == []
    end

    test "nil permission_callback produces no errors" do
      config = %MfaConfig{
        name: :nil_callback,
        request_type: "nil_callback",
        mfa: {SomeModule, :handler, []},
        arg_types: %{},
        permission_callback: nil
      }

      errors = collect_mfa_permission_callback_errors(config)
      assert errors == []
    end
  end

  # ---------------------------------------------------------------------------
  # Helper functions that replicate the verifier logic for unit testing
  # ---------------------------------------------------------------------------

  defp collect_mfa_mfa_errors(mfa_config) do
    case mfa_config.mfa do
      {mod, fun, args} when is_atom(mod) and is_atom(fun) and is_list(args) ->
        []

      mfa ->
        ["MFA `#{inspect(mfa_config.name)}`: invalid MFA tuple `#{inspect(mfa)}`. " <>
           "Expected `{module, function, args_list}` where module and function are atoms " <>
           "and args is a list."]
    end
  end

  defp collect_mfa_arg_consistency_errors(mfa_config) do
    arg_types = mfa_config.arg_types
    arg_orders = mfa_config.arg_orders

    cond do
      has_both_arg_configs?(arg_types, arg_orders) ->
        check_mfa_arg_keys_match(mfa_config)

      has_only_arg_types?(arg_types) ->
        []

      true ->
        []
    end
  end

  defp has_both_arg_configs?(arg_types, arg_orders) do
    is_map(arg_types) and map_size(arg_types) > 0 and
      is_list(arg_orders) and arg_orders != []
  end

  defp has_only_arg_types?(arg_types) do
    is_map(arg_types) and map_size(arg_types) > 0
  end

  defp check_mfa_arg_keys_match(mfa_config) do
    arg_types = mfa_config.arg_types
    arg_orders = mfa_config.arg_orders
    arg_type_keys = MapSet.new(Map.keys(arg_types))
    arg_order_keys = MapSet.new(arg_orders)

    missing_in_orders = MapSet.difference(arg_type_keys, arg_order_keys)
    missing_in_types = MapSet.difference(arg_order_keys, arg_type_keys)

    errors = []

    errors =
      if MapSet.size(missing_in_orders) > 0 do
        ["MFA `#{mfa_config.name}`: arg_types has keys " <>
           "#{inspect(MapSet.to_list(missing_in_orders))} that are missing from arg_orders" | errors]
      else
        errors
      end

    errors =
      if MapSet.size(missing_in_types) > 0 do
        ["MFA `#{mfa_config.name}`: arg_orders has keys " <>
           "#{inspect(MapSet.to_list(missing_in_types))} that are missing from arg_types" | errors]
      else
        errors
      end

    errors
  end

  defp collect_mfa_permission_arg_errors(mfa_config) do
    case mfa_config.check_permission do
      {:arg, arg_name} when is_binary(arg_name) ->
        if is_map(mfa_config.arg_types) and Map.has_key?(mfa_config.arg_types, arg_name) do
          []
        else
          ["MFA `#{mfa_config.name}`: check_permission references arg " <>
             "`#{inspect(arg_name)}` but it is not found in arg_types"]
        end

      _ ->
        []
    end
  end

  defp collect_mfa_permission_callback_errors(mfa_config) do
    case mfa_config.permission_callback do
      nil ->
        []

      {mod, fun, args} when is_atom(mod) and is_atom(fun) and is_list(args) ->
        []

      permission_callback ->
        ["MFA `#{mfa_config.name}`: invalid permission_callback `#{inspect(permission_callback)}`. " <>
           "Expected `{Module, :function, []}` where Module and function are atoms " <>
           "and args is a list, or `nil`."]
    end
  end
end
