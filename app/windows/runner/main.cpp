#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "launch_options.h"
#include "single_instance.h"
#include "startup_trace.h"
#include "utils.h"

namespace {

// Rendering backend (TECH_ARCHITECTURE §9.4). Skia by default: on the
// development PC Impeller (OpenGL ES, SDF text) added about 1 s to engine
// start-up (1.3 s against 0.33 s to first frame), which breaks the popup's
// 1 s budget. VEGAS_ENCODER_RENDERER=impeller opts back in for support and
// comparison. Release builds ignore FLUTTER_ENGINE_SWITCHES, hence our own.
flutter::ImpellerSwitch RendererFromEnvironment() {
  wchar_t value[16];
  const DWORD length = ::GetEnvironmentVariableW(L"VEGAS_ENCODER_RENDERER",
                                                 value, 16);
  if (length > 0 && length < 16 && _wcsicmp(value, L"impeller") == 0) {
    return flutter::ImpellerSwitch::Enabled;
  }
  return flutter::ImpellerSwitch::Disabled;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  startup_trace::Mark("runner_entry");

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();
  const LaunchOptions options =
      LaunchOptions::FromArguments(command_line_arguments);

  SingleInstance single_instance;
  if (options.kind == LaunchKind::kDesktop && !single_instance.Acquire()) {
    SingleInstance::ActivateExisting();
    return EXIT_SUCCESS;
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");
  project.set_impeller_switch(RendererFromEnvironment());

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project, options);
  if (!window.Create()) {
    return EXIT_FAILURE;
  }
  if (options.kind == LaunchKind::kDesktop) {
    SingleInstance::MarkWindow(window.GetHandle());
  }
  window.SetQuitOnClose(true);
  startup_trace::Mark("window_created");

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
