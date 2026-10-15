#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>

#include "win32_window.h"

// A window that hosts a Flutter view and answers the "vegas_encoder/window"
// channel (lib/platform/window_channel.dart).
//
// Dart -> runner:
//   configure {ownerHwnd?: int, hostHwnd?: int, keepOnTop?: bool,
//              bounds?: {x, y, width, height}, maximized?: bool}
//     -> {ownerSet: bool, boundsSet: bool, hostSet: bool}
//     (ownerHwnd: popup; hostHwnd: progress window, VEGAS's main window;
//      bounds: desktop; all before show)
//   getBounds -> {x, y, width, height, maximized}   (restored outer rect,
//     physical screen pixels)
//   startDrag, minimize, toggleMaximize, close
//   setKeepOnTop {value: bool}
//   getState -> {maximized, active, reducedMotion, keepOnTop, kind}
//   trace {label: String}   (startup trace, see startup_trace.h)
// Runner -> Dart:
//   windowEvent {type: maximized|active|reducedMotion, value: bool}
class FlutterWindow : public Win32Window {
 public:
  FlutterWindow(const flutter::DartProject& project,
                const LaunchOptions& options);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;
  void OnMaximizedChanged(bool maximized) override;
  void OnActivationChanged(bool active) override;
  void OnReducedMotionChanged(bool reduced) override;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void SendEvent(const char* type, bool value);

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;

  bool active_ = false;

  // "configure" is restoring the desktop window's bounds; a first frame that
  // arrives meanwhile shows the window once it is in place.
  bool placing_ = false;
  bool show_when_placed_ = false;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
