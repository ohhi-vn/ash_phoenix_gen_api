defmodule AshPhoenixGenApi.Resource.ActionConfig do
  @moduledoc """
  Configuration struct for a single PhoenixGenApi action endpoint.

  This struct is the target of the `action` entity in the `gen_api` DSL section.
  It holds all the configuration needed to generate a `PhoenixGenApi.Structs.FunConfig`
  from an Ash resource action.

  ## Fields

  - `name` - The Ash action name (required)
  - `request_type` - The PhoenixGenApi request type string (defaults to action name)
  - `timeout` - Timeout in milliseconds
  - `response_type` - Response mode (:sync, :async, :stream, :none)
  - `request_info` - Whether to pass request info as last argument
  - `check_permission` - Permission check mode
  - `permission_callback` - Custom callback MFA for permission checking (takes precedence over check_permission). Callback receives `(request_type, args)` and returns `true` (continue) or `false` (denied).
  - `choose_node_mode` - Node selection strategy
  - `nodes` - Target nodes (list, MFA tuple, or :local)
  - `retry` - Retry configuration
  - `version` - API version string
  - `mfa` - Explicit MFA tuple (overrides auto-generated)
  - `arg_types` - Explicit argument types map (overrides auto-derived)
  - `arg_orders` - Explicit argument order list (overrides auto-derived), or `:map` to derive from arg_types keys (default)
  - `disabled` - Whether this endpoint is disabled
  - `code_interface?` - Whether to generate a code interface function for this action
  - `result_encoder` - How to encode the result returned from the action MFA call

  ## Resolution Order

  When generating a `FunConfig`, values are resolved in this order:

  1. Action-level explicit configuration (e.g., `action :foo do timeout 10_000 end`)
  2. Section-level defaults (e.g., `gen_api do timeout 5_000 end`)
  3. Built-in defaults (e.g., timeout defaults to 5000)

  For `arg_types` and `arg_orders`:
  1. Explicit `arg_types`/`arg_orders` on the action entity
  2. Auto-derived from the Ash action's accepted attributes and arguments
  """

  alias AshPhoenixGenApi.Resource.SharedTypes

  @type permission_mode :: SharedTypes.permission_mode()
  @type permission_callback :: SharedTypes.permission_callback()
  @type node_config :: SharedTypes.node_config()
  @type choose_node_mode :: SharedTypes.choose_node_mode()
  @type retry_config :: SharedTypes.retry_config()
  @type gen_api_type :: SharedTypes.gen_api_type()
  @type result_encoder :: SharedTypes.result_encoder()

  @doc """
  Callback function signature for permission checking.

  The callback receives two arguments:
  - `request_type` - The PhoenixGenApi request type string (e.g., `"delete_user"`)
  - `args` - A map of request arguments (e.g., `%{"user_id" => "123", "role" => "admin"}`)

  Returns `true` to allow the request, or `false` to deny permission.

  ## Example

      def check_permission(request_type, args) do
        case request_type do
          "delete_user" -> args["role"] == "admin"
          "update_profile" -> args["user_id"] == args["target_user_id"]
          _ -> true
        end
      end
  """
  @callback permission_callback(request_type :: String.t(), args :: map()) :: boolean()

  @type t :: %__MODULE__{
          name: atom(),
          request_type: String.t() | nil,
          timeout: pos_integer() | :infinity | nil,
          response_type: :sync | :async | :stream | :none | nil,
          request_info: boolean() | nil,
          check_permission: permission_mode() | nil,
          permission_callback: permission_callback(),
          choose_node_mode: choose_node_mode() | nil,
          nodes: node_config() | nil,
          retry: retry_config() | nil,
          version: String.t() | nil,
          mfa: {module(), atom(), [any()]} | nil,
          arg_types: %{String.t() => gen_api_type()} | nil,
          arg_orders: [String.t()] | :map,
          disabled: boolean(),
          code_interface?: boolean() | nil,
          result_encoder: result_encoder(),
          __spark_metadata__: any()
        }

  defstruct [
    :name,
    :request_type,
    :timeout,
    :response_type,
    :request_info,
    :check_permission,
    :permission_callback,
    :choose_node_mode,
    :nodes,
    :retry,
    :version,
    :mfa,
    :arg_types,
    arg_orders: :map,
    disabled: false,
    code_interface?: nil,
    result_encoder: nil,
    __spark_metadata__: nil
  ]

  use AshPhoenixGenApi.Resource.EffectiveField

  @doc """
  Resolves the effective request_type for this action config.

  Returns the explicit `request_type` if set, otherwise derives it
  from the action `name` by converting to a string.

  ## Examples

      iex> config = %AshPhoenixGenApi.Resource.ActionConfig{name: :send_message, request_type: "send_msg"}
      iex> AshPhoenixGenApi.Resource.ActionConfig.effective_request_type(config)
      "send_msg"

      iex> config = %AshPhoenixGenApi.Resource.ActionConfig{name: :send_message, request_type: nil}
      iex> AshPhoenixGenApi.Resource.ActionConfig.effective_request_type(config)
      "send_message"
  """
  @spec effective_request_type(t()) :: String.t()
  def effective_request_type(%__MODULE__{request_type: nil, name: name}) do
    Atom.to_string(name)
  end

  def effective_request_type(%__MODULE__{request_type: request_type}) do
    request_type
  end

  @doc """
  Resolves the effective mfa, falling back to auto-generation from the resource module and action name.

  When `mfa` is explicitly set on the action config, it is returned as-is.
  Otherwise, generates `{resource_module, action_name, []}`.

  The generated function is expected to accept positional arguments matching
  `arg_orders`, plus an optional request_info map as the last argument.
  """
  @spec effective_mfa(t(), module()) :: {module(), atom(), [any()]}
  def effective_mfa(%__MODULE__{mfa: nil, name: name}, resource_module) do
    {resource_module, name, []}
  end

  def effective_mfa(%__MODULE__{mfa: mfa}, _resource_module) do
    mfa
  end

  @doc """
  Resolves the effective code_interface? setting, falling back to the provided default.

  When the action-level `code_interface?` is explicitly set (not `nil`), returns that value.
  Otherwise, returns the section-level default.

  ## Examples

      iex> config = %AshPhoenixGenApi.Resource.ActionConfig{code_interface?: false}
      iex> AshPhoenixGenApi.Resource.ActionConfig.effective_code_interface?(config, true)
      false

      iex> config = %AshPhoenixGenApi.Resource.ActionConfig{code_interface?: nil}
      iex> AshPhoenixGenApi.Resource.ActionConfig.effective_code_interface?(config, true)
      true
  """
  @spec effective_code_interface?(t(), boolean()) :: boolean()
  def effective_code_interface?(%__MODULE__{code_interface?: nil}, default), do: default
  def effective_code_interface?(%__MODULE__{code_interface?: code_interface?}, _default), do: code_interface?

  @doc """
  Resolves the effective result_encoder setting, falling back to the provided default.

  The `result_encoder` determines how the result from the action MFA call is encoded:

  - `:struct` — Return the Ash resource struct as-is (default behavior)
  - `:map` — Convert the Ash resource struct to a map containing only public fields
    (using `Ash.Resource.Info.public_fields/1` to filter; falls back to
    `Map.from_struct/1` for non-Ash-resource structs)
  - `{Module, :function, args}` — Custom encoder MFA. The function receives
    the result as its first argument, followed by `args`, and must return
    the encoded result.
  - `nil` — Inherit from the section-level default

  When the action-level `result_encoder` is explicitly set (not `nil`), returns that value.
  Otherwise, returns the section-level default.

  ## Examples

      iex> config = %AshPhoenixGenApi.Resource.ActionConfig{result_encoder: :map}
      iex> AshPhoenixGenApi.Resource.ActionConfig.effective_result_encoder(config, :struct)
      :map

      iex> config = %AshPhoenixGenApi.Resource.ActionConfig{result_encoder: nil}
      iex> AshPhoenixGenApi.Resource.ActionConfig.effective_result_encoder(config, :struct)
      :struct

      iex> config = %AshPhoenixGenApi.Resource.ActionConfig{result_encoder: {MyEncoder, :encode, []}}
      iex> AshPhoenixGenApi.Resource.ActionConfig.effective_result_encoder(config, :struct)
      {MyEncoder, :encode, []}
  """
  @spec effective_result_encoder(t(), result_encoder()) :: result_encoder()
  def effective_result_encoder(%__MODULE__{result_encoder: nil}, default), do: default
  def effective_result_encoder(%__MODULE__{result_encoder: result_encoder}, _default), do: result_encoder
end
