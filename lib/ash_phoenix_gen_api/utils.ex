defmodule AshPhoenixGenApi.Utils do
  @moduledoc """
  Internal helpers shared across transformers, verifiers, and Info modules.

  These functions consolidate logic that was previously duplicated across
  `AshPhoenixGenApi.Transformers.*` and `AshPhoenixGenApi.Verifiers.*`.
  """

  @doc """
  Extracts a value from a Spark.InfoGenerator accessor result.

  Spark.InfoGenerator generates two versions of each accessor:

  - `gen_api_foo/1` returns `{:ok, value}` or `:error`
  - `gen_api_foo!/1` returns the value or raises
  - Predicate functions (ending with `?`) return the value directly

  This helper unwraps the `{:ok, value}` tuple, falls back to the provided
  default when the option is not configured (`:error`), and passes through
  direct values (for predicate functions).
  """
  @spec extract_opt({:ok, term()} | :error | term(), term()) :: term()
  def extract_opt({:ok, value}, _default), do: value
  def extract_opt(:error, default), do: default
  def extract_opt(value, _default) when not is_tuple(value), do: value

  @doc """
  Checks whether a value has the shape of a valid MFA tuple
  `{module, function, args}` where module and function are atoms
  and args is a list.
  """
  @spec valid_mfa?(term()) :: boolean()
  def valid_mfa?({mod, fun, args}), do: is_atom(mod) and is_atom(fun) and is_list(args)
  def valid_mfa?(_), do: false

  @doc """
  Returns a list of human-readable problems with an MFA tuple.

  Used by verifiers to explain exactly which parts of the tuple are invalid.
  """
  @spec mfa_errors(term()) :: [String.t()]
  def mfa_errors({mod, fun, args}) do
    [
      {is_atom(mod), "Module must be an atom, got: #{inspect(mod)}"},
      {is_atom(fun), "Function must be an atom, got: #{inspect(fun)}"},
      {is_list(args), "Args must be a list, got: #{inspect(args)}"}
    ]
    |> Enum.reject(fn {valid?, _message} -> valid? end)
    |> Enum.map(fn {_valid?, message} -> "  #{message}" end)
  end

  def mfa_errors(other),
    do: ["  Expected an MFA tuple {module, function, args}, got: #{inspect(other)}"]

  @doc """
  Formats a source annotation as a "Defined at" suffix for error messages.

  Supports tuple (`{line, column}`), property-list, and other annotation
  shapes produced by `:erl_anno`. Returns an empty string when no usable
  annotation is available.
  """
  @spec format_source_location(term()) :: String.t()
  def format_source_location(nil), do: ""

  # A bare location tuple carries no file information.
  def format_source_location({line, _column}) when is_integer(line), do: "\n  Defined at"

  def format_source_location(anno) when is_list(anno) do
    format_defined_at(Keyword.get(anno, :location), Keyword.get(anno, :file))
  end

  def format_source_location(_), do: ""

  defp format_defined_at(_location, :undefined), do: "\n  Defined at"
  defp format_defined_at(nil, _file), do: "\n  Defined at"

  defp format_defined_at(location, file) when location != nil and file != nil do
    "\n  Defined at (source: #{Path.relative_to_cwd(to_string(file))}:#{format_line(location)})"
  end

  defp format_defined_at(_location, _file), do: "\n  Defined at"

  defp format_line({line, _column}), do: Integer.to_string(line)
  defp format_line(line) when is_integer(line), do: Integer.to_string(line)
end
