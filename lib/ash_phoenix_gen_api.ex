defmodule AshPhoenixGenApi do
  @moduledoc """
  Ash extension for generating PhoenixGenApi function configurations from Ash resources.

  `AshPhoenixGenApi` bridges the Ash Framework and PhoenixGenApi by allowing you to
  define PhoenixGenApi endpoints directly in your Ash resource and domain DSLs. It
  automatically generates `PhoenixGenApi.Structs.FunConfig` structs from your Ash
  actions, including type mappings, argument ordering, and configuration defaults.

  ## Architecture

  ### Resource Extension (`AshPhoenixGenApi.Resource`)

  Added to Ash resources to define which actions should be exposed as PhoenixGenApi
  endpoints. Each action is configured with routing, timeout, permission, and other
  settings.

  ### Domain Extension (`AshPhoenixGenApi.Domain`)

  Added to Ash domains to provide domain-level defaults and auto-generate a
  "supporter" module that aggregates FunConfigs from all resources. The supporter
  module implements the PhoenixGenApi client config interface (`get_config/1`,
  `get_config_version/1`), allowing gateway nodes to pull API configurations.

  ## Quick Start

      # In your resource:
      defmodule MyApp.Chat.DirectMessage do
        use Ash.Resource,
          extensions: [AshPhoenixGenApi.Resource]

        gen_api do
          service "chat"
          nodes {ClusterHelper, :get_nodes, [:chat]}
          choose_node_mode :random
          timeout 5_000

          action :send_direct_message do
            request_type "send_direct_message"
            timeout 10_000
            check_permission {:arg, "from_user_id"}
          end

          action :create do
            # Minimal config — request_type and args are auto-derived
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
          version "0.0.1"
          supporter_module MyApp.Chat.GenApiSupporter
        end

        resources do
          resource MyApp.Chat.DirectMessage
        end
      end

      # The supporter module is auto-generated:
      MyApp.Chat.GenApiSupporter.fun_configs()
      MyApp.Chat.GenApiSupporter.get_config(:gateway_1)
      MyApp.Chat.GenApiSupporter.get_config_version(:gateway_1)

      # On the gateway node (config.exs):
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
  | `:string`, `:uuid`, `:date`, etc. | `:string` |
  | `{:string, max_length}` | `{:string, max_bytes}` |
  | `:integer`, `:float`, `:decimal` | `:num` |
  | `:boolean` | `:boolean` |
  | `:datetime`, `:utc_datetime` | `:datetime` |
  | `:naive_datetime` | `:naive_datetime` |
  | `:map`, `:json`, `:struct`, `:keyword` | `:map` |
  | `{:map, max_items}` | `{:map, max_items}` |
  | `{:array, :string}`, `{:array, :uuid}` | `{:list_string, max_items, max_item_length}` |
  | `{:array, :integer}`, `{:array, :float}` | `{:list_num, max_items}` |
  | `{:array, :map}`, `{:array, :boolean}`, etc. | `{:list, max_items}` |

  See `AshPhoenixGenApi.TypeMapper` for the complete mapping table.

  ## Modules

  - `AshPhoenixGenApi.Resource` — Resource-level DSL extension
  - `AshPhoenixGenApi.Resource.Info` — Resource introspection helpers
  - `AshPhoenixGenApi.Resource.ActionConfig` — Action configuration struct
  - `AshPhoenixGenApi.Resource.SharedTypes` — Shared type definitions for config structs
  - `AshPhoenixGenApi.Resource.EffectiveField` — Macro for effective field resolution
  - `AshPhoenixGenApi.Domain` — Domain-level DSL extension
  - `AshPhoenixGenApi.Domain.Info` — Domain introspection helpers
  - `AshPhoenixGenApi.TypeMapper` — Ash type to PhoenixGenApi type mapping
  - `AshPhoenixGenApi.JsonConfig` — JSON function config list generation utilities
  - `AshPhoenixGenApi.Codec` — Result encoding for Ash resource structs
  - `AshPhoenixGenApi.Transformers.DefineFunConfigs` — Resource transformer
  - `AshPhoenixGenApi.Transformers.DefineDomainSupporter` — Domain transformer
  - `AshPhoenixGenApi.Verifiers.VerifyActionConfigs` — Resource verifier
  - `AshPhoenixGenApi.Verifiers.VerifyDomainConfig` — Domain verifier
  """

  @doc false
  def extract_spark_opt({:ok, value}, _default), do: value

  def extract_spark_opt(:error, default), do: default

  def extract_spark_opt(value, _default) when not is_tuple(value), do: value

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
        AshPhoenixGenApi.Resource.SharedTypes,
        AshPhoenixGenApi.Resource.EffectiveField,
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
      AshPhoenixGenApi.Resource.SharedTypes,
      AshPhoenixGenApi.Resource.EffectiveField,
      AshPhoenixGenApi.Domain,
      AshPhoenixGenApi.Domain.Info,
      AshPhoenixGenApi.TypeMapper,
      AshPhoenixGenApi.JsonConfig,
      AshPhoenixGenApi.Codec,
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
  - `permission_callback` — `nil` (no custom callback)
  - `choose_node_mode` — `:random`
  - `nodes` — `:local`
  - `version` — `"0.0.1"`
  - `retry` — `nil` (no retry)
  - `code_interface?` — `true` (auto-generate code interface functions)
  - `push_nodes` — `nil` (no push nodes)
  - `push_on_startup` — `false`
  - `result_encoder` — `:struct` (return Ash resource struct as-is)
  """
  @spec defaults() :: map()
  def defaults do
    %{
      timeout: 5_000,
      response_type: :async,
      request_info: true,
      check_permission: false,
      permission_callback: nil,
      choose_node_mode: :random,
      nodes: :local,
      version: "0.0.1",
      retry: nil,
      code_interface?: true,
      push_nodes: nil,
      push_on_startup: false,
      result_encoder: :struct
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
