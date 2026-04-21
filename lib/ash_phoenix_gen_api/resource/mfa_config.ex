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

  ## Resolution Order

  When generating a `FunConfig`, values are resolved in this order:

  1. MFA-level explicit configuration (e.g., `mfa :foo do timeout 10_000 end`)
  2. Section-level defaults (e.g., `gen_api do timeout 5_000 end`)
  3. Built-in defaults (e.g., timeout defaults to 5000)

  Unlike `ActionConfig`, there is no auto-derivation of `request_type`,
  `arg_types`, or `arg_orders` from an Ash action — all must be explicitly
  provided (except `arg_orders` which defaults to `:map`).
  """

  @type permission_mode ::
          false
          | :any_authenticated
          | {:arg, String.t()}
          | {:role, [String.t()]}
          | {:callback, {module(), atom(), [any()]}}

  @type permission_callback :: {module(), atom(), [any()]} | nil

  @doc """
  Callback function signature for permission checking.

  The callback receives two arguments:
  - `request_type` - The PhoenixGenApi request type string (e.g., `"delete_user"`)
  - `args` - A map of request arguments (e.g., `%{"user_id" => "123", "role" => "admin"}`)

  Returns `true` to allow the request, or `false` to deny permission.
  """
  @callback permission_callback(request_type :: String.t(), args :: map()) :: boolean()

  @type node_config ::
          [atom()]
          | {module(), atom(), [any()]}
          | :local

  @type choose_node_mode ::
          :random
          | :hash
          | {:hash, String.t()}
          | :round_robin

  @type retry_config ::
          nil
          | pos_integer()
          | {:same_node, pos_integer()}
          | {:all_nodes, pos_integer()}

  @type gen_api_type ::
          :string
          | :num
          | {:list_string, pos_integer(), pos_integer()}
          | {:list_num, pos_integer()}

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
    __spark_metadata__: nil
  ]

  @doc """
  Resolves the effective timeout, falling back to the provided default.

  ## Examples

      iex> config = %AshPhoenixGenApi.Resource.MfaConfig{timeout: 10_000}
      iex> AshPhoenixGenApi.Resource.MfaConfig.effective_timeout(config, 5_000)
      10_000

      iex> config = %AshPhoenixGenApi.Resource.MfaConfig{timeout: nil}
      iex> AshPhoenixGenApi.Resource.MfaConfig.effective_timeout(config, 5_000)
      5000
  """
  @spec effective_timeout(t(), pos_integer() | :infinity) :: pos_integer() | :infinity
  def effective_timeout(%__MODULE__{timeout: nil}, default), do: default
  def effective_timeout(%__MODULE__{timeout: timeout}, _default), do: timeout

  @doc """
  Resolves the effective response_type, falling back to the provided default.
  """
  @spec effective_response_type(t(), :sync | :async | :stream | :none) ::
          :sync | :async | :stream | :none
  def effective_response_type(%__MODULE__{response_type: nil}, default), do: default
  def effective_response_type(%__MODULE__{response_type: response_type}, _default), do: response_type

  @doc """
  Resolves the effective request_info, falling back to the provided default.
  """
  @spec effective_request_info(t(), boolean()) :: boolean()
  def effective_request_info(%__MODULE__{request_info: nil}, default), do: default
  def effective_request_info(%__MODULE__{request_info: request_info}, _default), do: request_info

  @doc """
  Resolves the effective check_permission, falling back to the provided default.
  """
  @spec effective_check_permission(t(), permission_mode()) :: permission_mode()
  def effective_check_permission(%__MODULE__{check_permission: nil}, default), do: default
  def effective_check_permission(%__MODULE__{check_permission: check_permission}, _default), do: check_permission

  @doc """
  Resolves the effective permission_callback, falling back to the provided default.

  When the mfa-level `permission_callback` is set, returns that value.
  Otherwise, returns the section-level default.

  The callback MFA function receives `(request_type, args)` as arguments and
  returns `true` (continue) or `false` (permission denied).

  ## Examples

      iex> config = %AshPhoenixGenApi.Resource.MfaConfig{permission_callback: {MyModule, :check, []}}
      iex> AshPhoenixGenApi.Resource.MfaConfig.effective_permission_callback(config, nil)
      {MyModule, :check, []}

      iex> config = %AshPhoenixGenApi.Resource.MfaConfig{permission_callback: nil}
      iex> AshPhoenixGenApi.Resource.MfaConfig.effective_permission_callback(config, {MyModule, :check, []})
      {MyModule, :check, []}

      iex> config = %AshPhoenixGenApi.Resource.MfaConfig{permission_callback: nil}
      iex> AshPhoenixGenApi.Resource.MfaConfig.effective_permission_callback(config, nil)
      nil
  """
  @spec effective_permission_callback(t(), permission_callback()) :: permission_callback()
  def effective_permission_callback(%__MODULE__{permission_callback: nil}, default), do: default
  def effective_permission_callback(%__MODULE__{permission_callback: permission_callback}, _default), do: permission_callback

  @doc """
  Resolves the effective choose_node_mode, falling back to the provided default.
  """
  @spec effective_choose_node_mode(t(), choose_node_mode()) :: choose_node_mode()
  def effective_choose_node_mode(%__MODULE__{choose_node_mode: nil}, default), do: default
  def effective_choose_node_mode(%__MODULE__{choose_node_mode: choose_node_mode}, _default), do: choose_node_mode

  @doc """
  Resolves the effective nodes, falling back to the provided default.
  """
  @spec effective_nodes(t(), node_config()) :: node_config()
  def effective_nodes(%__MODULE__{nodes: nil}, default), do: default
  def effective_nodes(%__MODULE__{nodes: nodes}, _default), do: nodes

  @doc """
  Resolves the effective retry, falling back to the provided default.
  """
  @spec effective_retry(t(), retry_config()) :: retry_config()
  def effective_retry(%__MODULE__{retry: nil}, default), do: default
  def effective_retry(%__MODULE__{retry: retry}, _default), do: retry

  @doc """
  Resolves the effective version, falling back to the provided default.
  """
  @spec effective_version(t(), String.t()) :: String.t()
  def effective_version(%__MODULE__{version: nil}, default), do: default
  def effective_version(%__MODULE__{version: version}, _default), do: version

  @doc """
  Checks if this mfa config has explicit arg_types defined.
  """
  @spec has_explicit_arg_types?(t()) :: boolean()
  def has_explicit_arg_types?(%__MODULE__{arg_types: nil}), do: false
  def has_explicit_arg_types?(%__MODULE__{arg_types: arg_types}) when map_size(arg_types) == 0, do: false
  def has_explicit_arg_types?(%__MODULE__{arg_types: _}), do: true

  @doc """
  Checks if this mfa config has explicit arg_orders defined (not `:map`).
  """
  @spec has_explicit_arg_orders?(t()) :: boolean()
  def has_explicit_arg_orders?(%__MODULE__{arg_orders: :map}), do: false
  def has_explicit_arg_orders?(%__MODULE__{arg_orders: nil}), do: false
  def has_explicit_arg_orders?(%__MODULE__{arg_orders: []}), do: false
  def has_explicit_arg_orders?(%__MODULE__{arg_orders: _}), do: true

  @doc """
  Checks if this mfa config is enabled (not disabled).
  """
  @spec enabled?(t()) :: boolean()
  def enabled?(%__MODULE__{disabled: disabled}), do: !disabled
end
