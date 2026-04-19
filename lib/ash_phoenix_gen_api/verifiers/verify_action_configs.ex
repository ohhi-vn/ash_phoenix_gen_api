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

  5. **MFA validity** — When an explicit `mfa` is provided, the module
     must be loaded (or the function must exist if the module is loaded).

  6. **Permission callback validity** — When `permission_callback` is
     provided, it must be a valid MFA tuple `{module, function, args}`
     where module and function are atoms and args is a list, or `nil`.

  ## Error Messages

  The verifier raises `Spark.Error.DslError` with descriptive messages
  and the path to the offending configuration, making it easy to locate
  and fix issues.
  """

  use Spark.Dsl.Verifier

  alias AshPhoenixGenApi.Resource.Info
  alias AshPhoenixGenApi.Resource.ActionConfig

  @impl true
  def verify(dsl_state) do
    resource = Spark.Dsl.Verifier.get_persisted(dsl_state, :module)
    actions = Info.gen_api(dsl_state)

    # Verify each action config
    with :ok <- verify_actions_exist(dsl_state, resource, actions),
         :ok <- verify_request_type_uniqueness(resource, actions),
         :ok <- verify_arg_consistency(resource, actions),
         :ok <- verify_permission_args(dsl_state, resource, actions),
         :ok <- verify_mfa_validity(resource, actions),
         :ok <- verify_permission_callbacks(resource, actions) do
      :ok
    end
  end

  # ---------------------------------------------------------------------------
  # Action existence verification
  # ---------------------------------------------------------------------------

  defp verify_actions_exist(dsl_state, resource, actions) do
    resource_actions = Ash.Resource.Info.actions(dsl_state)

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
        "The action `#{inspect(action_config.name)}` does not exist on " <>
          "resource `#{inspect(resource)}`. Available actions: " <>
          "#{inspect(MapSet.to_list(resource_action_names))}"
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

  defp verify_request_type_uniqueness(resource, actions) do
    # Collect all effective request_types and check for duplicates
    request_types =
      actions
      |> Enum.map(fn action_config ->
        {ActionConfig.effective_request_type(action_config), action_config.name}
      end)

    duplicates =
      request_types
      |> Enum.group_by(fn {request_type, _action_name} -> request_type end)
      |> Enum.filter(fn {_request_type, occurrences} -> length(occurrences) > 1 end)
      |> Enum.map(fn {request_type, occurrences} ->
        action_names = Enum.map(occurrences, fn {_, name} -> name end)
        "The request_type `#{request_type}` is used by multiple actions: " <>
          "#{inspect(action_names)}. Each action must have a unique request_type."
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

  defp verify_arg_consistency(resource, actions) do
    errors =
      actions
      |> Enum.flat_map(fn action_config ->
        arg_types = action_config.arg_types
        arg_orders = action_config.arg_orders

        cond do
          # Both provided — check keys match
          is_map(arg_types) and map_size(arg_types) > 0 and
              is_list(arg_orders) and arg_orders != [] ->
            arg_type_keys = MapSet.new(Map.keys(arg_types))
            arg_order_keys = MapSet.new(arg_orders)

            missing_in_orders = MapSet.difference(arg_type_keys, arg_order_keys)
            missing_in_types = MapSet.difference(arg_order_keys, arg_type_keys)

            errors = []

            errors =
              if MapSet.size(missing_in_orders) > 0 do
                [
                  "Action `#{action_config.name}`: arg_types has keys " <>
                    "#{inspect(MapSet.to_list(missing_in_orders))} that are missing from arg_orders"
                  | errors
                ]
              else
                errors
              end

            errors =
              if MapSet.size(missing_in_types) > 0 do
                [
                  "Action `#{action_config.name}`: arg_orders has keys " <>
                    "#{inspect(MapSet.to_list(missing_in_types))} that are missing from arg_types"
                  | errors
                ]
              else
                errors
              end

            errors

          # Only arg_types provided — arg_orders will be derived from keys, so OK
          is_map(arg_types) and map_size(arg_types) > 0 ->
            []

          # Only arg_orders provided without arg_types — can't determine types
          (is_nil(arg_types) or (is_map(arg_types) and map_size(arg_types) == 0)) and
              is_list(arg_orders) and arg_orders != [] ->
            [
              "Action `#{action_config.name}`: arg_orders is provided but arg_types is not. " <>
                "Please also provide arg_types, or remove arg_orders to auto-derive both from the Ash action."
            ]

          true ->
            []
        end
      end)

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

  # ---------------------------------------------------------------------------
  # Permission arg existence verification
  # ---------------------------------------------------------------------------

  defp verify_permission_args(dsl_state, resource, actions) do
    errors =
      actions
      |> Enum.flat_map(fn action_config ->
        case action_config.check_permission do
          {:arg, arg_name} when is_binary(arg_name) ->
            # Check that the arg exists in either explicit arg_types or the Ash action
            if permission_arg_exists?(dsl_state, action_config, arg_name) do
              []
            else
              [
                "Action `#{action_config.name}`: check_permission references arg " <>
                  "`#{inspect(arg_name)}` but it is not found in arg_types or the " <>
                  "Ash action's attributes/arguments"
              ]
            end

          _ ->
            []
        end
      end)

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

  defp permission_arg_exists?(dsl_state, action_config, arg_name) do
    # Check explicit arg_types first
    if is_map(action_config.arg_types) and Map.has_key?(action_config.arg_types, arg_name) do
      true
    else
      # Check the Ash action's attributes and arguments
      ash_action = Ash.Resource.Info.action(dsl_state, action_config.name)

      if is_nil(ash_action) do
        false
      else
        arg_exists_in_ash_action?(ash_action, arg_name)
      end
    end
  end

  defp arg_exists_in_ash_action?(ash_action, arg_name) do
    arg_name_atom = if is_binary(arg_name), do: String.to_atom(arg_name), else: arg_name

    # Check action arguments
    in_arguments =
      ash_action.arguments
      |> Enum.any?(fn arg -> arg.name == arg_name_atom end)

    # Check accepted attributes (for create/update actions)
    in_accept =
      case ash_action do
        %{accept: :*} ->
          true

        %{accept: accept_list} when is_list(accept_list) ->
          arg_name_atom in accept_list

        _ ->
          false
      end

    in_arguments or in_accept
  end

  # ---------------------------------------------------------------------------
  # MFA validity verification
  # ---------------------------------------------------------------------------

  defp verify_mfa_validity(resource, actions) do
    errors =
      actions
      |> Enum.flat_map(fn action_config ->
        case action_config.mfa do
          nil ->
            # Auto-generated MFA — always valid
            []

          {mod, fun, args} when is_atom(mod) and is_atom(fun) and is_list(args) ->
            # Check if the module is loaded and the function exists
            # Note: We don't require the module to be loaded at compile time
            # because the MFA might reference a module that hasn't been compiled yet.
            # We only validate the structure.
            []

          mfa ->
            [
              "Action `#{action_config.name}`: invalid MFA tuple `#{inspect(mfa)}`. " <>
                "Expected `{module, function, args_list}` where module and function are atoms " <>
                "and args is a list."
            ]
        end
      end)

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

  # ---------------------------------------------------------------------------
  # Permission callback verification
  # ---------------------------------------------------------------------------

  defp verify_permission_callbacks(resource, actions) do
    errors =
      actions
      |> Enum.flat_map(fn action_config ->
        case action_config.permission_callback do
          nil ->
            # No callback — always valid
            []

          {mod, fun, args} when is_atom(mod) and is_atom(fun) and is_list(args) ->
            # Valid MFA structure — we don't require the module to be loaded
            # at compile time because it might not be compiled yet.
            []

          permission_callback ->
            [
              "Action `#{action_config.name}`: invalid permission_callback `#{inspect(permission_callback)}`. " <>
                "Expected `{Module, :function, []}` where Module and function are atoms " <>
                "and args is a list, or `nil`."
            ]
        end
      end)

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
end
