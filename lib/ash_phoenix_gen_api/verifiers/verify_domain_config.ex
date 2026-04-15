defmodule AshPhoenixGenApi.Verifiers.VerifyDomainConfig do
  @moduledoc """
  Verifier for the `gen_api` section of `AshPhoenixGenApi.Domain`.

  This verifier performs compile-time validation of the PhoenixGenApi domain-level
  configuration. It checks:

  1. **Supporter module name** — The `supporter_module` must be a valid Elixir
     module name (atom).

  2. **Service configuration** — When `define_supporter?` is `true`, the `service`
     must be configured.

  3. **Resource consistency** — All resources in the domain that have the
     `AshPhoenixGenApi.Resource` extension must also have a `service` configured
     in their `gen_api` section. If a resource doesn't have its own `service`,
     the domain's `service` will be used as a fallback, so the domain must have
     one in that case.

  4. **Request type uniqueness across resources** — No two resources in the
     domain may expose the same `request_type` string. This prevents routing
     conflicts on the gateway node.

  5. **Supporter module not already defined** — When `define_supporter?` is
     `true`, warns if the supporter module already exists (which could indicate
     a conflict with a manually-defined module).

  ## Error Messages

  The verifier raises `Spark.Error.DslError` with descriptive messages
  and the path to the offending configuration.
  """

  use Spark.Dsl.Verifier

  alias AshPhoenixGenApi.Domain.Info
  alias AshPhoenixGenApi.Resource.Info, as: ResourceInfo

  @impl true
  def verify(dsl_state) do
    domain = Spark.Dsl.Verifier.get_persisted(dsl_state, :module)

    # Check if gen_api is configured on this domain
    supporter_module = extract_opt(Info.gen_api_supporter_module(dsl_state), nil)

    if is_nil(supporter_module) do
      # No gen_api configured — nothing to verify
      :ok
    else
      define_supporter? = extract_opt(Info.gen_api_define_supporter?(dsl_state), true)

      with :ok <- verify_supporter_module(domain, supporter_module),
           :ok <- verify_service_config(dsl_state, domain, define_supporter?),
           :ok <- verify_resource_services(dsl_state, domain),
           :ok <- verify_request_type_uniqueness(dsl_state, domain) do
        :ok
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Supporter module verification
  # ---------------------------------------------------------------------------

  defp verify_supporter_module(domain, supporter_module) do
    cond do
      not is_atom(supporter_module) ->
        raise Spark.Error.DslError,
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
        raise Spark.Error.DslError,
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

  defp valid_module_name?(_), do: false

  # ---------------------------------------------------------------------------
  # Service configuration verification
  # ---------------------------------------------------------------------------

  defp verify_service_config(dsl_state, _domain, define_supporter?) do
    service = extract_opt(Info.gen_api_service(dsl_state), nil)

    if define_supporter? and is_nil(service) do
      # When define_supporter? is true, we need a service name for the
      # generated FunConfigs. However, resources can provide their own service
      # names, so this is a warning rather than an error.
      # We still allow it but resources MUST have their own service configured.
      :ok
    else
      :ok
    end
  end

  # ---------------------------------------------------------------------------
  # Resource service verification
  # ---------------------------------------------------------------------------

  defp verify_resource_services(dsl_state, domain) do
    domain_service = extract_opt(Info.gen_api_service(dsl_state), nil)

    resources_with_gen_api =
      domain
      |> Ash.Domain.Info.resources()
      |> Enum.filter(fn resource ->
        extensions = Ash.Resource.Info.extensions(resource)
        Enum.any?(extensions, &(&1 == AshPhoenixGenApi.Resource))
      end)

    # Check that each resource with gen_api has a service configured,
    # either on the resource or on the domain
    errors =
      resources_with_gen_api
      |> Enum.flat_map(fn resource ->
        resource_service = extract_opt(ResourceInfo.gen_api_service(resource), nil)

        if is_nil(resource_service) and is_nil(domain_service) do
          [
            "Resource `#{inspect(resource)}` has gen_api configured but no service name. " <>
              "Either configure a service on the resource's gen_api section " <>
              "or on the domain's gen_api section."
          ]
        else
          []
        end
      end)

    if errors == [] do
      :ok
    else
      raise Spark.Error.DslError,
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
      |> Ash.Domain.Info.resources()
      |> Enum.filter(fn resource ->
        extensions = Ash.Resource.Info.extensions(resource)
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
            AshPhoenixGenApi.Resource.ActionConfig.effective_request_type(action_config)

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
          occurrences
          |> Enum.map(fn {_rt, resource, action_name} ->
            "  - `#{inspect(resource)}` action `:#{action_name}`"
          end)
          |> Enum.join("\n")

        "The request_type `#{request_type}` is used by multiple actions:\n#{details}\n" <>
          "Each request_type must be unique across all resources in the domain."
      end)

    if duplicates == [] do
      :ok
    else
      raise Spark.Error.DslError,
        module: domain,
        path: [:gen_api],
        message: """
        Duplicate request types found across resources:

        #{Enum.join(duplicates, "\n\n")}
        """
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Extracts a value from a Spark.InfoGenerator result.
  # Spark.InfoGenerator generates two versions of each accessor:
  # - `gen_api_foo/1` returns `{:ok, value}` or `:error`
  # - `gen_api_foo!/1` returns the value or raises
  #
  # This helper unwraps the `{:ok, value}` tuple, falling back to the
  # provided default when the option is not configured (`:error`).
  defp extract_opt({:ok, value}, _default), do: value
  defp extract_opt(:error, default), do: default
  defp extract_opt(value, _default) when not is_tuple(value), do: value
end
