defmodule AshPhoenixGenApi.Verifiers.VerifyDomainConfig do
  @moduledoc """
  Verifier for the `gen_api` section of `AshPhoenixGenApi.Domain`.

  This verifier performs compile-time validation of the PhoenixGenApi domain-level
  configuration. It checks:

  1. **Supporter module name** — The `supporter_module` must be a valid Elixir
     module name (atom).

  2. **Resource service consistency** — All resources in the domain that have the
     `AshPhoenixGenApi.Resource` extension must also have a `service` configured
     in their `gen_api` section. If a resource doesn't have its own `service`,
     the domain's `service` will be used as a fallback, so the domain must have
     one in that case.

  3. **Request type uniqueness across resources** — No two resources in the
     domain may expose the same `request_type` string. This prevents routing
     conflicts on the gateway node.

  4. **Push nodes configuration** — When `push_nodes` is configured, validates
     that it is either a list of atom node names, an MFA tuple
     `{module, function, args}`, `:local`, or `nil`. Lists must contain only
     atoms, and MFA tuples must have the correct structure.

  5. **Permission callback configuration** — When `permission_callback` is
     configured, validates that it is either a valid MFA tuple
     `{module, function, args}` or `nil`. MFA tuples must have the correct
     structure (module and function must be atoms, args must be a list).

  ## Error Messages

  The verifier raises `Spark.Error.DslError` with descriptive messages
  and the path to the offending configuration.
  """

  use Spark.Dsl.Verifier

  alias Ash.Domain.Info, as: DomainInfo
  alias Ash.Resource.Info, as: ResourceAshInfo
  alias AshPhoenixGenApi.Domain.Info
  alias AshPhoenixGenApi.Resource.ActionConfig, as: ActionConfig
  alias AshPhoenixGenApi.Resource.Info, as: ResourceInfo
  alias AshPhoenixGenApi.Utils
  alias Spark.Dsl.Extension
  alias Spark.Dsl.Verifier, as: SparkVerifier
  alias Spark.Error.DslError, as: SparkDslError

  @impl true
  def verify(dsl_state) do
    domain = SparkVerifier.get_persisted(dsl_state, :module)

    # Check if gen_api is configured on this domain
    supporter_module = Utils.extract_opt(Info.gen_api_supporter_module(dsl_state), nil)

    if is_nil(supporter_module) do
      # No gen_api configured — nothing to verify
      :ok
    else
      with :ok <- verify_supporter_module(domain, supporter_module),
           :ok <- verify_push_nodes(dsl_state, domain),
           :ok <- verify_permission_callback(dsl_state, domain),
           :ok <- verify_resource_services(dsl_state, domain) do
        verify_request_type_uniqueness(dsl_state, domain)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Supporter module verification
  # ---------------------------------------------------------------------------

  defp verify_supporter_module(domain, supporter_module) do
    cond do
      not is_atom(supporter_module) ->
        raise SparkDslError,
          module: domain,
          path: [:gen_api, :supporter_module],
          message: """
          The supporter_module must be a valid module name (atom).

          Got: #{inspect(supporter_module)}

          Example: supporter_module MyApp.Chat.GenApiSupporter
          """

      # Check that the module name is a reasonable Elixir module name
      # (starts with uppercase letter when converted to string)
      not valid_module_name?(supporter_module) ->
        raise SparkDslError,
          module: domain,
          path: [:gen_api, :supporter_module],
          message: """
          The supporter_module must be a valid Elixir module name.

          Got: #{inspect(supporter_module)}

          Module names should be dot-separated atoms starting with an uppercase letter,
          e.g.: MyApp.Chat.GenApiSupporter
          """

      true ->
        :ok
    end
  end

  defp valid_module_name?(module) when is_atom(module) do
    module_string = Atom.to_string(module)

    # Elixir module atoms that are valid start with "Elixir." and have
    # segments that start with uppercase letters
    # Also accept simple atoms like :my_module for edge cases
    case module_string do
      "Elixir." <> rest ->
        rest
        |> String.split(".")
        |> Enum.all?(fn segment ->
          segment != "" and String.match?(segment, ~r/^[A-Z]/)
        end)

      _ ->
        # Simple atom — accept it as a valid module name
        # (e.g., :MySupporter or MySupporter)
        true
    end
  end

  # ---------------------------------------------------------------------------
  # Push nodes verification
  # ---------------------------------------------------------------------------

  defp verify_push_nodes(dsl_state, domain) do
    push_nodes = Utils.extract_opt(Info.gen_api_push_nodes(dsl_state), nil)
    verify_push_nodes_value(push_nodes, domain)
  end

  defp verify_push_nodes_value(nil, _domain), do: :ok
  defp verify_push_nodes_value(:local, _domain), do: :ok

  defp verify_push_nodes_value(nodes, domain) when is_list(nodes) do
    invalid_elements =
      nodes
      |> Enum.with_index()
      |> Enum.filter(fn {elem, _idx} -> not is_atom(elem) end)
      |> Enum.map(fn {elem, idx} ->
        "  Element at index #{idx}: #{inspect(elem)} (expected an atom)"
      end)

    if invalid_elements == [] do
      :ok
    else
      raise SparkDslError,
        module: domain,
        path: [:gen_api, :push_nodes],
        message: """
        All elements in push_nodes list must be atoms (node names).

        Invalid elements:
        #{Enum.join(invalid_elements, "\n")}

        Example: push_nodes [:"gateway1@host", :"gateway2@host"]
        """
    end
  end

  defp verify_push_nodes_value({mod, fun, args}, domain) do
    if Utils.valid_mfa?({mod, fun, args}) do
      :ok
    else
      errors = Utils.mfa_errors({mod, fun, args})

      raise SparkDslError,
        module: domain,
        path: [:gen_api, :push_nodes],
        message: """
        Invalid MFA tuple for push_nodes.

        Errors:
        #{Enum.join(errors, "\n")}

        Expected format: {Module, :function, [arg1, arg2, ...]}
        Example: push_nodes {ClusterHelper, :get_gateway_nodes, []}
        """
    end
  end

  defp verify_push_nodes_value(other, domain) do
    raise SparkDslError,
      module: domain,
      path: [:gen_api, :push_nodes],
      message: """
      Invalid push_nodes configuration.

      Got: #{inspect(other)}

      push_nodes must be one of:
      - A list of node atoms: [:"gateway1@host", :"gateway2@host"]
      - An MFA tuple: {ClusterHelper, :get_gateway_nodes, []}
      - `:local` for the local node
      - `nil` for no push nodes (default)
      """
  end

  # ---------------------------------------------------------------------------
  # Permission callback verification
  # ---------------------------------------------------------------------------

  defp verify_permission_callback(dsl_state, domain) do
    permission_callback = Utils.extract_opt(Info.gen_api_permission_callback(dsl_state), nil)
    verify_permission_callback_value(permission_callback, domain)
  end

  defp verify_permission_callback_value(nil, _domain), do: :ok

  defp verify_permission_callback_value({mod, fun, args}, domain) do
    if Utils.valid_mfa?({mod, fun, args}) do
      :ok
    else
      errors = Utils.mfa_errors({mod, fun, args})

      raise SparkDslError,
        module: domain,
        path: [:gen_api, :permission_callback],
        message: """
        Invalid MFA tuple for permission_callback.

        Errors:
        #{Enum.join(errors, "\n")}

        Expected format: {Module, :function, [arg1, arg2, ...]}
        Example: permission_callback {MyApp.Permissions, :check, []}
        """
    end
  end

  defp verify_permission_callback_value(other, domain) do
    raise SparkDslError,
      module: domain,
      path: [:gen_api, :permission_callback],
      message: """
      Invalid permission_callback configuration.

      Got: #{inspect(other)}

      permission_callback must be one of:
      - An MFA tuple: {Module, :function, []}
      - `nil` for no callback (default)
      """
  end

  # ---------------------------------------------------------------------------
  # Resource service verification
  # ---------------------------------------------------------------------------

  defp verify_resource_services(dsl_state, domain) do
    domain_service = Utils.extract_opt(Info.gen_api_service(dsl_state), nil)

    resources_with_gen_api =
      domain
      |> DomainInfo.resources()
      |> Enum.filter(fn resource ->
        extensions = ResourceAshInfo.extensions(resource)
        Enum.any?(extensions, &(&1 == AshPhoenixGenApi.Resource))
      end)

    # Check that each resource with gen_api has a service configured,
    # either on the resource or on the domain
    errors =
      resources_with_gen_api
      |> Enum.flat_map(fn resource ->
        resource_service = Utils.extract_opt(ResourceInfo.gen_api_service(resource), nil)

        if is_nil(resource_service) and is_nil(domain_service) do
          # Try to find the resource's gen_api section annotation for better debugging
          resource_anno = get_resource_gen_api_anno(resource)
          source_info = Utils.format_source_location(resource_anno)

          [
            "No service configured for `#{inspect(resource)}`." <>
              source_info <>
              "\n" <>
              "Set `service` in the resource's `gen_api` block, e.g.:\n" <>
              "  gen_api do\n" <>
              "    service \"my_service\"\n" <>
              "  end\n" <>
              "Or set it at the domain level to apply to all resources:\n" <>
              "  gen_api do\n" <>
              "    service \"my_service\"\n" <>
              "  end"
          ]
        else
          []
        end
      end)

    if errors == [] do
      :ok
    else
      raise SparkDslError,
        module: domain,
        path: [:gen_api],
        message: """
        Service configuration errors:

        #{Enum.join(errors, "\n\n")}
        """
    end
  end

  # ---------------------------------------------------------------------------
  # Request type uniqueness verification across resources
  # ---------------------------------------------------------------------------

  defp verify_request_type_uniqueness(_dsl_state, domain) do
    resources_with_gen_api =
      domain
      |> DomainInfo.resources()
      |> Enum.filter(fn resource ->
        extensions = ResourceAshInfo.extensions(resource)
        Enum.any?(extensions, &(&1 == AshPhoenixGenApi.Resource))
      end)

    # Collect all request_types across all resources
    # {request_type, resource, action_name}
    all_request_types =
      resources_with_gen_api
      |> Enum.flat_map(fn resource ->
        resource
        |> ResourceInfo.enabled_actions()
        |> Enum.map(fn action_config ->
          request_type =
            ActionConfig.effective_request_type(action_config)

          {request_type, resource, action_config.name}
        end)
      end)

    # Find duplicates
    duplicates =
      all_request_types
      |> Enum.group_by(fn {request_type, _resource, _action_name} -> request_type end)
      |> Enum.filter(fn {_request_type, occurrences} -> length(occurrences) > 1 end)
      |> Enum.map(fn {request_type, occurrences} ->
        details =
          Enum.map_join(occurrences, "\n", fn {_rt, resource, action_name} ->
            "  - `#{inspect(resource)}` action `:#{action_name}`"
          end)

        "The request_type `#{request_type}` is used by multiple actions:\n#{details}\n" <>
          "Each request_type must be unique across all resources in the domain."
      end)

    if duplicates == [] do
      :ok
    else
      raise SparkDslError,
        module: domain,
        path: [:gen_api],
        message: """
        Duplicate request types found across resources:

        #{Enum.join(duplicates, "\n\n")}
        """
    end
  end

  # ---------------------------------------------------------------------------
  # Source annotation helpers
  # ---------------------------------------------------------------------------

  @doc false
  defp get_resource_gen_api_anno(resource) do
    dsl_state = resource.spark_dsl_config()
    Extension.get_section_anno(dsl_state, [:gen_api])
  rescue
    _ -> nil
  end
end
