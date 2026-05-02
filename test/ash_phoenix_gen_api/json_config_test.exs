defmodule AshPhoenixGenApi.JsonConfigTest do
  use ExUnit.Case

  @moduletag timeout: 60_000

  alias AshPhoenixGenApi.JsonConfig

  # ---------------------------------------------------------------------------
  # Test Resources & Domain
  # ---------------------------------------------------------------------------

  defmodule ChatMessage do
    use Ash.Resource,
      domain: AshPhoenixGenApi.JsonConfigTest.ChatDomain,
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
      attribute :priority, :integer do
        public? true
        allow_nil? true
      end
      attribute :tags, {:array, :string} do
        public? true
        allow_nil? true
      end
    end

    actions do
      create :create do
        accept [:from_user_id, :to_user_id, :content, :reply_to_id, :priority, :tags]
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
        timeout 3_000
      end

      action :update_content do
        request_type "update_message"
        response_type :sync
      end
    end
  end

  defmodule DisabledActionResource do
    use Ash.Resource,
      domain: AshPhoenixGenApi.JsonConfigTest.ChatDomain,
      extensions: [AshPhoenixGenApi.Resource]

    attributes do
      uuid_primary_key :id
      attribute :name, :string do
        public? true
      end
    end

    actions do
      create :create do
        accept [:name]
      end

      create :admin_create do
        accept [:name]
      end
    end

    gen_api do
      service "chat"

      action :create do
        request_type "create_item"
      end

      action :admin_create do
        request_type "admin_create_item"
        disabled true
      end
    end
  end

  defmodule ChatDomain do
    use Ash.Domain,
      extensions: [AshPhoenixGenApi.Domain]

    resources do
      resource AshPhoenixGenApi.JsonConfigTest.ChatMessage
      resource AshPhoenixGenApi.JsonConfigTest.DisabledActionResource
    end

    gen_api do
      service "chat"
      nodes {ClusterHelper, :get_nodes, [:chat]}
      choose_node_mode :random
      timeout 5_000
      response_type :async
      request_info true
      version "0.0.1"
      supporter_module AshPhoenixGenApi.JsonConfigTest.ChatDomain.GenApiSupporter
    end
  end

  # ---------------------------------------------------------------------------
  # Custom encoder for MFA tests
  # ---------------------------------------------------------------------------

  defmodule CustomEncoder do
    @moduledoc false
    def encode(fun_configs, _extra_arg) do
      fun_configs
      |> Enum.map(& &1.request_type)
      |> Enum.join(",")
    end
  end

  # ---------------------------------------------------------------------------
  # generate/2 — default format (:fun_configs)
  # ---------------------------------------------------------------------------

  describe "generate/2 — default format" do
    test "returns FunConfig structs from a resource" do
      result = JsonConfig.generate(ChatMessage)

      assert is_list(result)
      assert length(result) == 3

      request_types = Enum.map(result, & &1.request_type)
      assert "send_direct_message" in request_types
      assert "get_conversation" in request_types
      assert "update_message" in request_types
    end

    test "returns FunConfig structs from a domain" do
      result = JsonConfig.generate(ChatDomain)

      assert is_list(result)
      # 3 from ChatMessage + 1 from DisabledActionResource (disabled one excluded)
      assert length(result) >= 3

      request_types = Enum.map(result, & &1.request_type)
      assert "send_direct_message" in request_types
      assert "get_conversation" in request_types
    end
  end

  # ---------------------------------------------------------------------------
  # generate/2 — :map format
  # ---------------------------------------------------------------------------

  describe "generate/2 — :map format" do
    test "returns map from a resource" do
      result = JsonConfig.generate(ChatMessage, format: :map)

      assert is_map(result)
      assert Map.has_key?(result, "send_direct_message")
      assert Map.has_key?(result, "get_conversation")
      assert Map.has_key?(result, "update_message")
    end

    test "map entries have correct structure" do
      result = JsonConfig.generate(ChatMessage, format: :map)
      entry = result["send_direct_message"]

      assert Map.has_key?(entry, "event")
      assert Map.has_key?(entry, "data")
      assert entry["event"] == "phoenix_gen_api"

      data = entry["data"]
      assert Map.has_key?(data, "user_id")
      assert Map.has_key?(data, "device_id")
      assert Map.has_key?(data, "request_type")
      assert Map.has_key?(data, "request_id")
      assert Map.has_key?(data, "service")
      assert Map.has_key?(data, "version")
      assert Map.has_key?(data, "args")
    end

    test "map data has correct values" do
      result = JsonConfig.generate(ChatMessage, format: :map)
      data = result["send_direct_message"]["data"]

      assert data["user_id"] == "user_1"
      assert data["device_id"] == "device_1"
      assert data["request_id"] == "request_1"
      assert data["request_type"] == "send_direct_message"
      assert data["service"] == "chat"
      assert data["version"] == "0.0.1"
    end

    test "map args have correct keys from arg_orders" do
      result = JsonConfig.generate(ChatMessage, format: :map)
      args = result["send_direct_message"]["data"]["args"]

      # The create action accepts [:from_user_id, :to_user_id, :content, :reply_to_id, :priority, :tags]
      assert Map.has_key?(args, "from_user_id")
      assert Map.has_key?(args, "to_user_id")
      assert Map.has_key?(args, "content")
      assert Map.has_key?(args, "reply_to_id")
      assert Map.has_key?(args, "priority")
      assert Map.has_key?(args, "tags")
    end

    test "map args have type-based default values" do
      result = JsonConfig.generate(ChatMessage, format: :map)
      args = result["send_direct_message"]["data"]["args"]

      # UUID types map to :string → default ""
      assert args["from_user_id"] == ""
      assert args["to_user_id"] == ""
      assert args["content"] == ""
      assert args["reply_to_id"] == ""
      # Integer type maps to :num → default 0
      assert args["priority"] == 0
      # Array of string maps to {:list_string, _, _} → default []
      assert args["tags"] == []
    end

    test "excludes disabled actions" do
      result = JsonConfig.generate(DisabledActionResource, format: :map)

      assert Map.has_key?(result, "create_item")
      refute Map.has_key?(result, "admin_create_item")
    end

    test "returns map from a domain" do
      result = JsonConfig.generate(ChatDomain, format: :map)

      assert is_map(result)
      assert Map.has_key?(result, "send_direct_message")
      assert Map.has_key?(result, "get_conversation")
      assert Map.has_key?(result, "create_item")
    end
  end

  # ---------------------------------------------------------------------------
  # generate/2 — :json format
  # ---------------------------------------------------------------------------

  describe "generate/2 — :json format" do
    test "returns JSON string from a resource" do
      result = JsonConfig.generate(ChatMessage, format: :json)

      assert is_binary(result)
      # Should be valid JSON — decode it to verify
      {:ok, decoded} = Jason.decode(result)
      assert Map.has_key?(decoded, "send_direct_message")
    end

    test "JSON has correct nested structure" do
      result = JsonConfig.generate(ChatMessage, format: :json)
      {:ok, decoded} = Jason.decode(result)

      assert decoded["send_direct_message"]["event"] == "phoenix_gen_api"
      assert decoded["send_direct_message"]["data"]["request_type"] == "send_direct_message"
      assert decoded["send_direct_message"]["data"]["service"] == "chat"
    end
  end

  # ---------------------------------------------------------------------------
  # generate/2 — custom MFA format
  # ---------------------------------------------------------------------------

  describe "generate/2 — custom MFA format" do
    test "calls custom encoder with fun_configs and extra args" do
      result =
        JsonConfig.generate(ChatMessage,
          format: {CustomEncoder, :encode, ["extra"]}
        )

      assert result == "send_direct_message,get_conversation,update_message"
    end

    test "raises on invalid format" do
      assert_raise ArgumentError, ~r/Invalid format/, fn ->
        JsonConfig.generate(ChatMessage, format: :invalid)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # generate_from_resource/2
  # ---------------------------------------------------------------------------

  describe "generate_from_resource/2" do
    test "returns FunConfig structs by default" do
      result = JsonConfig.generate_from_resource(ChatMessage)

      assert is_list(result)
      assert length(result) == 3
    end

    test "returns map format" do
      result = JsonConfig.generate_from_resource(ChatMessage, format: :map)

      assert is_map(result)
      assert Map.has_key?(result, "send_direct_message")
    end
  end

  # ---------------------------------------------------------------------------
  # generate_from_domain/2
  # ---------------------------------------------------------------------------

  describe "generate_from_domain/2" do
    test "returns FunConfig structs by default" do
      result = JsonConfig.generate_from_domain(ChatDomain)

      assert is_list(result)
      assert length(result) >= 3
    end

    test "returns map format" do
      result = JsonConfig.generate_from_domain(ChatDomain, format: :map)

      assert is_map(result)
      assert Map.has_key?(result, "send_direct_message")
    end
  end

  # ---------------------------------------------------------------------------
  # to_map/2
  # ---------------------------------------------------------------------------

  describe "to_map/2" do
    test "converts FunConfig list to map" do
      fun_configs = AshPhoenixGenApi.Resource.Info.fun_configs(ChatMessage)
      result = JsonConfig.to_map(fun_configs)

      assert is_map(result)
      assert Map.has_key?(result, "send_direct_message")
      assert Map.has_key?(result, "get_conversation")
      assert Map.has_key?(result, "update_message")
    end

    test "converts with descriptions" do
      fun_configs = AshPhoenixGenApi.Resource.Info.fun_configs(ChatMessage)

      result =
        JsonConfig.to_map(fun_configs,
          descriptions: %{
            "send_direct_message" => "Send direct message to other user"
          }
        )

      assert Map.has_key?(result, "send_direct_message - Send direct message to other user")
    end

    test "handles empty list" do
      result = JsonConfig.to_map([])
      assert result == %{}
    end
  end

  # ---------------------------------------------------------------------------
  # to_json/2
  # ---------------------------------------------------------------------------

  describe "to_json/2" do
    test "converts FunConfig list to JSON string" do
      fun_configs = AshPhoenixGenApi.Resource.Info.fun_configs(ChatMessage)
      result = JsonConfig.to_json(fun_configs)

      assert is_binary(result)
      {:ok, decoded} = Jason.decode(result)
      assert Map.has_key?(decoded, "send_direct_message")
    end
  end

  # ---------------------------------------------------------------------------
  # fun_config_to_entry/2
  # ---------------------------------------------------------------------------

  describe "fun_config_to_entry/2" do
    test "returns key-value tuple" do
      fun_config =
        AshPhoenixGenApi.Resource.Info.fun_config(ChatMessage, "send_direct_message")

      {key, value} = JsonConfig.fun_config_to_entry(fun_config)

      assert key == "send_direct_message"
      assert Map.has_key?(value, "event")
      assert Map.has_key?(value, "data")
    end

    test "includes description in key when provided" do
      fun_config =
        AshPhoenixGenApi.Resource.Info.fun_config(ChatMessage, "send_direct_message")

      {key, _value} =
        JsonConfig.fun_config_to_entry(fun_config,
          descriptions: %{"send_direct_message" => "Send a direct message"}
        )

      assert key == "send_direct_message - Send a direct message"
    end

    test "entry data has correct structure" do
      fun_config =
        AshPhoenixGenApi.Resource.Info.fun_config(ChatMessage, "send_direct_message")

      {_key, value} = JsonConfig.fun_config_to_entry(fun_config)

      data = value["data"]
      assert data["request_type"] == "send_direct_message"
      assert data["service"] == "chat"
      assert data["version"] == "0.0.1"
      assert is_map(data["args"])
    end
  end

  # ---------------------------------------------------------------------------
  # default_value_for_type/1
  # ---------------------------------------------------------------------------

  describe "default_value_for_type/1" do
    test "returns empty string for :string" do
      assert JsonConfig.default_value_for_type(:string) == ""
    end

    test "returns 0 for :num" do
      assert JsonConfig.default_value_for_type(:num) == 0
    end

    test "returns empty list for list_string type" do
      assert JsonConfig.default_value_for_type({:list_string, 1000, 50}) == []
    end

    test "returns empty list for list_num type" do
      assert JsonConfig.default_value_for_type({:list_num, 1000}) == []
    end

    test "returns empty string for unknown types" do
      assert JsonConfig.default_value_for_type(:unknown) == ""
      assert JsonConfig.default_value_for_type({:custom, 1, 2}) == ""
    end
  end

  # ---------------------------------------------------------------------------
  # :descriptions option
  # ---------------------------------------------------------------------------

  describe ":descriptions option" do
    test "accepts a map of request_type => description" do
      result =
        JsonConfig.generate(ChatMessage,
          format: :map,
          descriptions: %{
            "send_direct_message" => "Send direct message to other user",
            "get_conversation" => "Get conversation messages"
          }
        )

      assert Map.has_key?(result, "send_direct_message - Send direct message to other user")
      assert Map.has_key?(result, "get_conversation - Get conversation messages")
      # Without description, key is just the request_type
      assert Map.has_key?(result, "update_message")
    end

    test "accepts a function (fun_config -> description)" do
      result =
        JsonConfig.generate(ChatMessage,
          format: :map,
          descriptions: fn fun_config ->
            String.replace(fun_config.request_type, "_", " ")
          end
        )

      # When a description function is provided, keys are formatted as "request_type - description"
      assert Map.has_key?(result, "send_direct_message - send direct message")
      assert Map.has_key?(result, "get_conversation - get conversation")
      assert Map.has_key?(result, "update_message - update message")
    end

    test "nil descriptions use request_type as key" do
      result = JsonConfig.generate(ChatMessage, format: :map, descriptions: nil)

      assert Map.has_key?(result, "send_direct_message")
      assert Map.has_key?(result, "get_conversation")
      assert Map.has_key?(result, "update_message")
    end
  end

  # ---------------------------------------------------------------------------
  # :arg_values option
  # ---------------------------------------------------------------------------

  describe ":arg_values option" do
    test "accepts a map of request_type => args map" do
      result =
        JsonConfig.generate(ChatMessage,
          format: :map,
          arg_values: %{
            "send_direct_message" => %{
              "from_user_id" => "user_1",
              "to_user_id" => "user_2",
              "content" => "Hello, how are you?",
              "reply_to_id" => ""
            }
          }
        )

      args = result["send_direct_message"]["data"]["args"]
      assert args["from_user_id"] == "user_1"
      assert args["to_user_id"] == "user_2"
      assert args["content"] == "Hello, how are you?"
      assert args["reply_to_id"] == ""
      # Unspecified args fall back to type-based defaults
      assert args["priority"] == 0
      assert args["tags"] == []
    end

    test "accepts a function (fun_config -> args_map)" do
      result =
        JsonConfig.generate(ChatMessage,
          format: :map,
          arg_values: fn fun_config ->
            # Generate example values based on arg types
            fun_config.arg_types
            |> Enum.map(fn {name, type} -> {name, example_from_type(type)} end)
            |> Map.new()
          end
        )

      args = result["send_direct_message"]["data"]["args"]
      assert args["from_user_id"] == "example"
      assert args["priority"] == 42
      assert args["tags"] == ["example"]
    end

    test "nil arg_values use type-based defaults" do
      result = JsonConfig.generate(ChatMessage, format: :map, arg_values: nil)
      args = result["send_direct_message"]["data"]["args"]

      assert args["from_user_id"] == ""
      assert args["priority"] == 0
      assert args["tags"] == []
    end

    test "function returning non-map falls back to empty" do
      result =
        JsonConfig.generate(ChatMessage,
          format: :map,
          arg_values: fn _fun_config -> "not a map" end
        )

      args = result["send_direct_message"]["data"]["args"]
      # Falls back to type-based defaults
      assert args["from_user_id"] == ""
    end
  end

  # ---------------------------------------------------------------------------
  # :event_name option
  # ---------------------------------------------------------------------------

  describe ":event_name option" do
    test "defaults to phoenix_gen_api" do
      result = JsonConfig.generate(ChatMessage, format: :map)
      assert result["send_direct_message"]["event"] == "phoenix_gen_api"
    end

    test "accepts custom event name" do
      result = JsonConfig.generate(ChatMessage, format: :map, event_name: "custom_event")
      assert result["send_direct_message"]["event"] == "custom_event"
    end
  end

  # ---------------------------------------------------------------------------
  # :user_id, :device_id, :request_id options
  # ---------------------------------------------------------------------------

  describe "request info options" do
    test "uses default values" do
      result = JsonConfig.generate(ChatMessage, format: :map)
      data = result["send_direct_message"]["data"]

      assert data["user_id"] == "user_1"
      assert data["device_id"] == "device_1"
      assert data["request_id"] == "request_1"
    end

    test "accepts custom user_id" do
      result = JsonConfig.generate(ChatMessage, format: :map, user_id: "admin_user")
      assert result["send_direct_message"]["data"]["user_id"] == "admin_user"
    end

    test "accepts custom device_id" do
      result = JsonConfig.generate(ChatMessage, format: :map, device_id: "mobile_device")
      assert result["send_direct_message"]["data"]["device_id"] == "mobile_device"
    end

    test "accepts custom request_id" do
      result = JsonConfig.generate(ChatMessage, format: :map, request_id: "req_123")
      assert result["send_direct_message"]["data"]["request_id"] == "req_123"
    end
  end

  # ---------------------------------------------------------------------------
  # Combined options
  # ---------------------------------------------------------------------------

  describe "combined options" do
    test "descriptions and arg_values together" do
      result =
        JsonConfig.generate(ChatMessage,
          format: :map,
          descriptions: %{
            "send_direct_message" => "Send direct message to other user"
          },
          arg_values: %{
            "send_direct_message" => %{
              "to_user_id" => "user_2",
              "content" => "Hello, how are you?",
              "reply_to_id" => ""
            }
          }
        )

      key = "send_direct_message - Send direct message to other user"
      assert Map.has_key?(result, key)

      args = result[key]["data"]["args"]
      assert args["to_user_id"] == "user_2"
      assert args["content"] == "Hello, how are you?"
      assert args["reply_to_id"] == ""
    end

    test "all custom options together" do
      result =
        JsonConfig.generate(ChatMessage,
          format: :map,
          user_id: "custom_user",
          device_id: "custom_device",
          request_id: "custom_request",
          event_name: "custom_event",
          descriptions: fn fc -> String.upcase(fc.request_type) end,
          arg_values: %{
            "send_direct_message" => %{"content" => "Hello"}
          }
        )

      # When a description function is provided, keys are formatted as "request_type - description"
      key = "send_direct_message - SEND_DIRECT_MESSAGE"
      assert Map.has_key?(result, key)

      entry = result[key]
      assert entry["event"] == "custom_event"
      assert entry["data"]["user_id"] == "custom_user"
      assert entry["data"]["device_id"] == "custom_device"
      assert entry["data"]["request_id"] == "custom_request"
      assert entry["data"]["args"]["content"] == "Hello"
    end
  end

  # ---------------------------------------------------------------------------
  # Full JSON config list format (matching the user's example)
  # ---------------------------------------------------------------------------

  describe "full JSON config list format" do
    test "matches the expected JSON config list structure" do
      result =
        JsonConfig.generate(ChatMessage,
          format: :map,
          descriptions: %{
            "send_direct_message" => "Send direct message to other user"
          },
          arg_values: %{
            "send_direct_message" => %{
              "to_user_id" => "user_2",
              "content" => "Hello, how are you?",
              "reply_to_id" => ""
            }
          }
        )

      key = "send_direct_message - Send direct message to other user"
      entry = result[key]

      # Verify the full structure matches the expected format
      assert entry["event"] == "phoenix_gen_api"
      assert entry["data"]["user_id"] == "user_1"
      assert entry["data"]["device_id"] == "device_1"
      assert entry["data"]["request_type"] == "send_direct_message"
      assert entry["data"]["request_id"] == "request_1"
      assert entry["data"]["service"] == "chat"
      assert entry["data"]["version"] == "0.0.1"
      assert entry["data"]["args"]["to_user_id"] == "user_2"
      assert entry["data"]["args"]["content"] == "Hello, how are you?"
      assert entry["data"]["args"]["reply_to_id"] == ""
    end

    test "JSON output matches the expected format" do
      result =
        JsonConfig.generate(ChatMessage,
          format: :json,
          descriptions: %{
            "send_direct_message" => "Send direct message to other user"
          },
          arg_values: %{
            "send_direct_message" => %{
              "to_user_id" => "user_2",
              "content" => "Hello, how are you?",
              "reply_to_id" => ""
            }
          }
        )

      {:ok, decoded} = Jason.decode(result)

      key = "send_direct_message - Send direct message to other user"
      entry = decoded[key]

      assert entry["event"] == "phoenix_gen_api"
      assert entry["data"]["request_type"] == "send_direct_message"
      assert entry["data"]["service"] == "chat"
      assert entry["data"]["version"] == "0.0.1"
      assert entry["data"]["args"]["to_user_id"] == "user_2"
      assert entry["data"]["args"]["content"] == "Hello, how are you?"
    end
  end

  # ---------------------------------------------------------------------------
  # Domain-level generation
  # ---------------------------------------------------------------------------

  describe "domain-level generation" do
    test "aggregates FunConfigs from all resources" do
      result = JsonConfig.generate(ChatDomain, format: :map)

      # Should have configs from both ChatMessage and DisabledActionResource
      assert Map.has_key?(result, "send_direct_message")
      assert Map.has_key?(result, "get_conversation")
      assert Map.has_key?(result, "update_message")
      assert Map.has_key?(result, "create_item")
      # Disabled action should be excluded
      refute Map.has_key?(result, "admin_create_item")
    end

    test "domain generation with descriptions" do
      result =
        JsonConfig.generate(ChatDomain,
          format: :map,
          descriptions: %{
            "send_direct_message" => "Send a direct message",
            "create_item" => "Create a new item"
          }
        )

      assert Map.has_key?(result, "send_direct_message - Send a direct message")
      assert Map.has_key?(result, "create_item - Create a new item")
    end
  end

  # ---------------------------------------------------------------------------
  # Edge cases
  # ---------------------------------------------------------------------------

  describe "edge cases" do
    test "handles resource with no gen_api extension gracefully" do
      result = JsonConfig.generate(PlainModule, format: :map)
      assert result == %{}
    end

    test "handles empty fun_configs list" do
      result = JsonConfig.to_map([], format: :map)
      assert result == %{}
    end

    test "to_json with empty list returns empty object JSON" do
      result = JsonConfig.to_json([])
      {:ok, decoded} = Jason.decode(result)
      assert decoded == %{}
    end

    test "arg_values function receives fun_config struct" do
      captured = []

      JsonConfig.generate(ChatMessage,
        format: :map,
        arg_values: fn fun_config ->
          send(self(), {:arg_values_called, fun_config.request_type})
          %{}
        end
      )

      captured =
        Enum.reduce(1..3, captured, fn _, acc ->
          receive do
            {:arg_values_called, request_type} -> [request_type | acc]
          after
            100 -> acc
          end
        end)

      assert "send_direct_message" in captured
      assert "get_conversation" in captured
      assert "update_message" in captured
    end

    test "descriptions function receives fun_config struct" do
      captured = []

      JsonConfig.generate(ChatMessage,
        format: :map,
        descriptions: fn fun_config ->
          send(self(), {:descriptions_called, fun_config.service})
          String.replace(fun_config.request_type, "_", " ")
        end
      )

      captured =
        Enum.reduce(1..3, captured, fn _, acc ->
          receive do
            {:descriptions_called, service} -> [service | acc]
          after
            100 -> acc
          end
        end)

      assert Enum.all?(captured, &(&1 == "chat"))
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers for tests
  # ---------------------------------------------------------------------------

  # A plain module without the gen_api extension, for edge case testing
  defmodule PlainModule do
  end

  defp example_from_type(:string), do: "example_string"
  defp example_from_type(:uuid), do: "example"
  defp example_from_type(:num), do: 42
  defp example_from_type({:list_string, _, _}), do: ["example"]
  defp example_from_type({:list_num, _}), do: [1, 2, 3]
  defp example_from_type(_), do: "example"
end
