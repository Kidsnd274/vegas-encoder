# Vegas Encoder app

The Flutter app: the desktop library app, the VEGAS popup editor and the render
progress window, all from one `VegasEncoder.exe`. Windows x64 only. Work from
`L:\repos\vegas-encoder\app` with one agent owning app and platform together.
Current [status](../docs/STATUS.md), [queue](../docs/NEXT_AGENT.md) and
[workflow](../docs/product/WORKSTREAMS.md) supersede the old split-agent handoff.
Historical spike results: [app history](../docs/product/workstreams/app.md).
Behaviour: [UI_SPEC.md](../docs/product/UI_SPEC.md). Look:
[signal-flow.html](../docs/product/design/signal-flow.html).

## Build and run

Flutter is at `L:\flutter` (3.47.7). From `app/`:

```powershell
flutter pub get
flutter run -d windows                    # desktop app
flutter build windows --release           # build\windows\x64\runner\Release\VegasEncoder.exe
VegasEncoder.exe --edit-session <dir>     # VEGAS popup (owned window)
VegasEncoder.exe --render-monitor <file>  # progress window (never takes focus)
```

Support switches (environment): `VEGAS_ENCODER_RENDERER=impeller` (default Skia),
`VEGAS_ENCODER_STARTUP_TRACE=<file>` (start-up timings).

## Layout

| Path | What |
| --- | --- |
| `lib/main.dart`, `lib/app/` | Mode dispatch and the app root |
| `lib/design/` | Tokens, theme, icons, components (no business logic) |
| `lib/features/` | Windows and screens; `gallery/` holds the F1 design-system page and its sample data |
| `lib/state/` | Riverpod providers |
| `lib/platform/` | The runner's window channel |
| `windows/runner/` | Frame, ownership, no-activate, single instance, trace |
| `test/` | Unit, widget and golden tests (`test/golden/goldens/`, light and dark) |
| `tool/spikes/` | Window spike probe against a fake VEGAS host |

## Tests

```powershell
flutter analyze
flutter test                                  # all tests
flutter test --update-goldens test/golden     # after an intended visual change
powershell -File tool\spikes\run_window_spikes.ps1 -Checks monitor # use the focused check for the changed runner behavior
```

The app reaches the core and the system only through `packages/ve_core` and
`packages/ve_services`. These implementations exist; tests use explicit fakes.
Single-agent ownership does not move domain or file/process logic into widgets.
