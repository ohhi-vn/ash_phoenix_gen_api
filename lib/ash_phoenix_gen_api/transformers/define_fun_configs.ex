defmodule AshPhoenixGenApi.Transformers.DefineFunConfigs do
  @moduledoc """
  Transformer that generates PhoenixGenApi FunConfig structs and code interface
  functions from Ash resource actions.

  This transformer reads the `gen_api` DSL section configuration and:

  1. Generates `PhoenixGenApi.Structs.FunConfig` structs for each configured action,
     stored in a `__ash_phoenix_gen_api_fun_configs__/0` function on the resource module.

  2. Generates code interface functions for each enabled action (when `code_interface?`
     is `true`), allowing developers to call Ash actions directly as Elixir functions
     on the resource module.

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

  For `code_interface?`:

  1. **Action-level `code_interface?`** on the action entity
  2. **Section-level `code_interface?`** — e.g., `gen_api do code_interface? true end`
  3. **Built-in default** — defaults to `true`

  ## Generated Functions

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

  Additionally, for each action with `code_interface?` enabled, the following
  functions are generated. All functions use `Ash.CodeInterface.params_and_opts/2`
  to properly disambiguate between args maps and opts keyword lists, allowing
  callers to pass just opts (e.g., `action(actor: user)`) without wrapping
  them in a second argument.

  ### Create actions

      def create_action(params_or_opts \\\\ [], opts \\\\ []) do
        {args, opts} = Ash.CodeInterface.params_and_opts(params_or_opts, opts)
        Ash.Changeset.for_create(__MODULE__, :create_action, args, opts)
        |> Ash.create(opts)
      end

      def create_action!(params_or_opts \\\\ [], opts \\\\ []) do
        {args, opts} = Ash.CodeInterface.params_and_opts(params_or_opts, opts)
        Ash.Changeset.for_create(__MODULE__, :create_action, args, opts)
        |> Ash.create!(opts)
      end

  ### Read actions

      def read_action(params_or_opts \\\\ [], opts \\\\ []) do
        {args, opts} = Ash.CodeInterface.params_and_opts(params_or_opts, opts)
        Ash.Query.for_read(__MODULE__, :read_action, args, opts)
        |> Ash.read(opts)
      end

      def read_action!(params_or_opts \\\\ [], opts \\\\ []) do
        {args, opts} = Ash.CodeInterface.params_and_opts(params_or_opts, opts)
        Ash.Query.for_read(__MODULE__, :read_action, args, opts)
        |> Ash.read!(opts)
      end

  ### Update actions (require a record as first argument)

      def update_action(record, params_or_opts \\\\ [], opts \\\\ []) do
        {args, opts} = Ash.CodeInterface.params_and_opts(params_or_opts, opts)
        Ash.Changeset.for_update(record, :update_action, args, opts)
        |> Ash.update(opts)
      end

      def update_action!(record, params_or_opts \\\\ [], opts \\\\ []) do
        {args, opts} = Ash.CodeInterface.params_and_opts(params_or_opts, opts)
        Ash.Changeset.for_update(record, :update_action, args, opts)
        |> Ash.update!(opts)
      end

  ### Destroy actions (require a record as first argument)

      def destroy_action(record, params_or_opts \\\\ [], opts \\\\ []) do
        {args, opts} = Ash.CodeInterface.params_and_opts(params_or_opts, opts)
        Ash.Changeset.for_destroy(record, :destroy_action, args, opts)
        |> Ash.destroy(opts)
      end

      def destroy_action!(record, params_or_opts \\\\ [], opts \\\\ []) do
        {args, opts} = Ash.CodeInterface.params_and_opts(params_or_opts, opts)
        Ash.Changeset.for_destroy(record, :destroy_action, args, opts)
        |> Ash.destroy!(opts)
      end

  ### Generic actions

      def generic_action(params_or_opts \\\\ [], opts \\\\ []) do
        {args, opts} = Ash.CodeInterface.params_and_opts(params_or_opts, opts)
        Ash.ActionInput.for_action(__MODULE__, :generic_action, args, opts)
        |> Ash.run_action(opts)
      end

      def generic_action!(params_or_opts \\\\ [], opts \\\\ []) do
        {args, opts} = Ash.CodeInterface.params_and_opts(params_or_opts, opts)
        Ash.ActionInput.for_action(__MODULE__, :generic_action, args, opts)
        |> Ash.run_action!(opts)
      end
  """

  use Spark.Dsl.Transformer

  alias AshPhoenixGenApi.Resource.Info
  alias AshPhoenixGenApi.Resource.ActionConfig
  alias AshPhoenixGenApi.Resource.MfaConfig
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
    entities = Info.gen_api(dsl_state)

    # Separate action and mfa entities by struct type
    actions = Enum.filter(entities, &match?(%ActionConfig{}, &1))
    mfas = Enum.filter(entities, &match?(%MfaConfig{}, &1))

    if entities == [] do
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
      section_code_interface? = extract_opt(Info.gen_api_code_interface?(dsl_state), true)

      action_fun_configs =
        actions
        |> Enum.filter(&ActionConfig.enabled?/1)
        |> Enum.map(fn action_config ->
          build_fun_config(action_config, resource, dsl_state, section_defaults)
        end)

      mfa_fun_configs =
        mfas
        |> Enum.filter(&MfaConfig.enabled?/1)
        |> Enum.map(fn mfa_config ->
          build_mfa_fun_config(mfa_config, section_defaults)
        end)

      fun_configs = action_fun_configs ++ mfa_fun_configs
      fun_configs_escaped = Macro.escape(fun_configs)

      # Build code interface function definitions for enabled actions
      enabled_actions = Enum.filter(actions, &ActionConfig.enabled?/1)

      code_interface_defs =
        enabled_actions
        |> Enum.filter(fn action_config ->
          ActionConfig.effective_code_interface?(action_config, section_code_interface?)
        end)
        |> Enum.flat_map(fn action_config ->
          build_code_interface_functions(action_config, dsl_state, section_defaults)
        end)

      dsl_state =
        Spark.Dsl.Transformer.eval(
          dsl_state,
          [],
          quote do
            @doc false
            def __ash_phoenix_gen_api_fun_configs__ do
              unquote(fun_configs_escaped)
            end

            unquote_splicing(code_interface_defs)
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
      permission_callback: extract_opt(Info.gen_api_permission_callback(dsl_state), nil),
      version: extract_opt(Info.gen_api_version(dsl_state), "0.0.1"),
      retry: extract_opt(Info.gen_api_retry(dsl_state), nil),
      result_encoder: extract_opt(Info.gen_api_result_encoder(dsl_state), :struct)
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
    permission_callback = ActionConfig.effective_permission_callback(action_config, section_defaults.permission_callback)
    choose_node_mode = ActionConfig.effective_choose_node_mode(action_config, section_defaults.choose_node_mode)
    nodes = ActionConfig.effective_nodes(action_config, section_defaults.nodes)
    version = ActionConfig.effective_version(action_config, section_defaults.version)
    retry = ActionConfig.effective_retry(action_config, section_defaults.retry)
    mfa = ActionConfig.effective_mfa(action_config, resource)

    # Resolve check_permission with permission_callback taking precedence.
    # Resolution order:
    # 1. Action-level permission_callback (if set)
    # 2. Section-level permission_callback (if set)
    # 3. Action-level check_permission (if set)
    # 4. Section-level check_permission (if set)
    # 5. Built-in default of false
    check_permission =
      if permission_callback do
        {:callback, permission_callback}
      else
        ActionConfig.effective_check_permission(action_config, section_defaults.check_permission)
      end

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

  # Builds a FunConfig from an MfaConfig entity.
  #
  # Unlike action configs, mfa configs have no Ash action to auto-derive from.
  # The `request_type`, `mfa`, and `arg_types` are all explicitly provided.
  # `arg_orders` defaults to `:map` (passing args as a map with string keys).
  defp build_mfa_fun_config(mfa_config, section_defaults) do
    request_type = mfa_config.request_type
    timeout = MfaConfig.effective_timeout(mfa_config, section_defaults.timeout)
    response_type = MfaConfig.effective_response_type(mfa_config, section_defaults.response_type)
    request_info = MfaConfig.effective_request_info(mfa_config, section_defaults.request_info)
    permission_callback = MfaConfig.effective_permission_callback(mfa_config, section_defaults.permission_callback)
    choose_node_mode = MfaConfig.effective_choose_node_mode(mfa_config, section_defaults.choose_node_mode)
    nodes = MfaConfig.effective_nodes(mfa_config, section_defaults.nodes)
    version = MfaConfig.effective_version(mfa_config, section_defaults.version)
    retry = MfaConfig.effective_retry(mfa_config, section_defaults.retry)

    # Resolve check_permission with permission_callback taking precedence.
    check_permission =
      if permission_callback do
        {:callback, permission_callback}
      else
        MfaConfig.effective_check_permission(mfa_config, section_defaults.check_permission)
      end

    # For mfa entities, arg_types and arg_orders are explicitly provided
    # (no auto-derivation from Ash actions). Normalize empty arg_types
    # to nil for FunConfig compatibility.
    {arg_types, arg_orders} =
      case mfa_config.arg_types do
        types when is_map(types) and map_size(types) == 0 ->
          {nil, nil}

        types when is_map(types) and map_size(types) > 0 ->
          {types, mfa_config.arg_orders}

        nil ->
          {nil, nil}
      end

    %PhoenixGenApi.Structs.FunConfig{
      request_type: request_type,
      service: section_defaults.service,
      nodes: nodes,
      choose_node_mode: choose_node_mode,
      timeout: timeout,
      mfa: mfa_config.mfa,
      arg_types: arg_types,
      arg_orders: arg_orders,
      response_type: response_type,
      check_permission: check_permission,
      request_info: request_info,
      version: version,
      disabled: mfa_config.disabled,
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
      # Both explicitly provided (arg_orders is a list, arg_types is a map)
      is_list(explicit_arg_orders) and explicit_arg_orders != [] and
          is_map(explicit_arg_types) and map_size(explicit_arg_types) > 0 ->
        {explicit_arg_types, explicit_arg_orders}

      # arg_orders is :map (default) — keep :map so FunConfig passes args as a map
      explicit_arg_orders == :map and is_map(explicit_arg_types) and map_size(explicit_arg_types) > 0 ->
        {explicit_arg_types, :map}

      # Auto-derive from the Ash action definition — arg_orders defaults to :map
      true ->
        {arg_types, _arg_orders} = auto_derive_arg_config(resource, action_config.name, dsl_state)
        {arg_types, :map}
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

  # ---------------------------------------------------------------------------
  # Code interface function generation
  # ---------------------------------------------------------------------------

  # Builds code interface function definitions for a single action config.
  #
  # Returns a list of quoted function definitions (both regular and bang versions).
  # The function signature depends on the Ash action type:
  #
  #   - :create  → def name(params_or_opts \\ [], opts \\ [])
  #   - :read    → def name(params_or_opts \\ [], opts \\ [])
  #   - :update  → def name(record, params_or_opts \\ [], opts \\ [])
  #   - :destroy → def name(record, params_or_opts \\ [], opts \\ [])
  #   - :action  → def name(params_or_opts \\ [], opts \\ [])
  #
  # Returns an empty list if the action cannot be found in the resource.
  defp build_code_interface_functions(action_config, dsl_state, section_defaults) do
    action_name = action_config.name
    ash_action = Ash.Resource.Info.action(dsl_state, action_name)

    if is_nil(ash_action) do
      []
    else
      action_type = ash_action.type
      bang_name = String.to_atom("#{action_name}!")
      result_encoder = ActionConfig.effective_result_encoder(action_config, section_defaults.result_encoder)

      case action_type do
        :create ->
          build_create_interface(action_name, bang_name, action_type, result_encoder)

        :read ->
          build_read_interface(action_name, bang_name, action_type, result_encoder)

        :update ->
          build_update_interface(action_name, bang_name, action_type, result_encoder)

        :destroy ->
          build_destroy_interface(action_name, bang_name, action_type, result_encoder)

        :action ->
          build_generic_interface(action_name, bang_name, action_type, result_encoder)
      end
    end
  end

  defp build_create_interface(action_name, bang_name, action_type, result_encoder) do
    doc_string =
      "Auto-generated code interface for the `:#{action_name}` gen_api action (#{action_type}).\n\n" <>
        "Calls `Ash.Changeset.for_create/4` then `Ash.create/2`.\n\n" <>
        "## Parameters\n" <>
        "  - `params_or_opts` - A map of arguments matching the action's accepted attributes and arguments,\n" <>
        "    or a keyword list of options. Uses `Ash.CodeInterface.params_and_opts/2` for disambiguation.\n" <>
        "  - `opts` - Keyword options passed to both `for_create` and `create`:\n" <>
        "    - `:actor` - The actor for authorization\n" <>
        "    - `:tenant` - The tenant for multitenancy\n" <>
        "    - `:authorize?` - Whether to run authorization\n" <>
        "    - Other Ash options\n\n" <>
        "## Returns\n" <>
        "  - `{:ok, result}` on success\n" <>
        "  - `{:error, error}` on failure"

    bang_doc_string =
      "Auto-generated code interface for the `:#{action_name}` gen_api action (#{action_type}).\n\n" <>
        "Same as `#{action_name}/2` but raises on error."

    result_encoder_escaped = Macro.escape(result_encoder)

    [
      quote do
        @doc unquote(doc_string)
        def unquote(action_name)(params_or_opts \\ [], opts \\ []) do
          {args, opts} = Ash.CodeInterface.params_and_opts(params_or_opts, opts)
          Ash.Changeset.for_create(__MODULE__, unquote(action_name), args, opts)
          |> Ash.create(opts)
          |> AshPhoenixGenApi.Codec.encode_result(unquote(result_encoder_escaped))
        end
      end,
      quote do
        @doc unquote(bang_doc_string)
        def unquote(bang_name)(params_or_opts \\ [], opts \\ []) do
          {args, opts} = Ash.CodeInterface.params_and_opts(params_or_opts, opts)
          Ash.Changeset.for_create(__MODULE__, unquote(action_name), args, opts)
          |> Ash.create!(opts)
          |> AshPhoenixGenApi.Codec.encode_value(unquote(result_encoder_escaped))
        end
      end
    ]
  end

  defp build_read_interface(action_name, bang_name, action_type, result_encoder) do
    doc_string =
      "Auto-generated code interface for the `:#{action_name}` gen_api action (#{action_type}).\n\n" <>
        "Calls `Ash.Query.for_read/4` then `Ash.read/2`.\n\n" <>
        "## Parameters\n" <>
        "  - `params_or_opts` - A map of arguments matching the action's arguments,\n" <>
        "    or a keyword list of options. Uses `Ash.CodeInterface.params_and_opts/2` for disambiguation.\n" <>
        "  - `opts` - Keyword options passed to both `for_read` and `read`:\n" <>
        "    - `:actor` - The actor for authorization\n" <>
        "    - `:tenant` - The tenant for multitenancy\n" <>
        "    - `:authorize?` - Whether to run authorization\n" <>
        "    - Other Ash options\n\n" <>
        "## Returns\n" <>
        "  - `{:ok, results}` on success (list of records)\n" <>
        "  - `{:error, error}` on failure"

    bang_doc_string =
      "Auto-generated code interface for the `:#{action_name}` gen_api action (#{action_type}).\n\n" <>
        "Same as `#{action_name}/2` but raises on error."

    result_encoder_escaped = Macro.escape(result_encoder)

    [
      quote do
        @doc unquote(doc_string)
        def unquote(action_name)(params_or_opts \\ [], opts \\ []) do
          {args, opts} = Ash.CodeInterface.params_and_opts(params_or_opts, opts)
          Ash.Query.for_read(__MODULE__, unquote(action_name), args, opts)
          |> Ash.read(opts)
          |> AshPhoenixGenApi.Codec.encode_result(unquote(result_encoder_escaped))
        end
      end,
      quote do
        @doc unquote(bang_doc_string)
        def unquote(bang_name)(params_or_opts \\ [], opts \\ []) do
          {args, opts} = Ash.CodeInterface.params_and_opts(params_or_opts, opts)
          Ash.Query.for_read(__MODULE__, unquote(action_name), args, opts)
          |> Ash.read!(opts)
          |> AshPhoenixGenApi.Codec.encode_value(unquote(result_encoder_escaped))
        end
      end
    ]
  end

  defp build_update_interface(action_name, bang_name, action_type, result_encoder) do
    doc_string =
      "Auto-generated code interface for the `:#{action_name}` gen_api action (#{action_type}).\n\n" <>
        "Calls `Ash.Changeset.for_update/4` then `Ash.update/2`.\n\n" <>
        "## Parameters\n" <>
        "  - `record` - The existing record to update\n" <>
        "  - `params_or_opts` - A map of arguments matching the action's accepted attributes and arguments,\n" <>
        "    or a keyword list of options. Uses `Ash.CodeInterface.params_and_opts/2` for disambiguation.\n" <>
        "  - `opts` - Keyword options passed to both `for_update` and `update`:\n" <>
        "    - `:actor` - The actor for authorization\n" <>
        "    - `:tenant` - The tenant for multitenancy\n" <>
        "    - `:authorize?` - Whether to run authorization\n" <>
        "    - Other Ash options\n\n" <>
        "## Returns\n" <>
        "  - `{:ok, result}` on success\n" <>
        "  - `{:error, error}` on failure"

    bang_doc_string =
      "Auto-generated code interface for the `:#{action_name}` gen_api action (#{action_type}).\n\n" <>
        "Same as `#{action_name}/3` but raises on error."

    result_encoder_escaped = Macro.escape(result_encoder)

    [
      quote do
        @doc unquote(doc_string)
        def unquote(action_name)(record, params_or_opts \\ [], opts \\ []) do
          {args, opts} = Ash.CodeInterface.params_and_opts(params_or_opts, opts)
          Ash.Changeset.for_update(record, unquote(action_name), args, opts)
          |> Ash.update(opts)
          |> AshPhoenixGenApi.Codec.encode_result(unquote(result_encoder_escaped))
        end
      end,
      quote do
        @doc unquote(bang_doc_string)
        def unquote(bang_name)(record, params_or_opts \\ [], opts \\ []) do
          {args, opts} = Ash.CodeInterface.params_and_opts(params_or_opts, opts)
          Ash.Changeset.for_update(record, unquote(action_name), args, opts)
          |> Ash.update!(opts)
          |> AshPhoenixGenApi.Codec.encode_value(unquote(result_encoder_escaped))
        end
      end
    ]
  end

  defp build_destroy_interface(action_name, bang_name, action_type, result_encoder) do
    doc_string =
      "Auto-generated code interface for the `:#{action_name}` gen_api action (#{action_type}).\n\n" <>
        "Calls `Ash.Changeset.for_destroy/4` then `Ash.destroy/2`.\n\n" <>
        "## Parameters\n" <>
        "  - `record` - The record to destroy\n" <>
        "  - `params_or_opts` - A map of arguments matching the action's arguments,\n" <>
        "    or a keyword list of options. Uses `Ash.CodeInterface.params_and_opts/2` for disambiguation.\n" <>
        "  - `opts` - Keyword options passed to both `for_destroy` and `destroy`:\n" <>
        "    - `:actor` - The actor for authorization\n" <>
        "    - `:tenant` - The tenant for multitenancy\n" <>
        "    - `:authorize?` - Whether to run authorization\n" <>
        "    - Other Ash options\n\n" <>
        "## Returns\n" <>
        "  - `:ok` on success\n" <>
        "  - `{:error, error}` on failure"

    bang_doc_string =
      "Auto-generated code interface for the `:#{action_name}` gen_api action (#{action_type}).\n\n" <>
        "Same as `#{action_name}/3` but raises on error."

    result_encoder_escaped = Macro.escape(result_encoder)

    [
      quote do
        @doc unquote(doc_string)
        def unquote(action_name)(record, params_or_opts \\ [], opts \\ []) do
          {args, opts} = Ash.CodeInterface.params_and_opts(params_or_opts, opts)
          Ash.Changeset.for_destroy(record, unquote(action_name), args, opts)
          |> Ash.destroy(opts)
          |> AshPhoenixGenApi.Codec.encode_result(unquote(result_encoder_escaped))
        end
      end,
      quote do
        @doc unquote(bang_doc_string)
        def unquote(bang_name)(record, params_or_opts \\ [], opts \\ []) do
          {args, opts} = Ash.CodeInterface.params_and_opts(params_or_opts, opts)
          Ash.Changeset.for_destroy(record, unquote(action_name), args, opts)
          |> Ash.destroy!(opts)
          |> AshPhoenixGenApi.Codec.encode_value(unquote(result_encoder_escaped))
        end
      end
    ]
  end

  defp build_generic_interface(action_name, bang_name, action_type, result_encoder) do
    doc_string =
      "Auto-generated code interface for the `:#{action_name}` gen_api action (#{action_type}).\n\n" <>
        "Calls `Ash.ActionInput.for_action/4` then `Ash.run_action/2`.\n\n" <>
        "## Parameters\n" <>
        "  - `params_or_opts` - A map of arguments matching the action's arguments,\n" <>
        "    or a keyword list of options. Uses `Ash.CodeInterface.params_and_opts/2` for disambiguation.\n" <>
        "  - `opts` - Keyword options passed to both `for_action` and `run_action`:\n" <>
        "    - `:actor` - The actor for authorization\n" <>
        "    - `:tenant` - The tenant for multitenancy\n" <>
        "    - `:authorize?` - Whether to run authorization\n" <>
        "    - Other Ash options\n\n" <>
        "## Returns\n" <>
        "  - `{:ok, result}` on success\n" <>
        "  - `{:error, error}` on failure"

    bang_doc_string =
      "Auto-generated code interface for the `:#{action_name}` gen_api action (#{action_type}).\n\n" <>
        "Same as `#{action_name}/2` but raises on error."

    result_encoder_escaped = Macro.escape(result_encoder)

    [
      quote do
        @doc unquote(doc_string)
        def unquote(action_name)(params_or_opts \\ [], opts \\ []) do
          {args, opts} = Ash.CodeInterface.params_and_opts(params_or_opts, opts)
          Ash.ActionInput.for_action(__MODULE__, unquote(action_name), args, opts)
          |> Ash.run_action(opts)
          |> AshPhoenixGenApi.Codec.encode_result(unquote(result_encoder_escaped))
        end
      end,
      quote do
        @doc unquote(bang_doc_string)
        def unquote(bang_name)(params_or_opts \\ [], opts \\ []) do
          {args, opts} = Ash.CodeInterface.params_and_opts(params_or_opts, opts)
          Ash.ActionInput.for_action(__MODULE__, unquote(action_name), args, opts)
          |> Ash.run_action!(opts)
          |> AshPhoenixGenApi.Codec.encode_value(unquote(result_encoder_escaped))
        end
      end
    ]
  end
end
