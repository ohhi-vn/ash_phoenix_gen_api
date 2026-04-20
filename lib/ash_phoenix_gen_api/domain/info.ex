defmodule AshPhoenixGenApi.Domain.Info do
  @moduledoc """
  Introspection helpers for the `AshPhoenixGenApi.Domain` DSL extension.

  Use this module to query the PhoenixGenApi configuration of an Ash domain
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
  - `gen_api_supporter_module/1` - Returns the supporter module name
  - `gen_api_define_supporter?/1` - Returns whether to auto-generate the supporter

  ## Additional Helpers

  This module also provides convenience functions:

  - `has_gen_api?/1` - Check if a domain has gen_api configured
  - `fun_configs/1` - Get aggregated FunConfigs from all resources in the domain
  - `resources_with_gen_api/1` - Get all resources that have gen_api configured
  - `all_request_types/1` - Get all request types across all resources
  - `supporter_module/1` - Get the supporter module name

  ## Usage

      # Get the service name for a domain
      AshPhoenixGenApi.Domain.Info.gen_api_service(MyApp.Chat)
      #=> "chat"

      # Get the supporter module name
      AshPhoenixGenApi.Domain.Info.supporter_module(MyApp.Chat)
      #=> MyApp.Chat.GenApiSupporter

      # Get all FunConfigs aggregated from domain resources
      AshPhoenixGenApi.Domain.Info.fun_configs(MyApp.Chat)
      #=> [%PhoenixGenApi.Structs.FunConfig{...}, ...]

      # Get all resources that have gen_api configured
      AshPhoenixGenApi.Domain.Info.resources_with_gen_api(MyApp.Chat)
      #=> [MyApp.Chat.DirectMessage, MyApp.Chat.GroupMessage]
  """

  use Spark.InfoGenerator, extension: AshPhoenixGenApi.Domain, sections: [:gen_api]

  alias AshPhoenixGenApi.Resource.Info, as: ResourceInfo

  @doc """
  Checks if a domain has the gen_api extension configured.

  Returns `true` if the domain uses the `AshPhoenixGenApi.Domain` extension
  and has a `gen_api` section configured, `false` otherwise.

  ## Parameters

    - `domain` - The Ash domain module

  ## Examples

      iex> AshPhoenixGenApi.Domain.Info.has_gen_api?(MyApp.Chat)
      true

      iex> AshPhoenixGenApi.Domain.Info.has_gen_api?(MyApp.SomeOtherDomain)
      false
  """
  @spec has_gen_api?(module()) :: boolean()
  def has_gen_api?(domain) when is_atom(domain) do
    extensions = Ash.Domain.Info.extensions(domain)
    Enum.any?(extensions, &(&1 == AshPhoenixGenApi.Domain))
  rescue
    _ -> false
  end

  @doc """
  Gets the supporter module name for the domain.

  Returns the module name configured in `gen_api supporter_module`, or `nil`
  if the domain doesn't have gen_api configured.

  ## Parameters

    - `domain` - The Ash domain module

  ## Examples

      iex> AshPhoenixGenApi.Domain.Info.supporter_module(MyApp.Chat)
      MyApp.Chat.GenApiSupporter
  """
  @spec supporter_module(module()) :: module() | nil
  def supporter_module(domain) when is_atom(domain) do
    if has_gen_api?(domain) do
      extract_opt(gen_api_supporter_module(domain), nil)
    else
      nil
    end
  rescue
    _ -> nil
  end

  @doc """
  Gets the service name for the domain.

  Returns the service name configured in the domain's `gen_api` section,
  or `nil` if not configured.

  ## Parameters

    - `domain` - The Ash domain module

  ## Examples

      iex> AshPhoenixGenApi.Domain.Info.service(MyApp.Chat)
      "chat"
  """
  @spec service(module()) :: String.t() | atom() | nil
  def service(domain) when is_atom(domain) do
    if has_gen_api?(domain) do
      extract_opt(gen_api_service(domain), nil)
    else
      nil
    end
  rescue
    _ -> nil
  end

  @doc """
  Gets all resources in the domain that have the `AshPhoenixGenApi.Resource`
  extension configured.

  Returns a list of resource modules that have `gen_api` configured.

  ## Parameters

    - `domain` - The Ash domain module

  ## Examples

      iex> AshPhoenixGenApi.Domain.Info.resources_with_gen_api(MyApp.Chat)
      [MyApp.Chat.DirectMessage, MyApp.Chat.GroupMessage]
  """
  @spec resources_with_gen_api(module()) :: [module()]
  def resources_with_gen_api(domain) when is_atom(domain) do
    domain
    |> Ash.Domain.Info.resources()
    |> Enum.filter(&ResourceInfo.has_gen_api?/1)
  rescue
    _ -> []
  end

  @doc """
  Gets all FunConfig structs aggregated from all resources in the domain
  that have the `AshPhoenixGenApi.Resource` extension.

  This function collects the generated FunConfigs from each resource's
  `__ash_phoenix_gen_api_fun_configs__/0` function and concatenates them
  into a single list.

  Returns an empty list if no resources have gen_api configured or if
  the FunConfigs haven't been generated yet.

  ## Parameters

    - `domain` - The Ash domain module

  ## Examples

      iex> AshPhoenixGenApi.Domain.Info.fun_configs(MyApp.Chat)
      [
        %PhoenixGenApi.Structs.FunConfig{request_type: "send_direct_message", ...},
        %PhoenixGenApi.Structs.FunConfig{request_type: "get_conversation", ...},
        ...
      ]
  """
  @spec fun_configs(module()) :: [PhoenixGenApi.Structs.FunConfig.t()]
  def fun_configs(domain) when is_atom(domain) do
    domain
    |> resources_with_gen_api()
    |> Enum.flat_map(&ResourceInfo.fun_configs/1)
  rescue
    _ -> []
  end

  @doc """
  Gets a specific FunConfig by request_type from the domain's aggregated configs.

  Searches across all resources in the domain for a FunConfig with the
  given request_type. Returns the first match, or `nil` if not found.

  ## Parameters

    - `domain` - The Ash domain module
    - `request_type` - The PhoenixGenApi request type string

  ## Examples

      iex> AshPhoenixGenApi.Domain.Info.fun_config(MyApp.Chat, "send_direct_message")
      %PhoenixGenApi.Structs.FunConfig{request_type: "send_direct_message", ...}

      iex> AshPhoenixGenApi.Domain.Info.fun_config(MyApp.Chat, "nonexistent")
      nil
  """
  @spec fun_config(module(), String.t()) :: PhoenixGenApi.Structs.FunConfig.t() | nil
  def fun_config(domain, request_type)
      when is_atom(domain) and is_binary(request_type) do
    domain
    |> fun_configs()
    |> Enum.find(&(&1.request_type == request_type))
  end

  @doc """
  Gets all request_type strings from all resources in the domain.

  Returns a flat list of all request types across all resources that
  have gen_api configured.

  ## Parameters

    - `domain` - The Ash domain module

  ## Examples

      iex> AshPhoenixGenApi.Domain.Info.all_request_types(MyApp.Chat)
      ["send_direct_message", "get_conversation", "send_group_message", ...]
  """
  @spec all_request_types(module()) :: [String.t()]
  def all_request_types(domain) when is_atom(domain) do
    domain
    |> resources_with_gen_api()
    |> Enum.flat_map(&ResourceInfo.request_types/1)
  rescue
    _ -> []
  end

  @doc """
  Gets the version string for the domain.

  Returns the version configured in the domain's `gen_api` section,
  or the default `"0.0.1"` if not configured.

  ## Parameters

    - `domain` - The Ash domain module

  ## Examples

      iex> AshPhoenixGenApi.Domain.Info.version(MyApp.Chat)
      "0.0.1"
  """
  @spec version(module()) :: String.t()
  def version(domain) when is_atom(domain) do
    if has_gen_api?(domain) do
      extract_opt(gen_api_version(domain), "0.0.1")
    else
      "0.0.1"
    end
  rescue
    _ -> "0.0.1"
  end

  @doc """
  Checks whether the supporter module should be auto-generated.

  Returns `true` if `gen_api define_supporter?` is `true` (the default),
  `false` otherwise.

  ## Parameters

    - `domain` - The Ash domain module

  ## Examples

      iex> AshPhoenixGenApi.Domain.Info.define_supporter?(MyApp.Chat)
      true
  """
  @spec define_supporter?(module()) :: boolean()
  def define_supporter?(domain) when is_atom(domain) do
    if has_gen_api?(domain) do
      extract_opt(gen_api_define_supporter?(domain), true)
    else
      false
    end
  rescue
    _ -> false
  end

  @doc """
  Gets the effective default timeout for the domain.

  Returns the timeout configured in the domain's `gen_api` section,
  or the built-in default of `5000` if not configured.

  ## Parameters

    - `domain` - The Ash domain module

  ## Examples

      iex> AshPhoenixGenApi.Domain.Info.timeout(MyApp.Chat)
      5000
  """
  @spec timeout(module()) :: pos_integer() | :infinity
  def timeout(domain) when is_atom(domain) do
    if has_gen_api?(domain) do
      extract_opt(gen_api_timeout(domain), 5_000)
    else
      5_000
    end
  rescue
    _ -> 5_000
  end

  @doc """
  Gets the effective default response_type for the domain.

  Returns the response_type configured in the domain's `gen_api` section,
  or the built-in default of `:async` if not configured.

  ## Parameters

    - `domain` - The Ash domain module

  ## Examples

      iex> AshPhoenixGenApi.Domain.Info.response_type(MyApp.Chat)
      :async
  """
  @spec response_type(module()) :: :sync | :async | :stream | :none
  def response_type(domain) when is_atom(domain) do
    if has_gen_api?(domain) do
      extract_opt(gen_api_response_type(domain), :async)
    else
      :async
    end
  rescue
    _ -> :async
  end

  @doc """
  Gets the effective default request_info for the domain.

  Returns the request_info configured in the domain's `gen_api` section,
  or the built-in default of `true` if not configured.

  ## Parameters

    - `domain` - The Ash domain module

  ## Examples

      iex> AshPhoenixGenApi.Domain.Info.request_info(MyApp.Chat)
      true
  """
  @spec request_info(module()) :: boolean()
  def request_info(domain) when is_atom(domain) do
    if has_gen_api?(domain) do
      extract_opt(gen_api_request_info(domain), true)
    else
      true
    end
  rescue
    _ -> true
  end

  @doc """
  Gets the effective default nodes for the domain.

  Returns the nodes configured in the domain's `gen_api` section,
  or the built-in default of `:local` if not configured.

  ## Parameters

    - `domain` - The Ash domain module

  ## Examples

      iex> AshPhoenixGenApi.Domain.Info.nodes(MyApp.Chat)
      {ClusterHelper, :get_nodes, [:chat]}
  """
  @spec nodes(module()) :: [atom()] | {module(), atom(), [any()]} | :local
  def nodes(domain) when is_atom(domain) do
    if has_gen_api?(domain) do
      extract_opt(gen_api_nodes(domain), :local)
    else
      :local
    end
  rescue
    _ -> :local
  end

  @doc """
  Gets the effective default choose_node_mode for the domain.

  Returns the choose_node_mode configured in the domain's `gen_api` section,
  or the built-in default of `:random` if not configured.

  ## Parameters

    - `domain` - The Ash domain module

  ## Examples

      iex> AshPhoenixGenApi.Domain.Info.choose_node_mode(MyApp.Chat)
      :random
  """
  @spec choose_node_mode(module()) :: :random | :hash | {:hash, String.t()} | :round_robin
  def choose_node_mode(domain) when is_atom(domain) do
    if has_gen_api?(domain) do
      extract_opt(gen_api_choose_node_mode(domain), :random)
    else
      :random
    end
  rescue
    _ -> :random
  end

  @doc """
  Gets the effective default check_permission for the domain.

  Returns the check_permission configured in the domain's `gen_api` section,
  or the built-in default of `false` if not configured.

  ## Parameters

    - `domain` - The Ash domain module

  ## Examples

      iex> AshPhoenixGenApi.Domain.Info.check_permission(MyApp.Chat)
      false
  """
  @spec check_permission(module()) ::
          false | :any_authenticated | {:arg, String.t()} | {:role, [String.t()]}
  def check_permission(domain) when is_atom(domain) do
    if has_gen_api?(domain) do
      extract_opt(gen_api_check_permission(domain), false)
    else
      false
    end
  rescue
    _ -> false
  end

  @doc """
  Gets the default permission callback MFA for the domain.

  Returns the permission_callback configured in the domain's `gen_api` section,
  or `nil` if not configured.

  When set, `permission_callback` takes precedence over `check_permission` and
  is stored as `{:callback, mfa}` in the FunConfig's `check_permission` field.

  The callback function receives a map with request context (same params as FunConfig)
  and returns `true` (continue) or `false` (permission denied).

  ## Parameters

    - `domain` - The Ash domain module

  ## Examples

      iex> AshPhoenixGenApi.Domain.Info.permission_callback(MyApp.Chat)
      nil

      iex> AshPhoenixGenApi.Domain.Info.permission_callback(MyApp.Chat)
      {MyApp.Permissions, :check, []}
  """
  @spec permission_callback(module()) :: {module(), atom(), [any()]} | nil
  def permission_callback(domain) when is_atom(domain) do
    if has_gen_api?(domain) do
      extract_opt(gen_api_permission_callback(domain), nil)
    else
      nil
    end
  rescue
    _ -> nil
  end

  @doc """
  Gets the effective default retry for the domain.

  Returns the retry configured in the domain's `gen_api` section,
  or `nil` if not configured.

  ## Parameters

    - `domain` - The Ash domain module

  ## Examples

      iex> AshPhoenixGenApi.Domain.Info.retry(MyApp.Chat)
      nil
  """
  @spec retry(module()) ::
          nil
          | pos_integer()
          | {:same_node, pos_integer()}
          | {:all_nodes, pos_integer()}
  def retry(domain) when is_atom(domain) do
    if has_gen_api?(domain) do
      extract_opt(gen_api_retry(domain), nil)
    else
      nil
    end
  rescue
    _ -> nil
  end

  @doc """
  Gets the push_nodes configuration for the domain.

  Returns the push_nodes configured in the domain's `gen_api` section,
  or `nil` if not configured.

  Can be:
  - A list of node atoms: `[:"gateway1@host", :"gateway2@host"]`
  - An MFA tuple that returns a node list at runtime: `{ClusterHelper, :get_gateway_nodes, []}`
  - `nil` - No push nodes configured (default)

  ## Parameters

    - `domain` - The Ash domain module

  ## Examples

      iex> AshPhoenixGenApi.Domain.Info.push_nodes(MyApp.Chat)
      [:"gateway1@host", :"gateway2@host"]

      iex> AshPhoenixGenApi.Domain.Info.push_nodes(MyApp.Chat)
      {ClusterHelper, :get_gateway_nodes, []}
  """
  @spec push_nodes(module()) :: [atom()] | {module(), atom(), [any()]} | nil
  def push_nodes(domain) when is_atom(domain) do
    if has_gen_api?(domain) do
      extract_opt(gen_api_push_nodes(domain), nil)
    else
      nil
    end
  rescue
    _ -> nil
  end

  @doc """
  Checks whether push_on_startup is enabled for the domain.

  Returns `true` if `gen_api push_on_startup` is `true`,
  `false` otherwise (the default).

  ## Parameters

    - `domain` - The Ash domain module

  ## Examples

      iex> AshPhoenixGenApi.Domain.Info.push_on_startup?(MyApp.Chat)
      false
  """
  @spec push_on_startup?(module()) :: boolean()
  def push_on_startup?(domain) when is_atom(domain) do
    if has_gen_api?(domain) do
      extract_opt(gen_api_push_on_startup(domain), false)
    else
      false
    end
  rescue
    _ -> false
  end

  @doc """
  Gets a summary of the domain's PhoenixGenApi configuration.

  Returns a map with the domain's gen_api settings and a list of
  resources with their request types.

  ## Parameters

    - `domain` - The Ash domain module

  ## Examples

      iex> AshPhoenixGenApi.Domain.Info.summary(MyApp.Chat)
      %{
        service: "chat",
        version: "0.0.1",
        supporter_module: MyApp.Chat.GenApiSupporter,
        total_fun_configs: 5,
        resources: [
          %{resource: MyApp.Chat.DirectMessage, request_types: ["send_direct_message", ...]},
          %{resource: MyApp.Chat.GroupMessage, request_types: ["send_group_message", ...]}
        ]
      }
  """
  @spec summary(module()) :: map()
  def summary(domain) when is_atom(domain) do
    resources =
      domain
      |> resources_with_gen_api()
      |> Enum.map(fn resource ->
        %{
          resource: resource,
          request_types: ResourceInfo.request_types(resource)
        }
      end)

    %{
      service: service(domain),
      version: version(domain),
      supporter_module: supporter_module(domain),
      total_fun_configs: length(fun_configs(domain)),
      push_nodes: push_nodes(domain),
      push_on_startup: push_on_startup?(domain),
      result_encoder: result_encoder(domain),
      resources: resources
    }
  rescue
    _ -> %{}
  end

  @doc """
  Gets the default result_encoder for this domain.

  The `result_encoder` determines how the result returned from the action
  MFA call is encoded before being returned to the caller:

  - `:struct` — Return the Ash resource struct as-is (default)
  - `:map` — Convert the Ash resource struct to a map containing only public fields
    (using `Ash.Resource.Info.public_fields/1` to filter; falls back to
    `Map.from_struct/1` for non-Ash-resource structs)
  - `{Module, :function, args}` — Custom encoder MFA

  ## Parameters

    - `domain` - The Ash domain module

  ## Examples

      iex> AshPhoenixGenApi.Domain.Info.result_encoder(MyApp.Chat)
      :struct

      iex> AshPhoenixGenApi.Domain.Info.result_encoder(MyApp.Chat)
      :map
  """
  @spec result_encoder(module()) :: :struct | :map | {module(), atom(), [any()]} | nil
  def result_encoder(domain) when is_atom(domain) do
    extract_opt(gen_api_result_encoder(domain), :struct)
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
end
