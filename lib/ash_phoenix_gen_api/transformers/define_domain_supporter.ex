defmodule AshPhoenixGenApi.Transformers.DefineDomainSupporter do
  @moduledoc """
  Transformer that generates the PhoenixGenApi supporter module for an Ash domain.

  This transformer reads the domain-level `gen_api` DSL configuration and generates
  a module that aggregates `FunConfig` structs from all resources in the domain
  that have the `AshPhoenixGenApi.Resource` extension configured.

  The generated supporter module implements the PhoenixGenApi client config interface,
  allowing gateway nodes to pull API configurations from service nodes.

  ## Generated Module

  Given a domain configuration like:

      defmodule MyApp.Chat do
        use Ash.Domain,
          extensions: [AshPhoenixGenApi.Domain]

        gen_api do
          service "chat"
          nodes {ClusterHelper, :get_nodes, [:chat]}
          supporter_module MyApp.Chat.GenApiSupporter
          version "0.0.1"
        end

        resources do
          resource MyApp.Chat.DirectMessage
          resource MyApp.Chat.GroupMessage
        end
      end

  This transformer generates:

      defmodule MyApp.Chat.GenApiSupporter do
        @moduledoc \"\"\"
        Auto-generated PhoenixGenApi supporter module for MyApp.Chat.

        Aggregates FunConfigs from all resources in the domain that have
        the AshPhoenixGenApi.Resource extension configured.

        ## Functions

        - `get_config/1` - Returns `{:ok, fun_configs()}` for PhoenixGenApi pull
        - `get_config_version/1` - Returns `{:ok, version}` for version checking
        - `fun_configs/0` - Returns the aggregated list of FunConfig structs
        - `list_request_types/0` - Returns all available request type strings
        - `get_fun_config/1` - Returns a specific FunConfig by request_type
        \"\"\"

        alias PhoenixGenApi.Structs.FunConfig

        require Logger

        @doc \"\"\"
        Support for remote pull general api config.
        Returns {:ok, list_of_fun_configs}
        \"\"\"
        def get_config(remote_id) do
          Logger.info("Get config from remote: \#{inspect(remote_id)}")
          {:ok, fun_configs()}
        end

        @doc \"\"\"
        Support for remote pull general api config version.
        \"\"\"
        def get_config_version(remote_id) do
          Logger.info("Get config version from remote: \#{inspect(remote_id)}")
          {:ok, "0.0.1"}
        end

        @doc \"\"\"
        Return list of %FunConfig{} for all APIs in this domain.
        \"\"\"
        def fun_configs do
          MyApp.Chat.DirectMessage.__ash_phoenix_gen_api_fun_configs__() ++
            MyApp.Chat.GroupMessage.__ash_phoenix_gen_api_fun_configs__()
        end

        @doc \"\"\"
        Get a specific function configuration by request_type.
        \"\"\"
        def get_fun_config(request_type) do
          fun_configs()
          |> Enum.find(&(&1.request_type == request_type))
        end

        @doc \"\"\"
        Get all available request types.
        \"\"\"
        def list_request_types do
          fun_configs()
          |> Enum.map(& &1.request_type)
        end
      end

  ## Push Configuration Functions

  When `push_nodes` is configured, the generated supporter module also includes
  functions for actively pushing configuration to gateway nodes:

      gen_api do
        service "chat"
        supporter_module MyApp.Chat.GenApiSupporter
        version "0.0.1"
        push_nodes [:"gateway1@host", :"gateway2@host"]
        # Or use an MFA tuple for runtime resolution:
        # push_nodes {ClusterHelper, :get_gateway_nodes, []}
      end

  This adds the following functions to the generated supporter module:

      # Builds a PushConfig struct from the domain configuration
      def build_push_config do
        # Resolves nodes at runtime (calls MFA if configured)
        # Returns %PushConfig{service: "chat", nodes: [...], ...}
      end

      # Pushes config to a specific gateway node
      def push_to_gateway(server_node, opts \\ [])

      # Pushes config on application startup (with enhanced logging)
      def push_on_startup(server_node, opts \\ [])

      # Verifies config version on a gateway node
      def verify_on_gateway(server_node, opts \\ [])

      # Resolves push_nodes at runtime (handles MFA tuples, lists, :local, nil)
      def resolve_push_nodes

      # Pushes config to all configured push_nodes
      def push_to_configured_nodes(opts \\ [])

  ## Configuration

  The `define_supporter?` option controls whether the supporter module is
  auto-generated. Set it to `false` if you want to define the module manually
  (e.g., when you need to add custom logic or merge configs from non-Ash sources).

  When `define_supporter?` is `false`, you can still use
  `AshPhoenixGenApi.Domain.Info.fun_configs/1` to get the aggregated FunConfigs
  and build your own supporter module.
  """

  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer, as: SparkTransformer
  alias Ash.Domain.Info, as: DomainInfo
  alias AshPhoenixGenApi.Domain.Info

  @doc """
  Runs after the DefineFunConfigs transformer so that resource FunConfigs
  are already generated.
  """
  # @impl true
  # def after?(_), do: true

  @impl true
  def after?(AshPhoenixGenApi.Transformers.DefineFunConfigs), do: true
  def after?(_), do: true

  @doc """
  Does not need to run before any specific transformer.
  """
  @impl true
  def before?(_), do: false

  @impl true
  def transform(dsl_state) do
    resources =
      SparkTransformer.get_entities(dsl_state, [:resources])

    Enum.each(resources, fn resource_info -> Code.ensure_compiled(resource_info.resource) end)


    domain = SparkTransformer.get_persisted(dsl_state, :module)

    # Check if gen_api is configured on this domain
    supporter_module = extract_opt(Info.gen_api_supporter_module(dsl_state), nil)
    define_supporter? = extract_opt(Info.gen_api_define_supporter?(dsl_state), true)

    if is_nil(supporter_module) do
      # No gen_api configured on this domain — skip
      {:ok, dsl_state}
    else
      if define_supporter? do
          version = extract_opt(Info.gen_api_version(dsl_state), "0.0.1")
          service = extract_opt(Info.gen_api_service(dsl_state), nil)
          push_nodes = extract_opt(Info.gen_api_push_nodes(dsl_state), nil)

          # We use runtime resource discovery instead of compile-time enumeration
          # because resource modules may not be fully compiled when the domain
          # transformer runs (e.g. when both are defined in the same test file).
          # The generated fun_configs/0 function will discover resources at
          # runtime by querying the domain and checking for the
          # __ash_phoenix_gen_api_fun_configs__/0 export.

          version_string = version || "0.0.1"
          service_string = if is_atom(service), do: Atom.to_string(service), else: service

          domain_escaped = Macro.escape(domain)
          service_string_escaped = Macro.escape(service_string)
          version_string_escaped = Macro.escape(version_string)
          push_nodes_escaped = Macro.escape(push_nodes)

          dsl_state =
            SparkTransformer.eval(
              dsl_state,
              [],
              generate_supporter_module(
                domain_escaped,
                service_string_escaped,
                version_string_escaped,
                push_nodes_escaped,
                supporter_module
              )
            )

          {:ok, dsl_state}
      else
        # define_supporter? is false — skip module generation
        {:ok, dsl_state}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # The `fun_configs/0` function is now generated inline in the supporter
  # module definition above, using runtime resource discovery instead of
  # compile-time enumeration. This avoids issues where resource modules
  # may not be fully compiled when the domain transformer runs.
  #
  # The previous approach used `generate_fun_configs_body/1` to build a
  # `def fun_configs do ... end` AST at compile time, but that required
  # knowing the list of resources with gen_api at compile time, which is
  # unreliable when resources and domains are compiled in the same run.
  #
  # The runtime approach:
  #   1. Calls `Ash.Domain.Info.resources(domain)` to get all resources
  #   2. Filters those that export `__ash_phoenix_gen_api_fun_configs__/0`
  #   3. Calls that function on each and concatenates with `Enum.flat_map/2`
  #
  # This is slightly slower at runtime but much more robust at compile time.

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Extracts a value from a Spark.InfoGenerator result.
  # Spark.InfoGenerator generates two versions of each accessor:
  # - `gen_api_foo/1` returns `{:ok, value}` or `:error`
  # - `gen_api_foo!/1` returns the value or raises
  # - Predicate functions (ending with `?`) return the value directly
  #
  # This helper unwraps the `{:ok, value}` tuple, falls back to the
  # provided default when the option is not configured (`:error`),
  # and also passes through direct values (for predicate functions).
  defp extract_opt({:ok, value}, _default), do: value
  defp extract_opt(:error, default), do: default
  defp extract_opt(value, _default) when not is_tuple(value), do: value

  # ---------------------------------------------------------------------------
  # Supporter module generation helpers
  # ---------------------------------------------------------------------------

  defp generate_supporter_module(domain_escaped, service_string_escaped, version_string_escaped, push_nodes_escaped, supporter_module) do
    quote do
      defmodule unquote(supporter_module) do
        unquote(generate_moduledoc(domain_escaped, service_string_escaped, version_string_escaped))

        alias PhoenixGenApi.Structs.FunConfig

        require Logger

        unquote(generate_get_config_functions(version_string_escaped))
        unquote(generate_fun_config_functions(domain_escaped))
        unquote(generate_push_config_functions(service_string_escaped, version_string_escaped, push_nodes_escaped))
      end
    end
  end

  defp generate_moduledoc(domain_escaped, service_string_escaped, version_string_escaped) do
    quote do
      @moduledoc """
      Auto-generated PhoenixGenApi supporter module for #{unquote(domain_escaped)}.

      Aggregates FunConfigs from all resources in the domain that have
      the AshPhoenixGenApi.Resource extension configured.

      ## Functions

      - `get_config/1` - Returns `{:ok, fun_configs()}` for PhoenixGenApi pull
      - `get_config_version/1` - Returns `{:ok, version}` for version checking
      - `fun_configs/0` - Returns the aggregated list of FunConfig structs
      - `list_request_types/0` - Returns all available request type strings
      - `get_fun_config/1` - Returns a specific FunConfig by request_type
      - `build_push_config/0` - Builds a PushConfig struct from this domain's configuration
      - `push_to_gateway/2` - Pushes config to a specified gateway node
      - `push_on_startup/2` - Pushes config to a gateway node on startup
      - `verify_on_gateway/2` - Verifies config version on a gateway node
      - `resolve_push_nodes/0` - Resolves push_nodes configuration at runtime
      - `push_to_configured_nodes/1` - Pushes config to all configured push_nodes

      ## Configuration

      Service: `#{unquote(service_string_escaped)}`
      Version: `#{unquote(version_string_escaped)}`
      Resources: discovered at runtime via `DomainInfo.resources/1`
      """
    end
  end

  defp generate_get_config_functions(version_string_escaped) do
    quote do
      @doc """
      Support for remote pull general api config.
      Returns {:ok, list_of_fun_configs}
      """
      def get_config(remote_id) do
        Logger.info("Get config from remote: #{inspect(remote_id)}")
        {:ok, fun_configs()}
      end

      @doc """
      Support for remote pull general api config version.
      """
      def get_config_version(remote_id) do
        Logger.info("Get config version from remote: #{inspect(remote_id)}")
        {:ok, unquote(version_string_escaped)}
      end
    end
  end

  defp generate_fun_config_functions(domain_escaped) do
    quote do
      @doc """
      Return list of %FunConfig{} for all APIs in this domain.

      Discovers resources at runtime by querying the domain and
      filtering those that export `__ash_phoenix_gen_api_fun_configs__/0`.
      This ensures correct behaviour even when resources are compiled
      after the domain module.
      """
      def fun_configs do
        unquote(domain_escaped)
        |> DomainInfo.resources()
        |> Enum.filter(fn resource ->
          Code.ensure_loaded(resource)
          function_exported?(resource, :__ash_phoenix_gen_api_fun_configs__, 0)
        end)
        |> Enum.flat_map(fn resource ->
          resource.__ash_phoenix_gen_api_fun_configs__()
        end)
      end

      @doc """
      Get a specific function configuration by request_type.
      """
      def get_fun_config(request_type) do
        fun_configs()
        |> Enum.find(&(&1.request_type == request_type))
      end

      @doc """
      Get all available request types.
      """
      def list_request_types do
        fun_configs()
        |> Enum.map(& &1.request_type)
      end
    end
  end

  defp generate_push_config_functions(service_string_escaped, version_string_escaped, push_nodes_escaped) do
    quote do
      @doc """
      Builds a PushConfig struct from this domain's configuration.

      The `nodes` field is resolved at runtime:
      - If `push_nodes` is an MFA tuple, it is called to get the node list
      - If `push_nodes` is a list, it is used directly
      - If `push_nodes` is `:local`, `[Node.self()]` is used
      - If `push_nodes` is `nil`, the nodes field is set to `nil`
      """
      def build_push_config do
        resolved_nodes =
          case unquote(push_nodes_escaped) do
            nil -> nil
            :local -> [Node.self()]
            nodes when is_list(nodes) -> nodes
            {mod, fun, args} when is_atom(mod) and is_atom(fun) and is_list(args) ->
              apply(mod, fun, args)
            _ -> nil
          end

        struct(PhoenixGenApi.Structs.PushConfig, %{
          service: unquote(service_string_escaped),
          nodes: resolved_nodes,
          config_version: unquote(version_string_escaped),
          fun_configs: fun_configs(),
          module: __MODULE__,
          function: :get_config,
          args: [],
          version_module: __MODULE__,
          version_function: :get_config_version,
          version_args: []
        })
      end

      unquote(generate_gateway_functions(service_string_escaped, version_string_escaped, push_nodes_escaped))
    end
  end

  defp generate_gateway_functions(service_string_escaped, version_string_escaped, push_nodes_escaped) do
    quote do
      @doc """
      Pushes this domain's configuration to the specified gateway node.

      ## Parameters

        - `server_node` - The gateway node atom to push config to
        - `opts` - Options passed to `PhoenixGenApi.ConfigPusher.push/3`

      ## Returns

        The result of `PhoenixGenApi.ConfigPusher.push/3`.
      """
      def push_to_gateway(server_node, opts \\ []) do
        push_config = build_push_config()
        PhoenixGenApi.ConfigPusher.push(server_node, push_config, opts)
      end

      @doc """
      Pushes this domain's configuration to the specified gateway node on startup.

      This is intended to be called during application startup to push
      the config to gateway nodes. The push is performed asynchronously
      and will retry according to the `PhoenixGenApi.ConfigPusher` configuration.

      ## Parameters

        - `server_node` - The gateway node atom to push config to
        - `opts` - Options passed to `PhoenixGenApi.ConfigPusher.push_on_startup/3`

      ## Returns

        The result of `PhoenixGenApi.ConfigPusher.push_on_startup/3`.
      """
      def push_on_startup(server_node, opts \\ []) do
        push_config = build_push_config()
        PhoenixGenApi.ConfigPusher.push_on_startup(server_node, push_config, opts)
      end

      @doc """
      Verifies this domain's configuration version on the gateway node.

      ## Parameters

        - `server_node` - The gateway node atom to verify config on
        - `opts` - Options passed to `PhoenixGenApi.ConfigPusher.verify/4`

      ## Returns

        The result of `PhoenixGenApi.ConfigPusher.verify/4`.
      """
      def verify_on_gateway(server_node, opts \\ []) do
        PhoenixGenApi.ConfigPusher.verify(
          server_node,
          unquote(service_string_escaped),
          unquote(version_string_escaped),
          opts
        )
      end

      unquote(generate_resolve_push_nodes(push_nodes_escaped))

      unquote(generate_push_to_configured_nodes())
    end
  end

  defp generate_resolve_push_nodes(push_nodes_escaped) do
    quote do
      @doc """
      Resolves the push_nodes configuration at runtime.

      Returns a list of node atoms based on the configured `push_nodes`:
      - If `push_nodes` is an MFA tuple `{Module, :function, args}`, calls it and returns the result
      - If `push_nodes` is a list of atoms, returns it directly
      - If `push_nodes` is `:local`, returns `[Node.self()]`
      - If `push_nodes` is `nil`, returns `nil`
      """
      def resolve_push_nodes do
        case unquote(push_nodes_escaped) do
          nil -> nil
          :local -> [Node.self()]
          nodes when is_list(nodes) -> nodes
          {mod, fun, args} when is_atom(mod) and is_atom(fun) and is_list(args) ->
            apply(mod, fun, args)
          _ -> nil
        end
      end
    end
  end

  defp generate_push_to_configured_nodes() do
    quote do
      @doc """
      Pushes config to all configured push_nodes.

      Resolves the `push_nodes` configuration at runtime and pushes
      the config to each node.

      ## Parameters

        - `opts` - Options passed to `push_to_gateway/2`

      ## Returns

        - `{:ok, results}` - A list of results from each push operation
        - `{:error, :no_push_nodes_configured}` - When no push_nodes are configured
      """
      def push_to_configured_nodes(opts \\ []) do
        case resolve_push_nodes() do
          nil ->
            {:error, :no_push_nodes_configured}

          nodes ->
            results = Enum.map(nodes, fn node -> push_to_gateway(node, opts) end)
            {:ok, results}
        end
      end
    end
  end
end
