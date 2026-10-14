#pragma once
#include <windows.h>
#include <cstddef>
#include <string>
#include <functional>

namespace vegas_encoder {
// Best-effort logging: one file per process, flushed per line.
// Build allocating arguments inside BestEffortDiagnostic at native boundaries.
void Log(const char* fmt, ...) noexcept;
void LogHex(const char* label, const void* p, size_t n) noexcept;
bool LogDetail(const char* key) noexcept;  // true for the first Cfg().detailCalls uses of key
std::string Hr(HRESULT hr);
std::string GuidText(const GUID& g);
std::string Utf8(const wchar_t* s);
std::wstring Widen(const std::string& s);
std::string HexBytes(const void* p, size_t n);
std::string FourCC(DWORD v);
std::string JsonEscape(const std::string& s);
double NowMs();  // milliseconds since DLL load
std::string ModulePath(HMODULE m);
std::string FileVersion(const std::string& path);
std::string Sha256File(const std::wstring& path, const std::function<bool()>& poll = {});


}  // namespace vegas_encoder
