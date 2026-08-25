# Fixtures for Info accessor coverage: plain modules without the gen_api
# extensions (fallback branches) and a fully-configured resource (overrides).

defmodule AshPhoenixGenApi.InfoFixtures.PlainResource do
  @moduledoc false
  use Ash.Resource,
    domain: nil

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string)
  end

  actions do
    defaults([:create])
  end
end

defmodule AshPhoenixGenApi.InfoFixtures.HookedResource do
  @moduledoc false
  use Ash.Resource,
    domain: nil,
    extensions: [AshPhoenixGenApi.Resource]

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string)
  end

  actions do
    defaults([:create])
    read(:list_items)
  end

  gen_api do
    service "hooked_service"
    timeout 9_000
    version "2.0.0"
    retry {:same_node, 2}
    nodes [:hooked@node]
    choose_node_mode :hash
    request_info false
    result_encoder(:map)
    before_execute({AshPhoenixGenApi.InfoFixtures.Hooks, :before})
    after_execute({AshPhoenixGenApi.InfoFixtures.Hooks, :after})
    hook_timeout(7_000)
    permission_callback(nil)

    action :create do
      check_permission false
      code_interface?(true)
    end

    action :list_items do
      check_permission :any_authenticated
      code_interface?(false)
      timeout 11_000
    end
  end
end

defmodule AshPhoenixGenApi.InfoFixtures.AcceptListResource do
  @moduledoc false
  use Ash.Resource,
    domain: nil,
    extensions: [AshPhoenixGenApi.Resource]

  attributes do
    uuid_primary_key(:id)
    attribute(:name, :string)
    attribute(:internal_note, :string, public?: false)
  end

  actions do
    defaults([:create])

    update :update_name do
      accept([:name])
      argument(:reason, :string, allow_nil?: false)
    end
  end

  gen_api do
    service "accept_list"

    action :update_name do
      request_type "update_name"
    end
  end
end

defmodule AshPhoenixGenApi.InfoFixtures.Hooks do
  @moduledoc false
  def before(_config), do: :ok
  def after_exec(_config), do: :ok
end

defmodule AshPhoenixGenApi.InfoFixtures.PlainDomain do
  @moduledoc false
  use Ash.Domain

  resources do
    resource(AshPhoenixGenApi.InfoFixtures.PlainResource)
  end
end

defmodule AshPhoenixGenApi.InfoFixtures.DisabledSupporterDomain do
  @moduledoc false
  use Ash.Domain,
    extensions: [AshPhoenixGenApi.Domain]

  gen_api do
    service "disabled_supporter"
    supporter_module AshPhoenixGenApi.InfoFixtures.DisabledSupporter
    define_supporter? false
    retry {:same_node, 2}
  end

  resources do
  end
end

defmodule AshPhoenixGenApi.InfoFixtures.EmptyGenApiResource do
  @moduledoc false
  use Ash.Resource,
    domain: nil,
    extensions: [AshPhoenixGenApi.Resource]

  attributes do
    uuid_primary_key(:id)
  end

  actions do
    defaults([:create])
  end
end

defmodule AshPhoenixGenApi.InfoFixtures.MfaWithCallbackResource do
  @moduledoc false
  use Ash.Resource,
    domain: nil,
    extensions: [AshPhoenixGenApi.Resource]

  attributes do
    uuid_primary_key(:id)
  end

  actions do
    defaults([:create])
  end

  gen_api do
    service "mfa_cb"

    mfa :with_callback do
      request_type "with_callback"
      mfa {AshPhoenixGenApi.InfoFixtures.Hooks, :before, []}
      arg_types %{"token" => :string}
      permission_callback({AshPhoenixGenApi.InfoFixtures.Hooks, :after, []})
    end
  end
end
