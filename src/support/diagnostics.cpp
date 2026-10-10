// diag.cpp - configuration, logging and template helpers for vegas-encoder.
#include "../vegas/adapter/vegas_encoder.h"

#include <bcrypt.h>
#include <share.h>

#include <cstdarg>
#include <cstdio>
#include <cstring>
#include <map>

namespace vegas_encoder {

HMODULE g_module = nullptr;

namespace {

SRWLOCK g_logLock = SRWLOCK_INIT;
FILE* g_log = nullptr;
bool g_logTried = false;
std::map<std::string, int> g_detailCounts;

LARGE_INTEGER LoadCounter() {
  static LARGE_INTEGER start = [] {
    LARGE_INTEGER v;
    QueryPerformanceCounter(&v);
    return v;
  }();
  return start;
}

std::wstring ModuleDir() {
  wchar_t path[MAX_PATH] = L"";
  GetModuleFileNameW(g_module, path, MAX_PATH);
  wchar_t* slash = wcsrchr(path, L'\\');
  if (slash) *slash = 0;
  return path;
}

std::wstring IniString(const std::wstring& ini, const wchar_t* key, const wchar_t* def) {
  wchar_t buf[1024];
  GetPrivateProfileStringW(L"vegas-encoder", key, def, buf, 1024, ini.c_str());
  return buf;
}

DWORD IniNumber(const std::wstring& ini, const wchar_t* key, DWORD def) {
  std::wstring s = IniString(ini, key, L"");
  if (s.empty()) return def;
  return (DWORD)wcstoul(s.c_str(), nullptr, 0);  // accepts 0x prefix
}

Config LoadConfig() {
  Config c;
  c.iniPath = ModuleDir() + L"\\vegas-encoder.ini";
  wchar_t local[MAX_PATH] = L"";
  GetEnvironmentVariableW(L"LOCALAPPDATA", local, MAX_PATH);
  std::wstring defLog = std::wstring(local) + L"\\vegas-encoder";
  c.logDir = IniString(c.iniPath, L"LogDir", defLog.c_str());
  c.access = IniNumber(c.iniPath, L"Access", c.access);
  c.streamTypes = IniNumber(c.iniPath, L"StreamTypes", c.streamTypes);
  c.caps = IniNumber(c.iniPath, L"Caps", c.caps);
  c.pluginFlags = IniNumber(c.iniPath, L"PluginFlags", c.pluginFlags);
  c.writeVideo = IniNumber(c.iniPath, L"WriteVideo", 1) != 0;
  c.writeAudio = IniNumber(c.iniPath, L"WriteAudio", 1) != 0;
  c.probeGetters = IniNumber(c.iniPath, L"ProbeGetters", 1) != 0;
  c.detailCalls = (int)IniNumber(c.iniPath, L"DetailCalls", (DWORD)c.detailCalls);
  std::wstring mode = IniString(c.iniPath, L"OutputMode", L"ffmpeg");
  c.encode = mode == L"ffmpeg";
  c.validMode = c.encode || mode == L"raw";
  c.ffmpegPath = IniString(c.iniPath, L"FFmpegPath", c.ffmpegPath.c_str());
  c.showEncoderErrors = IniNumber(c.iniPath, L"ShowEncoderErrors", 1) != 0;
  c.pipeTimeoutMs = IniNumber(c.iniPath, L"PipeTimeoutMs", c.pipeTimeoutMs);
  c.finishTimeoutMs = IniNumber(c.iniPath, L"FinishTimeoutMs", c.finishTimeoutMs);
  return c;
}

void OpenLogLocked() {
  g_logTried = true;
  const Config& c = Cfg();
  CreateDirectoryW(c.logDir.c_str(), nullptr);
  wchar_t exe[MAX_PATH] = L"";
  GetModuleFileNameW(nullptr, exe, MAX_PATH);
  const wchar_t* base = wcsrchr(exe, L'\\');
  base = base ? base + 1 : exe;
  SYSTEMTIME st;
  GetLocalTime(&st);
  wchar_t stamp[64];
  swprintf_s(stamp, L"-%04u%02u%02u-%02u%02u%02u-%lu.log", st.wYear, st.wMonth, st.wDay,
             st.wHour, st.wMinute, st.wSecond, GetCurrentProcessId());
  const std::wstring name = c.logDir + L"\\vegas-encoder-" + base + stamp;
  // Shared for reading so the log can be inspected while VEGAS is running.
  g_log = _wfsopen(name.c_str(), L"wb", _SH_DENYWR);
  if (!g_log) return;
  std::string dll = ModulePath(g_module);
  std::string host = ModulePath(nullptr);
  fprintf(g_log, "vegas-encoder %s log; pid %lu; local %04u-%02u-%02u %02u:%02u:%02u\n", kVersion,
          GetCurrentProcessId(), st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond);
  fprintf(g_log, "plugin %s sha256=%s\n", dll.c_str(), Sha256File(Widen(dll)).c_str());
  fprintf(g_log, "host %s version=%s\n", host.c_str(), FileVersion(host).c_str());
  fprintf(g_log,
          "config ini=%s access=0x%lx streamTypes=0x%lx caps=0x%lx flags=0x%lx writeVideo=%d "
          "writeAudio=%d probeGetters=%d detailCalls=%d\n",
          Utf8(c.iniPath.c_str()).c_str(), c.access, c.streamTypes, c.caps, c.pluginFlags,
          c.writeVideo, c.writeAudio, c.probeGetters, c.detailCalls);
  fflush(g_log);
  fprintf(g_log, "output mode=%s FFmpegPath=%s pipeTimeoutMs=%lu finishTimeoutMs=%lu\n",
          c.encode ? "ffmpeg" : "raw", Utf8(c.ffmpegPath.c_str()).c_str(), c.pipeTimeoutMs, c.finishTimeoutMs);
  fflush(g_log);
}

}  // namespace

const Config& Cfg() {
  static const Config c = LoadConfig();
  return c;
}

double NowMs() {
  LARGE_INTEGER start = LoadCounter(), now, freq;  // start first: it is set on first use
  QueryPerformanceCounter(&now);
  QueryPerformanceFrequency(&freq);
  return (double)(now.QuadPart - start.QuadPart) * 1000.0 / (double)freq.QuadPart;
}

void Log(const char* fmt, ...) noexcept {
  char msg[4096];
  va_list ap;
  va_start(ap, fmt);
  vsnprintf(msg, sizeof msg, fmt, ap);
  va_end(ap);
  BestEffortDiagnostic([&] {
    ScopedExclusiveSrwLock lock(g_logLock);
    if (!g_logTried) OpenLogLocked();
    if (g_log) {
      fprintf(g_log, "[%10.3f %5lu] %s\n", NowMs(), GetCurrentThreadId(), msg);
      fflush(g_log);
    }
  });
}

void LogHex(const char* label, const void* p, size_t n) noexcept {
  Log("%s (%zu bytes):", label, n);
  const BYTE* b = (const BYTE*)p;
  for (size_t off = 0; off < n; off += 32) {
    char line[160];
    int k = snprintf(line, sizeof line, "  +%03zx:", off);
    for (size_t i = off; i < off + 32 && i < n; i++)
      k += snprintf(line + k, sizeof line - k, "%s%02x", (i % 8) ? "" : " ", b[i]);
    Log("%s", line);
  }
}

bool LogDetail(const char* key) noexcept {
  try {
    if (!key) return false;
    const int limit = Cfg().detailCalls;
    if (limit <= 0) return false;
    ScopedExclusiveSrwLock lock(g_logLock);
    int& count = g_detailCounts[key];
    if (count >= limit) return false;  // Saturate instead of overflowing a long-lived counter.
    ++count;
    return true;
  } catch (...) {
    return false;
  }
}

std::string Hr(HRESULT hr) {
  char s[16];
  snprintf(s, sizeof s, "0x%08lx", (unsigned long)hr);
  return s;
}

std::string GuidText(const GUID& g) {
  wchar_t s[64];
  StringFromGUID2(g, s, 64);
  return Utf8(s);
}

std::string Utf8(const wchar_t* s) {
  if (!s) return "";
  int n = WideCharToMultiByte(CP_UTF8, 0, s, -1, nullptr, 0, nullptr, nullptr);
  if (n <= 1) return "";
  std::string out((size_t)n - 1, '\0');
  WideCharToMultiByte(CP_UTF8, 0, s, -1, out.data(), n, nullptr, nullptr);
  return out;
}

std::wstring Widen(const std::string& s) {
  int n = MultiByteToWideChar(CP_UTF8, 0, s.c_str(), -1, nullptr, 0);
  if (n <= 1) return L"";
  std::wstring out((size_t)n - 1, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, s.c_str(), -1, out.data(), n);
  return out;
}

std::string HexBytes(const void* p, size_t n) {
  static const char* digits = "0123456789abcdef";
  std::string s;
  s.reserve(n * 2);
  for (size_t i = 0; i < n; i++) {
    BYTE v = ((const BYTE*)p)[i];
    s += digits[v >> 4];
    s += digits[v & 15];
  }
  return s;
}

std::string FourCC(DWORD v) {
  if (v == BI_RGB) return "BI_RGB";
  if (v == BI_BITFIELDS) return "BI_BITFIELDS";
  char s[5];
  memcpy(s, &v, 4);
  s[4] = 0;
  for (int i = 0; i < 4; i++)
    if (s[i] < 32 || s[i] > 126) return Hr((HRESULT)v);
  return s;
}

std::string JsonEscape(const std::string& s) {
  std::string out;
  for (char ch : s) {
    unsigned char c = (unsigned char)ch;
    if (c == '"' || c == '\\') {
      out += '\\';
      out += ch;
    } else if (c < 0x20) {
      char e[8];
      snprintf(e, sizeof e, "\\u%04x", c);
      out += e;
    } else {
      out += ch;
    }
  }
  return out;
}

std::string ModulePath(HMODULE m) {
  wchar_t path[MAX_PATH] = L"";
  GetModuleFileNameW(m, path, MAX_PATH);
  return Utf8(path);
}

std::string FileVersion(const std::string& path) {
  std::wstring w = Widen(path);
  DWORD handle = 0;
  DWORD size = GetFileVersionInfoSizeW(w.c_str(), &handle);
  if (!size) return "?";
  std::vector<BYTE> data(size);
  if (!GetFileVersionInfoW(w.c_str(), 0, size, data.data())) return "?";
  VS_FIXEDFILEINFO* fi = nullptr;
  UINT len = 0;
  if (!VerQueryValueW(data.data(), L"\\", (void**)&fi, &len) || !fi) return "?";
  char s[64];
  snprintf(s, sizeof s, "%u.%u.%u.%u", HIWORD(fi->dwFileVersionMS), LOWORD(fi->dwFileVersionMS),
           HIWORD(fi->dwFileVersionLS), LOWORD(fi->dwFileVersionLS));
  return s;
}

std::string Sha256File(const std::wstring& path) {
  struct FileHandle {
    HANDLE value;
    ~FileHandle() noexcept { if (value != INVALID_HANDLE_VALUE) CloseHandle(value); }
  } file{CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_DELETE, nullptr,
                     OPEN_EXISTING, FILE_FLAG_SEQUENTIAL_SCAN, nullptr)};
  if (file.value == INVALID_HANDLE_VALUE) return "?";
  struct HashHandles {
    BCRYPT_ALG_HANDLE algorithm = nullptr;
    BCRYPT_HASH_HANDLE hash = nullptr;
    ~HashHandles() noexcept {
      if (hash) BCryptDestroyHash(hash);
      if (algorithm) BCryptCloseAlgorithmProvider(algorithm, 0);
    }
  } handles;
  std::string result = "?";
  if (BCryptOpenAlgorithmProvider(&handles.algorithm, BCRYPT_SHA256_ALGORITHM, nullptr, 0) == 0 &&
      BCryptCreateHash(handles.algorithm, &handles.hash, nullptr, 0, nullptr, 0, 0) == 0) {
    std::vector<BYTE> buf(1 << 20);
    DWORD got = 0;
    for (;;) {
      if (!ReadFile(file.value, buf.data(), (DWORD)buf.size(), &got, nullptr)) return "?";
      if (!got) break;
      if (BCryptHashData(handles.hash, buf.data(), got, 0) != 0) return "?";
    }
    BYTE digest[32];
    if (BCryptFinishHash(handles.hash, digest, 32, 0) == 0) {
      result = HexBytes(digest, 32);
      for (char& ch : result) ch = (char)toupper((unsigned char)ch);
    }
  }
  return result;
}

// Template formatting uses the internal host helper.

static std::string AudioText(const sfio::SFAUDIORECORD& r) {
  if (!r.cbRecord && !r.format && !r.sampleRate) return "empty";
  char s[128];
  snprintf(s, sizeof s, "fmt=0x%lx rate=%lu ch=%u align=%u avg=%lu", r.format, r.sampleRate,
           r.channels, r.blockAlign, r.avgBytesPerSec);
  return s;
}

static std::string BihText(const BITMAPINFOHEADER& h) {
  char s[128];
  snprintf(s, sizeof s, "%ldx%ld bits=%u %s", h.biWidth, h.biHeight, h.biBitCount,
           FourCC(h.biCompression).c_str());
  return s;
}

void LogTemplate(const char* label, const sfio::SFTEMPLATE* t, bool dump) noexcept {
  BestEffortDiagnostic([&] {
    if (!t) {
      Log("  %s: null", label);
      return;
    }
    if (!Tpl::Valid(t)) {
      DWORD cb;
      memcpy(&cb, t, 4);
      Log("  %s: INVALID template @%p cbStruct=%lu", label, (const void*)t, cb);
      return;
    }
    Tpl x = Tpl::Copy(t);
    Log("  %s: @%p cb=%lu ver=0x%08lx id=%lu owner=%s preset=%s", label, (const void*)t,
        x.U32(sfio::tpl::cbStruct), x.U32(sfio::tpl::dwVer), x.U32(sfio::tpl::id),
        GuidText(x.Guid(sfio::tpl::iidOwner)).c_str(), GuidText(x.Guid(sfio::tpl::guidPreset)).c_str());
    Log("    audio render {%s} codec {%s}", AudioText(x.Audio(sfio::tpl::audioRender)).c_str(),
        AudioText(x.Audio(sfio::tpl::audioCodec)).c_str());
    Log("    video render {%s} codec {%s} fps=%.17g par=%.17g cbExtra=%lu name=\"%s\"",
        BihText(x.Bih(sfio::tpl::videoRenderBih)).c_str(),
        BihText(x.Bih(sfio::tpl::videoCodecBih)).c_str(), x.F64(sfio::tpl::vexFps),
        x.F64(sfio::tpl::vexPixelAspect), x.U32(sfio::tpl::cbExtra), Utf8(x.Name().c_str()).c_str());
    if (dump) LogHex("    bytes", x.b.data(), x.b.size());
  });
}

}  // namespace vegas_encoder
