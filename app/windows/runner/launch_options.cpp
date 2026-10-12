#include "launch_options.h"

LaunchOptions LaunchOptions::FromArguments(
    const std::vector<std::string>& arguments) {
  LaunchOptions options;
  for (const std::string& argument : arguments) {
    if (argument == "--edit-session") {
      options.kind = LaunchKind::kEditSession;
      break;
    }
    if (argument == "--render-monitor") {
      options.kind = LaunchKind::kRenderMonitor;
      break;
    }
  }

  // Sizes from UI_SPEC §1 and §12.
  switch (options.kind) {
    case LaunchKind::kDesktop:
      options.title = L"Vegas Encoder";
      options.width = 1440;
      options.height = 900;
      options.min_width = 1100;
      options.min_height = 700;
      break;
    case LaunchKind::kEditSession:
      options.title = L"Vegas Encoder, editing a VEGAS render template";
      options.width = 1120;
      options.height = 740;
      options.min_width = 960;
      options.min_height = 640;
      break;
    case LaunchKind::kRenderMonitor:
      options.title = L"Vegas Encoder render progress";
      options.width = 380;
      options.height = 250;
      options.min_width = 380;
      options.min_height = 250;
      options.resizable = false;
      options.no_activate = true;
      break;
  }
  return options;
}
