#include "win32_window.h"

#include <commctrl.h>
#include <dwmapi.h>
#include <flutter_windows.h>
#include <windowsx.h>

#include <algorithm>

#include "resource.h"
#include "startup_trace.h"

namespace {

/// Window attribute that enables dark mode window decorations.
///
/// Redefined in case the developer's machine has a Windows SDK older than
/// version 10.0.22000.0.
/// See: https://docs.microsoft.com/windows/win32/api/dwmapi/ne-dwmapi-dwmwindowattribute
#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

constexpr const wchar_t kWindowClassName[] = L"VEGAS_ENCODER_WINDOW";

/// Registry key for app theme preference.
///
/// A value of 0 indicates apps should use dark mode. A non-zero or missing
/// value indicates apps should use light mode.
constexpr const wchar_t kGetPreferredBrightnessRegKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";
constexpr const wchar_t kGetPreferredBrightnessRegValue[] = L"AppsUseLightTheme";

constexpr UINT_PTR kChildSubclassId = 1;

// Gap between the progress window and the edges of the work area, logical px.
constexpr int kMonitorWindowMargin = 16;

// Height of the top resize band inside the client area, logical px.
constexpr int kTopResizeBand = 5;

// The number of Win32Window objects that currently exist.
static int g_active_window_count = 0;

using EnableNonClientDpiScaling = BOOL __stdcall(HWND hwnd);

// Scale helper to convert logical scaler values to physical using passed in
// scale factor
int Scale(int source, double scale_factor) {
  return static_cast<int>(source * scale_factor);
}

// Width of the invisible resize border on each side, physical px.
int ResizeBorderX(UINT dpi) {
  return GetSystemMetricsForDpi(SM_CXSIZEFRAME, dpi) +
         GetSystemMetricsForDpi(SM_CXPADDEDBORDER, dpi);
}

int ResizeBorderY(UINT dpi) {
  return GetSystemMetricsForDpi(SM_CYSIZEFRAME, dpi) +
         GetSystemMetricsForDpi(SM_CXPADDEDBORDER, dpi);
}

// Dynamically loads the |EnableNonClientDpiScaling| from the User32 module.
// This API is only needed for PerMonitor V1 awareness mode.
void EnableFullDpiSupportIfAvailable(HWND hwnd) {
  HMODULE user32_module = LoadLibraryA("User32.dll");
  if (!user32_module) {
    return;
  }
  auto enable_non_client_dpi_scaling =
      reinterpret_cast<EnableNonClientDpiScaling*>(
          GetProcAddress(user32_module, "EnableNonClientDpiScaling"));
  if (enable_non_client_dpi_scaling != nullptr) {
    enable_non_client_dpi_scaling(hwnd);
  }
  FreeLibrary(user32_module);
}

RECT WorkAreaOf(HMONITOR monitor) {
  MONITORINFO info{};
  info.cbSize = sizeof(info);
  GetMonitorInfo(monitor, &info);
  return info.rcWork;
}

}  // namespace

// Manages the Win32Window's window class registration.
class WindowClassRegistrar {
 public:
  ~WindowClassRegistrar() = default;

  // Returns the singleton registrar instance.
  static WindowClassRegistrar* GetInstance() {
    if (!instance_) {
      instance_ = new WindowClassRegistrar();
    }
    return instance_;
  }

  // Returns the name of the window class, registering the class if it hasn't
  // previously been registered.
  const wchar_t* GetWindowClass();

  // Unregisters the window class. Should only be called if there are no
  // instances of the window.
  void UnregisterWindowClass();

 private:
  WindowClassRegistrar() = default;

  static WindowClassRegistrar* instance_;

  bool class_registered_ = false;
};

WindowClassRegistrar* WindowClassRegistrar::instance_ = nullptr;

const wchar_t* WindowClassRegistrar::GetWindowClass() {
  if (!class_registered_) {
    WNDCLASS window_class{};
    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    window_class.lpszClassName = kWindowClassName;
    window_class.style = CS_HREDRAW | CS_VREDRAW;
    window_class.cbClsExtra = 0;
    window_class.cbWndExtra = 0;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.hIcon =
        LoadIcon(window_class.hInstance, MAKEINTRESOURCE(IDI_APP_ICON));
    window_class.hbrBackground = 0;
    window_class.lpszMenuName = nullptr;
    window_class.lpfnWndProc = Win32Window::WndProc;
    RegisterClass(&window_class);
    class_registered_ = true;
  }
  return kWindowClassName;
}

void WindowClassRegistrar::UnregisterWindowClass() {
  UnregisterClass(kWindowClassName, nullptr);
  class_registered_ = false;
}

Win32Window::Win32Window(const LaunchOptions& options) : options_(options) {
  ++g_active_window_count;
}

Win32Window::~Win32Window() {
  --g_active_window_count;
  Destroy();
}

bool Win32Window::Create() {
  Destroy();

  const wchar_t* window_class =
      WindowClassRegistrar::GetInstance()->GetWindowClass();

  // The progress window follows VEGAS, which is in the foreground when the
  // render starts. Everything else starts on the primary monitor.
  HMONITOR monitor = nullptr;
  if (options_.kind == LaunchKind::kRenderMonitor) {
    HWND foreground = GetForegroundWindow();
    if (foreground != nullptr) {
      monitor = MonitorFromWindow(foreground, MONITOR_DEFAULTTOPRIMARY);
    }
  }
  if (monitor == nullptr) {
    monitor = MonitorFromPoint(POINT{0, 0}, MONITOR_DEFAULTTOPRIMARY);
  }
  const UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  const double scale_factor = dpi / 96.0;
  const RECT work = WorkAreaOf(monitor);
  const int work_width = work.right - work.left;
  const int work_height = work.bottom - work.top;

  // The client area gets the logical size; resizable windows add the invisible
  // side and bottom resize borders around it.
  const int border_x = options_.resizable ? ResizeBorderX(dpi) : 0;
  const int border_y = options_.resizable ? ResizeBorderY(dpi) : 0;
  const int width = std::min(Scale(options_.width, scale_factor) + 2 * border_x,
                             work_width + 2 * border_x);
  const int height = std::min(Scale(options_.height, scale_factor) + border_y,
                              work_height + border_y);

  int x = work.left + (work_width - width) / 2;
  int y = work.top + (work_height - height) / 2;
  if (options_.kind == LaunchKind::kRenderMonitor) {
    const int margin = Scale(kMonitorWindowMargin, scale_factor);
    x = work.right - width - margin;
    y = work.bottom - height - margin;
  }

  const DWORD style = options_.resizable
                          ? WS_OVERLAPPEDWINDOW
                          : (WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU);
  const DWORD ex_style = options_.no_activate ? WS_EX_NOACTIVATE : 0;

  HWND window = CreateWindowEx(ex_style, window_class, options_.title.c_str(),
                               style, x, y, width, height, nullptr, nullptr,
                               GetModuleHandle(nullptr), this);

  if (!window) {
    return false;
  }

  UpdateTheme(window);

  if (!options_.resizable) {
    // Without a sizing frame Windows 11 draws square corners and no shadow;
    // ask for both, as the resizable windows get them.
    const DWORD round = 2;  // DWMWCP_ROUND
    DwmSetWindowAttribute(window, 33 /* DWMWA_WINDOW_CORNER_PREFERENCE */,
                          &round, sizeof(round));
    const MARGINS shadow{0, 0, 1, 0};
    DwmExtendFrameIntoClientArea(window, &shadow);
  }

  // Apply the caption-less frame computed in WM_NCCALCSIZE.
  SetWindowPos(window, nullptr, 0, 0, 0, 0,
               SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                   SWP_NOACTIVATE);

  return OnCreate();
}

bool Win32Window::Show() {
  if (options_.no_activate) {
    return ShowWindow(window_handle_, SW_SHOWNOACTIVATE);
  }
  return ShowWindow(window_handle_,
                    start_maximized_ ? SW_SHOWMAXIMIZED : SW_SHOWNORMAL);
}

std::optional<RECT> Win32Window::ClampBounds(RECT bounds) {
  if (window_handle_ == nullptr || options_.kind != LaunchKind::kDesktop ||
      bounds.right <= bounds.left || bounds.bottom <= bounds.top) {
    return std::nullopt;
  }
  HMONITOR monitor = MonitorFromRect(&bounds, MONITOR_DEFAULTTONULL);
  if (monitor == nullptr) {
    return std::nullopt;  // That monitor is gone: keep the default placement.
  }
  const RECT work = WorkAreaOf(monitor);
  const UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  const double scale_factor = dpi / 96.0;
  const int border_x = options_.resizable ? ResizeBorderX(dpi) : 0;
  const int border_y = options_.resizable ? ResizeBorderY(dpi) : 0;
  const int work_width = work.right - work.left;
  const int work_height = work.bottom - work.top;
  const int min_width = Scale(options_.min_width, scale_factor) + 2 * border_x;
  const int min_height = Scale(options_.min_height, scale_factor) + border_y;
  const int width = std::max(
      min_width, std::min(static_cast<int>(bounds.right - bounds.left),
                          work_width + 2 * border_x));
  const int height = std::max(
      min_height, std::min(static_cast<int>(bounds.bottom - bounds.top),
                           work_height + border_y));
  // Keep the whole window, title bar included, inside the work area (the
  // invisible resize borders may hang over its edges).
  const int x = std::max(
      static_cast<int>(work.left) - border_x,
      std::min(static_cast<int>(bounds.left),
               static_cast<int>(work.right) + border_x - width));
  const int y = std::max(
      static_cast<int>(work.top),
      std::min(static_cast<int>(bounds.top),
               static_cast<int>(work.bottom) + border_y - height));
  return RECT{x, y, x + width, y + height};
}

void Win32Window::RestoreBounds(RECT bounds, bool maximized) {
  if (window_handle_ == nullptr) {
    return;
  }
  start_maximized_ = maximized && options_.resizable;
  // Move first, so a monitor with another DPI rescales before the size is set.
  SetWindowPos(window_handle_, nullptr, bounds.left, bounds.top, 0, 0,
               SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
  SetWindowPos(window_handle_, nullptr, bounds.left, bounds.top,
               bounds.right - bounds.left, bounds.bottom - bounds.top,
               SWP_NOZORDER | SWP_NOACTIVATE);
}

RECT Win32Window::RestoredBounds(bool* maximized) {
  RECT rect{0, 0, 0, 0};
  if (maximized != nullptr) {
    *maximized = false;
  }
  if (window_handle_ == nullptr) {
    return rect;
  }
  WINDOWPLACEMENT placement{sizeof(WINDOWPLACEMENT)};
  if ((IsZoomed(window_handle_) || IsIconic(window_handle_)) &&
      GetWindowPlacement(window_handle_, &placement)) {
    // rcNormalPosition is in workspace coordinates: shift it by the gap
    // between the monitor and its work area (a taskbar on the top or left).
    rect = placement.rcNormalPosition;
    MONITORINFO info{sizeof(MONITORINFO)};
    if (GetMonitorInfo(MonitorFromRect(&rect, MONITOR_DEFAULTTONEAREST),
                       &info)) {
      OffsetRect(&rect, info.rcWork.left - info.rcMonitor.left,
                 info.rcWork.top - info.rcMonitor.top);
    }
    if (maximized != nullptr) {
      *maximized = IsZoomed(window_handle_) ||
                   (placement.flags & WPF_RESTORETOMAXIMIZED) != 0;
    }
    return rect;
  }
  GetWindowRect(window_handle_, &rect);
  return rect;
}

bool Win32Window::PlaceOnOwner(HWND owner) {
  if (window_handle_ == nullptr || owner == nullptr || !IsWindow(owner)) {
    return false;
  }
  owner_ = owner;
  SetWindowLongPtr(window_handle_, GWLP_HWNDPARENT,
                   reinterpret_cast<LONG_PTR>(owner));

  RECT owner_rect;
  RECT self;
  GetWindowRect(owner, &owner_rect);
  GetWindowRect(window_handle_, &self);
  const RECT work =
      WorkAreaOf(MonitorFromWindow(owner, MONITOR_DEFAULTTONEAREST));
  const int width = self.right - self.left;
  const int height = self.bottom - self.top;
  int x = (owner_rect.left + owner_rect.right - width) / 2;
  int y = (owner_rect.top + owner_rect.bottom - height) / 2;
  x = std::max(static_cast<int>(work.left),
               std::min(x, static_cast<int>(work.right) - width));
  y = std::max(static_cast<int>(work.top),
               std::min(y, static_cast<int>(work.bottom) - height));
  SetWindowPos(window_handle_, nullptr, x, y, 0, 0,
               SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
  char line[160];
  RECT placed;
  GetWindowRect(window_handle_, &placed);
  snprintf(line, sizeof(line),
           "place_on_owner owner=(%ld,%ld,%ld,%ld) self_before=(%ld,%ld,%ld,%ld) "
           "placed=(%ld,%ld,%ld,%ld)",
           owner_rect.left, owner_rect.top, owner_rect.right, owner_rect.bottom,
           self.left, self.top, self.right, self.bottom, placed.left, placed.top,
           placed.right, placed.bottom);
  startup_trace::Mark(line);
  return true;
}

void Win32Window::SetKeepOnTop(bool keep_on_top) {
  keep_on_top_ = keep_on_top;
  if (window_handle_ != nullptr) {
    SetWindowPos(window_handle_, keep_on_top ? HWND_TOPMOST : HWND_NOTOPMOST,
                 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
  }
}

void Win32Window::StartDrag() {
  if (window_handle_ == nullptr) {
    return;
  }
  ReleaseCapture();
  SendMessage(window_handle_, WM_NCLBUTTONDOWN, HTCAPTION, 0);
}

void Win32Window::Minimize() {
  if (window_handle_ != nullptr) {
    ShowWindow(window_handle_, SW_MINIMIZE);
  }
}

void Win32Window::ToggleMaximize() {
  if (window_handle_ != nullptr && options_.resizable) {
    ShowWindow(window_handle_, IsZoomed(window_handle_) ? SW_RESTORE
                                                        : SW_MAXIMIZE);
  }
}

bool Win32Window::IsWindowMaximized() {
  return window_handle_ != nullptr && IsZoomed(window_handle_);
}

void Win32Window::RequestClose() {
  if (window_handle_ != nullptr) {
    PostMessage(window_handle_, WM_CLOSE, 0, 0);
  }
}

// static
bool Win32Window::ReducedMotion() {
  BOOL animations = TRUE;
  if (!SystemParametersInfo(SPI_GETCLIENTAREAANIMATION, 0, &animations, 0)) {
    return false;
  }
  return animations == FALSE;
}

// static
LRESULT CALLBACK Win32Window::WndProc(HWND const window,
                                      UINT const message,
                                      WPARAM const wparam,
                                      LPARAM const lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto window_struct = reinterpret_cast<CREATESTRUCT*>(lparam);
    SetWindowLongPtr(window, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(window_struct->lpCreateParams));

    auto that = static_cast<Win32Window*>(window_struct->lpCreateParams);
    EnableFullDpiSupportIfAvailable(window);
    that->window_handle_ = window;
  } else if (Win32Window* that = GetThisFromHandle(window)) {
    return that->MessageHandler(window, message, wparam, lparam);
  }

  return DefWindowProc(window, message, wparam, lparam);
}

bool Win32Window::InTopResizeBand(POINT screen_point) {
  if (!options_.resizable || window_handle_ == nullptr ||
      IsZoomed(window_handle_)) {
    return false;
  }
  RECT rect;
  GetWindowRect(window_handle_, &rect);
  const double scale_factor = FlutterDesktopGetDpiForHWND(window_handle_) / 96.0;
  return screen_point.y >= rect.top &&
         screen_point.y < rect.top + Scale(kTopResizeBand, scale_factor);
}

// static
LRESULT CALLBACK Win32Window::ChildSubclassProc(HWND window,
                                                UINT message,
                                                WPARAM wparam,
                                                LPARAM lparam,
                                                UINT_PTR subclass_id,
                                                DWORD_PTR ref_data) {
  if (message == WM_NCHITTEST) {
    auto that = reinterpret_cast<Win32Window*>(ref_data);
    const POINT point{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
    // Let the top-level window answer HTTOP for the resize band.
    if (that->InTopResizeBand(point)) {
      return HTTRANSPARENT;
    }
  } else if (message == WM_NCDESTROY) {
    RemoveWindowSubclass(window, ChildSubclassProc, subclass_id);
  }
  return DefSubclassProc(window, message, wparam, lparam);
}

LRESULT
Win32Window::MessageHandler(HWND hwnd,
                            UINT const message,
                            WPARAM const wparam,
                            LPARAM const lparam) noexcept {
  switch (message) {
    case WM_DESTROY:
      window_handle_ = nullptr;
      Destroy();
      if (quit_on_close_) {
        PostQuitMessage(0);
      }
      return 0;

    case WM_CLOSE:
      // Reached only when Flutter allowed the close. Re-enable the owner first,
      // as a modal dialog does, so Windows returns activation to it.
      if (owner_ != nullptr && IsWindow(owner_)) {
        EnableWindow(owner_, TRUE);
      }
      break;

    case WM_NCCALCSIZE: {
      if (wparam == FALSE) {
        break;
      }
      if (!options_.resizable) {
        // The whole window is client area.
        return 0;
      }
      // Keep the system's side and bottom resize borders; drop the caption.
      auto params = reinterpret_cast<NCCALCSIZE_PARAMS*>(lparam);
      const LONG top = params->rgrc[0].top;
      const LRESULT result = DefWindowProc(hwnd, message, wparam, lparam);
      if (result != 0) {
        return result;
      }
      params->rgrc[0].top = top;
      if (IsZoomed(hwnd)) {
        // A maximized window overhangs the monitor by its frame.
        params->rgrc[0].top += ResizeBorderY(FlutterDesktopGetDpiForHWND(hwnd));
      }
      return 0;
    }

    case WM_NCHITTEST: {
      const LRESULT hit = DefWindowProc(hwnd, message, wparam, lparam);
      const POINT point{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
      if (hit == HTCLIENT && InTopResizeBand(point)) {
        RECT rect;
        GetWindowRect(hwnd, &rect);
        const int corner = 2 * ResizeBorderX(FlutterDesktopGetDpiForHWND(hwnd));
        if (point.x < rect.left + corner) {
          return HTTOPLEFT;
        }
        if (point.x >= rect.right - corner) {
          return HTTOPRIGHT;
        }
        return HTTOP;
      }
      return hit;
    }

    case WM_GETMINMAXINFO: {
      const UINT dpi = FlutterDesktopGetDpiForHWND(hwnd);
      const double scale_factor = dpi / 96.0;
      auto info = reinterpret_cast<MINMAXINFO*>(lparam);
      const int border_x = options_.resizable ? 2 * ResizeBorderX(dpi) : 0;
      const int border_y = options_.resizable ? ResizeBorderY(dpi) : 0;
      info->ptMinTrackSize.x =
          Scale(options_.min_width, scale_factor) + border_x;
      info->ptMinTrackSize.y =
          Scale(options_.min_height, scale_factor) + border_y;
      return 0;
    }

    case WM_MOUSEACTIVATE:
      if (options_.no_activate) {
        return MA_NOACTIVATE;
      }
      break;

    case WM_DPICHANGED: {
      auto newRectSize = reinterpret_cast<RECT*>(lparam);
      LONG newWidth = newRectSize->right - newRectSize->left;
      LONG newHeight = newRectSize->bottom - newRectSize->top;

      SetWindowPos(hwnd, nullptr, newRectSize->left, newRectSize->top, newWidth,
                   newHeight, SWP_NOZORDER | SWP_NOACTIVATE);

      return 0;
    }
    case WM_SIZE: {
      RECT rect = GetClientArea();
      if (child_content_ != nullptr) {
        // Size and position the child window.
        MoveWindow(child_content_, rect.left, rect.top, rect.right - rect.left,
                   rect.bottom - rect.top, TRUE);
      }
      if (wparam != SIZE_MINIMIZED) {
        const bool maximized = wparam == SIZE_MAXIMIZED;
        if (maximized != was_maximized_) {
          was_maximized_ = maximized;
          OnMaximizedChanged(maximized);
        }
      }
      return 0;
    }

    case WM_ACTIVATE:
      OnActivationChanged(LOWORD(wparam) != WA_INACTIVE);
      if (child_content_ != nullptr && !options_.no_activate) {
        SetFocus(child_content_);
      }
      return 0;

    case WM_SETTINGCHANGE:
      if (wparam == SPI_SETCLIENTAREAANIMATION) {
        OnReducedMotionChanged(ReducedMotion());
      } else if (lparam != 0 &&
                 lstrcmpW(reinterpret_cast<LPCWSTR>(lparam),
                          L"ImmersiveColorSet") == 0) {
        UpdateTheme(hwnd);
      }
      break;

    case WM_DWMCOLORIZATIONCOLORCHANGED:
      UpdateTheme(hwnd);
      return 0;
  }

  return DefWindowProc(window_handle_, message, wparam, lparam);
}

void Win32Window::Destroy() {
  OnDestroy();

  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }
  if (g_active_window_count == 0) {
    WindowClassRegistrar::GetInstance()->UnregisterWindowClass();
  }
}

Win32Window* Win32Window::GetThisFromHandle(HWND const window) noexcept {
  return reinterpret_cast<Win32Window*>(
      GetWindowLongPtr(window, GWLP_USERDATA));
}

void Win32Window::SetChildContent(HWND content) {
  child_content_ = content;
  SetParent(content, window_handle_);
  RECT frame = GetClientArea();

  MoveWindow(content, frame.left, frame.top, frame.right - frame.left,
             frame.bottom - frame.top, true);

  if (options_.resizable) {
    SetWindowSubclass(content, ChildSubclassProc, kChildSubclassId,
                      reinterpret_cast<DWORD_PTR>(this));
  }
  // SetFocus activates the top-level window; the progress window must not.
  if (!options_.no_activate) {
    SetFocus(child_content_);
  }
}

RECT Win32Window::GetClientArea() {
  RECT frame;
  GetClientRect(window_handle_, &frame);
  return frame;
}

HWND Win32Window::GetHandle() {
  return window_handle_;
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

bool Win32Window::OnCreate() {
  // No-op; provided for subclasses.
  return true;
}

void Win32Window::OnDestroy() {
  // No-op; provided for subclasses.
}

void Win32Window::UpdateTheme(HWND const window) {
  DWORD light_mode;
  DWORD light_mode_size = sizeof(light_mode);
  LSTATUS result = RegGetValue(HKEY_CURRENT_USER, kGetPreferredBrightnessRegKey,
                               kGetPreferredBrightnessRegValue,
                               RRF_RT_REG_DWORD, nullptr, &light_mode,
                               &light_mode_size);

  if (result == ERROR_SUCCESS) {
    BOOL enable_dark_mode = light_mode == 0;
    DwmSetWindowAttribute(window, DWMWA_USE_IMMERSIVE_DARK_MODE,
                          &enable_dark_mode, sizeof(enable_dark_mode));
  }
}
