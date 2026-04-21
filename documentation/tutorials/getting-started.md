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

The MFA (Module, Function, Arguments) tuple tells the gateway node which function to call when a request arrives. Understanding how it's called is key to configuring it correctly.

### How the MFA is Called

At runtime, the PhoenixGenApi executor calls your function like this:

```elixir
{mod, fun, predefined_args} = fun_config.mfa
final_args = predefined_args ++ converted_args ++ info_args
apply(mod, fun, final_args)
```

Where:

- **`predefined_args`** — the third element of your MFA tuple (e.g., `[]`). These are prepended to every call, useful for passing static context.
- **`converted_args`** — the request arguments, derived from `arg_types` and `arg_orders`:
  - When `arg_orders` is `:map` (the default), this is a single-element list containing a map with string keys: `[%{"from_user_id" => "...", "content" => "..."}]`
  - When `arg_orders` is an explicit list, this is a list of positional values: `["user_123", "hello"]`
  - When there are no arguments, this is `[]`
- **`info_args`** — if `request_info` is `true`, a single-element list with the request info map: `[%{user_id: "...", device_id: "...", request_id: "..."}]`. Otherwise `[]`.

### Default MFA

By default, the extension generates `{ResourceModule, :action_name, []}`. This works because the extension auto-generates code interface functions on the resource module (when `code_interface?` is `true`, which is the default). For example, with `arg_orders: :map` and `request_info: true`, the generated function is called as:

```elixir
MyApp.Chat.DirectMessage.create(%{"from_user_id" => "...", "content" => "..."}, %{user_id: "...", device_id: "...", request_id: "..."})
```

### Overriding with a Custom MFA

You can override the default with an explicit `mfa` to route requests to your own function:

```elixir
gen_api do
  service "chat"

  action :create do
    request_type "send_direct_message"
    mfa {MyApp.Interface.Api, :send_direct_message, []}
  end
end
```

This generates a FunConfig with `mfa: {MyApp.Interface.Api, :send_direct_message, []}`. Your function must accept the same calling convention. With the default `arg_orders: :map` and `request_info: true`:

```elixir
defmodule MyApp.Interface.Api do
  # Called as: send_direct_message(args_map, request_info)
  def send_direct_message(args, request_info) do
    # args is a map with string keys, e.g., %{"from_user_id" => "...", "content" => "..."}
    # request_info is a map, e.g., %{user_id: "...", device_id: "...", request_id: "..."}
    # ...
  end
end
```

If `request_info` is `false`, the `request_info` argument is omitted:

```elixir
def send_direct_message(args) do
  # Only receives the args map
end
```

If you set `arg_orders` to an explicit list (e.g., `["from_user_id", "content"]`), arguments are passed positionally instead of as a map:

```elixir
def send_direct_message(from_user_id, content, request_info) do
  # Positional args in the order specified by arg_orders, plus request_info
end
```

You can also use the third element of the MFA tuple to pass static predefined arguments:

```elixir
mfa {MyApp.Interface.Api, :send_direct_message, [:chat_service]}
```

This prepends `:chat_service` to every call:

```elixir
def send_direct_message(service, args, request_info) do
  # service is always :chat_service
  # ...
end
```

## Standalone MFA Endpoints

In addition to `action` entities (which map Ash resource actions to FunConfigs), you can define standalone MFA endpoints using the `mfa` entity. These call an arbitrary function directly — with no Ash action involved.

This is useful for exposing custom functions that don't map to standard Ash CRUD actions, such as utility endpoints, batch operations, or service-to-service calls.

### Basic Usage

```elixir
gen_api do
  service "chat"

  action :create do
    request_type "send_direct_message"
  end

  mfa :ping do
    request_type "ping"
    mfa {MyApp.Chat.Api, :ping, []}
    arg_types %{}
  end
end
```

### Required Fields

Unlike `action` entities, `mfa` entities require explicit configuration since there is no Ash action to auto-derive from:

- **`request_type`** — Required. The PhoenixGenApi request type string.
- **`mfa`** — Required. The MFA tuple to call, e.g., `{Module, :function, []}`.
- **`arg_types`** — Required. The argument types map. Use `%{}` for endpoints with no arguments.

### With Arguments

```elixir
mfa :search do
  request_type "search"
  mfa {MyApp.SearchHandler, :search, []}
  arg_types %{"query" => :string, "limit" => :num}
  # arg_orders defaults to :map — args are passed as a map with string keys
end
```

When `arg_orders` is `:map` (the default), your function receives a map:

```elixir
def search(args, request_info) do
  # args is %{"query" => "...", "limit" => 10}
  # request_info is %{user_id: ..., device_id: ..., request_id: ...}
end
```

For positional arguments, set `arg_orders` to a list:

```elixir
mfa :search do
  request_type "search"
  mfa {MyApp.SearchHandler, :search, []}
  arg_types %{"query" => :string, "limit" => :num}
  arg_orders ["query", "limit"]
end
```

Your function then receives positional args:

```elixir
def search(query, limit, request_info) do
  # query is the string value, limit is the number
end
```

### With Predefined Arguments

Use the third element of the MFA tuple to pass static context:

```elixir
mfa :batch_process do
  request_type "batch_process"
  mfa {MyApp.BatchProcessor, :run, [:chat_service]}
  arg_types %{"items" => {:list_string, 1000, 50}}
  response_type :async
end
```

This prepends `:chat_service` to every call:

```elixir
def run(service, args, request_info) do
  # service is always :chat_service
  # ...
end
```

### No Code Interface

Unlike `action` entities, `mfa` entities do not generate code interface functions on the resource module. This is because there is no Ash action to wrap — the MFA function is called directly by the PhoenixGenApi gateway.

### Inheriting Section Defaults

Like `action` entities, `mfa` entities inherit defaults from the `gen_api` section:

```elixir
gen_api do
  service "chat"
  timeout 5_000
  response_type :async
  request_info true

  mfa :ping do
    request_type "ping"
    mfa {MyApp.Chat.Api, :ping, []}
    arg_types %{}
    timeout 1_000  # Override section default
    # response_type, request_info, etc. inherited from section
  end
end
```

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
- **MFA required fields** — Every `mfa` entity must have `request_type`, `mfa`, and `arg_types` set
- **MFA tuple validity** — The `mfa` field must be a valid `{module, function, args_list}` tuple
- **Request type uniqueness** — No two endpoints (actions or mfas) in the same resource may share a `request_type`
- **Arg consistency** — When both `arg_types` and `arg_orders` are provided, their keys must match
- **Permission arg existence** — When `check_permission` is `{:arg, "name"}`, the argument must exist in `arg_types` (for `mfa` entities) or the Ash action (for `action` entities)
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
#=> ["send_direct_message", "get_conversation", "update_content", "ping"]

# MFA-specific introspection
AshPhoenixGenApi.Resource.Info.mfas(MyApp.Chat.DirectMessage)
#=> [%AshPhoenixGenApi.Resource.MfaConfig{name: :ping, ...}, ...]

AshPhoenixGenApi.Resource.Info.mfa(MyApp.Chat.DirectMessage, :ping)
#=> %AshPhoenixGenApi.Resource.MfaConfig{name: :ping, request_type: "ping", ...}

AshPhoenixGenApi.Resource.Info.enabled_mfas(MyApp.Chat.DirectMessage)
#=> [%AshPhoenixGenApi.Resource.MfaConfig{name: :ping, disabled: false, ...}, ...]

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