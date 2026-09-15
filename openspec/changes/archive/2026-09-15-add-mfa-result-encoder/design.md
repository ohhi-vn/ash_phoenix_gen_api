## Context

Only action-backed endpoints encode results today: the transformer bakes
`Codec.encode_result/encode_value` into generated code-interface functions, and the
FunConfig's `mfa` points at those generated functions. Standalone `mfa` endpoints get
no encoding — their FunConfig points at the user's function directly. See
proposal.md for the production failure that motivates this.

Two constraints shape the design:

- This library is a *generator*: it produces `PhoenixGenApi.Structs.FunConfig` data and
  compiled functions on the resource. Runtime execution lives in the companion
  `phoenix_gen_api` repo, which has no encoder hook today.
- The mfa return shape is `{:ok, data}` / `{:error, reason}` — exactly
  `Codec.encode_result/2`'s contract. Existing mfa endpoints that return plain data
  must be unaffected unless they opt in (directly or via an explicitly configured
  section default).

## Goals / Non-Goals

**Goals:**

- First-class `result_encoder` on `gen_api.mfa`, with section-level inheritance
  matching the existing mfa option pattern (`effective_*` resolvers).
- The encoder travels on the FunConfig so the runtime can apply it uniformly for
  `:sync` / `:async` response assembly.
- Compile-time rejection of invalid encoder values (today an unknown value silently
  disables encoding via the pass-through fallback in `codec.ex:169`).

**Non-Goals:**

- Deep/recursive encoding of structs nested inside map values (top-level only).
- Runtime encoder support in this repo — that is the companion change in
  `phoenix_gen_api`.
- Changing the generated code interfaces for action-backed endpoints.
- Changing `ClubSearch.for_api`-style user functions; they can keep returning structs.

## Decisions

### 1. Encoder travels on FunConfig as `{module, function, args}` (not generated wrapper functions)

`build_mfa_fun_config/2` stores `FunConfig.result_encoder` as a concrete MFA; the
phoenix_gen_api runtime applies it once after the mfa call.

- *Alternative considered:* generate a wrapper function per mfa endpoint in the
  resource module (mirroring the action path). Rejected — the wrapper must replicate
  phoenix_gen_api's exact calling convention (predefined args, `arg_orders` shape,
  `request_info`), which is fragile duplication, and it would only help mfa
  endpoints defined in this DSL.
- Contract: `apply(mod, fun, [result | extra_args])`, mirroring the existing
  `Codec.encode_value/2` MFA clause so custom encoders read naturally.

### 2. Codec modes translate at generation time

- `:struct` → `nil` on the FunConfig (identity; keeps the wire format clean and
  preserves current behavior for every existing endpoint).
- `:map` → `{AshPhoenixGenApi.Codec, :encode_result, [:map]}`.
- Custom MFA → verbatim. `nil` (unset) → inherit section default, then translate.

This keeps ash_phoenix_gen_api as the owner of codec semantics and keeps
phoenix_gen_api generic (it never imports this library; it just applies an MFA).

### 3. Inheritance matches the mfa option pattern

New `MfaConfig.effective_result_encoder/2`: explicit mfa value, else the section
default (`:struct` when the section does not configure one). Section-level `:map` or
custom MFA therefore applies to all mfa endpoints that do not override — that is the
user's confirmed intent.

### 4. Validation via a verifier, applied to both action and mfa values

Add validation of the allowed forms in the existing verifier chain
(`lib/ash_phoenix_gen_api/verifiers/`) covering `ActionConfig` and `MfaConfig`
`result_encoder` values, producing a compile error naming the offending value. The
shared type in `resource/shared_types.ex` gains the same union, and the mfa schema
documents the option like the action schema does. The runtime pass-through fallback
in `codec.ex:169` stays as defense in depth.

### 5. Top-level encoding only

`:map` mode keeps `encode_value/2` semantics: `:ok` pass-through, struct → map of
public fields, list → element-wise, other values unchanged. Nested map values are
not recursed — the confirmed scope ("list of map").

## Risks / Trade-offs

- [Runtime support missing until the companion change lands in phoenix_gen_api] →
  The option is declared, validated, and stored on the FunConfig immediately;
  without runtime support it is inert. Document this in the schema docs and ship
  the companion change before announcing the feature.
- [Encoder failure at runtime would crash the channel, as today's Nestru crash
  showed] → Companion change requires the runtime to rescue encoder exceptions into
  `{:error, ...}` responses instead of crashing.
- [Section-level `:map` now reaches mfa endpoints that return already-encoded data]
  → Encoding plain maps/data is a no-op under `encode_value/2` (only structs and
  lists of structs are transformed), so this is safe in practice.
- [Compile-time validation is a behavior change for configs that previously
  "worked" with invalid values] → Values that previously passed through silently
  produced no encoding anyway (the bug this change fixes); rejection surfaces them
  rather than breaking working endpoints. Any false positive is user-visible at
  compile time, not at runtime.

## Migration Plan

1. Land this change (schema option, resolver, transformer mapping, verifier, tests,
   docs). Existing configs compile unchanged; behavior is identical unless
   `result_encoder(:map)` (or a section-level `:map`) is configured.
2. Land the companion change in phoenix_gen_api (FunConfig field, runtime apply with
   exception rescue).
3. Rollback: the option is additive; removing runtime support reverts to
   pass-through. No data or wire-format migration involved.
