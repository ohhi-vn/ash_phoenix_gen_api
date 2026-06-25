defmodule AshPhoenixGenApi.VerifierTestResources do
  @moduledoc """
  Shared resource definitions for verifier tests.
  These resources use `domain: nil` to avoid domain inclusion validation
  when referenced from multiple test domains.
  """
end

defmodule AshPhoenixGenApi.VerifierTestResources.ResourceA do
  use Ash.Resource,
    domain: nil,
    extensions: [AshPhoenixGenApi.Resource]

  attributes do
    uuid_primary_key :id
    attribute :name, :string
  end

  actions do
    defaults [:create]
  end

  gen_api do
    service "test_service"
    action :create do
      request_type "shared_type"
    end
  end
end

defmodule AshPhoenixGenApi.VerifierTestResources.ResourceB do
  use Ash.Resource,
    domain: nil,
    extensions: [AshPhoenixGenApi.Resource]

  attributes do
    uuid_primary_key :id
    attribute :name, :string
  end

  actions do
    defaults [:create]
  end

  gen_api do
    service "test_service"
    action :create do
      request_type "shared_type"
    end
  end
end

defmodule AshPhoenixGenApi.VerifierTestResources.UniqueResourceA do
  use Ash.Resource,
    domain: nil,
    extensions: [AshPhoenixGenApi.Resource]

  attributes do
    uuid_primary_key :id
  end

  actions do
    defaults [:create]
  end

  gen_api do
    service "test_service"
    action :create do
      request_type "unique_type_a"
    end
  end
end

defmodule AshPhoenixGenApi.VerifierTestResources.UniqueResourceB do
  use Ash.Resource,
    domain: nil,
    extensions: [AshPhoenixGenApi.Resource]

  attributes do
    uuid_primary_key :id
  end

  actions do
    defaults [:create]
  end

  gen_api do
    service "test_service"
    action :create do
      request_type "unique_type_b"
    end
  end
end

defmodule AshPhoenixGenApi.VerifierTestResources.NoServiceResource do
  use Ash.Resource,
    domain: nil,
    extensions: [AshPhoenixGenApi.Resource]

  attributes do
    uuid_primary_key :id
  end

  actions do
    defaults [:create]
  end

  # Intentionally no gen_api block — the verifier should detect this
  # and report a missing service error when the domain also has no service.
end

defmodule AshPhoenixGenApi.VerifierTestResources.NoServiceAnnoResource do
  use Ash.Resource,
    domain: nil,
    extensions: [AshPhoenixGenApi.Resource]

  attributes do
    uuid_primary_key :id
  end

  actions do
    defaults [:create]
  end

  # Intentionally no gen_api block — used for source annotation testing
end
