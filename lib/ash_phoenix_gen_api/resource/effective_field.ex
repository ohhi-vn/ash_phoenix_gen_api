defmodule AshPhoenixGenApi.Resource.EffectiveField do
  @moduledoc """
  A macro that generates common `effective_*` functions for configuration structs.

  Both `ActionConfig` and `MfaConfig` share the same nil-fallback pattern for
  resolving effective field values. This macro generates those functions to
  avoid duplication.

  ## Usage

      defmodule MyConfig do
        use AshPhoenixGenApi.Resource.EffectiveField
        # ... struct and type definitions, unique functions, etc.
      end

  ## Generated Functions

  The following `effective_*` functions are generated, each returning the
  struct's field value when set, or the provided default when `nil`:

  - `effective_timeout/2`
  - `effective_response_type/2`
  - `effective_request_info/2`
  - `effective_check_permission/2`
  - `effective_permission_callback/2`
  - `effective_choose_node_mode/2`
  - `effective_nodes/2`
  - `effective_retry/2`
  - `effective_version/2`

  Additionally, these shared helper functions are generated:

  - `has_explicit_arg_types?/1`
  - `has_explicit_arg_orders?/1`
  - `enabled?/1`
  """

  @doc false
  defmacro __using__(_opts) do
    module = __CALLER__.module

    effective_functions = build_effective_functions(module)
    helper_functions = build_helper_functions()

    quote do
      unquote_splicing(effective_functions)
      unquote(helper_functions)
    end
  end

  defp build_effective_functions(module) do
    fields = [
      {:timeout,
       quote(do: pos_integer() | :infinity),
       timeout_doc(module)},
      {:response_type,
       quote(do: :sync | :async | :stream | :none),
       "Resolves the effective response type, falling back to the provided default."},
      {:request_info,
       quote(do: boolean()),
       "Resolves the effective request_info, falling back to the provided default."},
      {:check_permission,
       quote(do: permission_mode()),
       "Resolves the effective check_permission, falling back to the provided default."},
      {:permission_callback,
       quote(do: permission_callback()),
       permission_callback_doc(module)},
      {:choose_node_mode,
       quote(do: choose_node_mode()),
       "Resolves the effective choose_node_mode, falling back to the provided default."},
      {:nodes,
       quote(do: node_config()),
       "Resolves the effective nodes, falling back to the provided default."},
      {:retry,
       quote(do: retry_config()),
       "Resolves the effective retry, falling back to the provided default."},
      {:version,
       quote(do: String.t()),
       "Resolves the effective version, falling back to the provided default."}
    ]

    Enum.map(fields, fn {field, spec_type, doc} ->
      function_name = String.to_atom("effective_#{field}")

      quote do
        @doc unquote(doc)
        @spec unquote(function_name)(t(), unquote(spec_type)) :: unquote(spec_type)
        def unquote(function_name)(%__MODULE__{unquote(field) => nil}, default), do: default
        def unquote(function_name)(%__MODULE__{unquote(field) => value}, _default), do: value
      end
    end)
  end

  defp timeout_doc(module) do
    """
    Resolves the effective timeout, falling back to the provided default.

    ## Examples

        iex> config = %#{module}{timeout: 10_000}
        iex> #{module}.effective_timeout(config, 5_000)
        10_000

        iex> config = %#{module}{timeout: nil}
        iex> #{module}.effective_timeout(config, 5_000)
        5000
    """
  end

  defp permission_callback_doc(module) do
    """
    Resolves the effective permission_callback, falling back to the provided default.

    When the entity-level `permission_callback` is set, returns that value.
    Otherwise, returns the section-level default.

    The callback MFA function receives `(request_type, args)` as arguments and
    returns `true` (continue) or `false` (permission denied).

    ## Examples

        iex> config = %#{module}{permission_callback: {MyModule, :check, []}}
        iex> #{module}.effective_permission_callback(config, nil)
        {MyModule, :check, []}

        iex> config = %#{module}{permission_callback: nil}
        iex> #{module}.effective_permission_callback(config, {MyModule, :check, []})
        {MyModule, :check, []}

        iex> config = %#{module}{permission_callback: nil}
        iex> #{module}.effective_permission_callback(config, nil)
        nil
    """
  end

  defp build_helper_functions do
    quote do
      @doc """
      Checks if this config has explicit arg_types defined.
      """
      @spec has_explicit_arg_types?(t()) :: boolean()
      def has_explicit_arg_types?(%__MODULE__{arg_types: nil}), do: false
      def has_explicit_arg_types?(%__MODULE__{arg_types: arg_types}) when map_size(arg_types) == 0, do: false
      def has_explicit_arg_types?(%__MODULE__{arg_types: _}), do: true

      @doc """
      Checks if this config has explicit arg_orders defined (not `:map`).
      """
      @spec has_explicit_arg_orders?(t()) :: boolean()
      def has_explicit_arg_orders?(%__MODULE__{arg_orders: :map}), do: false
      def has_explicit_arg_orders?(%__MODULE__{arg_orders: nil}), do: false
      def has_explicit_arg_orders?(%__MODULE__{arg_orders: []}), do: false
      def has_explicit_arg_orders?(%__MODULE__{arg_orders: _}), do: true

      @doc """
      Checks if this config is enabled (not disabled).
      """
      @spec enabled?(t()) :: boolean()
      def enabled?(%__MODULE__{disabled: disabled}), do: !disabled
    end
  end
end
