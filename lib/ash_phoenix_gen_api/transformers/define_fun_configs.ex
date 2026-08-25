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
  functions are generated. All functions use `CodeInterface.params_and_opts/2`
  to properly disambiguate between args maps and opts keyword lists, allowing
  callers to pass just opts (e.g., `action(actor: user)`) without wrapping
  them in a second argument.

  ### Create actions

      def create_action(params_or_opts \\\\ [], opts \\\\ []) do
        {args, opts} = CodeInterface.params_and_opts(params_or_opts, opts)
        Changeset.for_create(__MODULE__, :create_action, args, opts)
        |> Ash.create(opts)
      end

      def create_action!(params_or_opts \\\\ [], opts \\\\ []) do
        {args, opts} = CodeInterface.params_and_opts(params_or_opts, opts)
        Changeset.for_create(__MODULE__, :create_action, args, opts)
        |> Ash.create!(opts)
      end

  ### Read actions

      def read_action(params_or_opts \\\\ [], opts \\\\ []) do
        {args, opts} = CodeInterface.params_and_opts(params_or_opts, opts)
        Query.for_read(__MODULE__, :read_action, args, opts)
        |> Ash.read(opts)
      end

      def read_action!(params_or_opts \\\\ [], opts \\\\ []) do
        {args, opts} = CodeInterface.params_and_opts(params_or_opts, opts)
        Query.for_read(__MODULE__, :read_action, args, opts)
        |> Ash.read!(opts)
      end

  ### Update actions (require a record as first argument)

      def update_action(record, params_or_opts \\\\ [], opts \\\\ []) do
        {args, opts} = CodeInterface.params_and_opts(params_or_opts, opts)
        Changeset.for_update(record, :update_action, args, opts)
        |> Ash.update(opts)
      end

      def update_action!(record, params_or_opts \\\\ [], opts \\\\ []) do
        {args, opts} = CodeInterface.params_and_opts(params_or_opts, opts)
        Changeset.for_update(record, :update_action, args, opts)
        |> Ash.update!(opts)
      end

  ### Destroy actions (require a record as first argument)

      def destroy_action(record, params_or_opts \\\\ [], opts \\\\ []) do
        {args, opts} = CodeInterface.params_and_opts(params_or_opts, opts)
        Changeset.for_destroy(record, :destroy_action, args, opts)
        |> Ash.destroy(opts)
      end

      def destroy_action!(record, params_or_opts \\\\ [], opts \\\\ []) do
        {args, opts} = CodeInterface.params_and_opts(params_or_opts, opts)
        Changeset.for_destroy(record, :destroy_action, args, opts)
        |> Ash.destroy!(opts)
      end

  ### Generic actions

      def generic_action(params_or_opts \\\\ [], opts \\\\ []) do
        {args, opts} = CodeInterface.params_and_opts(params_or_opts, opts)
        ActionInput.for_action(__MODULE__, :generic_action, args, opts)
        |> Ash.run_action(opts)
      end

      def generic_action!(params_or_opts \\\\ [], opts \\\\ []) do
        {args, opts} = CodeInterface.params_and_opts(params_or_opts, opts)
        ActionInput.for_action(__MODULE__, :generic_action, args, opts)
        |> Ash.run_action!(opts)
      end
  """

  use Spark.Dsl.Transformer

  alias Ash.ActionInput
  alias Ash.Changeset
  alias Ash.Query
  alias Ash.Resource.Info, as: ResourceAshInfo
  alias AshPhoenixGenApi.Resource.ActionConfig
  alias AshPhoenixGenApi.Resource.Info
  alias AshPhoenixGenApi.Resource.MfaConfig
  alias AshPhoenixGenApi.TypeMapper
  alias AshPhoenixGenApi.Utils
  alias Spark.Dsl.Transformer, as: SparkTransformer

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
    resource = SparkTransformer.get_persisted(dsl_state, :module)
    entities = Info.gen_api(dsl_state)

    # Separate action and mfa entities by struct type
    actions = Enum.filter(entities, &match?(%ActionConfig{}, &1))
    mfas = Enum.filter(entities, &match?(%MfaConfig{}, &1))

    if entities == [] do
      # No gen_api actions configured — define empty function for safe introspection
      dsl_state =
        SparkTransformer.eval(
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
      section_code_interface? = Utils.extract_opt(Info.gen_api_code_interface?(dsl_state), true)

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
        SparkTransformer.eval(
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
      service: Utils.extract_opt(Info.gen_api_service(dsl_state), nil),
      nodes: Utils.extract_opt(Info.gen_api_nodes(dsl_state), :local),
      choose_node_mode: Utils.extract_opt(Info.gen_api_choose_node_mode(dsl_state), :random),
      timeout: Utils.extract_opt(Info.gen_api_timeout(dsl_state), 5_000),
      response_type: Utils.extract_opt(Info.gen_api_response_type(dsl_state), :async),
      request_info: Utils.extract_opt(Info.gen_api_request_info(dsl_state), true),
      check_permission: Utils.extract_opt(Info.gen_api_check_permission(dsl_state), false),
      permission_callback: Utils.extract_opt(Info.gen_api_permission_callback(dsl_state), nil),
      version: Utils.extract_opt(Info.gen_api_version(dsl_state), "0.0.1"),
      retry: Utils.extract_opt(Info.gen_api_retry(dsl_state), nil),
      before_execute: Utils.extract_opt(Info.gen_api_before_execute(dsl_state), nil),
      after_execute: Utils.extract_opt(Info.gen_api_after_execute(dsl_state), nil),
      hook_timeout: Utils.extract_opt(Info.gen_api_hook_timeout(dsl_state), 5_000),
      result_encoder: Utils.extract_opt(Info.gen_api_result_encoder(dsl_state), :struct)
    }
  end

  defp build_fun_config(action_config, resource, dsl_state, section_defaults) do
    request_type = ActionConfig.effective_request_type(action_config)
    timeout = ActionConfig.effective_timeout(action_config, section_defaults.timeout)

    response_type =
      ActionConfig.effective_response_type(action_config, section_defaults.response_type)

    request_info =
      ActionConfig.effective_request_info(action_config, section_defaults.request_info)

    permission_callback =
      ActionConfig.effective_permission_callback(
        action_config,
        section_defaults.permission_callback
      )

    choose_node_mode =
      ActionConfig.effective_choose_node_mode(action_config, section_defaults.choose_node_mode)

    nodes = ActionConfig.effective_nodes(action_config, section_defaults.nodes)
    version = ActionConfig.effective_version(action_config, section_defaults.version)
    retry = ActionConfig.effective_retry(action_config, section_defaults.retry)
    mfa = ActionConfig.effective_mfa(action_config, resource)

    # Resolve check_permission: use the action/section-level check_permission
    # when no permission_callback is set.
    check_permission =
      if permission_callback do
        false
      else
        ActionConfig.effective_check_permission(action_config, section_defaults.check_permission)
      end

    {arg_types, arg_orders} = resolve_arg_config(action_config, resource, dsl_state)

    before_execute =
      ActionConfig.effective_before_execute(action_config, section_defaults.before_execute)

    after_execute =
      ActionConfig.effective_after_execute(action_config, section_defaults.after_execute)

    hook_timeout =
      ActionConfig.effective_hook_timeout(action_config, section_defaults.hook_timeout)

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
      permission_callback: permission_callback,
      request_info: request_info,
      version: version,
      disabled: action_config.disabled,
      retry: retry,
      before_execute: before_execute,
      after_execute: after_execute,
      hook_timeout: hook_timeout
    }
  end

  # Builds a FunConfig from an MfaConfig entity.
  #
  # Unlike action configs, mfa configs have no Ash action to auto-derive from.
  # The `request_type`, `mfa`, and `arg_types` are all explicitly provided.
  # `arg_orders` defaults to `:map` (passing args as a map with string keys).
  #
  # Dialyzer believes `arg_types` is always a populated map per the DSL schema,
  # but the entity struct carries nil before schema defaults are applied.
  @dialyzer {:nowarn_function, build_mfa_fun_config: 2}
  defp build_mfa_fun_config(mfa_config, section_defaults) do
    request_type = mfa_config.request_type
    timeout = MfaConfig.effective_timeout(mfa_config, section_defaults.timeout)
    response_type = MfaConfig.effective_response_type(mfa_config, section_defaults.response_type)
    request_info = MfaConfig.effective_request_info(mfa_config, section_defaults.request_info)

    permission_callback =
      MfaConfig.effective_permission_callback(mfa_config, section_defaults.permission_callback)

    choose_node_mode =
      MfaConfig.effective_choose_node_mode(mfa_config, section_defaults.choose_node_mode)

    nodes = MfaConfig.effective_nodes(mfa_config, section_defaults.nodes)
    version = MfaConfig.effective_version(mfa_config, section_defaults.version)
    retry = MfaConfig.effective_retry(mfa_config, section_defaults.retry)

    # Resolve check_permission: use the mfa/section-level check_permission
    # when no permission_callback is set.
    check_permission =
      if permission_callback do
        false
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
      permission_callback: permission_callback,
      request_info: request_info,
      version: version,
      disabled: mfa_config.disabled,
      retry: retry,
      before_execute:
        MfaConfig.effective_before_execute(mfa_config, section_defaults.before_execute),
      after_execute:
        MfaConfig.effective_after_execute(mfa_config, section_defaults.after_execute),
      hook_timeout: MfaConfig.effective_hook_timeout(mfa_config, section_defaults.hook_timeout)
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
      explicit_arg_orders == :map and is_map(explicit_arg_types) and
          map_size(explicit_arg_types) > 0 ->
        {explicit_arg_types, :map}

      # Auto-derive from the Ash action definition — arg_orders defaults to :map
      true ->
        {arg_types, _arg_orders} = auto_derive_arg_config(resource, action_config.name, dsl_state)
        derived_arg_config(arg_types)
    end
  end

  # Actions with no inputs (e.g. update actions that accept no attributes
  # and declare no arguments). FunConfig rejects empty arg_types paired
  # with a non-empty arg_orders, and ArgumentHandler ignores arg_orders
  # when arg_types is empty (convert_args!/2 returns []), so [] is both
  # valid and behaviorally identical.
  defp derived_arg_config(arg_types) when map_size(arg_types) == 0, do: {%{}, []}

  defp derived_arg_config(arg_types), do: {arg_types, :map}

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
    action = ResourceAshInfo.action(dsl_state, action_name)

    if is_nil(action) do
      []
    else
      # Get accepted attributes
      accepted_attrs = accepted_attributes(action, dsl_state)

      # Get action arguments
      arguments = action.arguments || []

      # Build the field list: accepted attributes first, then arguments
      attr_fields =
        Enum.map(accepted_attrs, fn attr ->
          gen_api_type = TypeMapper.to_gen_api_type(attr.type, attr.constraints)
          default_val = TypeMapper.get_ash_default_value(attr)
          {attr.name, gen_api_type, attr.allow_nil?, default_val}
        end)

      arg_fields =
        Enum.map(arguments, fn arg ->
          gen_api_type = TypeMapper.to_gen_api_type(arg.type, arg.constraints)
          default_val = TypeMapper.get_ash_default_value(arg)
          {arg.name, gen_api_type, arg.allow_nil?, default_val}
        end)

      attr_fields ++ arg_fields
    end
  end

  # Resolves the accepted attributes of an Ash action, preserving order.
  #
  # Dialyzer believes `accept: :*` cannot occur given Ash's action types, but
  # actions created via `defaults [...]` do carry `accept: :*` at runtime.
  @dialyzer {:nowarn_function, accepted_attributes: 2}
  defp accepted_attributes(%{accept: :*}, dsl_state) do
    dsl_state
    |> Ash.Resource.Info.attributes()
    |> Enum.filter(& &1.public?)
  end

  defp accepted_attributes(%{accept: accept_list}, dsl_state) when is_list(accept_list) do
    accept_list
    |> Enum.map(&Ash.Resource.Info.attribute(dsl_state, &1))
    |> Enum.filter(& &1)
  end

  defp accepted_attributes(_action, _dsl_state), do: []

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
      bang_name = String.to_atom("#{action_name}!")

      result_encoder =
        ActionConfig.effective_result_encoder(action_config, section_defaults.result_encoder)

      build_interface(action_name, bang_name, ash_action.type,
        spec: interface_spec(ash_action.type),
        result_encoder: result_encoder
      )
    end
  end

  # Per-action-type specification for generated code interface functions.
  #
  #   - `record?` — whether the function takes a record as its first argument
  #   - `builder` — `{module, function}` building the input from
  #     `(target, action_name, args, opts)`
  #   - `runner` / `runner_bang` — `{module, function}` executing the built input
  #   - `params_doc` — description of the accepted params
  #   - `returns_doc` — newline-separated successful return values
  #   - `record_doc` — description of the record argument (when `record?`)
  defp interface_spec(:create) do
    %{
      record?: false,
      builder: {Changeset, :for_create},
      runner: {Ash, :create},
      runner_bang: {Ash, :create!},
      params_doc:
        "A map of arguments matching the action's accepted attributes and arguments,\n" <>
          "or a keyword list of options",
      returns_doc: "`{:ok, result}` on success\n`{:error, error}` on failure"
    }
  end

  defp interface_spec(:read) do
    %{
      record?: false,
      builder: {Query, :for_read},
      runner: {Ash, :read},
      runner_bang: {Ash, :read!},
      params_doc:
        "A map of arguments matching the action's arguments,\n" <>
          "or a keyword list of options",
      returns_doc: "`{:ok, results}` on success (list of records)\n`{:error, error}` on failure"
    }
  end

  defp interface_spec(:update) do
    %{
      record?: true,
      builder: {Changeset, :for_update},
      runner: {Ash, :update},
      runner_bang: {Ash, :update!},
      params_doc:
        "A map of arguments matching the action's accepted attributes and arguments,\n" <>
          "or a keyword list of options",
      returns_doc: "`{:ok, result}` on success\n`{:error, error}` on failure",
      record_doc: "The existing record to update"
    }
  end

  defp interface_spec(:destroy) do
    %{
      record?: true,
      builder: {Changeset, :for_destroy},
      runner: {Ash, :destroy},
      runner_bang: {Ash, :destroy!},
      params_doc:
        "A map of arguments matching the action's arguments,\n" <>
          "or a keyword list of options",
      returns_doc: "`:ok` on success\n`{:error, error}` on failure",
      record_doc: "The record to destroy"
    }
  end

  defp interface_spec(:action) do
    %{
      record?: false,
      builder: {ActionInput, :for_action},
      runner: {Ash, :run_action},
      runner_bang: {Ash, :run_action!},
      params_doc:
        "A map of arguments matching the action's arguments,\n" <>
          "or a keyword list of options",
      returns_doc: "`{:ok, result}` on success\n`{:error, error}` on failure"
    }
  end

  # Generates the regular and bang code interface functions for one action.
  defp build_interface(action_name, bang_name, action_type, opts) do
    spec = Keyword.fetch!(opts, :spec)

    result_encoder_escaped =
      opts |> Keyword.fetch!(:result_encoder) |> Macro.escape()

    head_args = interface_head_args(spec.record?)
    target = if spec.record?, do: quote(do: record), else: quote(do: __MODULE__)

    doc_string = interface_doc(action_name, action_type, spec)
    bang_doc_string = interface_bang_doc(action_name, action_type, spec)

    {builder_mod, builder_fun} = spec.builder
    {runner_mod, runner_fun} = spec.runner
    {runner_mod_bang, runner_fun_bang} = spec.runner_bang

    [
      quote do
        @doc unquote(doc_string)
        def unquote(action_name)(unquote_splicing(head_args)) do
          {args, opts} = Ash.CodeInterface.params_and_opts(params_or_opts, opts)

          unquote(builder_mod).unquote(builder_fun)(
            unquote(target),
            unquote(action_name),
            args,
            opts
          )
          |> unquote(runner_mod).unquote(runner_fun)(opts)
          |> AshPhoenixGenApi.Codec.encode_result(unquote(result_encoder_escaped))
        end
      end,
      quote do
        @doc unquote(bang_doc_string)
        def unquote(bang_name)(unquote_splicing(head_args)) do
          {args, opts} = Ash.CodeInterface.params_and_opts(params_or_opts, opts)

          unquote(builder_mod).unquote(builder_fun)(
            unquote(target),
            unquote(action_name),
            args,
            opts
          )
          |> unquote(runner_mod_bang).unquote(runner_fun_bang)(opts)
          |> AshPhoenixGenApi.Codec.encode_value(unquote(result_encoder_escaped))
        end
      end
    ]
  end

  defp interface_head_args(true) do
    [quote(do: record), quote(do: params_or_opts \\ []), quote(do: opts \\ [])]
  end

  defp interface_head_args(false) do
    [quote(do: params_or_opts \\ []), quote(do: opts \\ [])]
  end

  defp interface_doc(action_name, action_type, spec) do
    {builder_mod, builder_fun} = spec.builder
    {runner_mod, runner_fun} = spec.runner

    record_section =
      if spec.record? do
        "  - `record` - #{spec.record_doc}\n"
      else
        ""
      end

    ("Auto-generated code interface for the `:#{action_name}` gen_api action (#{action_type}).\n\n" <>
       "Calls `#{module_label(builder_mod)}.#{builder_fun}/4` then " <>
       "`#{module_label(runner_mod)}.#{runner_fun}/2`.\n\n" <>
       "## Parameters\n" <>
       record_section <>
       "  - `params_or_opts` - #{spec.params_doc}.\n" <>
       "    Uses `CodeInterface.params_and_opts/2` for disambiguation.\n" <>
       "  - `opts` - Keyword options passed to both `#{builder_fun}` and `#{runner_fun}`:\n" <>
       "    - `:actor` - The actor for authorization\n" <>
       "    - `:tenant` - The tenant for multitenancy\n" <>
       "    - `:authorize?` - Whether to run authorization\n" <>
       "    - Other Ash options\n\n" <>
       "## Returns\n" <>
       spec.returns_doc)
    |> String.split("\n")
    |> Enum.map_join("\n", &"  - #{&1}")
  end

  defp interface_bang_doc(action_name, action_type, spec) do
    arity = if spec.record?, do: 3, else: 2

    "Auto-generated code interface for the `:#{action_name}` gen_api action (#{action_type}).\n\n" <>
      "Same as `#{action_name}/#{arity}` but raises on error."
  end

  # Friendly alias-style label used in generated docs.
  defp module_label(Ash.Changeset), do: "Changeset"
  defp module_label(Ash.Query), do: "Query"
  defp module_label(Ash.ActionInput), do: "ActionInput"
  defp module_label(other), do: inspect(other)
end
