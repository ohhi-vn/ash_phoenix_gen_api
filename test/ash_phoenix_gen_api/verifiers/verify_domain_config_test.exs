defmodule AshPhoenixGenApi.Verifiers.VerifyDomainConfigTest do
  use ExUnit.Case, async: true

  import Spark.Test

  describe "service configuration verification" do
    test "raises actionable error when resource has no service and domain has no service" do
      err =
        assert_dsl_error %Spark.Error.DslError{path: [:gen_api]} do
          defmodule Elixir.NoServiceDomain do
            use Ash.Domain,
              extensions: [AshPhoenixGenApi.Domain]

            gen_api do
              supporter_module Elixir.NoServiceDomain.Supporter
            end

            resources do
              resource(AshPhoenixGenApi.VerifierTestResources.NoServiceResource)
            end
          end
        end

      assert err.message =~ "No service configured for"
      assert err.message =~ "Set `service` in the resource's `gen_api` block"
      assert err.message =~ "Or set it at the domain level"
    end

    test "accepts domain with service configured" do
      refute_dsl_errors do
        defmodule Elixir.DomainWithService do
          use Ash.Domain,
            extensions: [AshPhoenixGenApi.Domain]

          gen_api do
            service "my_service"
            supporter_module Elixir.DomainWithService.Supporter
          end

          resources do
          end
        end
      end
    end

    test "error message includes source location for resource missing service" do
      err =
        assert_dsl_error %Spark.Error.DslError{path: [:gen_api]} do
          defmodule Elixir.NoServiceAnnoDomain do
            use Ash.Domain,
              extensions: [AshPhoenixGenApi.Domain]

            gen_api do
              supporter_module Elixir.NoServiceAnnoDomain.Supporter
            end

            resources do
              resource(AshPhoenixGenApi.VerifierTestResources.NoServiceAnnoResource)
            end
          end
        end

      assert is_binary(err.message)
    end
  end

  describe "request type uniqueness across resources" do
    test "raises error when two resources share the same request_type" do
      assert_dsl_error %Spark.Error.DslError{path: [:gen_api]} do
        defmodule Elixir.DuplicateRequestTypeDomain do
          use Ash.Domain,
            extensions: [AshPhoenixGenApi.Domain]

          gen_api do
            service "test_service"
            supporter_module Elixir.DuplicateRequestTypeDomain.Supporter
          end

          resources do
            resource(AshPhoenixGenApi.VerifierTestResources.ResourceA)
            resource(AshPhoenixGenApi.VerifierTestResources.ResourceB)
          end
        end
      end
    end

    test "accepts unique request types across resources" do
      refute_dsl_errors do
        defmodule Elixir.UniqueRequestTypeDomain do
          use Ash.Domain,
            extensions: [AshPhoenixGenApi.Domain]

          gen_api do
            service "test_service"
            supporter_module Elixir.UniqueRequestTypeDomain.Supporter
          end

          resources do
            resource(AshPhoenixGenApi.VerifierTestResources.UniqueResourceA)
            resource(AshPhoenixGenApi.VerifierTestResources.UniqueResourceB)
          end
        end
      end
    end
  end

  describe "push_nodes verification" do
    test "accepts list of atoms for push_nodes" do
      refute_dsl_errors do
        defmodule Elixir.PushNodesListDomain do
          use Ash.Domain,
            extensions: [AshPhoenixGenApi.Domain]

          gen_api do
            service "test_service"
            supporter_module Elixir.PushNodesListDomain.Supporter
            push_nodes([:gateway1@host, :gateway2@host])
          end

          resources do
          end
        end
      end
    end

    test "accepts MFA tuple for push_nodes" do
      refute_dsl_errors do
        defmodule Elixir.PushNodesMfaDomain do
          use Ash.Domain,
            extensions: [AshPhoenixGenApi.Domain]

          gen_api do
            service "test_service"
            supporter_module Elixir.PushNodesMfaDomain.Supporter
            push_nodes({ClusterHelper, :get_gateway_nodes, []})
          end

          resources do
          end
        end
      end
    end

    test "accepts :local for push_nodes" do
      refute_dsl_errors do
        defmodule Elixir.PushNodesLocalDomain do
          use Ash.Domain,
            extensions: [AshPhoenixGenApi.Domain]

          gen_api do
            service "test_service"
            supporter_module Elixir.PushNodesLocalDomain.Supporter
            push_nodes(:local)
          end

          resources do
          end
        end
      end
    end

    test "raises error for invalid push_nodes type" do
      assert_dsl_error %Spark.Error.DslError{path: [:gen_api, :push_nodes]} do
        defmodule Elixir.InvalidPushNodesDomain do
          use Ash.Domain,
            extensions: [AshPhoenixGenApi.Domain]

          gen_api do
            service "test_service"
            supporter_module Elixir.InvalidPushNodesDomain.Supporter
            push_nodes("not_valid")
          end

          resources do
          end
        end
      end
    end

    test "raises error when push_nodes list contains non-atoms" do
      assert_dsl_error %Spark.Error.DslError{path: [:gen_api, :push_nodes]} do
        defmodule Elixir.BadPushNodesListDomain do
          use Ash.Domain,
            extensions: [AshPhoenixGenApi.Domain]

          gen_api do
            service "test_service"
            supporter_module Elixir.BadPushNodesListDomain.Supporter
            push_nodes([:valid@host, "not_an_atom"])
          end

          resources do
          end
        end
      end
    end

    test "raises error for invalid MFA tuple in push_nodes" do
      assert_dsl_error %Spark.Error.DslError{path: [:gen_api, :push_nodes]} do
        defmodule Elixir.BadMfaPushNodesDomain do
          use Ash.Domain,
            extensions: [AshPhoenixGenApi.Domain]

          gen_api do
            service "test_service"
            supporter_module Elixir.BadMfaPushNodesDomain.Supporter
            push_nodes({"not_a_module", "not_a_func", "not_a_list"})
          end

          resources do
          end
        end
      end
    end
  end

  describe "permission_callback verification" do
    test "accepts valid MFA permission_callback" do
      refute_dsl_errors do
        defmodule Elixir.ValidPermissionCallbackDomain do
          use Ash.Domain,
            extensions: [AshPhoenixGenApi.Domain]

          gen_api do
            service "test_service"
            supporter_module Elixir.ValidPermissionCallbackDomain.Supporter
            permission_callback({MyApp.Permissions, :check, []})
          end

          resources do
          end
        end
      end
    end

    test "accepts nil permission_callback" do
      refute_dsl_errors do
        defmodule Elixir.NilPermissionCallbackDomain do
          use Ash.Domain,
            extensions: [AshPhoenixGenApi.Domain]

          gen_api do
            service "test_service"
            supporter_module Elixir.NilPermissionCallbackDomain.Supporter
            permission_callback(nil)
          end

          resources do
          end
        end
      end
    end

    test "raises error for invalid permission_callback" do
      assert_dsl_error %Spark.Error.DslError{path: [:gen_api, :permission_callback]} do
        defmodule Elixir.InvalidPermissionCallbackDomain do
          use Ash.Domain,
            extensions: [AshPhoenixGenApi.Domain]

          gen_api do
            service "test_service"
            supporter_module Elixir.InvalidPermissionCallbackDomain.Supporter
            permission_callback({"not_a_module", "not_a_func", "not_a_list"})
          end

          resources do
          end
        end
      end
    end
  end

  describe "supporter_module verification" do
    test "raises error for non-atom supporter_module" do
      assert_dsl_error %Spark.Error.DslError{path: [:gen_api, :supporter_module]} do
        defmodule Elixir.BadSupporterModuleDomain do
          use Ash.Domain,
            extensions: [AshPhoenixGenApi.Domain]

          gen_api do
            service "test_service"
            supporter_module "not_an_atom"
          end

          resources do
          end
        end
      end
    end

    test "accepts valid supporter_module name" do
      refute_dsl_errors do
        defmodule Elixir.ValidSupporterModuleDomain do
          use Ash.Domain,
            extensions: [AshPhoenixGenApi.Domain]

          gen_api do
            service "test_service"
            supporter_module Elixir.ValidSupporterModuleDomain.Supporter
          end

          resources do
          end
        end
      end
    end
  end

  describe "happy path" do
    test "valid full domain configuration compiles without errors" do
      refute_dsl_errors do
        defmodule Elixir.FullValidDomain do
          use Ash.Domain,
            extensions: [AshPhoenixGenApi.Domain]

          gen_api do
            service "chat"
            nodes {ClusterHelper, :get_nodes, [:chat]}
            choose_node_mode :random
            timeout 5_000
            response_type :async
            request_info true
            version "1.0.0"
            supporter_module Elixir.FullValidDomain.Supporter
            push_nodes([:gateway@host])
          end

          resources do
          end
        end
      end
    end

    test "domain without gen_api section produces no errors" do
      refute_dsl_errors do
        defmodule Elixir.NoGenApiDomain do
          use Ash.Domain,
            extensions: [AshPhoenixGenApi.Domain]

          resources do
          end
        end
      end
    end
  end

  describe "multiple errors" do
    test "collects all errors from a single domain" do
      errors =
        dsl_errors do
          defmodule Elixir.MultiErrorDomain do
            use Ash.Domain,
              extensions: [AshPhoenixGenApi.Domain]

            gen_api do
              service "test_service"
              supporter_module Elixir.MultiErrorDomain.Supporter
              push_nodes("invalid")
            end

            resources do
            end
          end
        end

      assert [{Elixir.MultiErrorDomain, error_list}] = errors
      refute error_list == []
    end
  end

  describe "permission callback verification" do
    test "raises for a non-MFA, non-nil permission_callback" do
      assert_dsl_error %Spark.Error.DslError{path: [:gen_api, :permission_callback]} do
        defmodule Elixir.BadPermCallbackDomain do
          use Ash.Domain,
            extensions: [AshPhoenixGenApi.Domain]

          gen_api do
            service "bad_perm"
            supporter_module Elixir.BadPermCallbackSupporter
            permission_callback "not_an_mfa"
          end

          resources do
          end
        end
      end
    end
  end
end
