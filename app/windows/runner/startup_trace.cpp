#include "startup_trace.h"

#include <windows.h>

#include <cstdio>

namespace startup_trace {

namespace {

ULONGLONG FileTimeTicks(const FILETIME& time) {
  ULARGE_INTEGER value;
  value.LowPart = time.dwLowDateTime;
  value.HighPart = time.dwHighDateTime;
  return value.QuadPart;
}

}  // namespace

void Mark(const std::string& label) {
  wchar_t path[MAX_PATH];
  const DWORD length = ::GetEnvironmentVariableW(
      L"VEGAS_ENCODER_STARTUP_TRACE", path, MAX_PATH);
  if (length == 0 || length >= MAX_PATH) {
    return;
  }

  FILETIME created, exited, kernel, user, now;
  if (!::GetProcessTimes(::GetCurrentProcess(), &created, &exited, &kernel,
                         &user)) {
    return;
  }
  ::GetSystemTimePreciseAsFileTime(&now);
  const double elapsed_ms =
      static_cast<double>(FileTimeTicks(now) - FileTimeTicks(created)) /
      10000.0;

  char line[256];
  const int count =
      std::snprintf(line, sizeof(line), "%lu %.1f %s\r\n",
                    ::GetCurrentProcessId(), elapsed_ms, label.c_str());
  if (count <= 0) {
    return;
  }

  HANDLE file = ::CreateFileW(path, FILE_APPEND_DATA, FILE_SHARE_READ |
                                  FILE_SHARE_WRITE, nullptr, OPEN_ALWAYS,
                              FILE_ATTRIBUTE_NORMAL, nullptr);
  if (file == INVALID_HANDLE_VALUE) {
    return;
  }
  DWORD written = 0;
  ::WriteFile(file, line, static_cast<DWORD>(count), &written, nullptr);
  ::CloseHandle(file);
}

}  // namespace startup_trace
