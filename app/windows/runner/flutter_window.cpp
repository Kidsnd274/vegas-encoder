#include "flutter_window.h"

#include <flutter/standard_method_codec.h>

#include <optional>
#include <string>

#include "file_dialog.h"
#include "flutter/generated_plugin_registrant.h"
#include "single_instance.h"
#include "startup_trace.h"

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;

constexpr char kChannelName[] = "vegas_encoder/window";

const EncodableValue* Find(const EncodableMap& map, const char* key) {
  auto it = map.find(EncodableValue(key));
  if (it == map.end() || it->second.IsNull()) {
    return nullptr;
  }
  return &it->second;
}

std::optional<int64_t> AsInt(const EncodableValue* value) {
  if (value == nullptr) {
    return std::nullopt;
  }
  if (auto v = std::get_if<int32_t>(value)) {
    return *v;
  }
  if (auto v = std::get_if<int64_t>(value)) {
    return *v;
  }
  return std::nullopt;
}

std::optional<bool> AsBool(const EncodableValue* value) {
  if (value == nullptr) {
    return std::nullopt;
  }
  if (auto v = std::get_if<bool>(value)) {
    return *v;
  }
  return std::nullopt;
}

const char* KindName(LaunchKind kind) {
  switch (kind) {
    case LaunchKind::kEditSession:
      return "editSession";
    case LaunchKind::kRenderMonitor:
      return "renderMonitor";
    case LaunchKind::kDesktop:
    default:
      return "desktop";
  }
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project,
                             const LaunchOptions& options)
    : Win32Window(options), project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  channel_ = std::make_unique<flutter::MethodChannel<EncodableValue>>(
      flutter_controller_->engine()->messenger(), kChannelName,
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    HandleMethodCall(call, std::move(result));
  });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Dart configures the window (owner, keep on top, bounds) before runApp,
  // and a frame drawn while bounds are still being restored waits for them
  // (HandleMethodCall), so the window is shown in place: no visible jump.
  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    startup_trace::Mark("first_frame");
    if (placing_) {
      // The frame came while "configure" was still moving the window.
      show_when_placed_ = true;
      return;
    }
    this->Show();
    startup_trace::Mark("shown");
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (GetHandle() != nullptr && options().kind == LaunchKind::kDesktop) {
    SingleInstance::UnmarkWindow(GetHandle());
  }
  channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

void FlutterWindow::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const std::string& method = call.method_name();
  const EncodableMap empty;
  const auto* arguments = std::get_if<EncodableMap>(call.arguments());
  const EncodableMap& args = arguments != nullptr ? *arguments : empty;

  if (method == "configure") {
    bool owner_set = false;
    if (auto owner = AsInt(Find(args, "ownerHwnd"))) {
      owner_set = PlaceOnOwner(
          reinterpret_cast<HWND>(static_cast<intptr_t>(*owner)));
    }
    if (auto keep_on_top = AsBool(Find(args, "keepOnTop"))) {
      SetKeepOnTop(*keep_on_top);
    }
    std::optional<RECT> restore;
    if (const auto* value = Find(args, "bounds")) {
      if (const auto* bounds = std::get_if<EncodableMap>(value)) {
        const auto x = AsInt(Find(*bounds, "x"));
        const auto y = AsInt(Find(*bounds, "y"));
        const auto width = AsInt(Find(*bounds, "width"));
        const auto height = AsInt(Find(*bounds, "height"));
        if (x && y && width && height) {
          restore = ClampBounds(RECT{static_cast<LONG>(*x),
                                     static_cast<LONG>(*y),
                                     static_cast<LONG>(*x + *width),
                                     static_cast<LONG>(*y + *height)});
        }
      }
    }
    result->Success(EncodableValue(EncodableMap{
        {EncodableValue("ownerSet"), EncodableValue(owner_set)},
        {EncodableValue("boundsSet"), EncodableValue(restore.has_value())},
    }));
    // Restore after replying. A new size (or a monitor with another DPI)
    // resizes the Flutter view, and the engine then blocks this thread for
    // up to ~100-200 ms waiting for a frame of that size
    // (FlutterWindowsView::OnWindowSizeChanged). Dart draws that frame only
    // after this reply (main awaits configure before runApp); while blocked
    // the engine keeps running Dart's tasks, so replying first lets the frame
    // arrive. The window is shown only once it is in place, so it never jumps.
    if (restore) {
      placing_ = true;
      RestoreBounds(*restore, AsBool(Find(args, "maximized")).value_or(false));
      placing_ = false;
      if (show_when_placed_) {
        show_when_placed_ = false;
        Show();
        startup_trace::Mark("shown");
      }
    }
  } else if (method == "startDrag") {
    // Reply first: the move loop runs until the button is released.
    result->Success();
    StartDrag();
  } else if (method == "minimize") {
    Minimize();
    result->Success();
  } else if (method == "toggleMaximize") {
    ToggleMaximize();
    result->Success();
  } else if (method == "close") {
    RequestClose();
    result->Success();
  } else if (method == "setKeepOnTop") {
    SetKeepOnTop(AsBool(Find(args, "value")).value_or(false));
    result->Success();
  } else if (method == "getState") {
    result->Success(EncodableValue(EncodableMap{
        {EncodableValue("maximized"), EncodableValue(IsWindowMaximized())},
        {EncodableValue("active"), EncodableValue(active_)},
        {EncodableValue("reducedMotion"), EncodableValue(ReducedMotion())},
        {EncodableValue("keepOnTop"), EncodableValue(keep_on_top())},
        {EncodableValue("kind"),
         EncodableValue(std::string(KindName(options().kind)))},
    }));
  } else if (method == "getBounds") {
    bool maximized = false;
    const RECT rect = RestoredBounds(&maximized);
    result->Success(EncodableValue(EncodableMap{
        {EncodableValue("x"), EncodableValue(static_cast<int64_t>(rect.left))},
        {EncodableValue("y"), EncodableValue(static_cast<int64_t>(rect.top))},
        {EncodableValue("width"),
         EncodableValue(static_cast<int64_t>(rect.right - rect.left))},
        {EncodableValue("height"),
         EncodableValue(static_cast<int64_t>(rect.bottom - rect.top))},
        {EncodableValue("maximized"), EncodableValue(maximized)},
    }));
  } else if (method == "pickFile") {
    OpenFileRequest request;
    for (auto [key, field] : {std::pair{"title", &request.title},
                              std::pair{"filterName", &request.filter_name},
                              std::pair{"filterPattern",
                                        &request.filter_pattern}}) {
      if (const auto* value = Find(args, key)) {
        if (const auto* text = std::get_if<std::string>(value)) {
          *field = *text;
        }
      }
    }
    const auto path = ShowOpenFileDialog(GetHandle(), request);
    result->Success(path ? EncodableValue(*path) : EncodableValue());
  } else if (method == "trace") {
    if (const auto* label = Find(args, "label")) {
      if (const auto* text = std::get_if<std::string>(label)) {
        startup_trace::Mark(*text);
      }
    }
    result->Success();
  } else {
    result->NotImplemented();
  }
}

void FlutterWindow::SendEvent(const char* type, bool value) {
  if (!channel_) {
    return;
  }
  channel_->InvokeMethod(
      "windowEvent",
      std::make_unique<EncodableValue>(EncodableMap{
          {EncodableValue("type"), EncodableValue(type)},
          {EncodableValue("value"), EncodableValue(value)},
      }));
}

void FlutterWindow::OnMaximizedChanged(bool maximized) {
  SendEvent("maximized", maximized);
}

void FlutterWindow::OnActivationChanged(bool active) {
  active_ = active;
  SendEvent("active", active);
}

void FlutterWindow::OnReducedMotionChanged(bool reduced) {
  SendEvent("reducedMotion", reduced);
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
