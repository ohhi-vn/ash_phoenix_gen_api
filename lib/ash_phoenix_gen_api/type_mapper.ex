defmodule AshPhoenixGenApi.TypeMapper do
  @moduledoc """
  Maps Ash types to PhoenixGenApi argument types.

  PhoenixGenApi supports the following argument types:

  - `:string` - String values (UUIDs, dates, etc.)
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

  ## Ash Type Mapping

  | Ash Type | PhoenixGenApi Type |
  |----------|-------------------|
  | `:string` / `Ash.Type.String` | `:string` or `{:string, max_bytes}` |
  | `:integer` / `Ash.Type.Integer` | `:num` |
  | `:float` / `Ash.Type.Float` | `:num` |
  | `:decimal` / `Ash.Type.Decimal` | `:num` |
  | `:boolean` / `Ash.Type.Boolean` | `:boolean` |
  | `:uuid` / `Ash.Type.UUID` | `:string` |
  | `:uuid_v7` / `Ash.Type.UUIDv7` | `:string` |
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
  """

  @default_max_list_items 1000
  @default_max_string_item_length 50
  @default_max_map_items 1000

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
      :string

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
  def to_gen_api_type(ash_type, constraints \\ [])

  # String types
  def to_gen_api_type(:string, constraints) do
    case Keyword.get(constraints, :max_length) do
      nil -> :string
      max_length when is_integer(max_length) and max_length > 0 -> {:string, max_length}
      _ -> :string
    end
  end

  def to_gen_api_type(Ash.Type.String, constraints), do: to_gen_api_type(:string, constraints)

  def to_gen_api_type(:ci_string, constraints) do
    case Keyword.get(constraints, :max_length) do
      nil -> :string
      max_length when is_integer(max_length) and max_length > 0 -> {:string, max_length}
      _ -> :string
    end
  end

  def to_gen_api_type(Ash.Type.CiString, constraints), do: to_gen_api_type(:ci_string, constraints)

  # Numeric types
  def to_gen_api_type(:integer, _constraints), do: :num
  def to_gen_api_type(Ash.Type.Integer, _constraints), do: :num
  def to_gen_api_type(:float, _constraints), do: :num
  def to_gen_api_type(Ash.Type.Float, _constraints), do: :num
  def to_gen_api_type(:decimal, _constraints), do: :num
  def to_gen_api_type(Ash.Type.Decimal, _constraints), do: :num

  # UUID types
  def to_gen_api_type(:uuid, _constraints), do: :string
  def to_gen_api_type(Ash.Type.UUID, _constraints), do: :string
  def to_gen_api_type(:uuid_v7, _constraints), do: :string
  def to_gen_api_type(Ash.Type.UUIDv7, _constraints), do: :string

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

  # Atom - serialized as string
  def to_gen_api_type(:atom, _constraints), do: :string
  def to_gen_api_type(Ash.Type.Atom, _constraints), do: :string

  # Map types - map to :map with optional max_items constraint
  def to_gen_api_type(:map, constraints) do
    case Keyword.get(constraints, :max_items) do
      nil -> :map
      max_items when is_integer(max_items) and max_items > 0 -> {:map, max_items}
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
    max_items = Keyword.get(constraints, :max_items, @default_max_list_items)
    inner_constraints = Keyword.get(constraints, :items, [])

    case to_gen_api_type(inner_type, inner_constraints) do
      :string ->
        max_item_length =
          Keyword.get(inner_constraints, :max_length, @default_max_string_item_length)

        {:list_string, max_items, max_item_length}

      {:string, _max_bytes} ->
        max_item_length =
          Keyword.get(inner_constraints, :max_length, @default_max_string_item_length)

        {:list_string, max_items, max_item_length}

      :num ->
        {:list_num, max_items}

      :map ->
        {:list, max_items}

      {:map, _max_items} ->
        {:list, max_items}

      :datetime ->
        {:list, max_items}

      :naive_datetime ->
        {:list, max_items}

      :boolean ->
        {:list, max_items}

      # Nested lists and other complex types use :list
      _ ->
        {:list, max_items}
    end
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

  # Catch-all: try to resolve the type module, otherwise default to :string
  def to_gen_api_type(ash_type, constraints) when is_atom(ash_type) do
    cond do
      function_exported?(ash_type, :type, 1) ->
        # It's an Ash type module, try to get the underlying type
        underlying = ash_type.type(constraints)
        to_gen_api_type(underlying, constraints)

      true ->
        # Unknown type, default to string
        :string
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

          %{accept: accept_list} when is_list(accept_list) ->
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
          {attr.name, gen_api_type, attr.allow_nil?}
        end)

      arg_fields =
        Enum.map(arguments, fn arg ->
          gen_api_type = to_gen_api_type(arg.type, arg.constraints)
          {arg.name, gen_api_type, arg.allow_nil?}
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
  @spec build_arg_config([{atom(), atom() | tuple(), boolean()}]) :: {map(), [String.t()]}
  def build_arg_config(fields) do
    arg_orders =
      fields
      |> Enum.map(fn {name, _type, _allow_nil?} -> Atom.to_string(name) end)

    arg_types =
      fields
      |> Enum.map(fn {name, type, _allow_nil?} -> {Atom.to_string(name), type} end)
      |> Map.new()

    {arg_types, arg_orders}
  end
end
