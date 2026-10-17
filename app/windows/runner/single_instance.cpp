#include "single_instance.h"

#include <cstdint>
#include <string>
#include <vector>

namespace {

// One desktop per data profile. The inherited override must never hand trial
// preset/job IDs to the user's ordinary desktop (or another isolated trial).
std::wstring ProfileKey() {
  const DWORD needed = GetEnvironmentVariableW(L"VEGAS_ENCODER_DATA_ROOT", nullptr, 0);
  if (needed == 0) return L"default";
  std::vector<wchar_t> buffer(needed);
  GetEnvironmentVariableW(L"VEGAS_ENCODER_DATA_ROOT", buffer.data(), needed);
  std::wstring root(buffer.data());
  if (root.find_first_not_of(L" \t\r\n") == std::wstring::npos) return L"default";
  const DWORD full_size = GetFullPathNameW(root.c_str(), 0, nullptr, nullptr);
  if (full_size != 0) {
    std::vector<wchar_t> full(full_size);
    if (GetFullPathNameW(root.c_str(), full_size, full.data(), nullptr) != 0) root = full.data();
  }
  for (auto& c : root) if (c == L'/') c = L'\\';
  while (root.size() > 3 && root.back() == L'\\') root.pop_back();
  CharLowerBuffW(root.data(), static_cast<DWORD>(root.size()));
  uint64_t hash = 14695981039346656037ull;
  for (const wchar_t c : root) {
    hash ^= static_cast<uint16_t>(c);
    hash *= 1099511628211ull;
  }
  return std::to_wstring(hash);
}

std::wstring WindowProperty() { return L"VegasEncoder.Desktop." + ProfileKey(); }

struct WindowSearch { const wchar_t* property; HWND found = nullptr; };

BOOL CALLBACK FindMarkedWindow(HWND window, LPARAM found) {
  auto* search = reinterpret_cast<WindowSearch*>(found);
  if (GetPropW(window, search->property) != nullptr) {
    search->found = window;
    return FALSE;
  }
  return TRUE;
}

}  // namespace

SingleInstance::~SingleInstance() {
  if (mutex_ != nullptr) {
    CloseHandle(mutex_);
  }
}

bool SingleInstance::Acquire() {
  const auto name = L"Local\\VegasEncoder.Desktop." + ProfileKey();
  mutex_ = CreateMutexW(nullptr, TRUE, name.c_str());
  if (mutex_ == nullptr) return false;
  if (mutex_ != nullptr && GetLastError() == ERROR_ALREADY_EXISTS) {
    CloseHandle(mutex_);
    mutex_ = nullptr;
    return false;
  }
  return true;
}

// static
bool SingleInstance::ActivateExisting(const std::optional<DesktopRoute>& route) {
  const auto property = WindowProperty();
  WindowSearch search{property.c_str()};
  // Another launch may still be creating its first window. Wait only in this
  // short-lived desktop launcher process, never in VEGAS or Render.
  const auto deadline = GetTickCount64() + 5000;
  do {
    EnumWindows(FindMarkedWindow, reinterpret_cast<LPARAM>(&search));
    if (search.found != nullptr) break;
    Sleep(20);
  } while (GetTickCount64() < deadline);
  const HWND window = search.found;
  if (window == nullptr) return false;
  if (route) {
    if (!route->valid()) return false;
    const std::string payload = route->kind + "\n" + route->id;
    COPYDATASTRUCT data{kRouteMessage, static_cast<DWORD>(payload.size()),
                        const_cast<char*>(payload.data())};
    DWORD_PTR acknowledged = 0;
    if (!SendMessageTimeoutW(window, WM_COPYDATA, 0,
                             reinterpret_cast<LPARAM>(&data),
                             SMTO_ABORTIFHUNG | SMTO_BLOCK | SMTO_ERRORONEXIT,
                             2000, &acknowledged) || acknowledged != TRUE) return false;
  }
  if (IsIconic(window)) {
    ShowWindow(window, SW_RESTORE);
  }
  SetForegroundWindow(window);
  return true;
}

std::optional<DesktopRoute> SingleInstance::ReadRoute(const COPYDATASTRUCT* data) {
  if (data == nullptr || data->dwData != kRouteMessage || data->lpData == nullptr ||
      data->cbData < 5 || data->cbData > 135) return std::nullopt;
  const std::string payload(static_cast<const char*>(data->lpData), data->cbData);
  const auto separator = payload.find('\n');
  if (separator == std::string::npos) return std::nullopt;
  DesktopRoute route{payload.substr(0, separator), payload.substr(separator + 1)};
  return route.valid() ? std::optional<DesktopRoute>(std::move(route)) : std::nullopt;
}

// static
void SingleInstance::MarkWindow(HWND window) {
  SetPropW(window, WindowProperty().c_str(), reinterpret_cast<HANDLE>(1));
}

// static
void SingleInstance::UnmarkWindow(HWND window) {
  RemovePropW(window, WindowProperty().c_str());
}
