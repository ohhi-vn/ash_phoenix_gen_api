defmodule AshPhoenixGenApi.Verifiers.VerifyActionConfigs do
  @moduledoc """
  Verifier for the `gen_api` section of `AshPhoenixGenApi.Resource`.

  This verifier performs compile-time validation of the PhoenixGenApi action
  configurations defined in an Ash resource's DSL. It checks:

  1. **Action existence** — Every `action` entity references an Ash action
     that actually exists on the resource.

  2. **Request type uniqueness** — No two actions in the same resource
     share the same `request_type` (either explicit or auto-derived).

  3. **Arg consistency** — When both `arg_types` and `arg_orders` are
     explicitly provided, their keys must match exactly.

  4. **Permission arg existence** — When `check_permission` is set to
     `{:arg, "arg_name"}`, the argument must exist in either the explicit
     `arg_types` or the Ash action's accepted attributes/arguments.

  5. **MFA structure** — When an explicit `mfa` is provided, it must be an
     MFA tuple `{module, function, args}` where module and function are atoms
     and args is a list. (Whether the module is loaded and the function exists
     is validated at runtime when the endpoint is invoked.)

  6. **Permission callback validity** — When `permission_callback` is
     provided, it must be a valid MFA tuple `{module, function, args}`
     where module and function are atoms and args is a list, or `nil`.

  ## Error Messages

  The verifier raises `Spark.Error.DslError` with descriptive messages
  and the path to the offending configuration, making it easy to locate
  and fix issues.
  """

  use Spark.Dsl.Verifier

  alias Ash.Resource.Info, as: ResourceAshInfo
  alias AshPhoenixGenApi.Resource.ActionConfig
  alias AshPhoenixGenApi.Resource.Info
  alias AshPhoenixGenApi.Resource.MfaConfig
  alias AshPhoenixGenApi.Utils
  alias Spark.Dsl.Verifier, as: SparkVerifier

  @impl true
  def verify(dsl_state) do
    resource = SparkVerifier.get_persisted(dsl_state, :module)
    entities = Info.gen_api(dsl_state)

    # Separate action and mfa entities by struct type
    actions = Enum.filter(entities, &match?(%ActionConfig{}, &1))
    mfas = Enum.filter(entities, &match?(%MfaConfig{}, &1))

    # Verify each config.
    # Note: required mfa fields (request_type, mfa, arg_types) are enforced by
    # the Spark entity schema itself, before verifiers run.
    with :ok <- verify_actions_exist(dsl_state, resource, actions),
         :ok <- verify_request_type_uniqueness(resource, actions, mfas),
         :ok <- verify_arg_consistency(resource, actions, mfas),
         :ok <- verify_permission_args(dsl_state, resource, actions, mfas),
         :ok <- verify_mfa_validity(resource, actions, mfas) do
      verify_permission_callbacks(resource, actions, mfas)
    end
  end

  # ---------------------------------------------------------------------------
  # Action existence verification
  # ---------------------------------------------------------------------------

  defp verify_actions_exist(dsl_state, resource, actions) do
    resource_actions = ResourceAshInfo.actions(dsl_state)

    resource_action_names =
      resource_actions
      |> Enum.map(& &1.name)
      |> MapSet.new()

    errors =
      actions
      |> Enum.reject(fn action_config ->
        MapSet.member?(resource_action_names, action_config.name)
      end)
      |> Enum.map(fn action_config ->
        location = get_entity_location(action_config)
        source_info = Utils.format_source_location(location)

        "The action `#{inspect(action_config.name)}` does not exist on " <>
          "resource `#{inspect(resource)}`. Available actions: " <>
          "#{inspect(MapSet.to_list(resource_action_names))}" <> source_info
      end)

    if errors == [] do
      :ok
    else
      raise Spark.Error.DslError,
        module: resource,
        path: [:gen_api],
        message: """
        Invalid action configurations:

        #{Enum.join(errors, "\n\n")}
        """
    end
  end

  # ---------------------------------------------------------------------------
  # Request type uniqueness verification
  # ---------------------------------------------------------------------------

  defp verify_request_type_uniqueness(resource, actions, mfas) do
    # Collect all effective request_types from both action and mfa entities
    action_request_types =
      actions
      |> Enum.map(fn action_config ->
        {ActionConfig.effective_request_type(action_config), action_config.name}
      end)

    mfa_request_types =
      mfas
      |> Enum.map(fn mfa_config ->
        {mfa_config.request_type, mfa_config.name}
      end)

    request_types = action_request_types ++ mfa_request_types

    duplicates =
      request_types
      |> Enum.group_by(fn {request_type, _name} -> request_type end)
      |> Enum.filter(fn {_request_type, occurrences} -> length(occurrences) > 1 end)
      |> Enum.map(fn {request_type, occurrences} ->
        names = Enum.map(occurrences, fn {_, name} -> name end)

        "The request_type `#{request_type}` is used by multiple endpoints: " <>
          "#{inspect(names)}. Each endpoint must have a unique request_type."
      end)

    if duplicates == [] do
      :ok
    else
      raise Spark.Error.DslError,
        module: resource,
        path: [:gen_api],
        message: """
        Duplicate request types found:

        #{Enum.join(duplicates, "\n\n")}
        """
    end
  end

  # ---------------------------------------------------------------------------
  # Arg consistency verification
  # ---------------------------------------------------------------------------

  defp verify_arg_consistency(resource, actions, mfas) do
    action_errors = check_action_arg_consistency(actions)
    mfa_errors = check_mfa_arg_consistency(mfas)
    errors = action_errors ++ mfa_errors

    if errors == [] do
      :ok
    else
      raise Spark.Error.DslError,
        module: resource,
        path: [:gen_api],
        message: """
        Argument configuration errors:

        #{Enum.join(errors, "\n\n")}
        """
    end
  end

  defp check_action_arg_consistency(actions) do
    actions
    |> Enum.flat_map(fn action_config ->
      arg_types = action_config.arg_types
      arg_orders = action_config.arg_orders

      cond do
        # Both provided — check keys match
        has_both_arg_configs?(arg_types, arg_orders) ->
          check_arg_keys_match(action_config.name, arg_types, arg_orders, "Action")

        # Only arg_types provided — arg_orders will be derived from keys, so OK
        has_only_arg_types?(arg_types) ->
          []

        # Only arg_orders provided without arg_types — can't determine types
        has_only_arg_orders?(arg_types, arg_orders) ->
          [
            "Action `#{action_config.name}`: arg_orders is provided but arg_types is not. " <>
              "Please also provide arg_types, or remove arg_orders to auto-derive both from the Ash action."
          ]

        true ->
          []
      end
    end)
  end

  defp check_mfa_arg_consistency(mfas) do
    mfas
    |> Enum.flat_map(fn mfa_config ->
      arg_types = mfa_config.arg_types
      arg_orders = mfa_config.arg_orders

      cond do
        # Both provided — check keys match
        has_both_arg_configs?(arg_types, arg_orders) ->
          check_arg_keys_match(mfa_config.name, arg_types, arg_orders, "MFA")

        # Only arg_types provided with arg_orders as :map — OK
        has_only_arg_types?(arg_types) ->
          []

        # Only arg_orders provided without arg_types — error for mfa entities
        has_only_arg_orders?(arg_types, arg_orders) ->
          [
            "MFA `#{mfa_config.name}`: arg_orders is provided but arg_types is not. " <>
              "arg_types is required for mfa entities."
          ]

        true ->
          []
      end
    end)
  end

  defp has_both_arg_configs?(arg_types, arg_orders) do
    is_map(arg_types) and map_size(arg_types) > 0 and
      is_list(arg_orders) and arg_orders != []
  end

  defp has_only_arg_types?(arg_types) do
    is_map(arg_types) and map_size(arg_types) > 0
  end

  defp has_only_arg_orders?(arg_types, arg_orders) do
    (is_nil(arg_types) or (is_map(arg_types) and map_size(arg_types) == 0)) and
      is_list(arg_orders) and arg_orders != []
  end

  defp check_arg_keys_match(name, arg_types, arg_orders, type) do
    arg_type_keys = MapSet.new(Map.keys(arg_types))
    arg_order_keys = MapSet.new(arg_orders)

    missing_in_orders = MapSet.difference(arg_type_keys, arg_order_keys)
    missing_in_types = MapSet.difference(arg_order_keys, arg_type_keys)

    errors = []

    errors =
      if MapSet.size(missing_in_orders) > 0 do
        [
          "#{type} `#{name}`: arg_types has keys " <>
            "#{inspect(MapSet.to_list(missing_in_orders))} that are missing from arg_orders"
          | errors
        ]
      else
        errors
      end

    errors =
      if MapSet.size(missing_in_types) > 0 do
        [
          "#{type} `#{name}`: arg_orders has keys " <>
            "#{inspect(MapSet.to_list(missing_in_types))} that are missing from arg_types"
          | errors
        ]
      else
        errors
      end

    errors
  end

  # ---------------------------------------------------------------------------
  # Permission arg existence verification
  # ---------------------------------------------------------------------------

  defp verify_permission_args(dsl_state, resource, actions, mfas) do
    action_errors =
      actions
      |> Enum.flat_map(fn action_config ->
        case action_config.check_permission do
          {:arg, arg_name} when is_binary(arg_name) ->
            missing_action_permission_arg?(dsl_state, action_config, arg_name)

          _ ->
            []
        end
      end)

    mfa_errors =
      mfas
      |> Enum.flat_map(fn mfa_config ->
        case mfa_config.check_permission do
          {:arg, arg_name} when is_binary(arg_name) ->
            missing_mfa_permission_arg?(mfa_config, arg_name)

          _ ->
            []
        end
      end)

    errors = action_errors ++ mfa_errors

    if errors == [] do
      :ok
    else
      raise Spark.Error.DslError,
        module: resource,
        path: [:gen_api],
        message: """
        Permission configuration errors:

        #{Enum.join(errors, "\n\n")}
        """
    end
  end

  # For mfa entities, only check against explicit arg_types
  defp missing_mfa_permission_arg?(mfa_config, arg_name) do
    if is_map(mfa_config.arg_types) and Map.has_key?(mfa_config.arg_types, arg_name) do
      []
    else
      [
        "MFA `#{mfa_config.name}`: check_permission references arg " <>
          "`#{inspect(arg_name)}` but it is not found in arg_types"
      ]
    end
  end

  # Checks that the arg exists in either explicit arg_types or the Ash action
  defp missing_action_permission_arg?(dsl_state, action_config, arg_name) do
    if permission_arg_exists_in_action?(dsl_state, action_config, arg_name) do
      []
    else
      [
        "Action `#{action_config.name}`: check_permission references arg " <>
          "`#{inspect(arg_name)}` but it is not found in arg_types or the " <>
          "Ash action's attributes/arguments"
      ]
    end
  end

  defp permission_arg_exists_in_action?(dsl_state, action_config, arg_name) do
    # Check the Ash action's attributes and arguments
    ash_action = ResourceAshInfo.action(dsl_state, action_config.name)
    arg_exists_in_ash_action?(ash_action, arg_name)
  end

  defp arg_exists_in_ash_action?(nil, _arg_name), do: false

  defp arg_exists_in_ash_action?(ash_action, arg_name) do
    # Compare names as strings to avoid creating atoms from DSL input
    in_arguments =
      ash_action.arguments
      |> Enum.any?(fn arg -> Atom.to_string(arg.name) == arg_name end)

    # Check accepted attributes (for create/update actions)
    in_accept =
      case Map.get(ash_action, :accept) do
        :* ->
          true

        accept_list when is_list(accept_list) ->
          Enum.any?(accept_list, fn name -> Atom.to_string(name) == arg_name end)

        _ ->
          false
      end

    in_arguments or in_accept
  end

  # ---------------------------------------------------------------------------
  # MFA validity verification
  # ---------------------------------------------------------------------------

  defp verify_mfa_validity(resource, actions, mfas) do
    action_errors = check_mfa_validity_for_items(actions, "Action")
    mfa_errors = check_mfa_validity_for_items(mfas, "MFA")
    errors = action_errors ++ mfa_errors

    if errors == [] do
      :ok
    else
      raise Spark.Error.DslError,
        module: resource,
        path: [:gen_api],
        message: """
        MFA configuration errors:

        #{Enum.join(errors, "\n\n")}
        """
    end
  end

  defp check_mfa_validity_for_items(items, type) do
    items
    |> Enum.flat_map(fn config ->
      cond do
        # Auto-generated MFA or not applicable — always valid
        is_nil(config.mfa) ->
          []

        Utils.valid_mfa?(config.mfa) ->
          []

        true ->
          [
            "#{type} `#{config.name}`: invalid MFA tuple `#{inspect(config.mfa)}`. " <>
              "Expected `{module, function, args_list}` where module and function are atoms " <>
              "and args is a list."
          ]
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Permission callback verification
  # ---------------------------------------------------------------------------

  defp verify_permission_callbacks(resource, actions, mfas) do
    action_errors = check_permission_callback_for_items(actions, "Action")
    mfa_errors = check_permission_callback_for_items(mfas, "MFA")
    errors = action_errors ++ mfa_errors

    if errors == [] do
      :ok
    else
      raise Spark.Error.DslError,
        module: resource,
        path: [:gen_api],
        message: """
        Permission callback configuration errors:

        #{Enum.join(errors, "\n\n")}
        """
    end
  end

  defp check_permission_callback_for_items(items, type) do
    items
    |> Enum.flat_map(fn config ->
      cond do
        # No callback — always valid
        is_nil(config.permission_callback) ->
          []

        Utils.valid_mfa?(config.permission_callback) ->
          []

        true ->
          location = get_entity_location(config)
          source_info = Utils.format_source_location(location)

          [
            "#{type} `#{config.name}`: invalid permission_callback `#{inspect(config.permission_callback)}`. " <>
              "Expected `{Module, :function, []}` where Module and function are atoms " <>
              "and args is a list, or `nil`." <> source_info
          ]
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # Source annotation helpers
  # ---------------------------------------------------------------------------

  @doc false
  defp get_entity_location(%{__spark_metadata__: metadata}) when is_map(metadata) do
    case Map.get(metadata, :anno) do
      nil ->
        case Map.get(metadata, :entity_anno) do
          nil -> nil
          anno -> anno
        end

      anno ->
        anno
    end
  end

  defp get_entity_location(_), do: nil
end
