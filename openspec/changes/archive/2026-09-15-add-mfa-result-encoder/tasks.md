## 1. Schema & types

- [x] 1.1 Add `result_encoder` to the `gen_api.mfa` schema in `lib/ash_phoenix_gen_api/resource.ex` (docs mirroring the action-level option; values `:struct | :map | {module, function, args} | nil`) and verify the DSL accepts `result_encoder(:map)` in an mfa block
- [x] 1.2 Extend the shared `result_encoder` type in `lib/ash_phoenix_gen_api/resource/shared_types.ex` to document/include the mfa usage and confirm no compile errors with `mix compile`

## 2. Resolution & FunConfig mapping

- [x] 2.1 Add `MfaConfig.effective_result_encoder/2` in `lib/ash_phoenix_gen_api/resource/mfa_config.ex` (explicit value, else section default) with doctests, following the existing `effective_*` resolver pattern, and verify with `mix test test/ash_phoenix_gen_api/codec/result_encoder_test.exs`
- [x] 2.2 Wire the encoder into `build_mfa_fun_config/2` in `lib/ash_phoenix_gen_api/transformers/define_fun_configs.ex`: `:struct` → `nil`, `:map` → `{AshPhoenixGenApi.Codec, :encode_result, [:map]}`, custom MFA → verbatim, `nil` → resolved via inheritance; verify by asserting the generated FunConfig for an mfa endpoint in a test

## 3. Compile-time validation

- [x] 3.1 Add verifier checks in `lib/ash_phoenix_gen_api/verifiers/` rejecting `result_encoder` values that are not `:struct`, `:map`, a valid `{module, function, args}` tuple, or `nil`, for both ActionConfig and MfaConfig, and verify with a test asserting a compile-time error names the invalid value (e.g. a two-element tuple)
- [x] 3.2 Run `mix test` and confirm the full suite passes, including existing codec and generator tests (back-compat: configs without `result_encoder` on mfa endpoints produce unchanged FunConfigs)

## 4. Docs

- [x] 4.1 Document the mfa `result_encoder` option, its section inheritance, and the FunConfig encoder contract (`apply(mod, fun, [result | extra_args])`) in the DSL docs; note that runtime application requires the companion phoenix_gen_api change
- [x] 4.2 Update the module-level docs in `lib/ash_phoenix_gen_api.ex` where mfa endpoints are described, and verify docs render with `mix docs` (or inspect generated doc output)
