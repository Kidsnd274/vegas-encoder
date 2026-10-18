# Vegas Encoder icon

`app_icon.svg` is the selected option A: the current signal mark in the app's
dark palette. Edit this vector source, then run from any working directory:

```bat
L:\repos\vegas-encoder\scripts\export_app_icons.bat
```

The command needs Python 3 and Inkscape. It finds Inkscape on PATH, in the standard
Program Files folder, or at this development PC's existing `L:\Program Files`
installation. Override discovery when needed:

```bat
scripts\export_app_icons.bat --inkscape "C:\Tools\Inkscape\bin\inkscape.com"
scripts\export_app_icons.bat --check
```

`INKSCAPE_EXE` also overrides Inkscape; `VEGAS_ENCODER_PYTHON` overrides Python.
No tools are installed or downloaded. The implementation is
`scripts/etc/Export-AppIcons.py` and uses only Python's standard library.
`--check` renders temporary outputs and fails if any generated file is missing
or stale, without replacing files. Check in the source and generated outputs.
Normal app builds use the checked-in ICO and do not require Inkscape.

| Output | Purpose |
| --- | --- |
| `app/assets/icon/app_icon.png` | 256 × 256 transparent PNG |
| `app/windows/runner/resources/app_icon.ico` | Windows executable/taskbar icon; 16, 20, 24, 32, 40, 48, 64, 128 and 256 px frames |
| `docs/assets/app-icon.png` | 512 × 512 transparent PNG ready for Markdown |

Each ICO frame is rendered directly from the SVG. Transparency outside the tile
is preserved. The SVG itself can also be used by Markdown renderers that support
SVG images. The main README is intentionally left for the owner's later edit.

The existing `Runner.rc` embeds `resources/app_icon.ico`; rebuild the Windows app
to incorporate it. This is Flutter's documented
[Windows icon workflow](https://docs.flutter.dev/deployment/windows#add-app-icons).
There is no need for `flutter_launcher_icons`, its YAML, a second generation
command, or a Flutter runtime dependency for this Windows-only project.
Do not add the source/export PNG to `pubspec.yaml` just for the executable icon:
the Windows resource compiler consumes the ICO directly.

The in-app title bar already draws the same option A geometry through `VeLogo`
in `app/lib/design/icons.dart`. It retains its theme-aware light/dark palette;
the Windows/Markdown assets use the selected fixed dark tile. If changing the
shape later, update that painter too and run the window widget/light-dark golden
checks. These assets introduce no new fonts, third-party artwork or bundled
dependencies. Generation/rebuilding does not replace an installed app/exporter.
