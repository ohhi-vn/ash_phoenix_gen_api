> ⚠️ **EXPERIMENTAL / UNDER ACTIVE DEVELOPMENT** ⚠️

# AshPhoenixGenApi

An Ash Framework extension for generating [PhoenixGenApi](https://github.com/ohhi-vn/phoenix_gen_api) function configurations from Ash resources and domains.

`AshPhoenixGenApi` bridges the Ash Framework and PhoenixGenApi by allowing you to define PhoenixGenApi endpoints directly in your Ash resource and domain DSLs. It automatically generates `PhoenixGenApi.Structs.FunConfig` structs from your Ash actions, including type mappings, argument ordering, and configuration defaults.

## Features

- **DSL-driven API configuration** — Define PhoenixGenApi endpoints alongside your Ash resource definitions
- **Automatic type mapping** — Ash types are automatically converted to PhoenixGenApi argument types
- **Auto-derived arguments** — Action arguments and accepted attributes are automatically extracted from Ash actions
- **Auto-generated code interface** — Elixir functions are generated on the resource module for each gen_api action (create, read, update, destroy, generic)
- **Domain-level aggregation** — Auto-generates a "supporter" module that aggregates FunConfigs from all resources
- **Active push configuration** — Push API configs to gateway nodes on startup, with MFA-based runtime node resolution
- **Permission callback** — Custom MFA callback for permission checking, receives `(request_type, args)` and returns `true`/`false`
- **Compile-time verification** — Validates action existence, request type uniqueness, and argument consistency
- **Resolution hierarchy** — Configuration values cascade from action → resource → domain → built-in defaults
- **PhoenixGenApi client interface** — Generated supporter modules implement `get_config/1`, `get_config_version/1`, `fun_configs/0`, `push_to_gateway/2`, etc.

## Installation

Add `ash_phoenix_gen_api` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ash_phoenix_gen_api, "~> 0.1.0"},
    {:ash, "~> 3.5"},
    {:phoenix_gen_api, "~> 2.1"}
  ]
end
```

Then fetch dependencies:

```bash
mix deps.get
```

## Quick Start

### 1. Add the Resource extension

Add `AshPhoenixGenApi.Resource` to your Ash resources:

```elixir
defmodule MyApp.Chat.DirectMessage do
  use Ash.Resource,
    domain: MyApp.Chat,
    extensions: [AshPhoenixGenApi.Resource]

  attributes do
    uuid_primary_key :id
    attribute :from_user_id, :uuid do
      public? true
    end
    attribute :to_user_id, :uuid do
      public? true
    end
    attribute :content, :string do
      public? true
      allow_nil? true
    end
    attribute :reply_to_id, :uuid do
      public? true
      allow_nil? true
    end
    attribute :file_id, :uuid do
      public? true
      allow_nil? true
    end
  end

  actions do
    create :create do
      accept [:from_user_id, :to_user_id, :content, :reply_to_id, :file_id]
    end

    read :read do
      primary? true
    end

    update :update_content do
      accept [:content]
    end

    destroy :destroy
  end

  gen_api do
    service "chat"
    nodes {ClusterHelper, :get_nodes, [:chat]}
    choose_node_mode :random
    timeout 5_000
    response_type :async
    request_info true
    version "0.0.1"

    action :create do
      request_type "send_direct_message"
      timeout 10_000
      check_permission {:arg, "from_user_id"}
    end

    action :read do
      request_type "get_conversation"
      timeout 5_000
    end

    action :update_content do
      request_type "update_content"
      response_type :sync
    end
  end
end
```

### 2. Add the Domain extension

Add `AshPhoenixGenApi.Domain` to your Ash domain:

```elixir
defmodule MyApp.Chat do
  use Ash.Domain,
    extensions: [AshPhoenixGenApi.Domain]

  gen_api do
    service "chat"
    nodes {ClusterHelper, :get_nodes, [:chat]}
    choose_node_mode :random
    version "0.0.1"
    supporter_module MyApp.Chat.GenApiSupporter
  end

  resources do
    resource MyApp.Chat.DirectMessage
    resource MyApp.Chat.GroupMessage
  end
end
```

### 3. Use the generated supporter module

After compilation, `MyApp.Chat.GenApiSupporter` is auto-generated:

```elixir
# Get all FunConfigs (for PhoenixGenApi pull)
MyApp.Chat.GenApiSupporter.fun_configs()
#=> [%PhoenixGenApi.Structs.FunConfig{request_type: "send_direct_message", ...}, ...]

# Get config for remote pull
MyApp.Chat.GenApiSupporter.get_config(:gateway_1)
#=> {:ok, [%PhoenixGenApi.Structs.FunConfig{...}, ...]}

# Get config version
MyApp.Chat.GenApiSupporter.get_config_version(:gateway_1)
#=> {:ok, "0.0.1"}

# Find a specific FunConfig by request_type
MyApp.Chat.GenApiSupporter.get_fun_config("send_direct_message")
#=> %PhoenixGenApi.Structs.FunConfig{request_type: "send_direct_message", ...}

# List all request types
MyApp.Chat.GenApiSupporter.list_request_types()
#=> ["send_direct_message", "get_conversation", ...]
```

### 4. Configure the gateway node

On the Phoenix gateway node, configure `phoenix_gen_api` in `config.exs`:

```elixir
config :phoenix_gen_api, :gen_api,
  service_configs: [
    %{
      service: "chat",
      nodes: {ClusterHelper, :get_nodes, [:chat]},
      module: MyApp.Chat.GenApiSupporter,
      function: :get_config,
      args: [:gateway_1]
    }
  ]
```

## DSL Reference

### Resource DSL (`gen_api`)

The `gen_api` section is added to Ash resources when using `AshPhoenixGenApi.Resource`.

#### Section Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `service` | `:atom \| :string` | **required** | Service name for routing |
| `nodes` | `:local \| {:list, :atom} \| {:tuple, [:atom, :atom, {:list, :any}]}` | `:local` | Default target nodes |
| `choose_node_mode` | `:random \| :hash \| :round_robin \| {:hash, string}` | `:random` | Default node selection strategy |
| `timeout` | `pos_integer \| :infinity` | `5000` | Default timeout in milliseconds |
| `response_type` | `:sync \| :async \| :stream \| :none` | `:async` | Default response mode |
| `request_info` | `:boolean` | `true` | Default for passing request info |
| `check_permission` | `false \| :any_authenticated \| {:arg, string} \| {:role, [string]}` | `false` | Default permission check mode |
| `permission_callback` | `{module, atom, list} \| nil` | `nil` | Default permission callback MFA. Callback receives `(request_type, args)` and returns `true`/`false`. Takes precedence over `check_permission` |
| `version` | `:string` | `"0.0.1"` | Default version string |
| `retry` | `pos_integer \| {:same_node, pos_integer} \| {:all_nodes, pos_integer}` | `nil` | Default retry configuration |
| `code_interface?` | `:boolean` | `true` | Whether to auto-generate code interface functions for gen_api actions |

#### Action Entity Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `name` | `:atom` | **required** | Ash action name to expose |
| `request_type` | `:string` | action name as string | PhoenixGenApi request type string |
| `timeout` | `pos_integer \| :infinity` | section default | Timeout in milliseconds |
| `response_type` | `:sync \| :async \| :stream \| :none` | section default | Response mode |
| `request_info` | `:boolean` | section default | Whether to pass request info |
| `check_permission` | see above | section default | Permission check mode |
| `permission_callback` | `{module, atom, list} \| nil` | section default | Permission callback MFA. Overrides `check_permission` when set |
| `choose_node_mode` | see above | section default | Node selection strategy |
| `nodes` | see above | section default | Target nodes |
| `retry` | see above | section default | Retry configuration |
| `version` | `:string` | section default | API version string |
| `mfa` | `{module, atom, list}` | auto-generated | Explicit MFA tuple |
| `arg_types` | `map \| nil` | auto-derived | Explicit argument types |
| `arg_orders` | `[string] \| nil` | auto-derived | Explicit argument order |
| `disabled` | `:boolean` | `false` | Disable this endpoint |
| `code_interface?` | `:boolean \| nil` | `nil` | Whether to generate code interface for this action. `nil` inherits from section-level |

### Domain DSL (`gen_api`)

The `gen_api` section is added to Ash domains when using `AshPhoenixGenApi.Domain`.

#### Section Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `service` | `:atom \| :string` | — | Service name (used as default for resources) |
| `nodes` | see above | `:local` | Default target nodes |
| `choose_node_mode` | see above | `:random` | Default node selection strategy |
| `timeout` | see above | `5000` | Default timeout |
| `response_type` | see above | `:async` | Default response mode |
| `request_info` | `:boolean` | `true` | Default for passing request info |
| `check_permission` | see above | `false` | Default permission check mode |
| `permission_callback` | `{module, atom, list} \| nil` | `nil` | Default permission callback MFA. Callback receives `(request_type, args)` and returns `true`/`false`. Takes precedence over `check_permission` |
| `version` | `:string` | `"0.0.1"` | Default version string |
| `retry` | see above | `nil` | Default retry configuration |
| `supporter_module` | `:atom` | **required** | Module name for auto-generated supporter |
| `define_supporter?` | `:boolean` | `true` | Whether to auto-generate the supporter module |
| `push_nodes` | `[atom] \| {module, atom, list} \| :local \| nil` | `nil` | Target gateway nodes to push config to |
| `push_on_startup` | `:boolean` | `false` | Whether to push config on application startup |

## Type Mapping

Ash types are automatically mapped to PhoenixGenApi argument types:

| Ash Type | PhoenixGenApi Type |
|----------|-------------------|
| `:string`, `Ash.Type.String` | `:string` |
| `:ci_string`, `Ash.Type.CiString` | `:string` |
| `:integer`, `Ash.Type.Integer` | `:num` |
| `:float`, `Ash.Type.Float` | `:num` |
| `:decimal`, `Ash.Type.Decimal` | `:num` |
| `:uuid`, `Ash.Type.UUID` | `:string` |
| `:uuid_v7`, `Ash.Type.UUIDv7` | `:string` |
| `:boolean`, `Ash.Type.Boolean` | `:string` |
| `:date`, `Ash.Type.Date` | `:string` |
| `:time`, `Ash.Type.Time` | `:string` |
| `:datetime`, `Ash.Type.DateTime` | `:string` |
| `:utc_datetime`, `Ash.Type.UtcDateTime` | `:string` |
| `:naive_datetime`, `Ash.Type.NaiveDateTime` | `:string` |
| `:atom`, `Ash.Type.Atom` | `:string` |
| `:map`, `Ash.Type.Map` | `:string` |
| `:json`, `Ash.Type.Json` | `:string` |
| `:binary`, `Ash.Type.Binary` | `:string` |
| `:term`, `Ash.Type.Term` | `:string` |
| `{:array, :string}` | `{:list_string, 1000, 50}` |
| `{:array, :integer}` | `{:list_num, 1000}` |
| `{:array, :uuid}` | `{:list_string, 1000, 50}` |
| `{:array, :float}` | `{:list_num, 1000}` |

See `AshPhoenixGenApi.TypeMapper` for the complete mapping and customization options.

## Resolution Order

Configuration values are resolved in this order (highest priority first):

1. **Action-level explicit config** — e.g., `action :foo do timeout 10_000 end`
2. **Resource section-level defaults** — e.g., `gen_api do timeout 5_000 end`
3. **Domain section-level defaults** — e.g., `gen_api do timeout 5_000 end`
4. **Built-in defaults** — e.g., timeout defaults to `5000`

For `arg_types` and `arg_orders`:

1. **Explicit `arg_types`/`arg_orders`** on the action entity
2. **Auto-derived** from the Ash action's accepted attributes and arguments

For `mfa`:

1. **Explicit `mfa`** on the action entity
2. **Auto-generated** as `{ResourceModule, :action_name, []}`

## Auto-Derived Arguments

When `arg_types` and `arg_orders` are not explicitly set, the extension automatically derives them from the Ash action:

- **For `:create` and `:update` actions**: Includes accepted attributes and action arguments
- **For `:read`, `:destroy`, and `:action` types**: Includes only action arguments

Example — given this Ash action:

```elixir
actions do
  create :create do
    accept [:from_user_id, :to_user_id, :content, :reply_to_id, :file_id]
  end
end
```

The auto-derived `arg_types` and `arg_orders` would be:

```elixir
arg_types: %{
  "from_user_id" => :string,  # UUID → :string
  "to_user_id" => :string,    # UUID → :string
  "content" => :string,       # String → :string
  "reply_to_id" => :string,   # UUID → :string
  "file_id" => :string        # UUID → :string
},
arg_orders: ["from_user_id", "to_user_id", "content", "reply_to_id", "file_id"]
```

## Generated Supporter Module

The domain extension auto-generates a supporter module that implements the PhoenixGenApi client config interface. This module:

1. **Aggregates FunConfigs** from all resources in the domain that have `AshPhoenixGenApi.Resource`
2. **Implements `get_config/1`** — Returns `{:ok, fun_configs()}` for PhoenixGenApi pull
3. **Implements `get_config_version/1`** — Returns `{:ok, version}` for version checking
4. **Implements `fun_configs/0`** — Returns the aggregated list of `FunConfig` structs
5. **Implements `list_request_types/0`** — Returns all available request type strings
6. **Implements `get_fun_config/1`** — Returns a specific `FunConfig` by request_type

The generated module matches the interface described in the PhoenixGenApi documentation for remote config pulling.

## Introspection

### Resource Introspection

```elixir
# Check if a resource has gen_api configured
AshPhoenixGenApi.Resource.Info.has_gen_api?(MyApp.Chat.DirectMessage)
#=> true

# Get the service name
AshPhoenixGenApi.Resource.Info.gen_api_service(MyApp.Chat.DirectMessage)
#=> "chat"

# Get all action configs
AshPhoenixGenApi.Resource.Info.gen_api_actions(MyApp.Chat.DirectMessage)
#=> [%ActionConfig{name: :create, ...}, ...]

# Get a specific action config
AshPhoenixGenApi.Resource.Info.action(MyApp.Chat.DirectMessage, :create)
#=> %ActionConfig{name: :create, request_type: "send_direct_message", ...}

# Get only enabled actions
AshPhoenixGenApi.Resource.Info.enabled_actions(MyApp.Chat.DirectMessage)
#=> [%ActionConfig{disabled: false, ...}, ...]

# Get the generated FunConfig structs
AshPhoenixGenApi.Resource.Info.fun_configs(MyApp.Chat.DirectMessage)
#=> [%PhoenixGenApi.Structs.FunConfig{...}, ...]

# Get a specific FunConfig by request_type
AshPhoenixGenApi.Resource.Info.fun_config(MyApp.Chat.DirectMessage, "send_direct_message")
#=> %PhoenixGenApi.Structs.FunConfig{request_type: "send_direct_message", ...}

# Get all request types
AshPhoenixGenApi.Resource.Info.request_types(MyApp.Chat.DirectMessage)
#=> ["send_direct_message", "get_conversation", ...]

# Get effective values with fallback resolution
AshPhoenixGenApi.Resource.Info.effective_timeout(MyApp.Chat.DirectMessage, :create)
#=> 10_000
AshPhoenixGenApi.Resource.Info.effective_mfa(MyApp.Chat.DirectMessage, :create)
#=> {MyApp.Chat.DirectMessage, :create, []}
```

### Domain Introspection

```elixir
# Check if a domain has gen_api configured
AshPhoenixGenApi.Domain.Info.has_gen_api?(MyApp.Chat)
#=> true

# Get the supporter module name
AshPhoenixGenApi.Domain.Info.supporter_module(MyApp.Chat)
#=> MyApp.Chat.GenApiSupporter

# Get all resources with gen_api configured
AshPhoenixGenApi.Domain.Info.resources_with_gen_api(MyApp.Chat)
#=> [MyApp.Chat.DirectMessage, MyApp.Chat.GroupMessage]

# Get aggregated FunConfigs from all resources
AshPhoenixGenApi.Domain.Info.fun_configs(MyApp.Chat)
#=> [%PhoenixGenApi.Structs.FunConfig{...}, ...]

# Get all request types across all resources
AshPhoenixGenApi.Domain.Info.all_request_types(MyApp.Chat)
#=> ["send_direct_message", "get_conversation", ...]

# Get a configuration summary
AshPhoenixGenApi.Domain.Info.summary(MyApp.Chat)
#=> %{
#=>   service: "chat",
#=>   version: "0.0.1",
#=>   supporter_module: MyApp.Chat.GenApiSupporter,
#=>   total_fun_configs: 5,
#=>   resources: [
#=>     %{resource: MyApp.Chat.DirectMessage, request_types: ["send_direct_message", ...]},
#=>     %{resource: MyApp.Chat.GroupMessage, request_types: ["send_group_message", ...]}
#=>   ]
#=> }
```

## Compile-Time Verification

The extension performs compile-time verification to catch configuration errors early:

### Resource Verification

- **Action existence** — Every `action` entity must reference an existing Ash action
- **Request type uniqueness** — No two actions in the same resource may share a `request_type`
- **Arg consistency** — When both `arg_types` and `arg_orders` are provided, their keys must match
- **Permission arg existence** — When `check_permission` is `{:arg, "name"}`, the argument must exist
- **MFA validity** — When an explicit `mfa` is provided, it must be a valid `{module, function, args}` tuple

### Domain Verification

- **Supporter module name** — Must be a valid Elixir module name
- **Service configuration** — Resources with gen_api must have a service configured (either on the resource or the domain)
- **Request type uniqueness across resources** — No two resources in the domain may expose the same `request_type`

## Code Interface

When `code_interface?` is `true` (the default), the extension auto-generates Elixir functions on the resource module for each gen_api action. This allows you to call actions directly without building queries or changesets manually.

```elixir
# Create action — auto-generates create/2 and create!/2
{:ok, message} = MyApp.Chat.DirectMessage.create(%{content: "Hello"})
message = MyApp.Chat.DirectMessage.create!(%{content: "Hello"})

# Read action — auto-generates read/2 and read!/2
{:ok, messages} = MyApp.Chat.DirectMessage.read()
messages = MyApp.Chat.DirectMessage.read!()

# Update action — auto-generates update/3 and update!/3 (requires record)
{:ok, updated} = MyApp.Chat.DirectMessage.update(message, %{content: "Updated"})
updated = MyApp.Chat.DirectMessage.update!(message, %{content: "Updated"})

# Destroy action — auto-generates destroy/3 and destroy!/3 (requires record)
:ok = MyApp.Chat.DirectMessage.destroy(message)
:ok = MyApp.Chat.DirectMessage.destroy!(message)

# Generic action — auto-generates action_name/2 and action_name!/2
{:ok, result} = MyApp.Chat.DirectMessage.greet(%{name: "World"})
```

You can disable code interface generation at the section level or per-action:

```elixir
gen_api do
  service "chat"
  code_interface? false  # Disable for all actions

  action :create do
    code_interface? true  # Re-enable for this action only
  end

  action :read  # Inherits section-level false
end
```

## Permission Callback

In addition to the built-in permission modes (`false`, `:any_authenticated`, `{:arg, "arg_name"}`, `{:role, ["admin"]}`), you can specify a custom callback function for permission checking using `permission_callback`.

The callback receives `request_type` (string) and `args` (map) as arguments and returns `true` (continue) or `false` (permission denied).

```elixir
defmodule MyApp.Permissions do
  def check_permission(request_type, args) do
    case request_type do
      "delete_user" -> args["role"] == "admin"
      "update_profile" -> args["user_id"] == args["target_user_id"]
      _ -> true
    end
  end
end

# In your resource:
gen_api do
  service "chat"
  permission_callback {MyApp.Permissions, :check_permission, []}

  action :delete_user do
    # Uses the section-level permission_callback
  end

  action :admin_action do
    # Override with a different callback
    permission_callback {MyApp.Permissions, :check_admin, []}
  end
end
```

When `permission_callback` is set, it takes precedence over `check_permission` and is stored as `{:callback, {Module, :function, []}}` in the FunConfig's `check_permission` field.

## Active Push Configuration

In addition to the pull-based model (where the gateway pulls config from service nodes), you can configure the supporter module to **actively push** its configuration to gateway nodes.

```elixir
gen_api do
  service "chat"
  supporter_module MyApp.Chat.GenApiSupporter
  version "0.0.1"
  push_nodes [:"gateway1@host", :"gateway2@host"]
  # Or use an MFA tuple for runtime resolution:
  # push_nodes {ClusterHelper, :get_gateway_nodes, []}
end
```

Then push config during application startup:

```elixir
def start(_type, _args) do
  # ... start supervision tree, then:
  MyApp.Chat.GenApiSupporter.push_to_configured_nodes()
  # Or push to a specific node:
  MyApp.Chat.GenApiSupporter.push_on_startup(:"gateway1@host")
end
```

The generated supporter module includes these push functions:

| Function | Description |
|----------|-------------|
| `build_push_config/0` | Builds a `PushConfig` struct from the domain config |
| `push_to_gateway/2` | Pushes config to a specific gateway node |
| `push_on_startup/2` | Pushes config on application startup |
| `verify_on_gateway/2` | Verifies config version on a gateway node |
| `resolve_push_nodes/0` | Resolves `push_nodes` at runtime (handles MFA tuples) |
| `push_to_configured_nodes/1` | Pushes to all configured push_nodes |

## Example: Chat Service

Here's a complete example matching the ChatService pattern from PhoenixGenApi:

```elixir
defmodule MyApp.Chat.DirectMessage do
  use Ash.Resource,
    domain: MyApp.Chat,
    extensions: [AshPhoenixGenApi.Resource]

  attributes do
    uuid_primary_key :id
    attribute :from_user_id, :uuid, public?: true
    attribute :to_user_id, :uuid, public?: true
    attribute :content, :string, public?: true, allow_nil?: true
    attribute :reply_to_id, :uuid, public?: true, allow_nil?: true
    attribute :file_id, :uuid, public?: true, allow_nil?: true
    attribute :order, :integer, public?: true
    attribute :read, :boolean, public?: true, allow_nil?: true, default: false
    attribute :deleted, :boolean, public?: true, allow_nil?: true, default: false
  end

  actions do
    create :create do
      accept [:from_user_id, :to_user_id, :content, :reply_to_id, :file_id]
    end

    read :read do
      primary? true
    end

    update :mark_read do
      accept [:read]
    end

    destroy :destroy
  end

  gen_api do
    service "chat"
    nodes {ClusterHelper, :get_nodes, [:chat]}
    choose_node_mode :random
    timeout 5_000
    response_type :async
    request_info true
    version "0.0.1"

    action :create do
      request_type "send_direct_message"
      timeout 10_000
      check_permission {:arg, "from_user_id"}
    end

    action :read do
      request_type "get_conversation"
    end

    action :mark_read do
      request_type "mark_direct_messages_as_read"
    end
  end
end

defmodule MyApp.Chat do
  use Ash.Domain,
    extensions: [AshPhoenixGenApi.Domain]

  gen_api do
    service "chat"
    nodes {ClusterHelper, :get_nodes, [:chat]}
    choose_node_mode :random
    version "0.0.1"
    supporter_module MyApp.Chat.GenApiSupporter
  end

  resources do
    resource MyApp.Chat.DirectMessage
  end
end
```

This generates the same FunConfig structures that were previously hand-written in `ChatService.Interface.GenApi.Supporter`, but now derived automatically from your Ash resource definitions.

## Modules

| Module | Description |
|--------|-------------|
| `AshPhoenixGenApi` | Top-level module with documentation and helpers |
| `AshPhoenixGenApi.Resource` | Resource-level DSL extension |
| `AshPhoenixGenApi.Resource.Info` | Resource introspection helpers |
| `AshPhoenixGenApi.Resource.ActionConfig` | Action configuration struct |
| `AshPhoenixGenApi.Domain` | Domain-level DSL extension |
| `AshPhoenixGenApi.Domain.Info` | Domain introspection helpers |
| `AshPhoenixGenApi.TypeMapper` | Ash type to PhoenixGenApi type mapping |
| `AshPhoenixGenApi.Transformers.DefineFunConfigs` | Resource transformer |
| `AshPhoenixGenApi.Transformers.DefineDomainSupporter` | Domain transformer |
| `AshPhoenixGenApi.Verifiers.VerifyActionConfigs` | Resource verifier |
| `AshPhoenixGenApi.Verifiers.VerifyDomainConfig` | Domain verifier |

## License

MPL 2.0
