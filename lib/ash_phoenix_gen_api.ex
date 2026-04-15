defmodule AshPhoenixGenApi do
  @moduledoc """
  Ash extension for generating PhoenixGenApi function configurations from Ash resources.

  `AshPhoenixGenApi` bridges the Ash Framework and PhoenixGenApi by allowing you to
  define PhoenixGenApi endpoints directly in your Ash resource and domain DSLs. It
  automatically generates `PhoenixGenApi.Structs.FunConfig` structs from your Ash
  actions, including type mappings, argument ordering, and configuration defaults.

  ## Architecture

  The extension consists of two main parts:

  ### Resource Extension (`AshPhoenixGenApi.Resource`)

  Added to Ash resources to define which actions should be exposed as PhoenixGenApi
  endpoints. Each action is configured with routing, timeout, permission, and other
  settings.

  ### Domain Extension (`AshPhoenixGenApi.Domain`)

  Added to Ash domains to provide domain-level defaults and auto-generate a
  "supporter" module that aggregates FunConfigs from all resources in the domain.
  The supporter module implements the PhoenixGenApi client config interface
  (`get_config/1`, `get_config_version/1`), allowing gateway nodes to pull API
  configurations from service nodes.

  ## Quick Start

  ### 1. Add the extensions to your resource and domain

      # In your resource:
      defmodule MyApp.Chat.DirectMessage do
        use Ash.Resource,
          extensions: [AshPhoenixGenApi.Resource]

        gen_api do
          service "chat"
          nodes {ClusterHelper, :get_nodes, [:chat]}
          choose_node_mode :random
          timeout 5_000
          response_type :async
          request_info true

          action :send_direct_message do
            request_type "send_direct_message"
            timeout 10_000
            check_permission {:arg, "from_user_id"}
          end

          action :get_conversation do
            timeout 5_000
          end

          action :create do
            # Minimal config — request_type and args are auto-derived
          end
        end

        attributes do
          uuid_primary_key :id
          attribute :from_user_id, :uuid
          attribute :to_user_id, :uuid
          attribute :content, :string
          attribute :reply_to_id, :uuid
          attribute :file_id, :uuid
        end

        actions do
          create :create do
            accept [:from_user_id, :to_user_id, :content, :reply_to_id, :file_id]
          end

          read :read do
            primary? true
          end
        end
      end

      # In your domain:
      defmodule MyApp.Chat do
        use Ash.Domain,
          extensions: [AshPhoenixGenApi.Domain]

        gen_api do
          service "chat"
          nodes {ClusterHelper, :get_nodes, [:chat]}
          choose_node_mode :random
          version "0.0.1"
          supporter_module MyApp.Chat.GenApiSupporter
        end

        resources do
          resource MyApp.Chat.DirectMessage
          resource MyApp.Chat.GroupMessage
        end
      end

  ### 2. The supporter module is auto-generated

  After compilation, `MyApp.Chat.GenApiSupporter` will be available with:

      # Get all FunConfigs (for PhoenixGenApi pull)
      MyApp.Chat.GenApiSupporter.fun_configs()
      #=> [%PhoenixGenApi.Structs.FunConfig{request_type: "send_direct_message", ...}, ...]

      # Get config for remote pull
      MyApp.Chat.GenApiSupporter.get_config(:gateway_1)
      #=> {:ok, [%PhoenixGenApi.Structs.FunConfig{...}, ...]}

      # Get config version
      MyApp.Chat.GenApiSupporter.get_config_version(:gateway_1)
      #=> {:ok, "0.0.1"}

      # Find a specific FunConfig by request_type
      MyApp.Chat.GenApiSupporter.get_fun_config("send_direct_message")
      #=> %PhoenixGenApi.Structs.FunConfig{request_type: "send_direct_message", ...}

      # List all request types
      MyApp.Chat.GenApiSupporter.list_request_types()
      #=> ["send_direct_message", "get_conversation", ...]

  ### 3. Configure the gateway node

  On the Phoenix gateway node, configure `phoenix_gen_api` in `config.exs`:

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

  ## Type Mapping

  Ash types are automatically mapped to PhoenixGenApi argument types:

  | Ash Type | PhoenixGenApi Type |
  |----------|-------------------|
  | `:string`, `:uuid`, `:boolean`, `:date`, etc. | `:string` |
  | `:integer`, `:float`, `:decimal` | `:num` |
  | `{:array, :string}`, `{:array, :uuid}` | `{:list_string, max_items, max_item_length}` |
  | `{:array, :integer}`, `{:array, :float}` | `{:list_num, max_items}` |

  See `AshPhoenixGenApi.TypeMapper` for the complete mapping table.

  ## Resolution Order

  Configuration values are resolved in this order (highest priority first):

  1. **Action-level explicit config** — e.g., `action :foo do timeout 10_000 end`
  2. **Resource section-level defaults** — e.g., `gen_api do timeout 5_000 end`
  3. **Domain section-level defaults** — e.g., `gen_api do timeout 5_000 end`
  4. **Built-in defaults** — e.g., timeout defaults to `5000`

  ## Modules

  - `AshPhoenixGenApi.Resource` — Resource-level DSL extension
  - `AshPhoenixGenApi.Resource.Info` — Resource introspection helpers
  - `AshPhoenixGenApi.Resource.ActionConfig` — Action configuration struct
  - `AshPhoenixGenApi.Domain` — Domain-level DSL extension
  - `AshPhoenixGenApi.Domain.Info` — Domain introspection helpers
  - `AshPhoenixGenApi.TypeMapper` — Ash type to PhoenixGenApi type mapping
  - `AshPhoenixGenApi.Transformers.DefineFunConfigs` — Resource transformer
  - `AshPhoenixGenApi.Transformers.DefineDomainSupporter` — Domain transformer
  - `AshPhoenixGenApi.Verifiers.VerifyActionConfigs` — Resource verifier
  - `AshPhoenixGenApi.Verifiers.VerifyDomainConfig` — Domain verifier
  """

  @doc """
  Lists all modules that are part of the AshPhoenixGenApi extension.

  Returns a list of module atoms for the resource extension, domain extension,
  and their supporting modules.

  ## Examples

      iex> AshPhoenixGenApi.modules()
      [
        AshPhoenixGenApi.Resource,
        AshPhoenixGenApi.Resource.Info,
        AshPhoenixGenApi.Resource.ActionConfig,
        AshPhoenixGenApi.Domain,
        AshPhoenixGenApi.Domain.Info,
        AshPhoenixGenApi.TypeMapper,
        ...
      ]
  """
  @spec modules() :: [module()]
  def modules do
    [
      AshPhoenixGenApi.Resource,
      AshPhoenixGenApi.Resource.Info,
      AshPhoenixGenApi.Resource.ActionConfig,
      AshPhoenixGenApi.Domain,
      AshPhoenixGenApi.Domain.Info,
      AshPhoenixGenApi.TypeMapper,
      AshPhoenixGenApi.Transformers.DefineFunConfigs,
      AshPhoenixGenApi.Transformers.DefineDomainSupporter,
      AshPhoenixGenApi.Verifiers.VerifyActionConfigs,
      AshPhoenixGenApi.Verifiers.VerifyDomainConfig
    ]
  end

  @doc """
  Returns the list of Spark DSL extensions provided by AshPhoenixGenApi.

  These are the extensions you add to your Ash resources and domains:

  - `AshPhoenixGenApi.Resource` — Add to Ash resources
  - `AshPhoenixGenApi.Domain` — Add to Ash domains

  ## Examples

      iex> AshPhoenixGenApi.extensions()
      [AshPhoenixGenApi.Resource, AshPhoenixGenApi.Domain]
  """
  @spec extensions() :: [module()]
  def extensions do
    [
      AshPhoenixGenApi.Resource,
      AshPhoenixGenApi.Domain
    ]
  end

  @doc """
  Returns the built-in defaults for the gen_api DSL section.

  These defaults are used when no explicit value is provided at any level:

  - `timeout` — `5000` (5 seconds)
  - `response_type` — `:async`
  - `request_info` — `true`
  - `check_permission` — `false`
  - `choose_node_mode` — `:random`
  - `nodes` — `:local`
  - `version` — `"0.0.1"`
  - `retry` — `nil` (no retry)
  """
  @spec defaults() :: map()
  def defaults do
    %{
      timeout: 5_000,
      response_type: :async,
      request_info: true,
      check_permission: false,
      choose_node_mode: :random,
      nodes: :local,
      version: "0.0.1",
      retry: nil
    }
  end

  @doc """
  Returns the version of the AshPhoenixGenApi library.
  """
  @spec version() :: String.t()
  def version do
    unquote(Mix.Project.config()[:version] || "0.1.0")
  end
end
