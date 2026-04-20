defmodule AshPhoenixGenApi.Codec do
  @moduledoc """
  Encodes Ash resource struct results based on `result_encoder` configuration.

  The `result_encoder` determines how the result returned from an Ash action
  call is encoded before being returned to the caller. This module provides
  the encoding functions used by the auto-generated code interface functions.

  ## Encoder Modes

  - `:struct` — Return the Ash resource struct as-is (default, no encoding)
  - `:map` — Convert the Ash resource struct to a map containing only public fields
    (using `Ash.Resource.Info.public_fields/1` to filter; falls back to `Map.from_struct/1`
    for non-Ash-resource structs)
  - `{Module, :function, args}` — Custom encoder MFA. The function receives
    the result as its first argument, followed by `args`, and must return
    the encoded result.

  ## Encoding Behavior

  ### `encode_result/2` (for ok/error tuples)

  Handles `{:ok, result}` and `{:error, error}` tuples returned by Ash actions.
  Only encodes the value on success; errors are passed through unchanged.

  For `:map` encoding:
  - Single Ash resource structs are converted to maps containing only public fields
    (using `Ash.Resource.Info.public_fields/1` to filter)
  - Lists of structs are mapped with each struct filtered to public fields
  - Non-Ash-resource structs fall back to `Map.from_struct/1`
  - The atom `:ok` (from destroy actions) is returned as-is
  - Non-struct values are returned as-is

  ### `encode_value/2` (for direct values)

  Encodes a value directly, used by bang (!) functions that already raise
  on error. The encoding behavior is the same as `encode_result/2` but
  operates on the raw value instead of an ok/error tuple.

  ## Usage

  This module is primarily used internally by the generated code interface
  functions. You typically don't call it directly, but you can if needed:

      # Encode an ok/error tuple result
      result = Ash.create(changeset)
      AshPhoenixGenApi.Codec.encode_result(result, :map)
      #=> {:ok, %{id: "...", name: "..."}}  # only public fields

      # Encode a direct value (from bang functions)
      record = Ash.create!(changeset)
      AshPhoenixGenApi.Codec.encode_value(record, :map)
      #=> %{id: "...", name: "..."}  # only public fields

      # Custom encoder MFA
      AshPhoenixGenApi.Codec.encode_value(record, {MyEncoder, :to_json, []})
      #=> MyEncoder.to_json(record)
  """

  @type result_encoder ::
          :struct
          | :map
          | {module(), atom(), [any()]}

  @doc """
  Encodes the result of an Ash action call that returns an ok/error tuple.

  Only encodes the value on success; errors are passed through unchanged.

  ## Parameters

    - `result` — An `{:ok, value}` or `{:error, error}` tuple
    - `encoder` — The encoder mode (`:struct`, `:map`, or `{Module, :function, args}`)

  ## Returns

  - `{:ok, encoded_value}` on success
  - `{:error, error}` on failure (passed through unchanged)

  ## Examples

      iex> AshPhoenixGenApi.Codec.encode_result({:ok, %MyResource{id: "1"}}, :struct)
      {:ok, %MyResource{id: "1"}}

      iex> AshPhoenixGenApi.Codec.encode_result({:ok, %MyResource{id: "1"}}, :map)
      {:ok, %{id: "1"}}  # only public fields from the Ash resource

      iex> AshPhoenixGenApi.Codec.encode_result({:error, :some_error}, :map)
      {:error, :some_error}

      iex> AshPhoenixGenApi.Codec.encode_result({:ok, :ok}, :map)
      {:ok, :ok}
  """
  @spec encode_result({:ok, term()} | {:error, term()} | :ok, result_encoder()) ::
          {:ok, term()} | {:error, term()} | :ok
  def encode_result({:ok, value}, encoder) do
    {:ok, encode_value(value, encoder)}
  end

  def encode_result({:error, error}, _encoder) do
    {:error, error}
  end

  # Destroy actions return :ok directly, not {:ok, :ok}
  def encode_result(:ok, _encoder) do
    :ok
  end

  @doc """
  Encodes a direct value using the specified encoder.

  Used by bang (!) functions that already raise on error, so the value
  is always a successful result.

  ## Parameters

    - `value` — The value to encode
    - `encoder` — The encoder mode (`:struct`, `:map`, or `{Module, :function, args}`)

  ## Returns

  The encoded value.

  ## Examples

      iex> AshPhoenixGenApi.Codec.encode_value(%MyResource{id: "1"}, :struct)
      %MyResource{id: "1"}

      iex> AshPhoenixGenApi.Codec.encode_value(%MyResource{id: "1"}, :map)
      %{id: "1"}  # only public fields from the Ash resource

      iex> AshPhoenixGenApi.Codec.encode_value([%MyResource{id: "1"}], :map)
      [%{id: "1"}]  # each struct filtered to public fields

      iex> AshPhoenixGenApi.Codec.encode_value(:ok, :map)
      :ok
  """
  @spec encode_value(term(), result_encoder()) :: term()
  def encode_value(value, :struct), do: value

  def encode_value(value, :map) do
    case value do
      # Destroy actions return :ok on success — no encoding needed
      :ok ->
        :ok

      # Single struct — convert to map
      value when is_struct(value) ->
        struct_to_map(value)

      # List of structs — map each one
      value when is_list(value) ->
        Enum.map(value, &encode_value(&1, :map))

      # Other values (e.g., generic action results) — pass through
      other ->
        other
    end
  end

  def encode_value(value, {mod, fun, args}) when is_atom(mod) and is_atom(fun) and is_list(args) do
    apply(mod, fun, [value | args])
  end

  # Fallback: if encoder is nil or unrecognized, return value as-is
  def encode_value(value, _), do: value

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Converts a struct to a map, keeping only public fields from the Ash resource.
  #
  # For Ash resources, uses `Ash.Resource.Info.public_fields/1` to determine
  # which fields are public and filters the map accordingly. This excludes
  # private attributes, internal metadata fields (like `__meta__`), and any
  # other non-public fields.
  #
  # For non-Ash-resource structs, falls back to `Map.from_struct/1`.
  defp struct_to_map(struct) do
    resource = struct.__struct__

    if ash_resource?(resource) do
      public_field_names =
        resource
        |> Ash.Resource.Info.public_fields()
        |> Enum.map(& &1.name)
        |> MapSet.new()

      struct
      |> Map.from_struct()
      |> Map.filter(fn {key, _value} -> MapSet.member?(public_field_names, key) end)
    else
      Map.from_struct(struct)
    end
  end

  # Checks if a module is an Ash Resource by verifying it uses the Ash.Resource DSL.
  defp ash_resource?(module) do
    Spark.Dsl.is?(module, Ash.Resource)
  rescue
    _ -> false
  end
end
