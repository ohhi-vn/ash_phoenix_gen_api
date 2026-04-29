defmodule AshPhoenixGenApi.JsonConfig do
  @moduledoc """
  Utility for generating JSON function config lists from Ash resources and domains.

  Generates configuration maps in the PhoenixGenApi JSON function config format,
  where each key is a `"request_type - Description"` string and each value
  contains the event/data structure for the gateway.

  ## Output Formats

  The module supports multiple output formats via the `:format` option:

  - `:fun_configs` (default) — Returns the original list of
    `PhoenixGenApi.Structs.FunConfig` structs (Ash Resource type)
  - `:map` — Returns an Elixir map in the JSON config list format
  - `:json` — Returns a JSON-encoded string
  - `{Module, :function, args}` — Custom encoder MFA that receives the
    FunConfig list and returns the desired format

  ## JSON Config List Format

  The map format produces a structure like:

      %{
        "send_direct_message - Send direct message to other user" => %{
          "event" => "phoenix_gen_api",
          "data" => %{
            "user_id" => "user_1",
            "device_id" => "device_1",
            "request_type" => "send_direct_message",
            "request_id" => "request_1",
            "service" => "chat",
            "version" => "0.0.1",
            "args" => %{
              "to_user_id" => "",
              "content" => "",
              "reply_to_id" => ""
            }
          }
        }
      }

  ## Usage

      # Default: returns FunConfig structs (Ash Resource type)
      AshPhoenixGenApi.JsonConfig.generate(MyApp.Chat)
      #=> [%PhoenixGenApi.Structs.FunConfig{...}, ...]

      # As Elixir map (JSON config list format)
      AshPhoenixGenApi.JsonConfig.generate(MyApp.Chat, format: :map)
      #=> %{"send_direct_message - ..." => %{...}, ...}

      # As JSON string
      AshPhoenixGenApi.JsonConfig.generate(MyApp.Chat, format: :json)
      #=> "{\\"send_direct_message - ...\\": {...}, ...}"

      # Custom encoder MFA
      AshPhoenixGenApi.JsonConfig.generate(MyApp.Chat, format: {MyEncoder, :encode, []})

      # With custom descriptions
      AshPhoenixGenApi.JsonConfig.generate(MyApp.Chat,
        format: :map,
        descriptions: %{"send_direct_message" => "Send direct message to other user"}
      )

      # With description function
      AshPhoenixGenApi.JsonConfig.generate(MyApp.Chat,
        format: :map,
        descriptions: fn fun_config ->
          String.replace(fun_config.request_type, "_", " ")
        end
      )

      # With custom arg values
      AshPhoenixGenApi.JsonConfig.generate(MyApp.Chat,
        format: :map,
        arg_values: %{
          "send_direct_message" => %{
            "to_user_id" => "user_2",
            "content" => "Hello, how are you?",
            "reply_to_id" => ""
          }
        }
      )

      # With arg values function
      AshPhoenixGenApi.JsonConfig.generate(MyApp.Chat,
        format: :map,
        arg_values: fn fun_config ->
          # Generate example values based on arg types
          fun_config.arg_types
          |> Enum.map(fn {name, type} -> {name, example_value(type)} end)
          |> Map.new()
        end
      )
  """

  alias AshPhoenixGenApi.Resource.Info, as: ResourceInfo
  alias AshPhoenixGenApi.Domain.Info, as: DomainInfo

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @typedoc """
  Output format for the generated config.

  - `:fun_configs` — Returns `PhoenixGenApi.Structs.FunConfig` structs (Ash Resource type)
  - `:map` — Returns Elixir map in JSON config list format
  - `:json` — Returns JSON-encoded string
  - `{Module, :function, args}` — Custom encoder MFA
  """
  @type format :: :fun_configs | :map | :json | {module(), atom(), [any()]}

  @typedoc """
  Source for description strings used in config keys.

  - A map of `%{request_type => description}` for static descriptions
  - A function `(fun_config -> description)` for dynamic descriptions
  - `nil` — Uses request_type as the key without description
  """
  @type description_source :: %{String.t() => String.t()} | (map() -> String.t()) | nil

  @typedoc """
  Source for argument example/default values.

  - A map of `%{request_type => %{arg_name => value}}` for static values
  - A function `(fun_config -> args_map)` for dynamic values
  - `nil` — Uses type-based default values
  """
  @type arg_values :: %{String.t() => %{String.t() => term()}} | (map() -> map()) | nil

  @typedoc """
  Option for `generate/2`.

  - `:format` — Output format (default: `:fun_configs`)
  - `:user_id` — Default user_id in data (default: `"user_1"`)
  - `:device_id` — Default device_id in data (default: `"device_1"`)
  - `:request_id` — Default request_id in data (default: `"request_1"`)
  - `:descriptions` — Description source for key names (default: `nil`)
  - `:event_name` — Event name string (default: `"phoenix_gen_api"`)
  - `:arg_values` — Argument values source (default: `nil`)
  """
  @type option ::
          {:format, format()}
          | {:user_id, String.t()}
          | {:device_id, String.t()}
          | {:request_id, String.t()}
          | {:descriptions, description_source()}
          | {:event_name, String.t()}
          | {:arg_values, arg_values()}

  @default_opts [
    format: :fun_configs,
    user_id: "user_1",
    device_id: "device_1",
    request_id: "request_1",
    descriptions: nil,
    event_name: "phoenix_gen_api",
    arg_values: nil
  ]

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Generates a function config list from an Ash domain or resource.

  Automatically detects whether the source is a domain or resource and
  retrieves the appropriate FunConfig structs.

  ## Parameters

    - `source` — An Ash domain or resource module
    - `opts` — Options for generation and encoding

  ## Options

    - `:format` — Output format (default: `:fun_configs`)
      - `:fun_configs` — Returns list of `PhoenixGenApi.Structs.FunConfig` structs
      - `:map` — Returns Elixir map in JSON config list format
      - `:json` — Returns JSON-encoded string
      - `{Module, :function, args}` — Custom encoder MFA
    - `:user_id` — Default user_id in data. Default: `"user_1"`
    - `:device_id` — Default device_id in data. Default: `"device_1"`
    - `:request_id` — Default request_id in data. Default: `"request_1"`
    - `:descriptions` — Description source for key names. Can be:
      - A map of `%{request_type => description}`
      - A function `(fun_config -> description)`
      - `nil` — Uses request_type as key (default)
    - `:event_name` — Event name string. Default: `"phoenix_gen_api"`
    - `:arg_values` — Argument values source. Can be:
      - A map of `%{request_type => %{arg_name => value}}`
      - A function `(fun_config -> args_map)`
      - `nil` — Uses type-based defaults (default)

  ## Returns

  The generated config in the specified format.

  ## Examples

      # From a domain — default format (FunConfig structs)
      AshPhoenixGenApi.JsonConfig.generate(MyApp.Chat)
      #=> [%PhoenixGenApi.Structs.FunConfig{request_type: "send_direct_message", ...}, ...]

      # From a domain — map format
      AshPhoenixGenApi.JsonConfig.generate(MyApp.Chat, format: :map)
      #=> %{"send_direct_message" => %{...}, ...}

      # From a resource — map format
      AshPhoenixGenApi.JsonConfig.generate(MyApp.Chat.DirectMessage, format: :map)

      # With custom descriptions
      AshPhoenixGenApi.JsonConfig.generate(MyApp.Chat,
        format: :map,
        descriptions: %{"send_direct_message" => "Send direct message to other user"}
      )

      # With custom encoder MFA
      AshPhoenixGenApi.JsonConfig.generate(MyApp.Chat, format: {MyEncoder, :encode, []})
  """
  @spec generate(module(), [option()]) :: term()
  def generate(source, opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)
    fun_configs = get_fun_configs(source)
    encode(fun_configs, opts)
  end

  @doc """
  Generates a function config list from an Ash domain.

  Same as `generate/2` but explicitly for domain modules.

  ## Parameters

    - `domain` — An Ash domain module
    - `opts` — Same options as `generate/2`

  ## Examples

      AshPhoenixGenApi.JsonConfig.generate_from_domain(MyApp.Chat, format: :map)
  """
  @spec generate_from_domain(module(), [option()]) :: term()
  def generate_from_domain(domain, opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)
    fun_configs = DomainInfo.fun_configs(domain)
    encode(fun_configs, opts)
  end

  @doc """
  Generates a function config list from an Ash resource.

  Same as `generate/2` but explicitly for resource modules.

  ## Parameters

    - `resource` — An Ash resource module
    - `opts` — Same options as `generate/2`

  ## Examples

      AshPhoenixGenApi.JsonConfig.generate_from_resource(MyApp.Chat.DirectMessage, format: :map)
  """
  @spec generate_from_resource(module(), [option()]) :: term()
  def generate_from_resource(resource, opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)
    fun_configs = ResourceInfo.fun_configs(resource)
    encode(fun_configs, opts)
  end

  @doc """
  Converts a list of FunConfig structs to the JSON config map format.

  This is useful when you already have FunConfig structs and want to
  convert them to the map format without re-fetching from a domain/resource.

  ## Parameters

    - `fun_configs` — A list of `PhoenixGenApi.Structs.FunConfig` structs
    - `opts` — Options (same as `generate/2`, except `:format` is ignored)

  ## Examples

      fun_configs = AshPhoenixGenApi.Resource.Info.fun_configs(MyApp.Chat.DirectMessage)
      AshPhoenixGenApi.JsonConfig.to_map(fun_configs)
      #=> %{"send_direct_message" => %{...}, ...}

      AshPhoenixGenApi.JsonConfig.to_map(fun_configs,
        descriptions: %{"send_direct_message" => "Send direct message"}
      )
  """
  @spec to_map([map()], [option()]) :: map()
  def to_map(fun_configs, opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)
    fun_configs_to_map(fun_configs, opts)
  end

  @doc """
  Converts a list of FunConfig structs to a JSON string.

  ## Parameters

    - `fun_configs` — A list of `PhoenixGenApi.Structs.FunConfig` structs
    - `opts` — Options (same as `generate/2`, except `:format` is ignored)

  ## Examples

      fun_configs = AshPhoenixGenApi.Resource.Info.fun_configs(MyApp.Chat.DirectMessage)
      AshPhoenixGenApi.JsonConfig.to_json(fun_configs)
      #=> "{\\"send_direct_message\\": {...}}"
  """
  @spec to_json([map()], [option()]) :: String.t()
  def to_json(fun_configs, opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)
    fun_configs
    |> fun_configs_to_map(opts)
    |> encode_json()
  end

  @doc """
  Converts a single FunConfig struct to a map entry tuple.

  Returns `{key, value}` where `key` is the config key string and `value`
  is the event/data map.

  ## Parameters

    - `fun_config` — A `PhoenixGenApi.Structs.FunConfig` struct
    - `opts` — Options for building the entry

  ## Examples

      fun_config = %PhoenixGenApi.Structs.FunConfig{request_type: "send_direct_message", ...}
      {key, value} = AshPhoenixGenApi.JsonConfig.fun_config_to_entry(fun_config)
      #=> {"send_direct_message", %{"event" => "phoenix_gen_api", "data" => %{...}}}
  """
  @spec fun_config_to_entry(map(), [option()]) :: {String.t(), map()}
  def fun_config_to_entry(fun_config, opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)
    descriptions = Keyword.get(opts, :descriptions)
    user_id = Keyword.get(opts, :user_id)
    device_id = Keyword.get(opts, :device_id)
    request_id = Keyword.get(opts, :request_id)
    event_name = Keyword.get(opts, :event_name)
    arg_values = Keyword.get(opts, :arg_values)

    key = build_key(fun_config, descriptions)
    value = build_entry(fun_config, user_id, device_id, request_id, event_name, arg_values)
    {key, value}
  end

  @doc """
  Returns a default example value for a PhoenixGenApi argument type.

  Useful for generating placeholder values in the args map.

  ## Examples

      iex> AshPhoenixGenApi.JsonConfig.default_value_for_type(:string)
      ""

      iex> AshPhoenixGenApi.JsonConfig.default_value_for_type(:num)
      0

      iex> AshPhoenixGenApi.JsonConfig.default_value_for_type(:boolean)
      false

      iex> AshPhoenixGenApi.JsonConfig.default_value_for_type(:datetime)
      ""

      iex> AshPhoenixGenApi.JsonConfig.default_value_for_type(:naive_datetime)
      ""

      iex> AshPhoenixGenApi.JsonConfig.default_value_for_type(:map)
      %{}

      iex> AshPhoenixGenApi.JsonConfig.default_value_for_type(:list)
      []

      iex> AshPhoenixGenApi.JsonConfig.default_value_for_type({:list_string, 100, 50})
      []

      iex> AshPhoenixGenApi.JsonConfig.default_value_for_type({:list_num, 100})
      []

      iex> AshPhoenixGenApi.JsonConfig.default_value_for_type({:string, 255})
      ""

      iex> AshPhoenixGenApi.JsonConfig.default_value_for_type({:map, 100})
      %{}

      iex> AshPhoenixGenApi.JsonConfig.default_value_for_type({:list, 100})
      []
  """
  @spec default_value_for_type(atom() | tuple()) :: term()
  def default_value_for_type(:string), do: ""
  def default_value_for_type({:string, _}), do: ""
  def default_value_for_type(:num), do: 0
  def default_value_for_type(:boolean), do: false
  def default_value_for_type(:datetime), do: ""
  def default_value_for_type(:naive_datetime), do: ""
  def default_value_for_type(:map), do: %{}
  def default_value_for_type({:map, _}), do: %{}
  def default_value_for_type(:list), do: []
  def default_value_for_type({:list, _}), do: []
  def default_value_for_type({:list_string, _, _}), do: []
  def default_value_for_type({:list_num, _}), do: []
  def default_value_for_type(_), do: ""

  # ---------------------------------------------------------------------------
  # Private: Source detection & FunConfig retrieval
  # ---------------------------------------------------------------------------

  # Retrieves FunConfig structs from a domain or resource module.
  #
  # Detection strategy:
  #   1. If the module exports `__ash_phoenix_gen_api_fun_configs__/0`, it's a resource.
  #   2. Otherwise, try treating it as a domain via `DomainInfo.fun_configs/1`.
  #   3. If both fail, return an empty list.
  defp get_fun_configs(source) do
    cond do
      function_exported?(source, :__ash_phoenix_gen_api_fun_configs__, 0) ->
        ResourceInfo.fun_configs(source)

      true ->
        DomainInfo.fun_configs(source)
    end
  rescue
    _ -> []
  end

  # ---------------------------------------------------------------------------
  # Private: Encoding
  # ---------------------------------------------------------------------------

  # Encodes FunConfig structs into the requested format.
  defp encode(fun_configs, opts) do
    format = Keyword.get(opts, :format)

    case format do
      :fun_configs ->
        fun_configs

      :map ->
        fun_configs_to_map(fun_configs, opts)

      :json ->
        fun_configs
        |> fun_configs_to_map(opts)
        |> encode_json()

      {mod, fun, args} when is_atom(mod) and is_atom(fun) and is_list(args) ->
        apply(mod, fun, [fun_configs | args])

      invalid ->
        raise ArgumentError,
              "Invalid format: #{inspect(invalid)}. " <>
                "Expected :fun_configs, :map, :json, or {Module, :function, args}"
    end
  end

  # Encodes a map to JSON using Jason if available, otherwise raises.
  defp encode_json(map) do
    case Code.ensure_loaded(Jason) do
      {:module, Jason} ->
        Jason.encode!(map)

      {:error, _} ->
        raise ArgumentError,
              "Cannot encode to JSON: Jason is not available. " <>
                "Add {:jason, \"~> 1.0\"} to your dependencies, " <>
                "or use a custom encoder MFA with format: {MyEncoder, :encode, []}"
    end
  end

  # ---------------------------------------------------------------------------
  # Private: Map format generation
  # ---------------------------------------------------------------------------

  # Converts a list of FunConfig structs to the JSON config map format.
  #
  # Filters out disabled configs and builds key/value entries for each.
  defp fun_configs_to_map(fun_configs, opts) do
    fun_configs
    |> Enum.filter(&(Map.get(&1, :disabled, false) != true))
    |> Enum.map(fn fun_config ->
      fun_config_to_entry(fun_config, opts)
    end)
    |> Map.new()
  end

  # Builds the key string for a FunConfig entry.
  #
  # Format: "request_type" or "request_type - Description"
  # depending on whether a description is available.
  defp build_key(fun_config, descriptions) do
    request_type = fun_config.request_type
    description = resolve_description(fun_config, descriptions)

    if description do
      "#{request_type} - #{description}"
    else
      request_type
    end
  end

  # Resolves a description string for a FunConfig from the description source.
  defp resolve_description(fun_config, descriptions) when is_map(descriptions) do
    Map.get(descriptions, fun_config.request_type)
  end

  defp resolve_description(fun_config, descriptions) when is_function(descriptions, 1) do
    descriptions.(fun_config)
  end

  defp resolve_description(_fun_config, nil), do: nil

  # Builds the value map for a FunConfig entry.
  #
  # Structure:
  #   %{
  #     "event" => event_name,
  #     "data" => %{
  #       "user_id" => user_id,
  #       "device_id" => device_id,
  #       "request_type" => request_type,
  #       "request_id" => request_id,
  #       "service" => service,
  #       "version" => version,
  #       "args" => args_map
  #     }
  #   }
  defp build_entry(fun_config, user_id, device_id, request_id, event_name, arg_values) do
    args = build_args(fun_config, arg_values)

    %{
      "event" => event_name,
      "data" => %{
        "user_id" => user_id,
        "device_id" => device_id,
        "request_type" => fun_config.request_type,
        "request_id" => request_id,
        "service" => fun_config.service,
        "version" => fun_config.version,
        "args" => args
      }
    }
  end

  # Builds the args map for a FunConfig entry.
  #
  # Uses custom arg values if provided, otherwise falls back to
  # type-based default values.
  defp build_args(fun_config, arg_values) do
    custom_args = resolve_arg_values(fun_config, arg_values)
    arg_orders = Map.get(fun_config, :arg_orders, []) || []
    arg_types = Map.get(fun_config, :arg_types, %{}) || %{}

    # When arg_orders is :map, derive order from arg_types keys
    arg_orders = if arg_orders == :map, do: Map.keys(arg_types), else: arg_orders

    arg_orders
    |> Enum.map(fn arg_name ->
      value =
        case Map.fetch(custom_args, arg_name) do
          {:ok, val} ->
            val

          :error ->
            arg_type = Map.get(arg_types, arg_name)
            default_value_for_type(arg_type)
        end

      {arg_name, value}
    end)
    |> Map.new()
  end

  # Resolves custom arg values for a FunConfig from the arg_values source.
  defp resolve_arg_values(fun_config, arg_values) when is_map(arg_values) do
    Map.get(arg_values, fun_config.request_type, %{})
  end

  defp resolve_arg_values(fun_config, arg_values) when is_function(arg_values, 1) do
    case arg_values.(fun_config) do
      map when is_map(map) -> map
      _ -> %{}
    end
  end

  defp resolve_arg_values(_fun_config, nil), do: %{}
end
