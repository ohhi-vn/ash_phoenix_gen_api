## Why

Standalone `mfa` endpoints silently ignore the `result_encoder` option: the mfa schema
(`resource.ex`) does not declare it and the transformer's `build_mfa_fun_config/2` never
reads it. Only action-backed endpoints encode results (encoding is baked into generated
code interfaces). Today this surfaced as a production crash: an mfa endpoint returning
`{:ok, list_of_structs}` pushed unencoded Ash structs to the channel, where the btoon
serializer's Nestru walk hit `Ash.NotLoaded` values and killed the channel. Users
currently work around this with leaky hand-rolled struct→map conversions that retain
`__struct__`, `__meta__`, and `Ash.NotLoaded` values.

## What Changes

- Add a `result_encoder` option to the `gen_api.mfa` DSL schema with the same allowed
  values as the action-level option: `:struct | :map | {module, function, args} | nil`.
- Resolve it with section inheritance like other mfa options: explicit value wins,
  otherwise the `gen_api` section-level `result_encoder` default applies.
- Translate the resolved codec mode into a concrete MFA stored on the generated
  `PhoenixGenApi.Structs.FunConfig`:
  - `:struct` → no encoder (pass-through, preserves current behavior)
  - `:map` → `{AshPhoenixGenApi.Codec, :encode_result, [:map]}`
  - custom `{m, f, args}` → stored verbatim
- Document the runtime contract on `FunConfig.result_encoder`: when set, the
  phoenix_gen_api runtime applies `apply(mod, fun, [result | extra_args])` to the mfa
  return value before response assembly; the encoder keeps the return format
  (`{:ok, data}` → `{:ok, new_data}`, `{:error, reason}` unchanged).
- Encoding is top-level only: a list result encodes element-wise; nested map values
  containing structs are not recursed (matches `Codec.encode_value/2` semantics).
- The phoenix_gen_api side (add `result_encoder` field to `FunConfig`, apply it once
  after the mfa call, rescue encoder failures into `{:error, ...}`) is a companion
  change in that repository.

## Capabilities

### New Capabilities

- `mfa-result-encoder`: Result encoding for standalone `gen_api.mfa` endpoints — the
  DSL option, its resolution/inheritance from the section default, the FunConfig
  encoder translation, and the runtime contract for `{:ok, data}` / `{:error, reason}`
  return shapes.

### Modified Capabilities

- (none — no existing specs in this project)

## Impact

- **Code:** `lib/ash_phoenix_gen_api/resource.ex` (mfa schema docs), `lib/ash_phoenix_gen_api/resource/mfa_config.ex` (new effective resolver), `lib/ash_phoenix_gen_api/transformers/define_fun_configs.ex` (`build_mfa_fun_config/2`).
- **Behavior change:** none for endpoints that do not configure `result_encoder(:map)` — the section default `:struct` translates to no encoder. Endpoints inheriting an explicitly configured section-level `:map` (or custom MFA) will start encoding their results; that is the intended feature.
- **Companion repo:** `phoenix_gen_api` — `FunConfig` gains a `result_encoder` field (default `nil`) and the runtime applies it post-call. Until that lands, the option has no runtime effect.
- **Dependencies:** none added.
