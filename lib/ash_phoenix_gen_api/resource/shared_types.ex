defmodule AshPhoenixGenApi.Resource.SharedTypes do
  @moduledoc """
  Shared type definitions for ActionConfig and MfaConfig.

  This module centralizes the type definitions used across both configuration
  structs, avoiding duplication and ensuring consistency.
  """

  @type permission_mode ::
          false
          | :any_authenticated
          | {:arg, String.t()}
          | {:role, [String.t()]}
          | {:callback, {module(), atom(), [any()]}}

  @type permission_callback :: {module(), atom(), [any()]} | nil

  @type node_config ::
          [atom()]
          | {module(), atom(), [any()]}
          | :local

  @type choose_node_mode ::
          :random
          | :hash
          | {:hash, String.t()}
          | :round_robin

  @type retry_config ::
          nil
          | pos_integer()
          | {:same_node, pos_integer()}
          | {:all_nodes, pos_integer()}

  @type gen_api_type ::
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

  @type result_encoder ::
          :struct
          | :map
          | {module(), atom(), [any()]}
          | nil
end
