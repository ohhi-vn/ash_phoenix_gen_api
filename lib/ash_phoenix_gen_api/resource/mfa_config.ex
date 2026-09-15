defmodule AshPhoenixGenApi.Resource.MfaConfig do
  @moduledoc """
  Configuration struct for a standalone PhoenixGenApi MFA endpoint.

  This struct is the target of the `mfa` entity in the `gen_api` DSL section.
  Unlike `ActionConfig` (which maps an Ash resource action to a FunConfig),
  `MfaConfig` defines a PhoenixGenApi endpoint that calls an arbitrary MFA
  function directly — with no Ash action involved.

  This is useful for exposing custom functions that don't map to standard
  Ash CRUD actions, such as utility endpoints, batch operations, or
  service-to-service calls.

  ## Fields

  - `name` - A unique identifier for this MFA endpoint (required)
  - `request_type` - The PhoenixGenApi request type string (required)
  - `mfa` - The MFA tuple to call, e.g., `{Module, :function, []}` (required)
  - `arg_types` - Argument types map (required, no auto-derivation)
  - `arg_orders` - Argument order list, or `:map` to derive from arg_types keys (default: `:map`)
  - `timeout` - Timeout in milliseconds
  - `response_type` - Response mode (:sync, :async, :stream, :none)
  - `request_info` - Whether to pass request info as last argument
  - `check_permission` - Permission check mode
  - `permission_callback` - Custom callback MFA for permission checking
  - `choose_node_mode` - Node selection strategy
  - `nodes` - Target nodes (list, MFA tuple, or :local)
  - `retry` - Retry configuration
  - `version` - API version string
  - `disabled` - Whether this endpoint is disabled
  - `result_encoder` - How to encode the result returned from the MFA call

  ## Resolution Order

  When generating a `FunConfig`, values are resolved in this order:

  1. MFA-level explicit configuration (e.g., `mfa :foo do timeout 10_000 end`)
  2. Section-level defaults (e.g., `gen_api do timeout 5_000 end`)
  3. Built-in defaults (e.g., timeout defaults to 5000)

  Unlike `ActionConfig`, there is no auto-derivation of `request_type`,
  `arg_types`, or `arg_orders` from an Ash action — all must be explicitly
  provided (except `arg_orders` which defaults to `:map`).
  """

  alias AshPhoenixGenApi.Resource.SharedTypes

  @type permission_mode :: SharedTypes.permission_mode()
  @type permission_callback :: SharedTypes.permission_callback()
  @type node_config :: SharedTypes.node_config()
  @type choose_node_mode :: SharedTypes.choose_node_mode()
  @type retry_config :: SharedTypes.retry_config()
  @type gen_api_type :: SharedTypes.gen_api_type()
  @type hook_config :: SharedTypes.hook_config()
  @type result_encoder :: SharedTypes.result_encoder()

  @doc """
  Callback function signature for permission checking.

  The callback receives two arguments:
  - `request_type` - The PhoenixGenApi request type string (e.g., `"delete_user"`)
  - `args` - A map of request arguments (e.g., `%{"user_id" => "123", "role" => "admin"}`)

  Returns `true` to allow the request, or `false` to deny permission.
  """
  @callback permission_callback(request_type :: String.t(), args :: map()) :: boolean()

  @type t :: %__MODULE__{
          name: atom(),
          request_type: String.t(),
          mfa: {module(), atom(), [any()]},
          arg_types: %{String.t() => gen_api_type()},
          arg_orders: [String.t()] | :map,
          timeout: pos_integer() | :infinity | nil,
          response_type: :sync | :async | :stream | :none | nil,
          request_info: boolean() | nil,
          check_permission: permission_mode() | nil,
          permission_callback: permission_callback(),
          choose_node_mode: choose_node_mode() | nil,
          nodes: node_config() | nil,
          retry: retry_config() | nil,
          version: String.t() | nil,
          disabled: boolean(),
          before_execute: hook_config(),
          after_execute: hook_config(),
          hook_timeout: pos_integer() | nil,
          result_encoder: result_encoder(),
          __spark_metadata__: any()
        }

  defstruct [
    :name,
    :request_type,
    :mfa,
    :arg_types,
    :timeout,
    :response_type,
    :request_info,
    :check_permission,
    :permission_callback,
    :choose_node_mode,
    :nodes,
    :retry,
    :version,
    arg_orders: :map,
    disabled: false,
    before_execute: nil,
    after_execute: nil,
    hook_timeout: nil,
    result_encoder: nil,
    __spark_metadata__: nil
  ]

  @doc """
  Resolves the effective result_encoder setting, falling back to the provided default.

  The `result_encoder` determines how the result from the MFA call is encoded:

  - `:struct` — Return the result as-is (pass-through, no encoding)
  - `:map` — Convert Ash resource structs in the result to maps containing only
    public fields, preserving the `{:ok, data}` / `{:error, reason}` return format
  - `{Module, :function, args}` — Custom encoder MFA. The function receives
    the result as its first argument, followed by `args`, and must return
    the encoded result.
  - `nil` — Inherit from the section-level default

  When the mfa-level `result_encoder` is explicitly set (not `nil`), returns that value.
  Otherwise, returns the section-level default.

  ## Examples

      iex> config = %AshPhoenixGenApi.Resource.MfaConfig{result_encoder: :map}
      iex> AshPhoenixGenApi.Resource.MfaConfig.effective_result_encoder(config, :struct)
      :map

      iex> config = %AshPhoenixGenApi.Resource.MfaConfig{result_encoder: nil}
      iex> AshPhoenixGenApi.Resource.MfaConfig.effective_result_encoder(config, :struct)
      :struct

      iex> config = %AshPhoenixGenApi.Resource.MfaConfig{result_encoder: {MyEncoder, :encode, []}}
      iex> AshPhoenixGenApi.Resource.MfaConfig.effective_result_encoder(config, :struct)
      {MyEncoder, :encode, []}
  """
  @spec effective_result_encoder(t(), result_encoder()) :: result_encoder()
  def effective_result_encoder(%__MODULE__{result_encoder: nil}, default), do: default

  def effective_result_encoder(%__MODULE__{result_encoder: result_encoder}, _default),
    do: result_encoder

  use AshPhoenixGenApi.Resource.EffectiveField
end
