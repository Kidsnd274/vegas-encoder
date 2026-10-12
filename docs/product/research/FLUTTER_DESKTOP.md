# Flutter desktop stack notes

Researched: 2026-10-11 (Asia/Singapore). Scope: facts needed for
[TECH_ARCHITECTURE.md](../TECH_ARCHITECTURE.md) §9.

Every statement below carries one of three labels:

- **verified:** checked against the local SDK, the pub.dev API or the current docs;
- **documented:** taken from the current docs;
- **to verify:** needs the Windows target machine.

No Windows build was run.

## Local toolchain (verified)

`flutter --version` on the development machine (Linux host):

- Flutter 3.47.2, stable channel, framework revision d3b14c8769 (2026-08-26)
- Dart 3.13.2
- DevTools 2.60.0

The SDK cache holds Android and Linux engine artifacts only. Windows artifacts and
builds need the Windows machine with Visual Studio's "Desktop development with C++"
workload.

## Renderer

- **Documented:** Flutter's Impeller page (via Context7 `/flutter/website`, perf/impeller.md)
  shows how to *disable* Impeller on Windows in `windows/runner/main.cpp`:
  ```cpp
  flutter::DartProject project(L"data");
  project.set_impeller_switch(flutter::ImpellerSwitch::Disabled);
  ```
  That implies Impeller is available, and possibly the default, on Windows desktop.
- **Verified:** the local `flutter_tools` passes a tri-state `enable-impeller=true|false`
  flag to desktop devices (`packages/flutter_tools/lib/src/desktop_device.dart`, lines 299–301).
  The Windows app template's `main.cpp` does not mention Impeller.
- **To verify:** which backend 3.47 actually uses on the target PC. `flutter run -v`
  logs the backend. Text rendering and GPU behaviour also need checking while VEGAS
  holds the GPU. Keep the switch available as a support setting if one backend misbehaves.

## Command-line arguments and runner (verified)

The Windows runner template (`packages/flutter_tools/templates/app/windows.tmpl/runner/main.cpp.tmpl`):

- attaches a console only when one exists or a debugger is present;
- calls `CoInitializeEx(COINIT_APARTMENTTHREADED)`;
- passes `GetCommandLineArguments()` through `project.set_dart_entrypoint_arguments(...)`;
- creates a 1280×720 window at (10, 10).

`--edit-session <dir>` therefore arrives in `main(List<String> args)`. For popup mode,
the runner should skip the default size/position and wait for Dart to place the
window on its owner, to avoid a visible jump.

## Native code: build hooks (documented)

Context7 `/dart-lang/site-www` (tools/hooks.md, interop/c-interop.md):

- "Dart *build hooks* (formerly known as *native assets*) enable packages to contain
  native code assets that are transparently built, bundled, and made available at runtime."
- A `hook/build.dart` uses `package:hooks` and `native_toolchain_c`'s `CLibrary(...).build(input:, output:)`.
- `dart pub add hooks code_assets`, then `dart pub add native_toolchain_c`. These go
  under `dependencies`, not `dev_dependencies`.
- An optional `hook/link.dart` can tree-shake symbols.

**To verify (P1 spike):** C++17 sources and MSVC flags through `native_toolchain_c`
on Windows; also that `flutter test` on Linux can load the hook-built core for unit
tests. Fallback: build `ve_core` with CMake inside `windows/CMakeLists.txt` and load
it with `DynamicLibrary.open`.

## Packages (versions verified from the pub.dev API on 2026-10-11)

| Package | Latest | Published | Intended use |
| --- | --- | --- | --- |
| flutter_riverpod / riverpod | 3.4.3 | 2026-09-03 | State management (`Notifier`, `select`) |
| signals_flutter | 7.1.0 | 2026-05-29 | Alternative fine-grained state (not chosen) |
| freezed | 4.0.2 | 2026-09-18 | Immutable models with JSON |
| dart_mappable | 4.10.0 | 2026-09-07 | Alternative to freezed |
| go_router | 18.0.2 | 2026-09-28 | Desktop navigation (optional; the app has 4 top-level pages) |
| ffigen | 23.0.0 | 2026-10-06 | Generate bindings from `ve_core.h` |
| hooks | 2.2.0 | 2026-08-18 | Build hooks |
| code_assets | 2.1.0 | 2026-09-16 | Code asset types for hooks |
| native_toolchain_c | 0.19.5 | 2026-09-16 | Compile the core in the hook |
| win32 | 6.4.0 | 2026-08-05 | Owner HWND, DWM backdrop, DXGI adapter fingerprint |
| window_manager | 0.5.2 | 2026-07-04 | Size, title bar, focus |
| re_editor | 0.10.0 | 2026-07-01 | Candidate code editor for Command mode |
| fluent_ui | 4.16.1 | 2026-08-03 | Only if the Mica direction wins |
| flutter_acrylic | 1.1.4 | **2024-06-11** | Stale; prefer direct `DwmSetWindowAttribute` via win32 |
| msix | 3.18.0 | 2026-06-27 | Not suitable for the plug-in install (Program Files write) |

## Recommendations

- **State:** Riverpod 3 Notifiers per feature. An editor draft is an immutable recipe.
  Derived command, validation and estimate come from synchronous FFI calls, with
  `select` to keep rebuilds local.
- **Models:** freezed + json_serializable for typed access. Core's canonical JSON is the
  interchange format, and round-trip fixtures guard against drift.
- **Command editor:** start with a custom `TextEditingController.buildTextSpan` for
  highlighting, plus an overlay popover for autocomplete. Commands are under 2 KB, so
  a full code editor is unnecessary. Evaluate re_editor only if multi-cursor or very
  long text matter.
- **Fonts:** bundle the chosen OFL families as subset TTFs (Latin plus symbols). Use
  Segoe UI Variable only if the Mica direction wins, because it is a Windows system
  font and cannot be bundled.
- **Lists:** `ListView.builder` / `SliverList.builder` for the library and options.
  Option lists are small (hevc_nvenc has 54 private options), but the library may grow.
- **Probing:** run FFmpeg from a background isolate pool.

## Open items for the Windows spike (P2)

1. Cold and warm start time of a release build to first frame. Repeat with the owner
   HWND set before first show.
2. Does `Process.start` (or `Process.run`) of `ffmpeg.exe` from the GUI app flash a
   console window? If yes, spawn through `CreateProcessW(CREATE_NO_WINDOW)` in the core.
3. Cross-process owner window: z-order, focus return to VEGAS, Alt+Tab grouping,
   minimize/restore with VEGAS.
4. Impeller vs Skia backend: text rendering and stability with VEGAS running.
5. Build hooks compile C++17 with MSVC; `flutter test` loads the core on Linux.
6. `FileSystemEntity.watch` reliability on the library folder, including OneDrive-redirected AppData.

## Sources

- Context7 `/flutter/website`: perf/impeller.md; resources/faq.md (desktop support stable for Windows, macOS, Linux). Accessed 2026-10-11.
- Context7 `/dart-lang/site-www`: tools/hooks.md; interop/c-interop.md. Accessed 2026-10-11.
- pub.dev package API (`https://pub.dev/api/packages/<name>`), latest versions. Accessed 2026-10-11.
- Local SDK: `/home/samueltee/flutter_sdk/flutter` 3.47.2: windows runner template, `desktop_device.dart`.
