## Purpose

Lets standalone `gen_api.mfa` endpoints encode their return values the same way
action-backed endpoints do, so that structs returned by custom MFA functions are
converted to clean, serializer-safe maps instead of crashing downstream serializers.

## Requirements

### Requirement: mfa endpoints accept a result_encoder option
The `gen_api.mfa` DSL SHALL accept a `result_encoder` option with values
`:struct`, `:map`, `{module, function, args}`, or `nil`, matching the allowed
values of the action-level `result_encoder` option.

#### Scenario: mfa declares map encoding
- **WHEN** an `mfa` entity declares `result_encoder(:map)`
- **THEN** the configuration compiles and the endpoint's FunConfig carries a
  map-mode result encoder

#### Scenario: mfa without result_encoder inherits the section default
- **WHEN** an `mfa` entity does not set `result_encoder`
- **THEN** the effective encoder is the `gen_api` section-level `result_encoder`
  default, resolved with the same precedence as other mfa options
  (mfa value, else section default)

### Requirement: mfa encoder translates to a FunConfig encoder MFA
The generator SHALL translate the resolved encoder into a concrete MFA stored on
the endpoint's FunConfig, without changing the endpoint's calling convention:

- `:struct` SHALL translate to no encoder (result passes through unchanged)
- `:map` SHALL translate to the result-encoding function that converts `{:ok, data}`
  to `{:ok, encoded_data}` and passes `{:error, reason}` through unchanged
- a custom `{module, function, args}` tuple SHALL be stored verbatim

#### Scenario: struct mode preserves current behavior
- **WHEN** an mfa endpoint's effective encoder is `:struct`
- **THEN** the FunConfig carries no result encoder and the mfa return value is
  pushed to the client unmodified

#### Scenario: map mode converts ok tuples
- **WHEN** an mfa endpoint with map encoding returns `{:ok, data}` where `data` is
  an Ash resource struct
- **THEN** the client receives `{:ok, map}` containing only the resource's public
  fields

#### Scenario: map mode converts lists element-wise
- **WHEN** an mfa endpoint with map encoding returns `{:ok, [struct_1, struct_2]}`
- **THEN** the client receives `{:ok, [map_1, map_2]}` with each struct converted
  to a map of public fields

#### Scenario: error tuples pass through
- **WHEN** an mfa endpoint with map encoding returns `{:error, reason}`
- **THEN** the client receives the error unchanged

### Requirement: encoding is top-level only
Map-mode encoding SHALL apply to the result value's top level only: a list is
encoded element-wise and a struct is converted, but structs nested inside map
values SHALL NOT be recursively converted.

#### Scenario: nested structs are left as-is
- **WHEN** an mfa endpoint with map encoding returns `{:ok, %{items: [struct]}}`
- **THEN** the `:items` list elements are not converted and remain as returned by
  the mfa

### Requirement: unknown encoder values do not silently disable encoding
The generator SHALL reject a `result_encoder` value that is not one of the
allowed forms (`:struct`, `:map`, `{module, function, args}`, `nil`) at
configuration time, instead of passing it through silently.

#### Scenario: invalid encoder value fails validation
- **WHEN** an mfa or action declares `result_encoder` with an unsupported value
  (for example a two-element tuple)
- **THEN** the domain fails to compile with an error naming the invalid value
