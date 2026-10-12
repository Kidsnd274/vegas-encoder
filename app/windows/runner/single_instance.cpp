#include "single_instance.h"

namespace {

constexpr wchar_t kMutexName[] = L"Local\\VegasEncoder.Desktop";
constexpr wchar_t kWindowProperty[] = L"VegasEncoder.Desktop";

BOOL CALLBACK FindMarkedWindow(HWND window, LPARAM found) {
  if (GetPropW(window, kWindowProperty) != nullptr) {
    *reinterpret_cast<HWND*>(found) = window;
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
  mutex_ = CreateMutexW(nullptr, TRUE, kMutexName);
  if (mutex_ != nullptr && GetLastError() == ERROR_ALREADY_EXISTS) {
    CloseHandle(mutex_);
    mutex_ = nullptr;
    return false;
  }
  return true;
}

// static
void SingleInstance::ActivateExisting() {
  HWND window = nullptr;
  EnumWindows(FindMarkedWindow, reinterpret_cast<LPARAM>(&window));
  if (window == nullptr) {
    return;
  }
  if (IsIconic(window)) {
    ShowWindow(window, SW_RESTORE);
  }
  SetForegroundWindow(window);
}

// static
void SingleInstance::MarkWindow(HWND window) {
  SetPropW(window, kWindowProperty, reinterpret_cast<HANDLE>(1));
}

// static
void SingleInstance::UnmarkWindow(HWND window) {
  RemovePropW(window, kWindowProperty);
}
