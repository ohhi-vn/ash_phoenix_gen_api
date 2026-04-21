defmodule AshPhoenixGenApi.Resource do
  @moduledoc """
  Ash extension for generating PhoenixGenApi function configurations from Ash resources.

  This extension allows you to define PhoenixGenApi endpoints directly in your
  Ash resource DSL, automatically generating `FunConfig` structs that can be
  pulled by gateway nodes.

  ## Usage

  Add the extension to your resource:

      defmodule MyApp.Chat.DirectMessage do
        use Ash.Resource,
          extensions: [AshPhoenixGenApi.Resource]

        gen_api do
          service "chat"
          nodes {ClusterHelper, :get_nodes, [:chat]}
          choose_node_mode :random

          action :send_direct_message do
            request_type "send_direct_message"
            timeout 10_000
            response_type :async
            request_info true
          end

          action :get_conversation do
            timeout 5_000
          end

          mfa :ping do
            request_type "ping"
            mfa {MyApp.Chat.Api, :ping, []}
            arg_types %{}
          end
        end
      end

  ## DSL

  See the DSL documentation for the full list of configuration options.
  """

  @action %Spark.Dsl.Entity{
    name: :action,
    target: AshPhoenixGenApi.Resource.ActionConfig,
    describe: """
    Configures a PhoenixGenApi endpoint for an Ash resource action.

    Each `action` entity maps an Ash action to a PhoenixGenApi `FunConfig`.
    If `request_type` is not specified, it defaults to the action name as a string.
    If `arg_types` and `arg_orders` are not specified, they are auto-derived
    from the Ash action's accepted attributes and arguments. `arg_orders`
    defaults to `:map`, which derives the order from `arg_types` keys. Set
    to a list of argument name strings to specify explicit ordering.
    """,
    examples: [
      """
      action :send_direct_message do
        request_type "send_direct_message"
        timeout 10_000
        response_type :async
        request_info true
        check_permission {:arg, "from_user_id"}
      end
      """,
      """
      action :get_conversation do
        timeout 5_000
        response_type :async
      end
      """,
      """
      # Minimal config - auto-derives request_type and args from Ash action
      action :create
      """
    ],
    args: [:name],
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: """
        The name of the Ash resource action to expose as a PhoenixGenApi endpoint.
        Must match an existing action defined on the resource.
        """
      ],
      request_type: [
        type: :string,
        doc: """
        The PhoenixGenApi request type string used by clients to call this endpoint.
        Defaults to the action name converted to a string.

        Example: `"send_direct_message"`, `"get_conversation"`
        """
      ],
      timeout: [
        type: :any,
        doc: """
        Timeout in milliseconds for the function call.
        Defaults to the `gen_api` section-level `timeout` (which defaults to `5000`).

        Accepts a positive integer or `:infinity`.
        """
      ],
      response_type: [
        type: :atom,
        doc: """
        The response mode for this endpoint.

        - `:sync` - Client waits for the result
        - `:async` - Client receives an ack, then the result later
        - `:stream` - Client receives streamed chunks
        - `:none` - Fire and forget

        Defaults to the `gen_api` section-level `response_type` (which defaults to `:async`).
        """
      ],
      request_info: [
        type: :boolean,
        doc: """
        Whether to pass request info (user_id, device_id, request_id) as the last
        argument to the MFA function. When `true`, the generated MFA will append
        a map with `%{user_id: ..., device_id: ..., request_id: ...}` to the
        function arguments.

        Defaults to the `gen_api` section-level `request_info` (which defaults to `true`).
        """
      ],
      check_permission: [
        type: :any,
        doc: """
        Permission check mode for this endpoint.

        - `false` - No permission check
        - `:any_authenticated` - Requires a valid user_id
        - `{:arg, "arg_name"}` - The specified argument must match user_id
        - `{:role, ["admin", "moderator"]}` - User must have one of the listed roles

        Defaults to the `gen_api` section-level `check_permission` (which defaults to `false`).
        """
      ],
      permission_callback: [
        type: :any,
        default: nil,
        doc: """
        A custom callback MFA for permission checking. When set, takes precedence
        over `check_permission`.

        Accepts `{Module, :function, []}` or `nil`. The callback function receives
        `request_type` (string) and `args` (map) as arguments and returns `true`
        (continue) or `false` (permission denied).

        The callback function signature:

            @callback check_permission(request_type :: String.t(), args :: map()) :: boolean()

        Example callback:

            def check_permission(request_type, args) do
              case request_type do
                "delete_user" -> args["role"] == "admin"
                "update_profile" -> args["user_id"] == args["target_user_id"]
                _ -> true
              end
            end

        When `nil`, inherits from the section-level `permission_callback`.
        When both `permission_callback` and `check_permission` are set,
        `permission_callback` takes precedence and is stored as
        `{:callback, {Module, :function, []}}` in the FunConfig's `check_permission` field.

        Defaults to the `gen_api` section-level `permission_callback` (which defaults to `nil`).
        """
      ],
      choose_node_mode: [
        type: :any,
        doc: """
        Node selection strategy for this endpoint. Overrides the section-level setting.

        - `:random` - Select a random node
        - `:hash` - Hash-based selection using request_type
        - `{:hash, key}` - Hash-based selection using the specified argument key
        - `:round_robin` - Round-robin across nodes
        """
      ],
      nodes: [
        type: :any,
        doc: """
        Target nodes for this endpoint. Overrides the section-level setting.

        Can be:
        - A list of node atoms: `[:"node1@host", :"node2@host"]`
        - An MFA tuple: `{ClusterHelper, :get_nodes, [:chat]}`
        - `:local` - Execute on the local node
        """
      ],
      retry: [
        type: :any,
        doc: """
        Retry configuration when execution fails.

        - `nil` (default) - No retry
        - A positive number `n` - Equivalent to `{:all_nodes, n}`
        - `{:same_node, n}` - Retry on the same node(s)
        - `{:all_nodes, n}` - Retry across all available nodes
        """
      ],
      version: [
        type: :string,
        doc: """
        Version string for this API endpoint. Used for API versioning.
        Defaults to the `gen_api` section-level `version` (which defaults to `"0.0.1"`).
        """
      ],
      mfa: [
        type: :any,
        doc: """
        Explicit MFA tuple to call instead of the auto-generated one.
        When specified, this overrides the default MFA derived from the resource
        module and action name.

        The auto-generated MFA is `{ResourceModule, :action_name, []}`.
        The actual function is called with the converted arguments plus
        request_info (if enabled).

        Example: `{MyApp.Interface.Api, :send_direct_message, []}`
        """
      ],
      arg_types: [
        type: :any,
        doc: """
        Explicit argument types map. When provided, overrides the auto-derived
        arg_types from the Ash action's attributes and arguments.

        Keys are argument name strings, values are PhoenixGenApi type atoms/tuples:
        - `:string` - String values
        - `:num` - Numeric values
        - `{:list_string, max_items, max_item_length}` - List of strings
        - `{:list_num, max_items}` - List of numbers

        Example: `%{"user_id" => :string, "count" => :num, "tags" => {:list_string, 1000, 50}}`
        """
      ],
      arg_orders: [
        type: :any,
        default: :map,
        doc: """
        Explicit argument order list, or `:map` to derive from arg_types keys.

        - A list of argument name strings overrides the auto-derived order.
          Example: `["user_id", "content", "file_id"]`
        - `:map` (default) derives arg_orders from the arg_types map keys.
        """
      ],
      disabled: [
        type: :boolean,
        default: false,
        doc: """
        When `true`, this endpoint is disabled and will not be included in
        the generated FunConfig list. Useful for temporarily disabling an
        endpoint without removing its configuration.
        """
      ],
      code_interface?: [
        type: {:or, [:boolean, :nil]},
        default: nil,
        doc: """
        Whether to generate a code interface function for this specific action.
        When `true`, a function matching the action name will be defined on the
        resource module that calls the action through the Ash framework.

        When `nil` (the default), inherits from the section-level `code_interface?` setting.
        Set to `false` to disable code interface generation for this action
        while keeping it enabled for others.
        """
      ],
      result_encoder: [
        type: :any,
        default: nil,
        doc: """
        How to encode the result returned from the action MFA call.

        - `:struct` — Return the Ash resource struct as-is (default behavior)
        - `:map` — Convert the Ash resource struct to a map containing only public fields
          (using `Ash.Resource.Info.public_fields/1` to filter; falls back to
          `Map.from_struct/1` for non-Ash-resource structs)
        - `{Module, :function, args}` — Custom encoder MFA. The function receives
          the result as its first argument, followed by `args`, and must return
          the encoded result.

        When `nil` (the default), inherits from the section-level `result_encoder` setting.

        The encoding is applied in the generated code interface functions.
        For `:map` encoding, Ash resource structs are converted to maps containing
        only their public fields (attributes, calculations, aggregates, relationships).
        Lists of structs are mapped accordingly. Non-Ash-resource structs fall back
        to `Map.from_struct/1`.
        For custom MFA encoders, the function receives the result and must return
        the encoded value.

        Defaults to the `gen_api` section-level `result_encoder` (which defaults to `:struct`).
        """
      ]
    ]
  }

  @mfa %Spark.Dsl.Entity{
    name: :mfa,
    target: AshPhoenixGenApi.Resource.MfaConfig,
    describe: """
    Configures a standalone PhoenixGenApi MFA endpoint.

    Unlike `action` entities which map an Ash resource action to a FunConfig,
    `mfa` entities define endpoints that call an arbitrary MFA function directly.
    This is useful for exposing custom functions that don't map to standard
    Ash CRUD actions, such as utility endpoints, batch operations, or
    service-to-service calls.

    Both `request_type` and `mfa` are required. `arg_types` must be explicitly
    provided since there is no Ash action to auto-derive from. `arg_orders`
    defaults to `:map`, which passes arguments as a map with string keys.
    """,
    examples: [
      """
      mfa :my_custom do
        request_type "my_custom"
        mfa {MyApp.Interface.Api, :my_custom, []}
        arg_types %{"user_id" => :string}
        timeout 5_000
      end
      """,
      """
      mfa :batch_process do
        request_type "batch_process"
        mfa {MyApp.BatchProcessor, :run, []}
        arg_types %{"items" => {:list_string, 1000, 50}, "mode" => :string}
        arg_orders ["items", "mode"]
        response_type :async
        request_info true
      end
      """
    ],
    args: [:name],
    schema: [
      name: [
        type: :atom,
        required: true,
        doc: """
        A unique identifier for this MFA endpoint. Used to distinguish
        this endpoint from others in the same resource.
        """
      ],
      request_type: [
        type: :string,
        required: true,
        doc: """
        The PhoenixGenApi request type string used by clients to call this endpoint.
        Must be unique across all endpoints in the same resource.

        Example: `"my_custom"`, `"batch_process"`
        """
      ],
      mfa: [
        type: :any,
        required: true,
        doc: """
        The MFA tuple to call when this endpoint is invoked.

        The function is called with `predefined_args ++ converted_args ++ info_args`:
        - `predefined_args` — the third element of this tuple (e.g., `[]`)
        - `converted_args` — request arguments (a map when `arg_orders` is `:map`,
          or positional values when `arg_orders` is a list)
        - `info_args` — request info map if `request_info` is `true`

        Example: `{MyApp.Interface.Api, :my_custom, []}`
        """
      ],
      arg_types: [
        type: :any,
        required: true,
        doc: """
        Argument types map. Required since there is no Ash action to auto-derive from.

        Keys are argument name strings, values are PhoenixGenApi type atoms/tuples:
        - `:string` - String values
        - `:num` - Numeric values
        - `{:list_string, max_items, max_item_length}` - List of strings
        - `{:list_num, max_items}` - List of numbers

        Example: `%{"user_id" => :string, "count" => :num, "tags" => {:list_string, 1000, 50}}`
        """
      ],
      arg_orders: [
        type: :any,
        default: :map,
        doc: """
        Argument order list, or `:map` to pass arguments as a map (default).

        - A list of argument name strings specifies positional ordering.
          Example: `["user_id", "content", "file_id"]`
        - `:map` (default) passes arguments as a map with string keys.
        """
      ],
      timeout: [
        type: :any,
        doc: """
        Timeout in milliseconds for the function call.
        Defaults to the `gen_api` section-level `timeout` (which defaults to `5000`).

        Accepts a positive integer or `:infinity`.
        """
      ],
      response_type: [
        type: :atom,
        doc: """
        The response mode for this endpoint.

        - `:sync` - Client waits for the result
        - `:async` - Client receives an ack, then the result later
        - `:stream` - Client receives streamed chunks
        - `:none` - Fire and forget

        Defaults to the `gen_api` section-level `response_type` (which defaults to `:async`).
        """
      ],
      request_info: [
        type: :boolean,
        doc: """
        Whether to pass request info (user_id, device_id, request_id) as the last
        argument to the MFA function. When `true`, the MFA will receive
        a map with `%{user_id: ..., device_id: ..., request_id: ...}` as the
        last argument.

        Defaults to the `gen_api` section-level `request_info` (which defaults to `true`).
        """
      ],
      check_permission: [
        type: :any,
        doc: """
        Permission check mode for this endpoint.

        - `false` - No permission check
        - `:any_authenticated` - Requires a valid user_id
        - `{:arg, "arg_name"}` - The specified argument must match user_id
        - `{:role, ["admin", "moderator"]}` - User must have one of the listed roles

        Defaults to the `gen_api` section-level `check_permission` (which defaults to `false`).
        """
      ],
      permission_callback: [
        type: :any,
        default: nil,
        doc: """
        A custom callback MFA for permission checking. When set, takes precedence
        over `check_permission`.

        Accepts `{Module, :function, []}` or `nil`. The callback function receives
        `request_type` (string) and `args` (map) as arguments and returns `true`
        (continue) or `false` (permission denied).

        When `nil`, inherits from the section-level `permission_callback`.
        When both `permission_callback` and `check_permission` are set,
        `permission_callback` takes precedence and is stored as
        `{:callback, {Module, :function, []}}` in the FunConfig's `check_permission` field.

        Defaults to the `gen_api` section-level `permission_callback` (which defaults to `nil`).
        """
      ],
      choose_node_mode: [
        type: :any,
        doc: """
        Node selection strategy for this endpoint. Overrides the section-level setting.

        - `:random` - Select a random node
        - `:hash` - Hash-based selection using request_type
        - `{:hash, key}` - Hash-based selection using the specified argument key
        - `:round_robin` - Round-robin across nodes
        """
      ],
      nodes: [
        type: :any,
        doc: """
        Target nodes for this endpoint. Overrides the section-level setting.

        Can be:
        - A list of node atoms: `[:"node1@host", :"node2@host"]`
        - An MFA tuple: `{ClusterHelper, :get_nodes, [:chat]}`
        - `:local` - Execute on the local node
        """
      ],
      retry: [
        type: :any,
        doc: """
        Retry configuration when execution fails.

        - `nil` (default) - No retry
        - A positive number `n` - Equivalent to `{:all_nodes, n}`
        - `{:same_node, n}` - Retry on the same node(s)
        - `{:all_nodes, n}` - Retry across all available nodes
        """
      ],
      version: [
        type: :string,
        doc: """
        Version string for this API endpoint. Used for API versioning.
        Defaults to the `gen_api` section-level `version` (which defaults to `"0.0.1"`).
        """
      ],
      disabled: [
        type: :boolean,
        default: false,
        doc: """
        When `true`, this endpoint is disabled and will not be included in
        the generated FunConfig list. Useful for temporarily disabling an
        endpoint without removing its configuration.
        """
      ]
    ]
  }

  @gen_api %Spark.Dsl.Section{
    name: :gen_api,
    describe: """
    Configure PhoenixGenApi endpoints for this Ash resource.

    The `gen_api` section allows you to define which Ash resource actions
    should be exposed as PhoenixGenApi endpoints, along with their configuration
    for routing, timeout, permissions, and more.

    Section-level options serve as defaults for all `action` entities within.
    Each `action` entity can override these defaults.
    """,
    examples: [
      """
      gen_api do
        service "chat"
        nodes {ClusterHelper, :get_nodes, [:chat]}
        choose_node_mode :random
        timeout 5_000
        response_type :async
        request_info true
        version "0.0.1"

        action :send_direct_message do
          request_type "send_direct_message"
          timeout 10_000
        end

        action :get_conversation do
          timeout 5_000
        end
      end
      """,
      """
      # Minimal configuration with defaults
      gen_api do
        service "chat"

        action :create
        action :read
      end
      """
    ],
    schema: [
      service: [
        type: :any,
        required: true,
        doc: """
        The service name for this resource's API endpoints.
        This is used by PhoenixGenApi to group and route API calls.

        Accepts a string or atom.
        Example: `"chat"`, `"user_service"`, `:notification`
        """
      ],
      nodes: [
        type: :any,
        default: :local,
        doc: """
        Default target nodes for all actions in this resource.

        Can be:
        - A list of node atoms: `[:"node1@host", :"node2@host"]`
        - An MFA tuple that returns a node list at runtime: `{ClusterHelper, :get_nodes, [:chat]}`
        - `:local` - Execute on the local node (default)
        """
      ],
      choose_node_mode: [
        type: :any,
        default: :random,
        doc: """
        Default node selection strategy for all actions.

        - `:random` - Select a random node (default)
        - `:hash` - Hash-based selection using request_type
        - `{:hash, key}` - Hash-based selection using the specified argument key
        - `:round_robin` - Round-robin across nodes
        """
      ],
      timeout: [
        type: :any,
        default: 5_000,
        doc: """
        Default timeout in milliseconds for all actions.
        Individual actions can override this.

        Accepts a positive integer or `:infinity`.
        """
      ],
      response_type: [
        type: :atom,
        default: :async,
        doc: """
        Default response mode for all actions.

        - `:sync` - Client waits for the result
        - `:async` - Client receives an ack, then the result later (default)
        - `:stream` - Client receives streamed chunks
        - `:none` - Fire and forget
        """
      ],
      request_info: [
        type: :boolean,
        default: true,
        doc: """
        Default for whether to pass request info (user_id, device_id, request_id)
        as the last argument to the MFA function.
        """
      ],
      check_permission: [
        type: :any,
        default: false,
        doc: """
        Default permission check mode for all actions.

        - `false` - No permission check (default)
        - `:any_authenticated` - Requires a valid user_id
        - `{:arg, "arg_name"}` - The specified argument must match user_id
        - `{:role, ["admin"]}` - User must have one of the listed roles
        """
      ],
      permission_callback: [
        type: :any,
        default: nil,
        doc: """
        Default permission callback MFA for all actions. When set, takes precedence
        over `check_permission`.

        Accepts `{Module, :function, []}` or `nil`. The callback function receives
        `request_type` (string) and `args` (map) as arguments and returns `true`
        (continue) or `false` (permission denied).

        The callback function signature:

            @callback check_permission(request_type :: String.t(), args :: map()) :: boolean()

        Example callback:

            def check_permission(request_type, args) do
              case request_type do
                "delete_user" -> args["role"] == "admin"
                "update_profile" -> args["user_id"] == args["target_user_id"]
                _ -> true
              end
            end

        When both `permission_callback` and `check_permission` are set,
        `permission_callback` takes precedence and is stored as
        `{:callback, {Module, :function, []}}` in the FunConfig's `check_permission` field.

        Defaults to `nil`.
        """
      ],
      version: [
        type: :string,
        default: "0.0.1",
        doc: """
        Default version string for all actions.
        Used for PhoenixGenApi API versioning.
        """
      ],
      retry: [
        type: :any,
        doc: """
        Default retry configuration for all actions.

        - `nil` - No retry (default)
        - A positive number `n` - Equivalent to `{:all_nodes, n}`
        - `{:same_node, n}` - Retry on the same node(s)
        - `{:all_nodes, n}` - Retry across all available nodes
        """
      ],
      code_interface?: [
        type: :boolean,
        default: true,
        doc: """
        Whether to auto-generate code interface functions for the gen_api actions
        on the resource module. When `true`, a function matching each action name
        will be defined on the resource module that calls the action through the
        Ash framework.

        Individual actions can override this with their own `code_interface?` option.

        Defaults to `true`.
        """
      ],
      result_encoder: [
        type: :any,
        default: :struct,
        doc: """
        Default result encoding mode for all actions.

        Determines how the result returned from the action MFA call is encoded
        before being returned to the caller.

        - `:struct` — Return the Ash resource struct as-is (default)
        - `:map` — Convert the Ash resource struct to a map containing only public fields
          (using `Ash.Resource.Info.public_fields/1` to filter; falls back to
          `Map.from_struct/1` for non-Ash-resource structs)
        - `{Module, :function, args}` — Custom encoder MFA. The function receives
          the result as its first argument, followed by `args`, and must return
          the encoded result.

        Individual actions can override this with their own `result_encoder` option.

        For `:map` encoding, Ash resource structs are converted to maps containing
        only their public fields (attributes, calculations, aggregates, relationships).
        Lists of structs are mapped accordingly. Non-Ash-resource structs fall back
        to `Map.from_struct/1`.
        For custom MFA encoders, the function receives the result and must return
        the encoded value.

        Defaults to `:struct`.
        """
      ]
    ],
    entities: [
      @action,
      @mfa
    ]
  }

  use Spark.Dsl.Extension,
    verifiers: [
      AshPhoenixGenApi.Verifiers.VerifyActionConfigs
    ],
    transformers: [
      AshPhoenixGenApi.Transformers.DefineFunConfigs
    ],
    sections: [@gen_api]
end
