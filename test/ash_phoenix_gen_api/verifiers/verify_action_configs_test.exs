defmodule AshPhoenixGenApi.Verifiers.VerifyActionConfigsTest do
  use ExUnit.Case, async: true

  import Spark.Test

  describe "action existence verification" do
    test "raises error when action does not exist on resource" do
      assert_dsl_error %Spark.Error.DslError{path: [:gen_api]} do
        defmodule Elixir.NonExistentActionResource do
          use Ash.Resource,
            domain: nil,
            extensions: [AshPhoenixGenApi.Resource]

          attributes do
            uuid_primary_key(:id)
            attribute(:name, :string)
          end

          actions do
            defaults([:create, :read])
          end

          gen_api do
            service "test"

            action :non_existent_action do
              request_type "non_existent"
            end
          end
        end
      end
    end

    test "accepts valid action configurations" do
      refute_dsl_errors do
        defmodule Elixir.ValidActionResource do
          use Ash.Resource,
            domain: nil,
            extensions: [AshPhoenixGenApi.Resource]

          attributes do
            uuid_primary_key(:id)
            attribute(:name, :string)
          end

          actions do
            defaults([:create, :read])
          end

          gen_api do
            service "test"

            action :create do
              request_type "create"
            end
          end
        end
      end
    end

    test "error message includes available actions" do
      err =
        assert_dsl_error %Spark.Error.DslError{path: [:gen_api]} do
          defmodule Elixir.BadActionResource do
            use Ash.Resource,
              domain: nil,
              extensions: [AshPhoenixGenApi.Resource]

            attributes do
              uuid_primary_key(:id)
            end

            actions do
              defaults([:create, :read])
            end

            gen_api do
              service "test"

              action :bogus_action do
                request_type "bogus"
              end
            end
          end
        end

      assert err.message =~ "bogus_action"
      assert err.message =~ "Available actions"
    end
  end

  describe "request type uniqueness verification" do
    test "raises error when two actions share the same request_type" do
      assert_dsl_error %Spark.Error.DslError{path: [:gen_api]} do
        defmodule Elixir.DuplicateRequestTypeResource do
          use Ash.Resource,
            domain: nil,
            extensions: [AshPhoenixGenApi.Resource]

          attributes do
            uuid_primary_key(:id)
            attribute(:name, :string)
          end

          actions do
            defaults([:create, :read])
          end

          gen_api do
            service "test"

            action :create do
              request_type "shared_type"
            end

            action :read do
              request_type "shared_type"
            end
          end
        end
      end
    end

    test "accepts unique request types" do
      refute_dsl_errors do
        defmodule Elixir.UniqueRequestTypeResource do
          use Ash.Resource,
            domain: nil,
            extensions: [AshPhoenixGenApi.Resource]

          attributes do
            uuid_primary_key(:id)
          end

          actions do
            defaults([:create, :read])
          end

          gen_api do
            service "test"

            action :create do
              request_type "create_thing"
            end

            action :read do
              request_type "read_thing"
            end
          end
        end
      end
    end
  end

  describe "MFA configuration verification" do
    test "raises error when MFA has invalid structure" do
      assert_dsl_error %Spark.Error.DslError{path: [:gen_api]} do
        defmodule Elixir.InvalidMfaResource do
          use Ash.Resource,
            domain: nil,
            extensions: [AshPhoenixGenApi.Resource]

          attributes do
            uuid_primary_key(:id)
          end

          actions do
            defaults([:create])
          end

          gen_api do
            service "test"

            action :create do
              request_type "create"
              mfa {"not_a_module", "not_a_function", "not_a_list"}
            end
          end
        end
      end
    end

    test "accepts valid MFA tuple" do
      refute_dsl_errors do
        defmodule Elixir.ValidMfaResource do
          use Ash.Resource,
            domain: nil,
            extensions: [AshPhoenixGenApi.Resource]

          attributes do
            uuid_primary_key(:id)
          end

          actions do
            defaults([:create])
          end

          gen_api do
            service "test"

            action :create do
              request_type "create"
              mfa {SomeModule, :some_function, []}
            end
          end
        end
      end
    end
  end

  describe "permission arg existence verification" do
    test "raises error when check_permission references non-existent arg" do
      assert_dsl_error %Spark.Error.DslError{path: [:gen_api]} do
        defmodule Elixir.BadPermissionArgResource do
          use Ash.Resource,
            domain: nil,
            extensions: [AshPhoenixGenApi.Resource]

          attributes do
            uuid_primary_key(:id)
            attribute(:name, :string)
          end

          actions do
            defaults([:create])
          end

          gen_api do
            service "test"

            action :create do
              request_type "create"
              check_permission {:arg, "nonexistent_arg"}
            end
          end
        end
      end
    end

    test "accepts check_permission with existing arg" do
      refute_dsl_errors do
        defmodule Elixir.GoodPermissionArgResource do
          use Ash.Resource,
            domain: nil,
            extensions: [AshPhoenixGenApi.Resource]

          attributes do
            uuid_primary_key(:id)
            attribute(:user_id, :string)
          end

          actions do
            create :create do
              accept [:user_id]
            end
          end

          gen_api do
            service "test"

            action :create do
              request_type "create"
              check_permission {:arg, "user_id"}
            end
          end
        end
      end
    end
  end

  describe "MFA entity verification" do
    test "raises error when MFA entity has invalid MFA tuple" do
      assert_dsl_error %Spark.Error.DslError{path: [:gen_api]} do
        defmodule Elixir.MfaInvalidTupleResource do
          use Ash.Resource,
            domain: nil,
            extensions: [AshPhoenixGenApi.Resource]

          attributes do
            uuid_primary_key(:id)
          end

          actions do
            defaults([:create])
          end

          gen_api do
            service "test"

            mfa :my_endpoint do
              request_type "my_endpoint"
              mfa {"not_a_module", :func, []}
              arg_types %{"name" => :string}
            end
          end
        end
      end
    end

    test "accepts valid MFA entity configuration" do
      refute_dsl_errors do
        defmodule Elixir.ValidMfaEntityResource do
          use Ash.Resource,
            domain: nil,
            extensions: [AshPhoenixGenApi.Resource]

          attributes do
            uuid_primary_key(:id)
          end

          actions do
            defaults([:create])
          end

          gen_api do
            service "test"

            mfa :my_endpoint do
              request_type "my_endpoint"
              mfa {SomeModule, :some_function, []}
              arg_types %{"name" => :string}
            end
          end
        end
      end
    end
  end

  describe "arg consistency verification" do
    test "raises error when arg_orders has keys missing from arg_types" do
      assert_dsl_error %Spark.Error.DslError{path: [:gen_api]} do
        defmodule Elixir.ArgConsistencyResource do
          use Ash.Resource,
            domain: nil,
            extensions: [AshPhoenixGenApi.Resource]

          attributes do
            uuid_primary_key(:id)
          end

          actions do
            defaults([:create])
          end

          gen_api do
            service "test"

            action :create do
              request_type "create"
              arg_types %{"name" => :string}
              arg_orders ["name", "extra_field"]
            end
          end
        end
      end
    end

    test "accepts matching arg_types and arg_orders" do
      refute_dsl_errors do
        defmodule Elixir.ArgMatchResource do
          use Ash.Resource,
            domain: nil,
            extensions: [AshPhoenixGenApi.Resource]

          attributes do
            uuid_primary_key(:id)
          end

          actions do
            defaults([:create])
          end

          gen_api do
            service "test"

            action :create do
              request_type "create"
              arg_types %{"name" => :string, "age" => :num}
              arg_orders ["name", "age"]
            end
          end
        end
      end
    end
  end

  describe "permission callback verification" do
    test "raises error when action has invalid permission_callback" do
      assert_dsl_error %Spark.Error.DslError{path: [:gen_api]} do
        defmodule Elixir.BadPermissionCallbackResource do
          use Ash.Resource,
            domain: nil,
            extensions: [AshPhoenixGenApi.Resource]

          attributes do
            uuid_primary_key(:id)
          end

          actions do
            defaults([:create])
          end

          gen_api do
            service "test"

            action :create do
              request_type "create"
              permission_callback({"not_a_module", "not_a_func", "not_a_list"})
            end
          end
        end
      end
    end

    test "accepts valid permission_callback" do
      refute_dsl_errors do
        defmodule Elixir.ValidPermissionCallbackResource do
          use Ash.Resource,
            domain: nil,
            extensions: [AshPhoenixGenApi.Resource]

          attributes do
            uuid_primary_key(:id)
          end

          actions do
            defaults([:create])
          end

          gen_api do
            service "test"

            action :create do
              request_type "create"
              permission_callback({MyApp.Permissions, :check, []})
            end
          end
        end
      end
    end
  end

  describe "source annotations in error messages" do
    test "error includes source location for non-existent action" do
      err =
        assert_dsl_error %Spark.Error.DslError{path: [:gen_api]} do
          defmodule Elixir.AnnoTestBadAction do
            use Ash.Resource,
              domain: nil,
              extensions: [AshPhoenixGenApi.Resource]

            attributes do
              uuid_primary_key(:id)
            end

            actions do
              defaults([:create])
            end

            gen_api do
              service "test"

              action :does_not_exist do
                request_type "bad"
              end
            end
          end
        end

      # When debug_info is enabled, the error message should include source info
      assert is_binary(err.message)
    end
  end

  describe "multiple errors" do
    test "collects all errors from a single resource" do
      errors =
        dsl_errors do
          defmodule Elixir.MultiErrorResource do
            use Ash.Resource,
              domain: nil,
              extensions: [AshPhoenixGenApi.Resource]

            attributes do
              uuid_primary_key(:id)
            end

            actions do
              defaults([:create])
            end

            gen_api do
              service "test"

              action :nonexistent_one do
                request_type "one"
              end

              action :nonexistent_two do
                request_type "two"
              end
            end
          end
        end

      assert [{Elixir.MultiErrorResource, error_list}] = errors
      refute error_list == []
      # Both nonexistent actions should be reported in the error message
      assert Enum.any?(error_list, &(&1.message =~ "nonexistent_one"))
      assert Enum.any?(error_list, &(&1.message =~ "nonexistent_two"))
    end
  end

  # ---------------------------------------------------------------------------
  # Remaining validation branches
  # ---------------------------------------------------------------------------

  describe "mfa required field verification" do
    # The entity schema itself (required: true) rejects these at build time,
    # before verifiers run — assert Spark's own build error.
    test "schema rejects an mfa entity without required fields" do
      assert_raise Spark.Error.DslError, ~r/arg_types/, fn ->
        defmodule Elixir.MfaMissingFieldsResource do
          use Ash.Resource,
            domain: nil,
            extensions: [AshPhoenixGenApi.Resource]

          attributes do
            uuid_primary_key(:id)
          end

          actions do
            defaults([:create])
          end

          gen_api do
            service "test"

            mfa :bare_endpoint do
              mfa({SomeEndpoint, :call, []})
            end
          end
        end
      end
    end
  end

  describe "arg_orders without arg_types" do
    test "errors for action entities" do
      assert_dsl_error %Spark.Error.DslError{path: [:gen_api]} do
        defmodule Elixir.ActionOrdersOnlyResource do
          use Ash.Resource,
            domain: nil,
            extensions: [AshPhoenixGenApi.Resource]

          attributes do
            uuid_primary_key(:id)
          end

          actions do
            defaults([:create])
          end

          gen_api do
            service "test"

            action :create do
              request_type "create"
              arg_orders(["id"])
            end
          end
        end
      end
    end

    test "errors for mfa entities with empty arg_types map" do
      assert_dsl_error %Spark.Error.DslError{path: [:gen_api]} do
        defmodule Elixir.MfaOrdersOnlyResource do
          use Ash.Resource,
            domain: nil,
            extensions: [AshPhoenixGenApi.Resource]

          attributes do
            uuid_primary_key(:id)
          end

          actions do
            defaults([:create])
          end

          gen_api do
            service "test"

            mfa :orders_only do
              request_type "orders_only"
              mfa({SomeEndpoint, :call, []})
              arg_types(%{})
              arg_orders(["a", "b"])
            end
          end
        end
      end
    end
  end

  describe "arg key mismatch between arg_types and arg_orders" do
    test "reports keys missing from arg_orders" do
      assert_dsl_error %Spark.Error.DslError{path: [:gen_api]} do
        defmodule Elixir.ArgKeysMismatchResource do
          use Ash.Resource,
            domain: nil,
            extensions: [AshPhoenixGenApi.Resource]

          attributes do
            uuid_primary_key(:id)
          end

          actions do
            defaults([:create])
          end

          gen_api do
            service "test"

            action :create do
              request_type "create"
              arg_types(%{"id" => :uuid, "name" => :string})
              arg_orders(["id"])
            end
          end
        end
      end
    end
  end

  describe "mfa check_permission arg not present in arg_types" do
    test "raises permission configuration error" do
      assert_dsl_error %Spark.Error.DslError{path: [:gen_api]} do
        defmodule Elixir.MfaPermArgMissingResource do
          use Ash.Resource,
            domain: nil,
            extensions: [AshPhoenixGenApi.Resource]

          attributes do
            uuid_primary_key(:id)
          end

          actions do
            defaults([:create])
          end

          gen_api do
            service "test"

            mfa :perm_checked do
              request_type "perm_checked"
              mfa({SomeEndpoint, :call, []})
              arg_types(%{"token" => :string})
              check_permission({:arg, "missing_arg"})
            end
          end
        end
      end
    end
  end
end
