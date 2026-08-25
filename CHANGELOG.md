# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.1] - 2026-08-25

### Fixed
- Fixed invalid FunConfig generation for Ash actions with no inputs (e.g. update actions
  that accept no attributes and declare no arguments): auto-derivation now yields
  `arg_orders: []` instead of `:map`, which `PhoenixGenApi.Structs.FunConfig` validation
  rejects when `arg_types` is empty ("arg_types is empty but arg_orders is not")

## [1.3.0] - 2026-08-25

### Added
- Support for `before_execute` / `after_execute` hooks with `hook_timeout` on gen_api actions
- Detailed DSL failure logs via `AshPhoenixGenApi.Debug`
- Shared internal helpers module (`AshPhoenixGenApi.Utils`) consolidating MFA validation,
  Spark option extraction, and source-location formatting across transformers and verifiers

### Fixed
- Fixed push using incorrect service config; nodes config from `define` is now preserved
- Fixed permission_callback being assigned to the wrong attribute

### Changed
- `JsonConfig.generate/2` now raises an `ArgumentError` with a descriptive message when the
  source module cannot be loaded or is not a gen_api resource/domain, instead of silently
  returning an empty list. Empty results are still returned for valid sources without configs.
- Removed dead code paths in `VerifyDomainConfig` (no-op service check); verifier moduledocs
  now accurately describe what is validated (MFA structure only, not module loading)
- Permission arg existence checks compare argument names as strings instead of creating atoms
  at compile time, and no longer crash when the referenced Ash action is missing
- Resolved all Dialyzer warnings; consolidated duplicated transformer/verifier helpers into
  `AshPhoenixGenApi.Utils`; CI now tests Elixir 1.18–1.20 across OTP 27–29
- Code quality cleanup: resolved all Credo strict-mode findings across library and test code
  (sorted alias groups, aliased nested modules, implicit `try`, removed redundant parentheses
  and stray blank lines); no behavior changes

## [1.1.0] - 2026-06-25

### Added
- Added support for MFA endpoint generation
- Added support for `:uuid` argument type
- Added support for passing arguments as map
- Added support for encoding results and utility for generating JSON of FunConfigs
- Added `active` push to PhoenixGenApi with auto-generated actions for resources
- Added generate-to-json utilities
- Added new format for generated arguments with `default_value` support from Ash attributes
- Updated supporter module for AI agent

### Fixed
- Fixed permission_callback assigned to wrong attribute
- Fixed compilation failure on Erlang/OTP 29
- Fixed bug where support functions were not generated after recompile without changes
- Fixed inconsistency for compiling supporter functions
- Fixed incorrect Ash boolean type conversion
- Fixed bug with not generating support functions after recompile without change
- Fixed return handling in `:map` case

### Changed
- Updated type mapping to support new formats
- Updated documentation and dependencies

## [1.0.3] - 2025-06-10

### Fixed
- Fixed duplicate `:usage_rules` key in `mix.exs` `usage_rules/0` function where the second entry silently overrode the first
- Fixed type mapping documentation to accurately reflect actual type mappings

## [1.0.2] - 2024-03-15

### Added
- Extended `arg_types` format with `allow_nil?` and `default_value` support
- Nil attribute support: attributes with `allow_nil? true` now generate extended format automatically

### Changed
- `AshPhoenixGenApi.TypeMapper.build_type_config/3` now returns extended format for nil-able attributes
- `AshPhoenixGenApi.TypeMapper.build_arg_config/1` passes `allow_nil?` information

## [1.0.1] - 2024-02-01

### Added
- Initial release with Ash to PhoenixGenApi type mapping
- Auto-derived arguments from Ash actions
- DSL configuration for resources and domains
- Supporter module generation
- MFA endpoint support
- Permission callback support
- Code interface generation

## [0.8.0] - 2024-01-15

### Added
- Initial release with basic Ash to PhoenixGenApi type mapping
- Auto-derived arguments from Ash actions
- DSL configuration for resources and domains
- Supporter module generation
- MFA endpoint support
- Permission callback support
- Code interface generation
