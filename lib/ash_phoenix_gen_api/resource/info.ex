defmodule AshPhoenixGenApi.Resource.Info do
  @moduledoc """
  Introspection helpers for the `AshPhoenixGenApi.Resource` DSL extension.

  Use this module to query the PhoenixGenApi configuration of an Ash resource
  at runtime or during compilation.

  ## Generated Functions

  Using `Spark.InfoGenerator` automatically generates accessor functions for
  all options in the `gen_api` section:

  - `gen_api_service/1` - Returns the service name
  - `gen_api_nodes/1` - Returns the default nodes configuration
  - `gen_api_choose_node_mode/1` - Returns the default node selection strategy
  - `gen_api_timeout/1` - Returns the default timeout
  - `gen_api_response_type/1` - Returns the default response type
  - `gen_api_request_info/1` - Returns the default request_info setting
  - `gen_api_check_permission/1` - Returns the default permission check mode
  - `gen_api_permission_callback/1` - Returns the default permission callback MFA
  - `gen_api_version/1` - Returns the default version string
  - `gen_api_retry/1` - Returns the default retry configuration
  - `gen_api_code_interface?/1` - Returns whether code interface generation is enabled at section level
  - `gen_api/1` - Returns the list of action entities

  ## Additional Helpers

  This module also provides convenience functions:

  - `action/2` - Get a specific action config by name
  - `enabled_actions/1` - Get only enabled (non-disabled) action configs
  - `action_request_type/2` - Get the effective request_type for an action
  - `fun_configs/1` - Get the list of generated FunConfig structs
  - `has_gen_api?/1` - Check if a resource has gen_api configured

  ## Usage

      # Get the service name for a resource
      AshPhoenixGenApi.Resource.Info.gen_api_service(MyApp.Chat.DirectMessage)
      #=> "chat"

      # Get all action configs
      AshPhoenixGenApi.Resource.Info.gen_api(MyApp.Chat.DirectMessage)
      #=> [%ActionConfig{name: :send_direct_message, ...}, ...]

      # Get a specific action config
      AshPhoenixGenApi.Resource.Info.action(MyApp.Chat.DirectMessage, :send_direct_message)
      #=> %ActionConfig{name: :send_direct_message, ...}

      # Get only enabled actions
      AshPhoenixGenApi.Resource.Info.enabled_actions(MyApp.Chat.DirectMessage)
      #=> [%ActionConfig{name: :send_direct_message, disabled: false, ...}, ...]

      # Get the generated FunConfig structs (after compilation)
      AshPhoenixGenApi.Resource.Info.fun_configs(MyApp.Chat.DirectMessage)
      #=> [%PhoenixGenApi.Structs.FunConfig{...}, ...]
  """

  use Spark.InfoGenerator, extension: AshPhoenixGenApi.Resource, sections: [:gen_api]

  alias AshPhoenixGenApi.Resource.ActionConfig
  alias AshPhoenixGenApi.Resource.MfaConfig

  @doc """
  Gets a specific action configuration by name.

  Returns `nil` if no action with the given name is configured.

  ## Parameters

    - `resource` - The Ash resource module
    - `action_name` - The action name atom

  ## Examples

      iex> AshPhoenixGenApi.Resource.Info.action(MyApp.Chat.DirectMessage, :send_direct_message)
      %AshPhoenixGenApi.Resource.ActionConfig{name: :send_direct_message, ...}

      iex> AshPhoenixGenApi.Resource.Info.action(MyApp.Chat.DirectMessage, :nonexistent)
      nil
  """
  @spec action(module(), atom()) :: ActionConfig.t() | nil
  def action(resource, action_name) when is_atom(resource) and is_atom(action_name) do
    resource
    |> gen_api()
    |> Enum.filter(&match?(%ActionConfig{}, &1))
    |> Enum.find(&(&1.name == action_name))
  end

  @doc """
  Gets a specific MFA configuration by name.

  Returns `nil` if no MFA with the given name is configured.

  ## Parameters

    - `resource` - The Ash resource module
    - `mfa_name` - The MFA name atom

  ## Examples

      iex> AshPhoenixGenApi.Resource.Info.mfa(MyApp.Chat.DirectMessage, :ping)
      %AshPhoenixGenApi.Resource.MfaConfig{name: :ping, ...}

      iex> AshPhoenixGenApi.Resource.Info.mfa(MyApp.Chat.DirectMessage, :nonexistent)
      nil
  """
  @spec mfa(module(), atom()) :: MfaConfig.t() | nil
  def mfa(resource, mfa_name) when is_atom(resource) and is_atom(mfa_name) do
    resource
    |> gen_api()
    |> Enum.filter(&match?(%MfaConfig{}, &1))
    |> Enum.find(&(&1.name == mfa_name))
  end

  @doc """
  Gets only enabled (non-disabled) action configurations.

  Returns a list of `ActionConfig` structs where `disabled` is `false`.

  ## Parameters

    - `resource` - The Ash resource module

  ## Examples

      iex> AshPhoenixGenApi.Resource.Info.enabled_actions(MyApp.Chat.DirectMessage)
      [%AshPhoenixGenApi.Resource.ActionConfig{name: :send_direct_message, disabled: false, ...}, ...]
  """
  @spec enabled_actions(module()) :: [ActionConfig.t()]
  def enabled_actions(resource) when is_atom(resource) do
    resource
    |> gen_api()
    |> Enum.filter(&match?(%ActionConfig{}, &1))
    |> Enum.filter(&ActionConfig.enabled?/1)
  end

  @doc """
  Gets all MFA configurations from the resource.

  Returns a list of `MfaConfig` structs.

  ## Parameters

    - `resource` - The Ash resource module

  ## Examples

      iex> AshPhoenixGenApi.Resource.Info.mfas(MyApp.Chat.DirectMessage)
      [%AshPhoenixGenApi.Resource.MfaConfig{name: :ping, ...}, ...]
  """
  @spec mfas(module()) :: [MfaConfig.t()]
  def mfas(resource) when is_atom(resource) do
    resource
    |> gen_api()
    |> Enum.filter(&match?(%MfaConfig{}, &1))
  end

  @doc """
  Gets only enabled (non-disabled) MFA configurations.

  Returns a list of `MfaConfig` structs where `disabled` is `false`.

  ## Parameters

    - `resource` - The Ash resource module

  ## Examples

      iex> AshPhoenixGenApi.Resource.Info.enabled_mfas(MyApp.Chat.DirectMessage)
      [%AshPhoenixGenApi.Resource.MfaConfig{name: :ping, disabled: false, ...}, ...]
  """
  @spec enabled_mfas(module()) :: [MfaConfig.t()]
  def enabled_mfas(resource) when is_atom(resource) do
    resource
    |> gen_api()
    |> Enum.filter(&match?(%MfaConfig{}, &1))
    |> Enum.filter(&MfaConfig.enabled?/1)
  end

  @doc """
  Gets the effective request_type for a specific action.

  Resolves the request_type by checking the action-level config first,
  then falling back to the action name as a string.

  ## Parameters

    - `resource` - The Ash resource module
    - `action_name` - The action name atom

  ## Examples

      iex> AshPhoenixGenApi.Resource.Info.action_request_type(MyApp.Chat.DirectMessage, :send_direct_message)
      "send_direct_message"

      # If request_type is explicitly set to "send_msg":
      iex> AshPhoenixGenApi.Resource.Info.action_request_type(MyApp.Chat.DirectMessage, :send_message)
      "send_msg"
  """
  @spec action_request_type(module(), atom()) :: String.t() | nil
  def action_request_type(resource, action_name) when is_atom(resource) and is_atom(action_name) do
    case action(resource, action_name) do
      nil -> nil
      action_config -> ActionConfig.effective_request_type(action_config)
    end
  end

  @doc """
  Gets the list of generated FunConfig structs for this resource.

  This function returns the FunConfig structs that were generated by the
  `AshPhoenixGenApi.Transformers.DefineFunConfigs` transformer during compilation.
  The FunConfigs are stored in the resource module's `__ash_phoenix_gen_api_fun_configs__` function.

  Returns an empty list if the resource has no gen_api configuration or
  if the FunConfigs haven't been generated yet.

  ## Parameters

    - `resource` - The Ash resource module

  ## Examples

      iex> AshPhoenixGenApi.Resource.Info.fun_configs(MyApp.Chat.DirectMessage)
      [%PhoenixGenApi.Structs.FunConfig{request_type: "send_direct_message", ...}, ...]
  """
  @spec fun_configs(module()) :: [PhoenixGenApi.Structs.FunConfig.t()]
  def fun_configs(resource) when is_atom(resource) do
    if function_exported?(resource, :__ash_phoenix_gen_api_fun_configs__, 0) do
      resource.__ash_phoenix_gen_api_fun_configs__()
    else
      []
    end
  end

  @doc """
  Gets a specific FunConfig by request_type.

  ## Parameters

    - `resource` - The Ash resource module
    - `request_type` - The PhoenixGenApi request type string

  ## Examples

      iex> AshPhoenixGenApi.Resource.Info.fun_config(MyApp.Chat.DirectMessage, "send_direct_message")
      %PhoenixGenApi.Structs.FunConfig{request_type: "send_direct_message", ...}
  """
  @spec fun_config(module(), String.t()) :: PhoenixGenApi.Structs.FunConfig.t() | nil
  def fun_config(resource, request_type) when is_atom(resource) and is_binary(request_type) do
    resource
    |> fun_configs()
    |> Enum.find(&(&1.request_type == request_type))
  end

  @doc """
  Gets all request_type strings for this resource's API endpoints.

  ## Parameters

    - `resource` - The Ash resource module

  ## Examples

      iex> AshPhoenixGenApi.Resource.Info.request_types(MyApp.Chat.DirectMessage)
      ["send_direct_message", "get_conversation", ...]
  """
  @spec request_types(module()) :: [String.t()]
  def request_types(resource) when is_atom(resource) do
    action_types =
      resource
      |> enabled_actions()
      |> Enum.map(&ActionConfig.effective_request_type/1)

    mfa_types =
      resource
      |> enabled_mfas()
      |> Enum.map(& &1.request_type)

    action_types ++ mfa_types
  end

  @doc """
  Checks if a resource has the gen_api extension configured.

  Returns `true` if the resource uses the `AshPhoenixGenApi.Resource` extension
  and has a `gen_api` section configured, `false` otherwise.

  ## Parameters

    - `resource` - The Ash resource module

  ## Examples

      iex> AshPhoenixGenApi.Resource.Info.has_gen_api?(MyApp.Chat.DirectMessage)
      true

      iex> AshPhoenixGenApi.Resource.Info.has_gen_api?(MyApp.Chat.SomeOtherResource)
      false
  """
  @spec has_gen_api?(module()) :: boolean()
  def has_gen_api?(resource) when is_atom(resource) do
    case Code.ensure_compiled(resource) do
      {:module, _} ->
        try do
          extensions = Ash.Resource.Info.extensions(resource)
          Enum.any?(extensions, &(&1 == AshPhoenixGenApi.Resource))
        rescue
          _ -> false
        end

      {:error, _} ->
        false
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Extracts a value from a Spark.InfoGenerator result.
  #
  # Spark.InfoGenerator generates two versions of each accessor:
  # - `gen_api_foo/1` returns `{:ok, value}` or `:error`
  # - `gen_api_foo!/1` returns the value or raises
  #
  # This helper unwraps the `{:ok, value}` tuple, falling back to the
  # provided default when the option is not configured (`:error`).
  defp extract_opt({:ok, value}, _default), do: value
  defp extract_opt(:error, default), do: default
  defp extract_opt(value, _default) when not is_tuple(value), do: value

  @doc """
  Gets the effective service name for a resource.

  Returns the service name configured in the `gen_api` section, or `nil`
  if the resource doesn't have gen_api configured.

  ## Parameters

    - `resource` - The Ash resource module

  ## Examples

      iex> AshPhoenixGenApi.Resource.Info.service(MyApp.Chat.DirectMessage)
      "chat"
  """
  @spec service(module()) :: String.t() | atom() | nil
  def service(resource) when is_atom(resource) do
    if has_gen_api?(resource) do
      extract_opt(gen_api_service(resource), nil)
    else
      nil
    end
  rescue
    _ -> nil
  end

  @doc """
  Gets the effective timeout for a specific action, resolving all defaults.

  Resolves the timeout in this order:
  1. Action-level `timeout` (if set)
  2. Section-level `timeout` (if set)
  3. Built-in default of `5000`

  ## Parameters

    - `resource` - The Ash resource module
    - `action_name` - The action name atom

  ## Examples

      iex> AshPhoenixGenApi.Resource.Info.effective_timeout(MyApp.Chat.DirectMessage, :send_direct_message)
      10_000
  """
  @spec effective_timeout(module(), atom()) :: pos_integer() | :infinity
  def effective_timeout(resource, action_name) when is_atom(resource) and is_atom(action_name) do
    section_default = extract_opt(gen_api_timeout(resource), 5_000)
    action_config = action(resource, action_name)

    case action_config do
      nil -> section_default
      config -> ActionConfig.effective_timeout(config, section_default)
    end
  end

  @doc """
  Gets the effective response_type for a specific action, resolving all defaults.

  ## Parameters

    - `resource` - The Ash resource module
    - `action_name` - The action name atom
  """
  @spec effective_response_type(module(), atom()) :: :sync | :async | :stream | :none
  def effective_response_type(resource, action_name) when is_atom(resource) and is_atom(action_name) do
    section_default = extract_opt(gen_api_response_type(resource), :async)
    action_config = action(resource, action_name)

    case action_config do
      nil -> section_default
      config -> ActionConfig.effective_response_type(config, section_default)
    end
  end

  @doc """
  Gets the effective request_info for a specific action, resolving all defaults.

  ## Parameters

    - `resource` - The Ash resource module
    - `action_name` - The action name atom
  """
  @spec effective_request_info(module(), atom()) :: boolean()
  def effective_request_info(resource, action_name) when is_atom(resource) and is_atom(action_name) do
    section_default = extract_opt(gen_api_request_info(resource), true)
    action_config = action(resource, action_name)

    case action_config do
      nil -> section_default
      config -> ActionConfig.effective_request_info(config, section_default)
    end
  end

  @doc """
  Gets the effective check_permission for a specific action, resolving all defaults.

  ## Parameters

    - `resource` - The Ash resource module
    - `action_name` - The action name atom
  """
  @spec effective_check_permission(module(), atom()) :: ActionConfig.permission_mode()
  def effective_check_permission(resource, action_name) when is_atom(resource) and is_atom(action_name) do
    section_default = extract_opt(gen_api_check_permission(resource), false)
    action_config = action(resource, action_name)

    case action_config do
      nil -> section_default
      config -> ActionConfig.effective_check_permission(config, section_default)
    end
  end

  @doc """
  Gets the effective permission_callback for a specific action, resolving all defaults.

  Resolves the permission_callback in this order:
  1. Action-level `permission_callback` (if set)
  2. Section-level `permission_callback` (if set)
  3. Built-in default of `nil`

  When `permission_callback` is set, it takes precedence over `check_permission`
  and is stored as `{:callback, mfa}` in the FunConfig's `check_permission` field.

  ## Parameters

    - `resource` - The Ash resource module
    - `action_name` - The action name atom

  ## Examples

      iex> AshPhoenixGenApi.Resource.Info.effective_permission_callback(MyApp.Chat.DirectMessage, :send_direct_message)
      nil

      iex> AshPhoenixGenApi.Resource.Info.effective_permission_callback(MyApp.Chat.DirectMessage, :admin_action)
      {MyApp.Permissions, :check_admin, []}
  """
  @spec effective_permission_callback(module(), atom()) :: ActionConfig.permission_callback()
  def effective_permission_callback(resource, action_name) when is_atom(resource) and is_atom(action_name) do
    section_default = extract_opt(gen_api_permission_callback(resource), nil)
    action_config = action(resource, action_name)

    case action_config do
      nil -> section_default
      config -> ActionConfig.effective_permission_callback(config, section_default)
    end
  end

  @doc """
  Gets the effective choose_node_mode for a specific action, resolving all defaults.

  ## Parameters

    - `resource` - The Ash resource module
    - `action_name` - The action name atom
  """
  @spec effective_choose_node_mode(module(), atom()) :: ActionConfig.choose_node_mode()
  def effective_choose_node_mode(resource, action_name) when is_atom(resource) and is_atom(action_name) do
    section_default = extract_opt(gen_api_choose_node_mode(resource), :random)
    action_config = action(resource, action_name)

    case action_config do
      nil -> section_default
      config -> ActionConfig.effective_choose_node_mode(config, section_default)
    end
  end

  @doc """
  Gets the effective nodes for a specific action, resolving all defaults.

  ## Parameters

    - `resource` - The Ash resource module
    - `action_name` - The action name atom
  """
  @spec effective_nodes(module(), atom()) :: ActionConfig.node_config()
  def effective_nodes(resource, action_name) when is_atom(resource) and is_atom(action_name) do
    section_default = extract_opt(gen_api_nodes(resource), :local)
    action_config = action(resource, action_name)

    case action_config do
      nil -> section_default
      config -> ActionConfig.effective_nodes(config, section_default)
    end
  end

  @doc """
  Gets the effective version for a specific action, resolving all defaults.

  ## Parameters

    - `resource` - The Ash resource module
    - `action_name` - The action name atom
  """
  @spec effective_version(module(), atom()) :: String.t()
  def effective_version(resource, action_name) when is_atom(resource) and is_atom(action_name) do
    section_default = extract_opt(gen_api_version(resource), "0.0.1")
    action_config = action(resource, action_name)

    case action_config do
      nil -> section_default
      config -> ActionConfig.effective_version(config, section_default)
    end
  end

  @doc """
  Gets the effective retry for a specific action, resolving all defaults.

  ## Parameters

    - `resource` - The Ash resource module
    - `action_name` - The action name atom
  """
  @spec effective_retry(module(), atom()) :: ActionConfig.retry_config()
  def effective_retry(resource, action_name) when is_atom(resource) and is_atom(action_name) do
    section_default = extract_opt(gen_api_retry(resource), nil)
    action_config = action(resource, action_name)

    case action_config do
      nil -> section_default
      config -> ActionConfig.effective_retry(config, section_default)
    end
  end

  @doc """
  Gets the effective code_interface? for a specific action, resolving all defaults.

  Resolves the code_interface? setting in this order:
  1. Action-level `code_interface?` (if set)
  2. Section-level `code_interface?` (if set)
  3. Built-in default of `true`

  ## Parameters

    - `resource` - The Ash resource module
    - `action_name` - The action name atom

  ## Examples

      iex> AshPhoenixGenApi.Resource.Info.effective_code_interface?(MyApp.Chat.DirectMessage, :send_direct_message)
      true
  """
  @spec effective_code_interface?(module(), atom()) :: boolean()
  def effective_code_interface?(resource, action_name) when is_atom(resource) and is_atom(action_name) do
    section_default = extract_opt(gen_api_code_interface?(resource), true)
    action_config = action(resource, action_name)

    case action_config do
      nil -> section_default
      config -> ActionConfig.effective_code_interface?(config, section_default)
    end
  end

  @doc """
  Gets the effective MFA for a specific action.

  If the action config has an explicit `mfa`, returns that.
  Otherwise, generates `{resource_module, action_name, []}`.

  ## Parameters

    - `resource` - The Ash resource module
    - `action_name` - The action name atom
  """
  @spec effective_mfa(module(), atom()) :: {module(), atom(), [any()]} | nil
  def effective_mfa(resource, action_name) when is_atom(resource) and is_atom(action_name) do
    action_config = action(resource, action_name)

    case action_config do
      nil -> nil
      config -> ActionConfig.effective_mfa(config, resource)
    end
  end

  @doc """
  Gets the effective result_encoder for a specific action, resolving all defaults.

  Resolves the result_encoder in this order:
  1. Action-level `result_encoder` (if set)
  2. Section-level `result_encoder` (if set)
  3. Built-in default of `:struct`

  The `result_encoder` determines how the result returned from the action
  MFA call is encoded before being returned to the caller:

  - `:struct` — Return the Ash resource struct as-is (default)
  - `:map` — Convert the Ash resource struct to a map containing only public fields
    (using `Ash.Resource.Info.public_fields/1` to filter; falls back to
    `Map.from_struct/1` for non-Ash-resource structs)
  - `{Module, :function, args}` — Custom encoder MFA

  ## Parameters

    - `resource` - The Ash resource module
    - `action_name` - The action name atom

  ## Examples

      iex> AshPhoenixGenApi.Resource.Info.effective_result_encoder(MyApp.Chat.DirectMessage, :send_direct_message)
      :struct

      iex> AshPhoenixGenApi.Resource.Info.effective_result_encoder(MyApp.Chat.DirectMessage, :list_messages)
      :map
  """
  @spec effective_result_encoder(module(), atom()) :: ActionConfig.result_encoder()
  def effective_result_encoder(resource, action_name) when is_atom(resource) and is_atom(action_name) do
    section_default = extract_opt(gen_api_result_encoder(resource), :struct)
    action_config = action(resource, action_name)

    case action_config do
      nil -> section_default
      config -> ActionConfig.effective_result_encoder(config, section_default)
    end
  end
end
