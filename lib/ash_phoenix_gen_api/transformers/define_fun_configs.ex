defmodule AshPhoenixGenApi.Transformers.DefineFunConfigs do
  @moduledoc """
  Transformer that generates PhoenixGenApi FunConfig structs from Ash resource actions.

  This transformer reads the `gen_api` DSL section configuration and generates
  `PhoenixGenApi.Structs.FunConfig` structs for each configured action. The generated
  FunConfigs are stored in a `__ash_phoenix_gen_api_fun_configs__/0` function on the
  resource module.

  ## Resolution Order

  For each FunConfig field, values are resolved in this order:

  1. **Action-level explicit config** — e.g., `action :foo do timeout 10_000 end`
  2. **Resource section-level defaults** — e.g., `gen_api do timeout 5_000 end`
  3. **Built-in defaults** — e.g., timeout defaults to `5000`

  For `arg_types` and `arg_orders`:

  1. **Explicit `arg_types`/`arg_orders`** on the action entity
  2. **Auto-derived** from the Ash action's accepted attributes and arguments
     using `AshPhoenixGenApi.TypeMapper`

  For `mfa`:

  1. **Explicit `mfa`** on the action entity
  2. **Auto-generated** as `{ResourceModule, :action_name, []}`

  ## Generated Function

  After this transformer runs, the resource module will have:

      def __ash_phoenix_gen_api_fun_configs__ do
        [
          %PhoenixGenApi.Structs.FunConfig{
            request_type: "send_direct_message",
            service: "chat",
            nodes: {ClusterHelper, :get_nodes, [:chat]},
            # ...
          },
          # ...
        ]
      end

  This function is used by `AshPhoenixGenApi.Resource.Info.fun_configs/1` and
  by the domain-level supporter module to aggregate FunConfigs.
  """

  use Spark.Dsl.Transformer

  alias AshPhoenixGenApi.Resource.Info
  alias AshPhoenixGenApi.Resource.ActionConfig
  alias AshPhoenixGenApi.TypeMapper

  @doc """
  Runs after all other transformers so that Ash action info is fully available.
  """
  @impl true
  def after?(_), do: true

  @doc """
  Does not need to run before any specific transformer.
  """
  @impl true
  def before?(_), do: false

  @impl true
  def transform(dsl_state) do
    resource = Spark.Dsl.Transformer.get_persisted(dsl_state, :module)
    actions = Info.gen_api(dsl_state)

    if actions == [] do
      # No gen_api actions configured — define empty function for safe introspection
      dsl_state =
        Spark.Dsl.Transformer.eval(
          dsl_state,
          [],
          quote do
            @doc false
            def __ash_phoenix_gen_api_fun_configs__ do
              []
            end
          end
        )

      {:ok, dsl_state}
    else
      section_defaults = extract_section_defaults(dsl_state)

      fun_configs =
        actions
        |> Enum.filter(&ActionConfig.enabled?/1)
        |> Enum.map(fn action_config ->
          build_fun_config(action_config, resource, dsl_state, section_defaults)
        end)

      fun_configs_escaped = Macro.escape(fun_configs)

      dsl_state =
        Spark.Dsl.Transformer.eval(
          dsl_state,
          [],
          quote do
            @doc false
            def __ash_phoenix_gen_api_fun_configs__ do
              unquote(fun_configs_escaped)
            end
          end
        )

      {:ok, dsl_state}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp extract_section_defaults(dsl_state) do
    %{
      service: extract_opt(Info.gen_api_service(dsl_state), nil),
      nodes: extract_opt(Info.gen_api_nodes(dsl_state), :local),
      choose_node_mode: extract_opt(Info.gen_api_choose_node_mode(dsl_state), :random),
      timeout: extract_opt(Info.gen_api_timeout(dsl_state), 5_000),
      response_type: extract_opt(Info.gen_api_response_type(dsl_state), :async),
      request_info: extract_opt(Info.gen_api_request_info(dsl_state), true),
      check_permission: extract_opt(Info.gen_api_check_permission(dsl_state), false),
      version: extract_opt(Info.gen_api_version(dsl_state), "0.0.1"),
      retry: extract_opt(Info.gen_api_retry(dsl_state), nil)
    }
  end

  defp extract_opt({:ok, value}, _default), do: value
  defp extract_opt(:error, default), do: default
  defp extract_opt(value, _default) when not is_tuple(value), do: value

  defp build_fun_config(action_config, resource, dsl_state, section_defaults) do
    request_type = ActionConfig.effective_request_type(action_config)
    timeout = ActionConfig.effective_timeout(action_config, section_defaults.timeout)
    response_type = ActionConfig.effective_response_type(action_config, section_defaults.response_type)
    request_info = ActionConfig.effective_request_info(action_config, section_defaults.request_info)
    check_permission = ActionConfig.effective_check_permission(action_config, section_defaults.check_permission)
    choose_node_mode = ActionConfig.effective_choose_node_mode(action_config, section_defaults.choose_node_mode)
    nodes = ActionConfig.effective_nodes(action_config, section_defaults.nodes)
    version = ActionConfig.effective_version(action_config, section_defaults.version)
    retry = ActionConfig.effective_retry(action_config, section_defaults.retry)
    mfa = ActionConfig.effective_mfa(action_config, resource)

    {arg_types, arg_orders} = resolve_arg_config(action_config, resource, dsl_state)

    %PhoenixGenApi.Structs.FunConfig{
      request_type: request_type,
      service: section_defaults.service,
      nodes: nodes,
      choose_node_mode: choose_node_mode,
      timeout: timeout,
      mfa: mfa,
      arg_types: arg_types,
      arg_orders: arg_orders,
      response_type: response_type,
      check_permission: check_permission,
      request_info: request_info,
      version: version,
      disabled: action_config.disabled,
      retry: retry
    }
  end

  # Resolves arg_types and arg_orders for a FunConfig.
  #
  # Priority:
  #   1. Both arg_types and arg_orders explicitly set on the action entity
  #   2. Only arg_types explicitly set → derive arg_orders from its keys
  #   3. Neither set → auto-derive from the Ash action's attributes & arguments
  @doc false
  def resolve_arg_config(action_config, resource, dsl_state \\ nil) do
    explicit_arg_types = action_config.arg_types
    explicit_arg_orders = action_config.arg_orders

    cond do
      # Both explicitly provided
      is_map(explicit_arg_types) and map_size(explicit_arg_types) > 0 and
          is_list(explicit_arg_orders) and explicit_arg_orders != [] ->
        {explicit_arg_types, explicit_arg_orders}

      # Only arg_types explicitly provided — derive arg_orders from keys
      is_map(explicit_arg_types) and map_size(explicit_arg_types) > 0 ->
        {explicit_arg_types, Map.keys(explicit_arg_types)}

      # Auto-derive from the Ash action definition
      true ->
        auto_derive_arg_config(resource, action_config.name, dsl_state)
    end
  end

  # Auto-derives arg_types and arg_orders from an Ash resource action.
  #
  # Uses `AshPhoenixGenApi.TypeMapper.get_action_fields/2` to extract the
  # action's accepted attributes and arguments, maps their Ash types to
  # PhoenixGenApi types, and builds the arg_types map and arg_orders list.
  #
  # For :create/:update actions, includes accepted attributes + action arguments.
  # For :read/:destroy/:action actions, includes only action arguments.
  # Returns {%{}, []} if the action has no inputs or doesn't exist.
  defp auto_derive_arg_config(resource, action_name, dsl_state) do
    fields = get_action_fields(resource, action_name, dsl_state)
    TypeMapper.build_arg_config(fields)
  end

  # Gets the input fields for an Ash action, using dsl_state when available
  # (during compilation) or the resource module (at runtime).
  defp get_action_fields(resource, action_name, nil) do
    TypeMapper.get_action_fields(resource, action_name)
  end

  defp get_action_fields(_resource, action_name, dsl_state) do
    action = Ash.Resource.Info.action(dsl_state, action_name)

    if is_nil(action) do
      []
    else
      # Get accepted attributes
      accepted_attrs =
        case action do
          %{accept: :*} ->
            Ash.Resource.Info.attributes(dsl_state)
            |> Enum.filter(& &1.public?)

          %{accept: accept_list} when is_list(accept_list) ->
            accept_list
            |> Enum.map(fn name -> Ash.Resource.Info.attribute(dsl_state, name) end)
            |> Enum.filter(& &1)

          _ ->
            []
        end

      # Get action arguments
      arguments = action.arguments || []

      # Build the field list: accepted attributes first, then arguments
      attr_fields =
        Enum.map(accepted_attrs, fn attr ->
          gen_api_type = TypeMapper.to_gen_api_type(attr.type, attr.constraints)
          {attr.name, gen_api_type, attr.allow_nil?}
        end)

      arg_fields =
        Enum.map(arguments, fn arg ->
          gen_api_type = TypeMapper.to_gen_api_type(arg.type, arg.constraints)
          {arg.name, gen_api_type, arg.allow_nil?}
        end)

      attr_fields ++ arg_fields
    end
  end
end
