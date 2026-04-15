# Getting Started with AshPhoenixGenApi

This guide will walk you through setting up `AshPhoenixGenApi` to generate PhoenixGenApi function configurations from your Ash resources and domains.

## Prerequisites

- Elixir ~> 1.18
- Ash ~> 3.5
- PhoenixGenApi ~> 2.1

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

## Step 1: Add the Resource Extension

Add `AshPhoenixGenApi.Resource` to your Ash resources that you want to expose as PhoenixGenApi endpoints:

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
```

Now add the `gen_api` section to configure your PhoenixGenApi endpoints:

```elixir
  gen_api do
    # Required: the service name used for routing
    service "chat"

    # Target nodes — can be a list of atoms, an MFA tuple, or :local
    nodes {ClusterHelper, :get_nodes, [:chat]}

    # Default node selection strategy
    choose_node_mode :random

    # Default timeout in milliseconds
    timeout 5_000

    # Default response mode
    response_type :async

    # Whether to pass request info (user_id, device_id, request_id)
    request_info true

    # API version string
    version "0.0.1"

    # Expose the :create action as "send_direct_message"
    action :create do
      request_type "send_direct_message"
      timeout 10_000
      check_permission {:arg, "from_user_id"}
    end

    # Expose the :read action as "get_conversation"
    action :read do
      request_type "get_conversation"
      timeout 5_000
    end

    # Expose the :update_content action as "update_content"
    action :update_content do
      request_type "update_content"
      response_type :sync
    end
  end
end
```

## Step 2: Add the Domain Extension

Add `AshPhoenixGenApi.Domain` to your Ash domain to aggregate FunConfigs from all resources:

```elixir
defmodule MyApp.Chat do
  use Ash.Domain,
    extensions: [AshPhoenixGenApi.Domain]

  gen_api do
    # Domain-level defaults (used as fallback for resources)
    service "chat"
    nodes {ClusterHelper, :get_nodes, [:chat]}
    choose_node_mode :random
    version "0.0.1"

    # Required: the module name for the auto-generated supporter
    supporter_module MyApp.Chat.GenApiSupporter
  end

  resources do
    resource MyApp.Chat.DirectMessage
    resource MyApp.Chat.GroupMessage
  end
end
```

## Step 3: Use the Generated Supporter Module

After compilation, `MyApp.Chat.GenApiSupporter` is automatically generated. It implements the PhoenixGenApi client config interface:

```elixir
# Get all FunConfigs (for PhoenixGenApi pull)
MyApp.Chat.GenApiSupporter.fun_configs()
#=> [%PhoenixGenApi.Structs.FunConfig{request_type: "send_direct_message", ...}, ...]

# Get config for remote pull (matches the PhoenixGenApi client interface)
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
#=> ["send_direct_message", "get_conversation", "update_content", ...]
```

## Step 4: Configure the Gateway Node

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

## Understanding Auto-Derived Arguments

When you don't specify `arg_types` and `arg_orders` on an action, the extension automatically derives them from the Ash action's accepted attributes and arguments.

For example, given this action:

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
  "from_user_id" => :string,   # UUID → :string
  "to_user_id" => :string,     # UUID → :string
  "content" => :string,        # String → :string
  "reply_to_id" => :string,    # UUID → :string
  "file_id" => :string         # UUID → :string
},
arg_orders: ["from_user_id", "to_user_id", "content", "reply_to_id", "file_id"]
```

### Type Mapping Reference

| Ash Type | PhoenixGenApi Type |
|----------|-------------------|
| `:string` | `:string` |
| `:uuid` | `:string` |
| `:integer` | `:num` |
| `:float` | `:num` |
| `:decimal` | `:num` |
| `:boolean` | `:string` |
| `:date` | `:string` |
| `:datetime` | `:string` |
| `:atom` | `:string` |
| `:map` | `:string` |
| `{:array, :string}` | `{:list_string, 1000, 50}` |
| `{:array, :integer}` | `{:list_num, 1000}` |

## Overriding Auto-Derived Arguments

You can override the auto-derived arguments by explicitly specifying `arg_types` and `arg_orders`:

```elixir
gen_api do
  service "chat"

  action :create do
    request_type "send_direct_message"
    # Override auto-derived args with custom types
    arg_types %{
      "from_user_id" => :string,
      "to_user_id" => :string,
      "content" => :string,
      "reply_to_id" => :string,
      "file_id" => :string,
      "tags" => {:list_string, 100, 20}  # Custom list type
    }
    arg_orders ["from_user_id", "to_user_id", "content", "reply_to_id", "file_id", "tags"]
  end
end
```

If you only provide `arg_types`, `arg_orders` will be derived from its keys:

```elixir
action :create do
  request_type "send_direct_message"
  arg_types %{
    "from_user_id" => :string,
    "content" => :string
  }
  # arg_orders will be ["from_user_id", "content"]
end
```

## Resolution Order

Configuration values are resolved in this order (highest priority first):

1. **Action-level explicit config** — e.g., `action :foo do timeout 10_000 end`
2. **Resource section-level defaults** — e.g., `gen_api do timeout 5_000 end`
3. **Domain section-level defaults** — e.g., `gen_api do timeout 5_000 end`
4. **Built-in defaults** — e.g., timeout defaults to `5000`

## Custom MFA

By default, the extension generates an MFA tuple as `{ResourceModule, :action_name, []}`. You can override this with an explicit `mfa`:

```elixir
gen_api do
  service "chat"

  action :create do
    request_type "send_direct_message"
    mfa {MyApp.Interface.Api, :send_direct_message, []}
  end
end
```

This generates a FunConfig with `mfa: {MyApp.Interface.Api, :send_direct_message, []}`, which means the gateway node will call `MyApp.Interface.Api.send_direct_message/3` (with args + request_info) instead of the resource's action directly.

## Disabling an Action

You can temporarily disable an endpoint without removing its configuration:

```elixir
gen_api do
  service "chat"

  action :create do
    request_type "send_direct_message"
  end

  action :deprecated_action do
    disabled true
  end
end
```

Disabled actions are excluded from the generated FunConfig list.

## Compile-Time Verification

The extension performs compile-time verification to catch configuration errors early:

- **Action existence** — Every `action` entity must reference an existing Ash action on the resource
- **Request type uniqueness** — No two actions in the same resource may share a `request_type`
- **Arg consistency** — When both `arg_types` and `arg_orders` are provided, their keys must match
- **Permission arg existence** — When `check_permission` is `{:arg, "name"}`, the argument must exist
- **Cross-resource request type uniqueness** — No two resources in the domain may expose the same `request_type`

If any verification fails, you'll get a descriptive error message at compile time.

## Introspection

You can introspect your configuration at runtime:

```elixir
# Resource introspection
AshPhoenixGenApi.Resource.Info.has_gen_api?(MyApp.Chat.DirectMessage)
#=> true

AshPhoenixGenApi.Resource.Info.gen_api_service(MyApp.Chat.DirectMessage)
#=> "chat"

AshPhoenixGenApi.Resource.Info.fun_configs(MyApp.Chat.DirectMessage)
#=> [%PhoenixGenApi.Structs.FunConfig{...}, ...]

AshPhoenixGenApi.Resource.Info.request_types(MyApp.Chat.DirectMessage)
#=> ["send_direct_message", "get_conversation", "update_content"]

# Domain introspection
AshPhoenixGenApi.Domain.Info.supporter_module(MyApp.Chat)
#=> MyApp.Chat.GenApiSupporter

AshPhoenixGenApi.Domain.Info.fun_configs(MyApp.Chat)
#=> [%PhoenixGenApi.Structs.FunConfig{...}, ...]

AshPhoenixGenApi.Domain.Info.summary(MyApp.Chat)
#=> %{
#=>   service: "chat",
#=>   version: "0.0.1",
#=>   supporter_module: MyApp.Chat.GenApiSupporter,
#=>   total_fun_configs: 3,
#=>   resources: [
#=>     %{resource: MyApp.Chat.DirectMessage, request_types: ["send_direct_message", ...]}
#=>   ]
#=> }
```

## What's Next?

- Read the [DSL Reference](../dsls/DSL-AshPhoenixGenApi.Resource.html) for the complete list of configuration options
- Read the [TypeMapper documentation](AshPhoenixGenApi.TypeMapper.html) for details on type mapping
- Check the [PhoenixGenApi documentation](https://github.com/ohhi-vn/phoenix_gen_api) for more on FunConfig and the gateway architecture