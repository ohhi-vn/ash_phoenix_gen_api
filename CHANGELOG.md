# Changelog

## [1.0.0] - 2024-01-XX

### Added
- **Nil Attribute Support**: Attributes with `allow_nil? true` now generate extended `arg_types` format that includes `:allow_nil?` option
- Extended `arg_types` format: `[type: :string, allow_nil?: true]` for nil-able attributes
- Support for `:default_value` in extended format when attributes have default values
- Documentation for nil attribute support in README.md and getting-started.md
- Fixed type mapping table (`:uuid` now correctly maps to `:uuid`, `:boolean` to `:boolean`, `:datetime` to `:datetime`, `:map` to `:map`)

### Changed
- `AshPhoenixGenApi.TypeMapper.build_type_config/3` now returns extended format for nil-able attributes
- `AshPhoenixGenApi.TypeMapper.build_arg_config/1` passes `allow_nil?` information

### Fixed
- Type mapping documentation now accurately reflects actual type mappings
- Consistent documentation between README.md and getting-started.md

## [0.8.0] - 2024-XX-XX

### Added
- Initial release with basic Ash to PhoenixGenApi type mapping
- Auto-derived arguments from Ash actions
- DSL configuration for resources and domains
- Supporter module generation
- MFA endpoint support
- Permission callback support
- Code interface generation
