#include "launch_options.h"

#include <algorithm>
#include <cctype>

bool DesktopRoute::valid() const {
  if ((kind != "preset" && kind != "job") || id.empty() || id.size() > 128 ||
      id.back() == '.') return false;
  const auto alnum = [](unsigned char c) {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
           (c >= '0' && c <= '9');
  };
  if (!alnum(static_cast<unsigned char>(id.front()))) return false;
  for (const unsigned char c : id) {
    if (!alnum(c) && c != '.' && c != '_' && c != '-') return false;
  }
  std::string base = id.substr(0, id.find('.'));
  std::transform(base.begin(), base.end(), base.begin(),
                 [](unsigned char c) { return static_cast<char>(std::toupper(c)); });
  return base != "CON" && base != "PRN" && base != "AUX" && base != "NUL" &&
         !(base.size() == 4 && (base.substr(0, 3) == "COM" || base.substr(0, 3) == "LPT") &&
           base[3] >= '1' && base[3] <= '9');
}

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

  if (options.kind == LaunchKind::kDesktop) {
    for (size_t i = 0; i < arguments.size(); ++i) {
      if (arguments[i] != "--open-preset" && arguments[i] != "--open-job") continue;
      DesktopRoute route{arguments[i] == "--open-preset" ? "preset" : "job",
                         i + 1 < arguments.size() ? arguments[i + 1] : ""};
      if (route.valid()) options.desktop_route = std::move(route);
      else options.invalid_desktop_route = true;
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
      options.height = 340;
      options.min_width = 380;
      options.min_height = 340;
      options.resizable = false;
      options.no_activate = true;
      break;
  }
  return options;
}
