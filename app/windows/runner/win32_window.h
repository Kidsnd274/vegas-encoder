#ifndef RUNNER_WIN32_WINDOW_H_
#define RUNNER_WIN32_WINDOW_H_

#include <windows.h>

#include <functional>
#include <memory>
#include <optional>
#include <string>

#include "launch_options.h"

// A high DPI-aware Win32 window without a system caption. The app draws its own
// title bar (Signal Flow's `.tb`); the window keeps the system resize borders,
// shadow and snap behaviour. Based on the Flutter runner template.
class Win32Window {
 public:
  explicit Win32Window(const LaunchOptions& options);
  virtual ~Win32Window();

  // Creates the window, hidden, at its default size. Desktop windows are centred
  // on the primary monitor; progress windows go to the bottom-right of the
  // monitor holding the foreground window (VEGAS when a render starts); popups
  // are placed when Dart supplies the owner (OwnerBounds).
  bool Create();

  // Shows the window. Progress windows show without activation.
  bool Show();

  // Release OS resources associated with window.
  void Destroy();

  // Inserts |content| into the window tree.
  void SetChildContent(HWND content);

  // Returns the backing Window handle. Returns nullptr after destruction.
  HWND GetHandle();

  // If true, closing this window will quit the application.
  void SetQuitOnClose(bool quit_on_close);

  // Return a RECT representing the bounds of the current client area.
  RECT GetClientArea();

  // Makes |owner| this window's owner (GWLP_HWNDPARENT) and returns where the
  // window goes: centred on the owner at the window's default size for the
  // owner's monitor and its DPI, inside that monitor's work area. Nullopt if
  // |owner| is not a window. Put it there with RestoreBounds before Show, so
  // it never jumps; on a monitor with another DPI that resizes the Flutter
  // view, so do it after replying to Dart (FlutterWindow::HandleMethodCall).
  std::optional<RECT> OwnerBounds(HWND owner);
  HWND owner() const { return owner_; }

  // Progress window only: where it goes for VEGAS's main window |host| (C5
  // `hostHwnd`): the bottom-right corner of the work area of the monitor
  // |host| is on, at the window's size for that monitor's DPI. Neither owns
  // nor activates anything. Nullopt if |host| is not a top-level window any
  // more (keep Create's placement, on the foreground window's monitor). Put
  // it there with RestoreBounds before Show, after replying to Dart.
  std::optional<RECT> HostBounds(HWND host);

  void SetKeepOnTop(bool keep_on_top);
  bool keep_on_top() const { return keep_on_top_; }

  // Desktop window only: |bounds| (the outer rectangle in physical screen
  // pixels, as RestoredBounds reported it) clamped to its monitor's work area
  // and the minimum size, or nullopt if no monitor holds it any more (keep the
  // default placement).
  std::optional<RECT> ClampBounds(RECT bounds);

  // Before Show: puts the window at |bounds|, a ClampBounds or OwnerBounds
  // result, and shows it maximized if |maximized|.
  void RestoreBounds(RECT bounds, bool maximized);

  // The outer rectangle the window has when restored (not maximized or
  // minimized), in physical screen pixels, and whether it is maximized.
  RECT RestoredBounds(bool* maximized);

  // Starts a system move loop, as if the caption were dragged.
  void StartDrag();
  void Minimize();
  void ToggleMaximize();
  bool IsWindowMaximized();
  // Posts WM_CLOSE, which Flutter routes to the framework's exit request.
  void RequestClose();

  // Windows "Animation effects" (SPI_GETCLIENTAREAANIMATION) is off.
  static bool ReducedMotion();

  const LaunchOptions& options() const { return options_; }

 protected:
  virtual LRESULT MessageHandler(HWND window,
                                 UINT const message,
                                 WPARAM const wparam,
                                 LPARAM const lparam) noexcept;

  // Called when Create is called, allowing subclass window-related setup.
  virtual bool OnCreate();

  // Called when Destroy is called.
  virtual void OnDestroy();

  // Window state notifications for subclasses.
  virtual void OnMaximizedChanged(bool maximized) {}
  virtual void OnActivationChanged(bool active) {}
  virtual void OnReducedMotionChanged(bool reduced) {}

 private:
  friend class WindowClassRegistrar;

  static LRESULT CALLBACK WndProc(HWND const window,
                                  UINT const message,
                                  WPARAM const wparam,
                                  LPARAM const lparam) noexcept;

  static Win32Window* GetThisFromHandle(HWND const window) noexcept;

  // Hit test for the top resize band, which lies inside the client area
  // because the caption is removed.
  static LRESULT CALLBACK ChildSubclassProc(HWND window,
                                            UINT message,
                                            WPARAM wparam,
                                            LPARAM lparam,
                                            UINT_PTR subclass_id,
                                            DWORD_PTR ref_data);
  bool InTopResizeBand(POINT screen_point);

  // Update the window frame's theme to match the system theme.
  static void UpdateTheme(HWND const window);

  LaunchOptions options_;
  bool quit_on_close_ = false;
  bool keep_on_top_ = false;
  bool was_maximized_ = false;
  bool start_maximized_ = false;
  HWND owner_ = nullptr;

  // window handle for top level window.
  HWND window_handle_ = nullptr;

  // window handle for hosted content.
  HWND child_content_ = nullptr;
};

#endif  // RUNNER_WIN32_WINDOW_H_
