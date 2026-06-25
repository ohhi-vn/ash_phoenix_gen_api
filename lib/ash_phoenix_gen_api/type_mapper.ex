defmodule AshPhoenixGenApi.TypeMapper do
  @moduledoc """
  Maps Ash types to PhoenixGenApi argument types.
  PhoenixGenApi supports the following argument types:

  - `:string` - String values
  - `:uuid` - UUID values (auto-validated and converted)
  - `{:string, max_bytes}` - String with custom max byte size
  - `:num` - Numeric values (integers, floats)
  - `:boolean` - Boolean values
  - `:datetime` - ISO 8601 datetime string, auto-converted to DateTime
  - `:naive_datetime` - ISO 8601 datetime string, auto-converted to NaiveDateTime
  - `:map` - Generic map
  - `{:map, max_items}` - Map with max items constraint
  - `:list` - Generic list
  - `{:list, max_items}` - List with max items constraint
  - `{:list_string, max_items, max_item_length}` - Lists of strings with constraints
  - `{:list_num, max_items}` - Lists of numbers with constraints

  alias Ash.Resource.Info, as: ResourceInfo

  | Ash Type | PhoenixGenApi Type |
  |----------|-------------------|
  | `:string` / `Ash.Type.String` | `:string` or `{:string, max_bytes}` |
  | `:integer` / `Ash.Type.Integer` | `:num` |
  | `:float` / `Ash.Type.Float` | `:num` |
  | `:decimal` / `Ash.Type.Decimal` | `:num` |
  | `:boolean` / `Ash.Type.Boolean` | `:boolean` |
  | `:uuid` / `Ash.Type.UUID` | `:uuid` |
  | `:uuid_v7` / `Ash.Type.UUIDv7` | `:uuid` |
  | `:date` / `Ash.Type.Date` | `:string` |
  | `:time` / `Ash.Type.Time` | `:string` |
  | `:datetime` / `Ash.Type.DateTime` | `:datetime` |
  | `:utc_datetime` / `Ash.Type.UtcDateTime` | `:datetime` |
  | `:utc_datetime_usec` / `Ash.Type.UtcDateTimeUsec` | `:datetime` |
  | `:naive_datetime` / `Ash.Type.NaiveDateTime` | `:naive_datetime` |
  | `:naive_datetime_usec` / `Ash.Type.NaiveDateTimeUsec` | `:naive_datetime` |
  | `:atom` / `Ash.Type.Atom` | `:string` |
  | `:map` / `Ash.Type.Map` | `:map` or `{:map, max_items}` |
  | `:json` / `Ash.Type.Json` | `:map` |
  | `:struct` / `Ash.Type.Struct` | `:map` |
  | `:keyword` / `Ash.Type.Keyword` | `:map` |
  | `:binary` / `Ash.Type.Binary` | `:string` |
  | `:term` / `Ash.Type.Term` | `:string` |
  | `:tuple` / `Ash.Type.Tuple` | `:string` |
  | `{:array, :string}` | `{:list_string, 1000, 50}` |
  | `{:array, :integer}` | `{:list_num, 1000}` |
  | `{:array, :uuid}` | `{:list_string, 1000, 50}` |
  | `{:array, :map}` | `{:list, 1000}` |
  | `:ci_string` / `Ash.Type.CiString` | `:string` |
  | `:duration` / `Ash.Type.Duration` | `:string` |
  | `:duration_name` / `Ash.Type.DurationName` | `:string` |
  | `Ash.Type.Enum` | `:string` |
  | `:enum` | `:string` |

  **Notes:**

  - `{:array, :uuid}` maps to `{:list_string, 1000, 50}` — UUIDs are always 36 characters,
    so the 50-byte `max_item_bytes` cap provides a small safety margin.
  - `Ash.Type.Enum` and `:enum` map to `:string`. If PhoenixGenApi adds native enum
    validation in the future, consider registering a custom mapping via
    `AshPhoenixGenApi.TypeMapper.register/2`.
  - Custom Ash types (types that use `Ash.Type`) that are not in this table will
    attempt to resolve via `type/1` and recursively map. If resolution fails, they
    default to `:string`. Use `register/2` to provide an explicit mapping.
  """

  @default_max_list_items 1000
  @default_max_string_item_length 50
  @default_max_map_items 1000

  # Persistent storage for custom type mappings (cross-process)
  @custom_type_mappings_table :custom_type_mappings_table

  @doc """
  Registers a custom type mapping.

  Allows users to extend or override the default Ash-to-PhoenixGenApi type mappings
  for custom Ash types (types that use `Ash.Type`).

  ## Parameters

  - `ash_type` — The Ash type module (e.g., `MyApp.CustomType`) or a type identifier
  - `gen_api_type` — The PhoenixGenApi type to map to (e.g., `:string`, `:num`, `{:string, 255}`)

  ## Examples

      # In your application startup or config:
      AshPhoenixGenApi.TypeMapper.register(MyApp.CustomType, :string)
      AshPhoenixGenApi.TypeMapper.register(MyApp.Types.Status, :num)

  """
  @spec register(atom() | module(), atom() | tuple()) :: :ok
  def register(ash_type, gen_api_type) do
    table = :persistent_term.get(@custom_type_mappings_table, %{})
    :persistent_term.put(@custom_type_mappings_table, Map.put(table, ash_type, gen_api_type))
    :ok
  end

  @doc """
  Unregisters a custom type mapping.

  ## Examples

      AshPhoenixGenApi.TypeMapper.unregister(MyApp.CustomType)

  """
  @spec unregister(atom() | module()) :: :ok
  def unregister(ash_type) do
    table = :persistent_term.get(@custom_type_mappings_table, %{})
    :persistent_term.put(@custom_type_mappings_table, Map.delete(table, ash_type))
    :ok
  end

  @doc """
  Looks up a registered custom type mapping.

  Returns `{:ok, gen_api_type}` if a mapping exists, or `:error` if not registered.

  ## Examples

      iex> AshPhoenixGenApi.TypeMapper.register(MyCustomType, :string)
      iex> AshPhoenixGenApi.TypeMapper.lookup(MyCustomType)
      {:ok, :string}

      iex> AshPhoenixGenApi.TypeMapper.lookup(UnregisteredType)
      :error
  """
  @spec lookup(atom() | module()) :: {:ok, atom() | tuple()} | :error
  def lookup(ash_type) do
    table = :persistent_term.get(@custom_type_mappings_table, %{})

    case Map.fetch(table, ash_type) do
      :error -> :error
      {:ok, type} -> {:ok, type}
    end
  end

  @doc """
  Returns all registered custom type mappings.

  ## Examples

      AshPhoenixGenApi.TypeMapper.register(MyType, :string)
      mappings = AshPhoenixGenApi.TypeMapper.custom_mappings()
      %{MyType => :string} = mappings
  """
  @spec custom_mappings() :: %{(atom() | module()) => atom() | tuple()}
  def custom_mappings do
    :persistent_term.get(@custom_type_mappings_table, %{})
  end

  @doc """
  Clears all registered custom type mappings.
  """
  @spec clear_custom_mappings() :: :ok
  def clear_custom_mappings do
    :persistent_term.put(@custom_type_mappings_table, %{})
    :ok
  end

  @doc """
  Maps an Ash type to a PhoenixGenApi argument type.

  ## Parameters

    - `ash_type` - The Ash type (atom or tuple) to map
    - `constraints` - Optional Ash type constraints (used for list constraints, etc.)

  ## Returns

  A PhoenixGenApi compatible type atom or tuple.

  ## Examples

      iex> AshPhoenixGenApi.TypeMapper.to_gen_api_type(:string)
      :string

      iex> AshPhoenixGenApi.TypeMapper.to_gen_api_type(:integer)
      :num

      iex> AshPhoenixGenApi.TypeMapper.to_gen_api_type(:uuid)
      :uuid

      iex> AshPhoenixGenApi.TypeMapper.to_gen_api_type(:datetime)
      :datetime

      iex> AshPhoenixGenApi.TypeMapper.to_gen_api_type(:naive_datetime)
      :naive_datetime

      iex> AshPhoenixGenApi.TypeMapper.to_gen_api_type(:map)
      :map

      iex> AshPhoenixGenApi.TypeMapper.to_gen_api_type(:map, max_items: 50)
      {:map, 50}

      iex> AshPhoenixGenApi.TypeMapper.to_gen_api_type({:array, :string})
      {:list_string, 1000, 50}

      iex> AshPhoenixGenApi.TypeMapper.to_gen_api_type({:array, :integer})
      {:list_num, 1000}

      iex> AshPhoenixGenApi.TypeMapper.to_gen_api_type({:array, :map})
      {:list, 1000}
  """
  @spec to_gen_api_type(atom() | tuple(), keyword()) ::
          :string
          | {:string, pos_integer()}
          | :num
          | :boolean
          | :datetime
          | :naive_datetime
          | :map
          | {:map, pos_integer()}
          | :list
          | {:list, pos_integer()}
          | {:list_string, pos_integer(), pos_integer()}
          | {:list_num, pos_integer()}
  # String types
  def to_gen_api_type(type, constraints \\ [])

  def to_gen_api_type(:string, constraints) do
    case Keyword.get(constraints, :max_length) do
      nil ->
        :string

      max_length when is_integer(max_length) and max_length > 0 ->
        [type: :string, max_bytes: max_length]

      _ ->
        :string
    end
  end

  def to_gen_api_type(Ash.Type.String, constraints), do: to_gen_api_type(:string, constraints)

  def to_gen_api_type(:ci_string, constraints) do
    case Keyword.get(constraints, :max_length) do
      nil ->
        :string

      max_length when is_integer(max_length) and max_length > 0 ->
        [type: :string, max_bytes: max_length]

      _ ->
        :string
    end
  end

  def to_gen_api_type(Ash.Type.CiString, constraints),
    do: to_gen_api_type(:ci_string, constraints)

  # Numeric types
  def to_gen_api_type(:integer, _constraints), do: :num
  def to_gen_api_type(Ash.Type.Integer, _constraints), do: :num
  def to_gen_api_type(:float, _constraints), do: :num
  def to_gen_api_type(Ash.Type.Float, _constraints), do: :num
  def to_gen_api_type(:decimal, _constraints), do: :num
  def to_gen_api_type(Ash.Type.Decimal, _constraints), do: :num

  # UUID types
  def to_gen_api_type(:uuid, _constraints), do: :uuid
  def to_gen_api_type(Ash.Type.UUID, _constraints), do: :uuid
  def to_gen_api_type(:uuid_v7, _constraints), do: :uuid
  def to_gen_api_type(Ash.Type.UUIDv7, _constraints), do: :uuid

  # Date/Time types - date, time, duration remain as :string
  def to_gen_api_type(:date, _constraints), do: :string
  def to_gen_api_type(Ash.Type.Date, _constraints), do: :string
  def to_gen_api_type(:time, _constraints), do: :string
  def to_gen_api_type(Ash.Type.Time, _constraints), do: :string
  def to_gen_api_type(:time_usec, _constraints), do: :string
  def to_gen_api_type(Ash.Type.TimeUsec, _constraints), do: :string
  def to_gen_api_type(:duration, _constraints), do: :string
  def to_gen_api_type(Ash.Type.Duration, _constraints), do: :string
  def to_gen_api_type(:duration_name, _constraints), do: :string
  def to_gen_api_type(Ash.Type.DurationName, _constraints), do: :string

  # DateTime types - map to :datetime for auto-conversion
  def to_gen_api_type(:datetime, _constraints), do: :datetime
  def to_gen_api_type(Ash.Type.DateTime, _constraints), do: :datetime
  def to_gen_api_type(:utc_datetime, _constraints), do: :datetime
  def to_gen_api_type(Ash.Type.UtcDateTime, _constraints), do: :datetime
  def to_gen_api_type(:utc_datetime_usec, _constraints), do: :datetime
  def to_gen_api_type(Ash.Type.UtcDateTimeUsec, _constraints), do: :datetime

  # NaiveDateTime types - map to :naive_datetime for auto-conversion
  def to_gen_api_type(:naive_datetime, _constraints), do: :naive_datetime
  def to_gen_api_type(Ash.Type.NaiveDateTime, _constraints), do: :naive_datetime
  def to_gen_api_type(:naive_datetime_usec, _constraints), do: :naive_datetime
  def to_gen_api_type(Ash.Type.NaiveDateTimeUsec, _constraints), do: :naive_datetime

  # Boolean
  def to_gen_api_type(:boolean, _constraints), do: :boolean
  def to_gen_api_type(Ash.Type.Boolean, _constraints), do: :boolean

  # Map types - map to :map with optional max_items constraint
  def to_gen_api_type(:map, constraints) do
    case Keyword.get(constraints, :max_items) do
      nil -> :map
      max_items when is_integer(max_items) and max_items > 0 -> [type: :map, max_items: max_items]
      _ -> :map
    end
  end

  def to_gen_api_type(Ash.Type.Map, constraints), do: to_gen_api_type(:map, constraints)

  # JSON - map to :map
  def to_gen_api_type(Ash.Type.Json, _constraints), do: :map

  # Struct - map to :map
  def to_gen_api_type(:struct, _constraints), do: :map
  def to_gen_api_type(Ash.Type.Struct, _constraints), do: :map

  # Keyword - map to :map
  def to_gen_api_type(:keyword, _constraints), do: :map
  def to_gen_api_type(Ash.Type.Keyword, _constraints), do: :map

  # Binary - base64 encoded as string
  def to_gen_api_type(:binary, _constraints), do: :string
  def to_gen_api_type(Ash.Type.Binary, _constraints), do: :string

  # Term - serialized as string
  def to_gen_api_type(:term, _constraints), do: :string
  def to_gen_api_type(Ash.Type.Term, _constraints), do: :string

  # Tuple - serialized as string
  def to_gen_api_type(:tuple, _constraints), do: :string
  def to_gen_api_type(Ash.Type.Tuple, _constraints), do: :string

  # Vector - serialized as string
  def to_gen_api_type(Ash.Type.Vector, _constraints), do: :string

  # Array types - map to list types
  def to_gen_api_type({:array, inner_type}, constraints) do
    map_array_type(inner_type, constraints)
  end

  # Ash.Type.Array module form
  def to_gen_api_type(Ash.Type.Array, constraints) do
    inner_type = Keyword.get(constraints, :items, :string)
    to_gen_api_type({:array, inner_type}, constraints)
  end

  # Union type - use the first non-nil type's mapping, default to string
  def to_gen_api_type(Ash.Type.Union, _constraints), do: :string
  def to_gen_api_type(:union, _constraints), do: :string

  # Enum types
  def to_gen_api_type(Ash.Type.Enum, _constraints), do: :string

  # File type (if using ash_type_file or similar)
  def to_gen_api_type(:file, _constraints), do: :string

  # Catch-all: check custom mappings first, then try to resolve the type module,
  # otherwise default to :string
  def to_gen_api_type(ash_type, constraints) when is_atom(ash_type) do
    case :persistent_term.get(@custom_type_mappings_table, %{}) do
      %{^ash_type => custom_type} ->
        custom_type

      _ ->
        if function_exported?(ash_type, :type, 1) do
          # It's an Ash type module, try to get the underlying type
          underlying = ash_type.type(constraints)
          to_gen_api_type(underlying, constraints)
        else
          # Unknown type, default to string
          :string
        end
    end
  end

  def to_gen_api_type(_ash_type, _constraints), do: :string

  @doc """
  Maps an Ash attribute to a PhoenixGenApi argument type.

  Takes an Ash resource attribute and returns the appropriate PhoenixGenApi type,
  considering the attribute's type and constraints.

  ## Parameters

    - `attribute` - An Ash resource attribute struct

  ## Returns

  A PhoenixGenApi compatible type atom or tuple.

  ## Examples

      iex> attr = %{__struct__: Ash.Resource.Attribute, name: :user_id, type: Ash.Type.UUID, constraints: []}
      iex> AshPhoenixGenApi.TypeMapper.attribute_to_gen_api_type(attr)
      :string

      iex> attr = %{__struct__: Ash.Resource.Attribute, name: :count, type: Ash.Type.Integer, constraints: []}
      iex> AshPhoenixGenApi.TypeMapper.attribute_to_gen_api_type(attr)
      :num

      iex> attr = %{__struct__: Ash.Resource.Attribute, name: :created_at, type: Ash.Type.DateTime, constraints: []}
      iex> AshPhoenixGenApi.TypeMapper.attribute_to_gen_api_type(attr)
      :datetime

      iex> attr = %{__struct__: Ash.Resource.Attribute, name: :metadata, type: Ash.Type.Map, constraints: []}
      iex> AshPhoenixGenApi.TypeMapper.attribute_to_gen_api_type(attr)
      :map
  """
  @spec attribute_to_gen_api_type(%{type: term(), constraints: keyword()}) ::
          :string
          | {:string, pos_integer()}
          | :num
          | :boolean
          | :datetime
          | :naive_datetime
          | :map
          | {:map, pos_integer()}
          | :list
          | {:list, pos_integer()}
          | {:list_string, pos_integer(), pos_integer()}
          | {:list_num, pos_integer()}
  def attribute_to_gen_api_type(%{type: type, constraints: constraints}) do
    to_gen_api_type(type, constraints)
  end

  @doc """
  Maps an Ash action argument to a PhoenixGenApi argument type.

  Takes an Ash action argument and returns the appropriate PhoenixGenApi type,
  considering the argument's type and constraints.

  ## Parameters

    - `argument` - An Ash action argument struct

  ## Returns

  A PhoenixGenApi compatible type atom or tuple.
  """
  @spec argument_to_gen_api_type(%{type: term(), constraints: keyword()}) ::
          :string
          | {:string, pos_integer()}
          | :num
          | :boolean
          | :datetime
          | :naive_datetime
          | :map
          | {:map, pos_integer()}
          | :list
          | {:list, pos_integer()}
          | {:list_string, pos_integer(), pos_integer()}
          | {:list_num, pos_integer()}
  def argument_to_gen_api_type(%{type: type, constraints: constraints}) do
    to_gen_api_type(type, constraints)
  end

  @doc """
  Determines if an Ash type maps to a PhoenixGenApi list type.

  ## Examples

      iex> AshPhoenixGenApi.TypeMapper.list_type?({:array, :string})
      true

      iex> AshPhoenixGenApi.TypeMapper.list_type?(:string)
      false
  """
  @spec list_type?(atom() | tuple()) :: boolean()
  def list_type?({:array, _}), do: true
  def list_type?(Ash.Type.Array), do: true
  def list_type?(_), do: false

  @doc """
  Returns the default max list items for list types.
  """
  @spec default_max_list_items() :: pos_integer()
  def default_max_list_items, do: @default_max_list_items

  @doc """
  Returns the default max string item length for list_string types.
  """
  @spec default_max_string_item_length() :: pos_integer()
  def default_max_string_item_length, do: @default_max_string_item_length

  @doc """
  Returns the default max map items for map types.
  """
  @spec default_max_map_items() :: pos_integer()
  def default_max_map_items, do: @default_max_map_items

  @doc """
  Gets the input fields for an Ash action, combining accepted attributes and arguments.

  Returns a list of `{name, type, constraints, allow_nil?}` tuples suitable for
  building PhoenixGenApi arg_types and arg_orders.

  ## Parameters

    - `resource` - The Ash resource module
    - `action_name` - The action name atom

  ## Returns

  A list of `{field_name :: atom, gen_api_type, allow_nil? :: boolean}` tuples,
  ordered by the action's accept list followed by arguments.
  """
  @spec get_action_fields(module(), atom()) :: [{atom(), atom() | tuple(), boolean()}]
  def get_action_fields(resource, action_name) do
    action = Ash.Resource.Info.action(resource, action_name)

    if is_nil(action) do
      []
    else
      # Get accepted attributes
      accepted_attrs =
        case action do
          %{accept: :*} ->
            Ash.Resource.Info.attributes(resource)
            |> Enum.filter(& &1.public?)

          accept_list when is_list(accept_list) ->
            accept_list
            |> Enum.map(fn name -> Ash.Resource.Info.attribute(resource, name) end)
            |> Enum.filter(& &1)

          _ ->
            []
        end

      # Get action arguments
      arguments = action.arguments || []

      # Build the field list: accepted attributes first, then arguments
      attr_fields =
        Enum.map(accepted_attrs, fn attr ->
          gen_api_type = to_gen_api_type(attr.type, attr.constraints)
          default_val = get_ash_default_value(attr)
          {attr.name, gen_api_type, attr.allow_nil?, default_val}
        end)

      arg_fields =
        Enum.map(arguments, fn arg ->
          gen_api_type = to_gen_api_type(arg.type, arg.constraints)
          default_val = get_ash_default_value(arg)
          {arg.name, gen_api_type, arg.allow_nil?, default_val}
        end)

      attr_fields ++ arg_fields
    end
  end

  @doc """
  Builds arg_types map and arg_orders list from action fields.

  ## Parameters

    - `fields` - List of `{name, gen_api_type, allow_nil?}` tuples from `get_action_fields/2`

  ## Returns

  A `{arg_types, arg_orders}` tuple where:
  - `arg_types` is a map of `field_name_string => gen_api_type`
  - `arg_orders` is a list of field name strings in order
  """
  @spec build_arg_config([
          {atom(), atom() | tuple(), boolean()} | {atom(), atom() | tuple(), boolean(), any()}
        ]) :: {map(), [String.t()]}
  def build_arg_config(fields) do
    arg_orders =
      fields
      |> Enum.map(fn {name, _type, _allow_nil?, _default_val} -> Atom.to_string(name) end)

    arg_types =
      fields
      |> Enum.map(fn field ->
        {name, type, allow_nil?, default_val} = extract_field_info(field)
        arg_config = build_type_config(type, allow_nil?, default_val)
        {Atom.to_string(name), arg_config}
      end)
      |> Map.new()

    {arg_types, arg_orders}
  end

  defp extract_field_info({name, type, allow_nil?}), do: {name, type, allow_nil?, nil}

  defp extract_field_info({name, type, allow_nil?, default_val}),
    do: {name, type, allow_nil?, default_val}

  @doc """
  Gets the default value from an Ash attribute or argument.

  Returns the default value if set, or `nil` if not set.
  """
  def get_ash_default_value(%{default: default}) when not is_function(default) do
    default
  end

  def get_ash_default_value(%{default: default}) when is_function(default) do
    # For functions, we can't call them here (compile-time), so return nil
    nil
  end

  def get_ash_default_value(_), do: nil

  @doc """
  Builds the type configuration for a field.

  Returns either:
  - A simple type atom (backward compatible) when `allow_nil?` is false
  - A keyword list with `:type` and `:allow_nil?` options (extended format) when `allow_nil?` is true

  ## Examples

      iex> AshPhoenixGenApi.TypeMapper.build_type_config(:string, false)
      :string

      iex> AshPhoenixGenApi.TypeMapper.build_type_config(:string, true)
      [type: :string, allow_nil?: true]

      iex> AshPhoenixGenApi.TypeMapper.build_type_config({:string, 255}, true)
      [type: {:string, 255}, allow_nil?: true]
  """
  @spec build_type_config(atom() | tuple(), boolean(), any()) :: atom() | tuple() | keyword()
  def build_type_config(type, false, _default_val), do: type

  def build_type_config(type, true, nil) do
    {_base_type, keyword} = build_base_type_and_keyword(type)
    keyword ++ [allow_nil?: true]
  end

  def build_type_config(type, true, default_val) do
    {_base_type, keyword} = build_base_type_and_keyword(type)
    keyword ++ [default_value: default_val, allow_nil?: true]
  end

  defp build_base_type_and_keyword(type) do
    case type do
      # Keyword lists from to_gen_api_type (e.g. [type: :string, max_bytes: 5000])
      # Pass through directly — they already have the correct format
      keyword when is_list(keyword) ->
        base_type = Keyword.get(keyword, :type, :string)
        {base_type, keyword}

      # Tuple forms (legacy / explicit)
      {:string, max_bytes} ->
        {:string, [type: :string, max_bytes: max_bytes]}

      {:map, max_items} ->
        {:map, [type: :map, max_items: max_items]}

      {:list_string, max_items, max_item_bytes} ->
        {:list_string, [type: :list_string, max_items: max_items, max_item_bytes: max_item_bytes]}

      {:list_num, max_items} ->
        {:list_num, [type: :list_num, max_items: max_items]}

      {:list, max_items} ->
        {:list, [type: :list, max_items: max_items]}

      # Simple atom types
      simple_type when is_atom(simple_type) ->
        {simple_type, [type: simple_type]}
    end
  end

  @doc """
  Wraps a type with nil support.

  In PhoenixGenApi, to indicate that an argument can accept nil values,
  wrap the type in a `{:nil, type}` tuple.

  ## Examples

      iex> AshPhoenixGenApi.TypeMapper.wrap_nil_type(:string)
      {:nil, :string}

      iex> AshPhoenixGenApi.TypeMapper.wrap_nil_type({:string, 255})
      {:nil, {:string, 255}}

      iex> AshPhoenixGenApi.TypeMapper.wrap_nil_type(:num)
      {:nil, :num}
  """
  @spec wrap_nil_type(atom() | tuple()) :: {nil, atom() | tuple()}
  def wrap_nil_type(type) when is_atom(type) do
    {nil, type}
  end

  def wrap_nil_type(type) when is_tuple(type) do
    {nil, type}
  end

  defp map_array_type(inner_type, constraints) do
    max_items = Keyword.get(constraints, :max_items, @default_max_list_items)
    inner_constraints = Keyword.get(constraints, :items, [])

    # Call to_gen_api_type/2 with inner_type and inner_constraints
    inner_type
    |> to_gen_api_type(inner_constraints)
    |> map_to_list_type(max_items, inner_constraints)
  end

  defp map_to_list_type(type, max_items, inner_constraints) when is_list(type) do
    # type is a keyword list like [type: :string, max_bytes: 50]
    # This shouldn't happen anymore since to_gen_api_type returns tuples,
    # but handle it for backward compatibility
    actual_type = Keyword.get(type, :type, :string)
    map_to_list_type(actual_type, max_items, inner_constraints)
  end

  defp map_to_list_type(:string, max_items, inner_constraints) do
    max_item_length =
      Keyword.get(inner_constraints, :max_length, @default_max_string_item_length)

    [type: :list_string, max_items: max_items, max_item_bytes: max_item_length]
  end

  defp map_to_list_type(:uuid, max_items, inner_constraints) do
    max_item_length =
      Keyword.get(inner_constraints, :max_length, @default_max_string_item_length)

    [type: :list_string, max_items: max_items, max_item_bytes: max_item_length]
  end

  defp map_to_list_type({:string, _max_bytes}, max_items, inner_constraints) do
    max_item_length =
      Keyword.get(inner_constraints, :max_length, @default_max_string_item_length)

    [type: :list_string, max_items: max_items, max_item_bytes: max_item_length]
  end

  defp map_to_list_type(:num, max_items, _inner_constraints) do
    [type: :list_num, max_items: max_items]
  end

  defp map_to_list_type(:map, max_items, _inner_constraints) do
    [type: :list, max_items: max_items]
  end

  defp map_to_list_type({:map, _max_items}, max_items, _inner_constraints) do
    [type: :list, max_items: max_items]
  end

  defp map_to_list_type(:datetime, max_items, _inner_constraints) do
    [type: :list, max_items: max_items]
  end

  defp map_to_list_type(:naive_datetime, max_items, _inner_constraints) do
    [type: :list, max_items: max_items]
  end

  defp map_to_list_type(:boolean, max_items, _inner_constraints) do
    [type: :list, max_items: max_items]
  end

  defp map_to_list_type(_other, max_items, _inner_constraints) do
    [type: :list, max_items: max_items]
  end
end
