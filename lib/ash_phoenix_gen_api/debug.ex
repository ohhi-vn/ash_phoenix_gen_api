defmodule AshPhoenixGenApi.Debug do
  @moduledoc """
  Debugging utilities for AshPhoenixGenApi DSL source annotations.

  Provides functions to inspect where DSL elements are defined in source code,
  which is useful for debugging configuration issues or building developer tools.

  ## Usage

      # Inspect source locations for a resource's gen_api config
      AshPhoenixGenApi.Debug.inspect_resource_sources(MyApp.Chat.DirectMessage)

      # Inspect source locations for a domain's gen_api config
      AshPhoenixGenApi.Debug.inspect_domain_sources(MyApp.Chat)

  Source annotations require `debug_info` to be enabled (the default in dev/test).
  They are not available in production or `.exs` scripts unless explicitly enabled.
  """

  alias AshPhoenixGenApi.Resource.Info, as: ResourceInfo
  alias AshPhoenixGenApi.Domain.Info, as: DomainInfo

  @doc """
  Inspects source locations for a resource's `gen_api` DSL section.

  Returns a map with section, option, and entity locations.
  """
  @spec inspect_resource_sources(module()) :: map() | {:error, :no_gen_api}
  def inspect_resource_sources(resource) do
    if ResourceInfo.has_gen_api?(resource) do
      dsl_state = resource.spark_dsl_config()
      section_anno = Spark.Dsl.Extension.get_section_anno(dsl_state, [:gen_api])

      entities = Spark.Dsl.Extension.get_entities(dsl_state, [:gen_api])

      %{
        section: format_anno(section_anno),
        entities: Enum.map(entities, &format_entity_anno/1),
        resource: resource
      }
    else
      {:error, :no_gen_api}
    end
  end

  @doc """
  Inspects source locations for a domain's `gen_api` DSL section.

  Returns a map with section, option, and entity locations.
  """
  @spec inspect_domain_sources(module()) :: map() | {:error, :no_gen_api}
  def inspect_domain_sources(domain) do
    if DomainInfo.has_gen_api?(domain) do
      dsl_state = domain.spark_dsl_config()
      section_anno = Spark.Dsl.Extension.get_section_anno(dsl_state, [:gen_api])

      entities = Spark.Dsl.Extension.get_entities(dsl_state, [:gen_api])

      %{
        section: format_anno(section_anno),
        entities: Enum.map(entities, &format_entity_anno/1),
        domain: domain
      }
    else
      {:error, :no_gen_api}
    end
  end

  @doc """
  Prints a human-readable summary of DSL source locations for a resource.
  """
  @spec print_resource_sources(module()) :: :ok
  def print_resource_sources(resource) do
    case inspect_resource_sources(resource) do
      {:error, :no_gen_api} ->
        IO.puts("Resource #{inspect(resource)} does not have gen_api configured.")

      info ->
        IO.puts("Source locations for #{inspect(info.resource)}:")
        IO.puts("  Section: #{format_location(info.section)}")

        Enum.each(info.entities, fn entity ->
          IO.puts("  Entity #{entity.name}: #{format_location(entity.location)}")
        end)
    end
  end

  @doc """
  Prints a human-readable summary of DSL source locations for a domain.
  """
  @spec print_domain_sources(module()) :: :ok
  def print_domain_sources(domain) do
    case inspect_domain_sources(domain) do
      {:error, :no_gen_api} ->
        IO.puts("Domain #{inspect(domain)} does not have gen_api configured.")

      info ->
        IO.puts("Source locations for #{inspect(info.domain)}:")
        IO.puts("  Section: #{format_location(info.section)}")

        Enum.each(info.entities, fn entity ->
          IO.puts("  Entity #{entity.name}: #{format_location(entity.location)}")
        end)
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp format_entity_anno(entity) do
    anno = Spark.Dsl.Entity.anno(entity)
    %{name: entity.name, location: format_anno(anno)}
  end

  defp format_anno(nil), do: nil

  defp format_anno(anno) when is_tuple(anno) do
    line = :erl_anno.location(anno)
    file = :erl_anno.file(anno)

    case file do
      :undefined -> "line #{line}"
      charlist -> "#{Path.relative_to_cwd(to_string(charlist))}:#{line}"
    end
  end

  defp format_anno(anno) when is_list(anno) do
    # Keyword list annotation (e.g. [file: ..., line: ...])
    line = Keyword.get(anno, :line, "?")
    file = Keyword.get(anno, :file, "unknown")
    "#{Path.relative_to_cwd(to_string(file))}:#{line}"
  end

  defp format_anno(_), do: nil

  defp format_location(nil), do: "unknown"
  defp format_location(location) when is_binary(location), do: location
end
