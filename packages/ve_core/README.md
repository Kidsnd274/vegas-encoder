# ve_core — B0

Pure Dart models, `VeCore` interface, and `FakeVeCore`. Import
`package:ve_core/ve_core.dart`. No Flutter or third-party dependencies.

See [C1/C2 contracts](../../docs/product/CONTRACTS.md) for wire shapes, null/default
semantics, issue IDs, UTF-16 ranges and ownership. The native DLL/build hook is B2.

```dart
final core = FakeVeCore();
final fixture = core.fixtures.first;
final command = core.compile(fixture.recipe,
    media: fixture.media, paths: fixture.paths);
```

Six built-ins and a popup snapshot are lookup fixtures from the read-only design
model. Other edited recipes/contexts require injected `CoreFixture` values. The fake
throws `B0-FIXTURE-MISSING` for unmatched requests, so it cannot imply that an edit
compiled successfully. Estimates with entered durations, arbitrary lint/completion,
diffs and custom payloads can be injected using the static fixture-key helpers.

Unknown keys remain at their original nesting positions. `toJson` gives a deep copy;
`fromJson` handles serialization, while the future C++ implementation validates.

Run `dart pub get --offline`, `dart analyze`, and
`dart run test/contracts_test.dart`, or the repository's `scripts/Test-B0.ps1`.
