#ifndef RUNNER_SINGLE_INSTANCE_H_
#define RUNNER_SINGLE_INSTANCE_H_

#include <windows.h>

// The desktop app is single instance (TECH_ARCHITECTURE §9.2): a second launch
// brings the first window forward and exits. Popup and progress windows are
// not counted.
class SingleInstance {
 public:
  SingleInstance() = default;
  ~SingleInstance();

  // Returns false if another desktop instance already holds the lock.
  bool Acquire();

  // Restores and activates the running instance's window, if found.
  static void ActivateExisting();

  // Marks |window| as the desktop window so a later launch can find it.
  static void MarkWindow(HWND window);
  static void UnmarkWindow(HWND window);

 private:
  HANDLE mutex_ = nullptr;
};

#endif  // RUNNER_SINGLE_INSTANCE_H_
