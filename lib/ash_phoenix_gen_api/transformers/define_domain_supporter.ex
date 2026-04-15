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

  ## Configuration

  The `define_supporter?` option controls whether the supporter module is
  auto-generated. Set it to `false` if you want to define the module manually
  (e.g., when you need to add custom logic or merge configs from non-Ash sources).

  When `define_supporter?` is `false`, you can still use
  `AshPhoenixGenApi.Domain.Info.fun_configs/1` to get the aggregated FunConfigs
  and build your own supporter module.
  """

  use Spark.Dsl.Transformer

  alias AshPhoenixGenApi.Domain.Info

  @doc """
  Runs after the DefineFunConfigs transformer so that resource FunConfigs
  are already generated.
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
    domain = Spark.Dsl.Transformer.get_persisted(dsl_state, :module)

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

        dsl_state =
          Spark.Dsl.Transformer.eval(
            dsl_state,
            [],
            quote do
              defmodule unquote(supporter_module) do
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

                ## Configuration

                Service: `#{unquote(service_string_escaped)}`
                Version: `#{unquote(version_string_escaped)}`
                Resources: discovered at runtime via `Ash.Domain.Info.resources/1`
                """

                alias PhoenixGenApi.Structs.FunConfig

                require Logger

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

                @doc """
                Return list of %FunConfig{} for all APIs in this domain.

                Discovers resources at runtime by querying the domain and
                filtering those that export `__ash_phoenix_gen_api_fun_configs__/0`.
                This ensures correct behaviour even when resources are compiled
                after the domain module.
                """
                def fun_configs do
                  unquote(domain_escaped)
                  |> Ash.Domain.Info.resources()
                  |> Enum.filter(fn resource ->
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
end
