defmodule AshPhoenixGenApi.Domain do
  @moduledoc """
  Ash Domain extension for PhoenixGenApi configuration.

  This extension provides domain-level configuration for PhoenixGenApi,
  including default service settings and automatic generation of a
  "supporter" module that aggregates FunConfigs from all resources
  in the domain.

  The generated supporter module implements the `PhoenixGenApi` client
  config interface (`get_config/1`, `get_config_version/1`), allowing
  gateway nodes to pull API configurations from service nodes.

  ## Usage

  Add the extension to your Ash domain:

      defmodule MyApp.Chat do
        use Ash.Domain,
          extensions: [AshPhoenixGenApi.Domain]

        gen_api do
          service "chat"
          nodes {ClusterHelper, :get_nodes, [:chat]}
          choose_node_mode :random
          timeout 5_000
          response_type :async
          request_info true
          version "0.0.1"

          supporter_module MyApp.Chat.GenApiSupporter
        end

        resources do
          resource MyApp.Chat.DirectMessage
          resource MyApp.Chat.GroupMessage
        end
      end

  This will generate `MyApp.Chat.GenApiSupporter` with:

      defmodule MyApp.Chat.GenApiSupporter do
        @moduledoc \"\"\"
        Auto-generated PhoenixGenApi supporter module for MyApp.Chat.
        Aggregates FunConfigs from all resources in the domain.
        \"\"\"

        alias PhoenixGenApi.Structs.FunConfig

        def get_config(remote_id) do
          {:ok, fun_configs()}
        end

        def get_config_version(remote_id) do
          {:ok, "0.0.1"}
        end

        def fun_configs do
          MyApp.Chat.DirectMessage.__ash_phoenix_gen_api_fun_configs__() ++
            MyApp.Chat.GroupMessage.__ash_phoenix_gen_api_fun_configs__()
        end

        def list_request_types do
          fun_configs() |> Enum.map(& &1.request_type)
        end

        def get_fun_config(request_type) do
          fun_configs() |> Enum.find(&(&1.request_type == request_type))
        end
      end

  ## Domain-Level Defaults

  Domain-level settings serve as defaults for all resources in the domain
  that use `AshPhoenixGenApi.Resource`. Each resource can override these
  defaults in its own `gen_api` section.

  Resolution order for any setting:
  1. Resource action-level (e.g., `action :foo do timeout 10_000 end`)
  2. Resource section-level (e.g., `gen_api do timeout 5_000 end`)
  3. Domain section-level (this extension, e.g., `gen_api do timeout 5_000 end`)
  4. Built-in defaults (e.g., timeout defaults to 5000)

  ## Gateway Node Configuration

  On the Phoenix gateway node, configure the supporter module in `config.exs`:

      config :phoenix_gen_api, :gen_api,
        service_configs: [
          %{
            service: "chat",
            nodes: {ClusterHelper, :get_nodes, [:chat]},
            module: MyApp.Chat.GenApiSupporter,
            function: :get_config,
            args: [:gateway_1]
          }
        ]
  """

  @gen_api %Spark.Dsl.Section{
    name: :gen_api,
    describe: """
    Configure PhoenixGenApi at the domain level.

    Domain-level settings serve as defaults for all resources in the domain
    that use `AshPhoenixGenApi.Resource`. Each resource can override these
    defaults in its own `gen_api` section.

    The `supporter_module` option defines the name of the module that will
    be auto-generated to aggregate FunConfigs from all resources. This module
    implements the PhoenixGenApi client config interface.
    """,
    examples: [
      """
      gen_api do
        service "chat"
        nodes {ClusterHelper, :get_nodes, [:chat]}
        choose_node_mode :random
        timeout 5_000
        response_type :async
        request_info true
        version "0.0.1"
        supporter_module MyApp.Chat.GenApiSupporter
      end
      """,
      """
      # Minimal configuration
      gen_api do
        service "chat"
        supporter_module MyApp.Chat.GenApiSupporter
      end
      """
    ],
    schema: [
      service: [
        type: :any,
        doc: """
        The service name for this domain's API endpoints.
        This serves as the default for all resources in the domain.

        Accepts a string or atom.
        Example: `"chat"`, `"user_service"`, `:notification`
        """
      ],
      nodes: [
        type: :any,
        default: :local,
        doc: """
        Default target nodes for all resources in this domain.

        Can be:
        - A list of node atoms: `[:"node1@host", :"node2@host"]`
        - An MFA tuple that returns a node list at runtime: `{ClusterHelper, :get_nodes, [:chat]}`
        - `:local` - Execute on the local node (default)
        """
      ],
      choose_node_mode: [
        type: :any,
        default: :random,
        doc: """
        Default node selection strategy for all resources in this domain.

        - `:random` - Select a random node (default)
        - `:hash` - Hash-based selection using request_type
        - `{:hash, key}` - Hash-based selection using the specified argument key
        - `:round_robin` - Round-robin across nodes
        """
      ],
      timeout: [
        type: :any,
        default: 5_000,
        doc: """
        Default timeout in milliseconds for all resources in this domain.
        Individual resources and actions can override this.

        Accepts a positive integer or `:infinity`.
        """
      ],
      response_type: [
        type: :atom,
        default: :async,
        doc: """
        Default response mode for all resources in this domain.

        - `:sync` - Client waits for the result
        - `:async` - Client receives an ack, then the result later (default)
        - `:stream` - Client receives streamed chunks
        - `:none` - Fire and forget
        """
      ],
      request_info: [
        type: :boolean,
        default: true,
        doc: """
        Default for whether to pass request info (user_id, device_id, request_id)
        as the last argument to the MFA function for all resources in this domain.
        """
      ],
      check_permission: [
        type: :any,
        default: false,
        doc: """
        Default permission check mode for all resources in this domain.

        - `false` - No permission check (default)
        - `:any_authenticated` - Requires a valid user_id
        - `{:arg, "arg_name"}` - The specified argument must match user_id
        - `{:role, ["admin"]}` - User must have one of the listed roles
        """
      ],
      version: [
        type: :string,
        default: "0.0.1",
        doc: """
        Default version string for all resources in this domain.
        Used for PhoenixGenApi API versioning.
        """
      ],
      retry: [
        type: :any,
        doc: """
        Default retry configuration for all resources in this domain.

        - `nil` - No retry (default)
        - A positive number `n` - Equivalent to `{:all_nodes, n}`
        - `{:same_node, n}` - Retry on the same node(s)
        - `{:all_nodes, n}` - Retry across all available nodes
        """
      ],
      supporter_module: [
        type: :atom,
        required: true,
        doc: """
        The name of the module to generate that will serve as the PhoenixGenApi
        supporter for this domain.

        This module will be auto-generated with functions:
        - `get_config/1` - Returns `{:ok, fun_configs()}` for PhoenixGenApi pull
        - `get_config_version/1` - Returns `{:ok, version}` for version checking
        - `fun_configs/0` - Returns the aggregated list of FunConfig structs
        - `list_request_types/0` - Returns all available request type strings
        - `get_fun_config/1` - Returns a specific FunConfig by request_type

        Example: `MyApp.Chat.GenApiSupporter`
        """
      ],
      define_supporter?: [
        type: :boolean,
        default: true,
        doc: """
        Whether to auto-generate the supporter module. Set to `false` if you
        want to define the supporter module manually.

        When `false`, the extension will still collect FunConfigs from resources
        but will not generate the supporter module. You can use
        `AshPhoenixGenApi.Domain.Info.fun_configs/1` to get the aggregated
        FunConfigs and build your own supporter module.
        """
      ]
    ]
  }

  use Spark.Dsl.Extension,
    verifiers: [
      AshPhoenixGenApi.Verifiers.VerifyDomainConfig
    ],
    transformers: [
      AshPhoenixGenApi.Transformers.DefineDomainSupporter
    ],
    sections: [@gen_api]
end
