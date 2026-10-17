#ifndef RUNNER_LAUNCH_OPTIONS_H_
#define RUNNER_LAUNCH_OPTIONS_H_

#include <string>
#include <optional>
#include <vector>

// The three ways VegasEncoder.exe runs (TECH_ARCHITECTURE §9.2). The runner only
// needs the kind to choose the window's size, frame and activation behaviour;
// Dart parses the same arguments for everything else (lib/app/launch.dart).
enum class LaunchKind {
  kDesktop,        // user-started library app; single instance
  kEditSession,    // --edit-session <dir>: popup owned by VEGAS's dialog
  kRenderMonitor,  // --render-monitor <file>: progress window, never activates
};

struct DesktopRoute {
  std::string kind;
  std::string id;
  bool valid() const;
};

struct LaunchOptions {
  LaunchKind kind = LaunchKind::kDesktop;
  std::wstring title;
  // Logical pixels (96 dpi); scaled by the monitor's DPI on creation.
  int width = 0;
  int height = 0;
  int min_width = 0;
  int min_height = 0;
  bool resizable = true;
  // Shown with SW_SHOWNOACTIVATE and WS_EX_NOACTIVATE; clicks never activate it.
  bool no_activate = false;
  std::optional<DesktopRoute> desktop_route;
  bool invalid_desktop_route = false;

  // The first of --edit-session or --render-monitor decides the kind, the same
  // rule as the Dart parser. Anything else is the desktop app.
  static LaunchOptions FromArguments(const std::vector<std::string>& arguments);
};

#endif  // RUNNER_LAUNCH_OPTIONS_H_
