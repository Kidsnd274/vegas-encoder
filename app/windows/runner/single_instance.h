#ifndef RUNNER_SINGLE_INSTANCE_H_
#define RUNNER_SINGLE_INSTANCE_H_

#include <windows.h>

#include "launch_options.h"

// The desktop app is single instance (TECH_ARCHITECTURE §9.2): a second launch
// brings the first window forward and forwards a preset/job route. The lock
// and window marker are scoped to the inherited data-root profile. Popup and
// progress windows are not counted.
class SingleInstance {
 public:
  SingleInstance() = default;
  ~SingleInstance();

  // Returns false if another desktop instance already holds the lock.
  bool Acquire();

  // Waits at most 5 s for startup, sends a route with a 2 s timeout, then
  // restores/activates the window. False means absent, hung or refused.
  static bool ActivateExisting(const std::optional<DesktopRoute>& route);

  // Bounded WM_COPYDATA route protocol; receiver copies before returning.
  static constexpr ULONG_PTR kRouteMessage = 0x56454E31;
  static std::optional<DesktopRoute> ReadRoute(const COPYDATASTRUCT* data);

  // Marks |window| as the desktop window so a later launch can find it.
  static void MarkWindow(HWND window);
  static void UnmarkWindow(HWND window);

 private:
  HANDLE mutex_ = nullptr;
};

#endif  // RUNNER_SINGLE_INSTANCE_H_
