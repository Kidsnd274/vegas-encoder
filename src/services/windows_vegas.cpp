// Read-only installation dashboard. Never loads/executes an inspected file,
// changes registration, installs, repairs or changes security settings.
// Windows API contracts: RegOpenKeyExW/RegEnumKeyExW, GetFileAttributesW,
// GetFileVersionInfoW/VerQueryValueW; see docs/product/CONTRACTS.md.
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <bcrypt.h>
#include <algorithm>
#include <cstdint>
#include <cstring>
#include <filesystem>
#include <map>
#include <set>
#include <string>
#include <vector>
#include "../core/third_party/nlohmann/json.hpp"

namespace {
using Json = nlohmann::ordered_json;
namespace fs = std::filesystem;
std::string Utf8(const std::wstring& text) {
  if (text.empty()) return {};
  const auto n = WideCharToMultiByte(CP_UTF8,WC_ERR_INVALID_CHARS,text.data(),static_cast<int>(text.size()),nullptr,0,nullptr,nullptr);
  if (n <= 0) throw std::runtime_error("Invalid UTF-16 text");
  std::string out(static_cast<size_t>(n),'\0');
  if (!WideCharToMultiByte(CP_UTF8,WC_ERR_INVALID_CHARS,text.data(),static_cast<int>(text.size()),out.data(),n,nullptr,nullptr)) throw std::runtime_error("Cannot encode UTF-16 text");
  return out;
}
std::wstring Wide(const std::string& text) {
  if (text.empty()) return {};
  if (text.size() > 32700 || text.find('\0') != std::string::npos) throw std::runtime_error("Invalid path length or NUL");
  const auto n = MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,text.data(),static_cast<int>(text.size()),nullptr,0);
  if (n <= 0) throw std::runtime_error("Invalid UTF-8 path");
  std::wstring out(static_cast<size_t>(n),L'\0');
  if (!MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,text.data(),static_cast<int>(text.size()),out.data(),n)) throw std::runtime_error("Cannot decode path");
  return out;
}
[[noreturn]] void Error(const char* operation, const std::wstring& path, DWORD code = GetLastError()) {
  throw std::runtime_error(std::string(operation) + " (Windows error " + std::to_string(code) + "): " + Utf8(path));
}
struct Less { bool operator()(const std::wstring& a, const std::wstring& b) const { return _wcsicmp(a.c_str(),b.c_str()) < 0; } };
std::wstring Clean(std::wstring path) {
  std::replace(path.begin(),path.end(),L'/',L'\\');
  while (path.size() > 3 && path.back() == L'\\') path.pop_back();
  return path;
}
std::wstring Full(std::wstring path) {
  if (path.size() > 1 && path.front() == L'"' && path.back() == L'"') path = path.substr(1,path.size()-2);
  if (!fs::path(path).is_absolute()) Error("Not an absolute path",path,ERROR_BAD_PATHNAME);
  std::vector<wchar_t> out(32768);
  const auto count = GetFullPathNameW(path.c_str(),static_cast<DWORD>(out.size()),out.data(),nullptr);
  if (!count || count >= out.size()) Error("Cannot resolve directory",path);
  return Clean(std::wstring(out.data(),count));
}
DWORD Attributes(const std::wstring& path) {
  const auto a = GetFileAttributesW(path.c_str());
  if (a == INVALID_FILE_ATTRIBUTES) {
    const auto code = GetLastError();
    if (code != ERROR_FILE_NOT_FOUND && code != ERROR_PATH_NOT_FOUND) Error("Cannot inspect path",path,code);
  }
  return a;
}
void Plain(const std::wstring& path) {
  auto cursor = fs::path(path);
  for (;;) {
    const auto a = Attributes(cursor.wstring());
    if (a != INVALID_FILE_ATTRIBUTES && (a & FILE_ATTRIBUTE_REPARSE_POINT)) Error("Cannot verify a link or junction",cursor.wstring(),ERROR_REPARSE_TAG_INVALID);
    const auto parent = cursor.parent_path();
    if (parent.empty() || parent == cursor) break;
    cursor = parent;
  }
}
bool FileExists(const std::wstring& path) {
  Plain(path);
  const auto a = Attributes(path);
  if (a == INVALID_FILE_ATTRIBUTES) return false;
  if (a & FILE_ATTRIBUTE_DIRECTORY) Error("Expected a file",path,ERROR_DIRECTORY);
  return true;
}
struct File {
  HANDLE handle = INVALID_HANDLE_VALUE;
  explicit File(const std::wstring& path) {
    Plain(path);
    handle = CreateFileW(path.c_str(),GENERIC_READ,FILE_SHARE_READ,nullptr,OPEN_EXISTING,FILE_FLAG_OPEN_REPARSE_POINT | FILE_FLAG_SEQUENTIAL_SCAN,nullptr);
    if (handle == INVALID_HANDLE_VALUE) Error("Cannot read file",path);
    BY_HANDLE_FILE_INFORMATION info{};
    if (!GetFileInformationByHandle(handle,&info) || (info.dwFileAttributes & (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT))) {
      const auto code = GetLastError(); CloseHandle(handle); handle = INVALID_HANDLE_VALUE;
      Error("Cannot inspect regular file",path,code);
    }
  }
  ~File() { if (handle != INVALID_HANDLE_VALUE) CloseHandle(handle); }
  File(const File&) = delete;
  File& operator=(const File&) = delete;
  uint64_t Size() const { LARGE_INTEGER n{}; if (!GetFileSizeEx(handle,&n) || n.QuadPart < 0) throw std::runtime_error("Cannot read file size"); return static_cast<uint64_t>(n.QuadPart); }
};
std::string Read(const std::wstring& path, DWORD limit) {
  File file(path);
  if (file.Size() > limit) Error("File exceeds inspection size limit",path,ERROR_FILE_TOO_LARGE);
  std::string bytes(static_cast<size_t>(file.Size()),'\0'); DWORD count = 0;
  if (!ReadFile(file.handle,bytes.data(),static_cast<DWORD>(bytes.size()),&count,nullptr) || count != bytes.size()) Error("Cannot read complete file",path);
  return bytes;
}
std::vector<std::wstring> Entries(const std::wstring& path, const wchar_t* pattern, size_t limit) {
  Plain(path);
  WIN32_FIND_DATAW data{};
  const auto search = FindFirstFileW((path + L"\\" + pattern).c_str(),&data);
  if (search == INVALID_HANDLE_VALUE) {
    const auto code = GetLastError();
    if (code == ERROR_FILE_NOT_FOUND) return {};
    Error("Cannot enumerate directory",path,code);
  }
  struct Close { HANDLE h; ~Close() { FindClose(h); } } close{search};
  std::vector<std::wstring> result;
  do {
    const std::wstring name(data.cFileName);
    if (name == L"." || name == L"..") continue;
    if (result.size() == limit) Error("Directory inspection limit exceeded",path,ERROR_MORE_DATA);
    result.push_back(name);
  } while (FindNextFileW(search,&data));
  if (GetLastError() != ERROR_NO_MORE_FILES) Error("Cannot finish directory enumeration",path);
  std::sort(result.begin(),result.end(),Less{});
  return result;
}
bool HostName(const std::wstring& name) {
  if (name.size() < 10 || _wcsnicmp(name.c_str(),L"vegas",5) || _wcsicmp(name.c_str()+name.size()-4,L".exe")) return false;
  return std::all_of(name.begin()+5,name.end()-4,[](wchar_t c) { return c >= L'0' && c <= L'9'; });
}
bool X64(const std::wstring& path) {
  File f(path); uint8_t head[64]{}; DWORD n = 0;
  if (!ReadFile(f.handle,head,sizeof head,&n,nullptr) || n != sizeof head || head[0] != 'M' || head[1] != 'Z') Error("Not a PE executable",path,ERROR_BAD_EXE_FORMAT);
  uint32_t offset = 0; memcpy(&offset,head+0x3c,sizeof offset);
  if (offset < 64 || static_cast<uint64_t>(offset)+6 > f.Size()) Error("Invalid PE header",path,ERROR_BAD_EXE_FORMAT);
  LARGE_INTEGER pos{}; pos.QuadPart = offset;
  uint8_t pe[6]{};
  if (!SetFilePointerEx(f.handle,pos,nullptr,FILE_BEGIN) || !ReadFile(f.handle,pe,sizeof pe,&n,nullptr) || n != sizeof pe || memcmp(pe,"PE\0\0",4)) Error("Invalid PE signature",path,ERROR_BAD_EXE_FORMAT);
  return pe[4] == 0x64 && pe[5] == 0x86;
}
struct Version { std::string name, version; };
Version FileVersion(const std::wstring& path) {
  DWORD ignored = 0; const auto size = GetFileVersionInfoSizeW(path.c_str(),&ignored);
  if (!size) {
    const auto code = GetLastError();
    if (code == ERROR_RESOURCE_DATA_NOT_FOUND || code == ERROR_RESOURCE_TYPE_NOT_FOUND || code == ERROR_RESOURCE_NAME_NOT_FOUND) return {};
    Error("Cannot read file version",path,code);
  }
  if (size > 1048576) Error("Version resource exceeds inspection limit",path,ERROR_MORE_DATA);
  std::vector<uint8_t> data(size);
  if (!GetFileVersionInfoW(path.c_str(),0,size,data.data())) Error("Cannot read file version",path);
  Version result;
  struct Translation { WORD language, page; };
  Translation* translations = nullptr; UINT bytes = 0;
  if (VerQueryValueW(data.data(),L"\\VarFileInfo\\Translation",reinterpret_cast<void**>(&translations),&bytes)) {
    for (UINT i = 0; i < bytes / sizeof(Translation); ++i) {
      for (const auto field : {L"ProductName",L"FileVersion"}) {
        wchar_t key[100]{}; swprintf_s(key,L"\\StringFileInfo\\%04x%04x\\%s",translations[i].language,translations[i].page,field);
        wchar_t* value = nullptr; UINT length = 0;
        if (VerQueryValueW(data.data(),key,reinterpret_cast<void**>(&value),&length) && value && length && value[length-1] == L'\0') {
          auto& target = wcscmp(field,L"ProductName") == 0 ? result.name : result.version;
          if (target.empty()) target = Utf8(std::wstring(value,length-1));
        }
      }
    }
  }
  VS_FIXEDFILEINFO* fixed = nullptr; UINT length = 0;
  if (result.version.empty() && VerQueryValueW(data.data(),L"\\",reinterpret_cast<void**>(&fixed),&length) && length >= sizeof *fixed && fixed->dwSignature == 0xfeef04bd) {
    result.version = std::to_string(HIWORD(fixed->dwFileVersionMS))+"."+std::to_string(LOWORD(fixed->dwFileVersionMS))+"."+
      std::to_string(HIWORD(fixed->dwFileVersionLS))+"."+std::to_string(LOWORD(fixed->dwFileVersionLS));
  }
  return result;
}
struct Budget {
  ULONGLONG deadline = GetTickCount64()+30000;
  uint64_t bytes = 0;
  void Check() const { if (GetTickCount64() >= deadline) throw std::runtime_error("Installation inspection exceeded 30 seconds; refresh to retry."); }
};
std::string Hash(const std::wstring& path, Budget& budget) {
  if (!FileExists(path)) return {};
  File file(path);
  const auto size = file.Size(); budget.bytes += size;
  if (size > 536870912 || budget.bytes > 1073741824) Error("Hash inspection size limit exceeded",path,ERROR_FILE_TOO_LARGE);
  struct Crypto {
    BCRYPT_ALG_HANDLE algorithm = nullptr; BCRYPT_HASH_HANDLE hash = nullptr;
    ~Crypto() { if (hash) BCryptDestroyHash(hash); if (algorithm) BCryptCloseAlgorithmProvider(algorithm,0); }
  } crypto;
  if (BCryptOpenAlgorithmProvider(&crypto.algorithm,BCRYPT_SHA256_ALGORITHM,nullptr,0) < 0 || BCryptCreateHash(crypto.algorithm,&crypto.hash,nullptr,0,nullptr,0,0) < 0) throw std::runtime_error("Cannot initialize SHA-256");
  std::vector<uint8_t> block(65536); DWORD count = 0;
  for (;;) {
    budget.Check();
    if (!ReadFile(file.handle,block.data(),static_cast<DWORD>(block.size()),&count,nullptr)) Error("Cannot hash file",path);
    if (!count) break;
    if (BCryptHashData(crypto.hash,block.data(),count,0) < 0) throw std::runtime_error("Cannot hash installed file");
  }
  uint8_t digest[32]{};
  if (BCryptFinishHash(crypto.hash,digest,sizeof digest,0) < 0) throw std::runtime_error("Cannot finish SHA-256");
  constexpr char hex[] = "0123456789abcdef"; std::string result;
  for (const auto byte : digest) { result += hex[byte >> 4]; result += hex[byte & 15]; }
  return result;
}
bool SamePath(const Json& value, const std::wstring& expected) {
  return value.is_string() && _wcsicmp(Clean(Wide(value.get<std::string>())).c_str(),expected.c_str()) == 0;
}
bool Digest(const Json& value) {
  if (!value.is_string()) return false;
  const auto s = value.get<std::string>();
  return s.size() == 64 && std::all_of(s.begin(),s.end(),[](char c) { return (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F'); });
}
bool SameHash(const std::string& hash, const Json& expected) { return !hash.empty() && _stricmp(hash.c_str(),expected.get<std::string>().c_str()) == 0; }
void Inspect(Json& row, const std::wstring& root, Budget& budget) {
  const auto plugin = root+L"\\FileIO Plug-Ins\\vegas-encoder";
  const auto dll = plugin+L"\\vegas-encoder.dll", ini = plugin+L"\\vegas-encoder.ini";
  const auto config = root+L"\\VegasEncoder-x64.fio2007-config", manifest = plugin+L"\\install-manifest.json";
  const bool hasDll = FileExists(dll), hasIni = FileExists(ini), hasConfig = FileExists(config), hasManifest = FileExists(manifest);
  const auto attributes = Attributes(plugin);
  const auto items = attributes == INVALID_FILE_ATTRIBUTES ? std::vector<std::wstring>{} : Entries(plugin,L"*",32);
  auto& details = row["details"];
  if (!hasDll && !hasIni && !hasConfig && !hasManifest && items.empty()) {
    row["state"] = "notInstalled"; details.push_back("No exporter or discovery files were found."); return;
  }
  if (hasDll) {
    const auto version = FileVersion(dll).version;
    if (version.empty()) details.push_back("The exporter file has no readable version resource.");
    else row["exporterVersion"] = version;
  }
  for (const auto& entry : {std::make_pair(hasDll,dll),std::make_pair(hasIni,ini),std::make_pair(hasConfig,config)}) {
    if (!entry.first) { row["state"] = "changed"; details.push_back("Missing file: "+Utf8(entry.second)); }
  }
  if (!hasManifest) { details.push_back("No supported installed manifest; file integrity is unknown."); return; }
  const auto text = Read(manifest,1048576);
  // nlohmann accepts the UTF-8 BOM used by older development manifests.
  const auto m = Json::parse(text);
  if (!m.is_object()) throw std::runtime_error("Installed manifest must be a JSON object: "+Utf8(manifest));
  if (m.value("schema",Json()) != "vegas-encoder-install/1") { details.push_back("Unsupported installed manifest schema: "+m.value("schema",Json()).dump()); return; }
  const auto records = m.value("files",Json());
  bool valid = m.value("product",Json()) == "Vegas Encoder" && SamePath(m.value("vegasDir",Json()),root) &&
    SamePath(m.value("pluginDir",Json()),plugin) && SamePath(m.value("config",Json()),config) && Digest(m.value("configSha256",Json())) &&
    records.is_array() && records.size() >= 2 && records.size() <= 3;
  std::map<std::wstring,Json,Less> known;
  if (records.is_array() && records.size() <= 3) for (const auto& record : records) {
    if (!record.is_object() || !record.value("file",Json()).is_string()) { valid = false; continue; }
    const auto name = fs::path(Wide(record.at("file").get<std::string>())).filename().wstring();
    const bool allowed = _wcsicmp(name.c_str(),L"vegas-encoder.dll") == 0 || _wcsicmp(name.c_str(),L"vegas-encoder.ini") == 0 || _wcsicmp(name.c_str(),L"vegas-encoder.pdb") == 0;
    if (!allowed || !SamePath(record.at("file"),plugin+L"\\"+name) || !Digest(record.value("sha256",Json())) || known.count(name)) valid = false;
    known[name] = record.value("sha256",Json());
  }
  if (!known.count(L"vegas-encoder.dll") || !known.count(L"vegas-encoder.ini")) valid = false;
  if (!valid) { details.push_back("Installed manifest has invalid identity, paths or file coverage; no hashes were trusted."); return; }
  for (const auto& entry : known) {
    const auto path = plugin+L"\\"+entry.first;
    if (!SameHash(Hash(path,budget),entry.second)) { row["state"] = "changed"; details.push_back("Missing or changed recorded file: "+Utf8(path)); }
  }
  if (!SameHash(Hash(config,budget),m.at("configSha256"))) { row["state"] = "changed"; details.push_back("Missing or changed discovery file: "+Utf8(config)); }
  for (const auto& name : items) {
    const auto path = plugin+L"\\"+name; Plain(path);
    if (_wcsicmp(name.c_str(),L"install-manifest.json") && (!known.count(name) || (Attributes(path) & FILE_ATTRIBUTE_DIRECTORY))) {
      row["state"] = "changed"; details.push_back("Unrecorded item: "+Utf8(path));
    }
  }
  if (row["state"] != "changed") { row["state"] = "verified"; details.push_back("Recorded exporter, INI and discovery bytes match the installed manifest (SHA-256)."); }
}
struct Key { HKEY value = nullptr; ~Key() { if (value) RegCloseKey(value); } };
std::wstring RegString(HKEY key, const wchar_t* name) {
  DWORD type = 0, size = 0;
  auto code = RegQueryValueExW(key,name,nullptr,&type,nullptr,&size);
  if (code == ERROR_FILE_NOT_FOUND) return {};
  if (code != ERROR_SUCCESS) Error("Cannot read registry value",name,code);
  if ((type != REG_SZ && type != REG_EXPAND_SZ) || size > 65536 || size % sizeof(wchar_t)) Error("Unsupported registry path value",name,ERROR_INVALID_DATA);
  std::vector<wchar_t> text(size/sizeof(wchar_t)+1,L'\0');
  code = RegQueryValueExW(key,name,nullptr,&type,reinterpret_cast<BYTE*>(text.data()),&size);
  if (code != ERROR_SUCCESS) Error("Cannot read registry value",name,code);
  std::wstring result(text.data());
  if (type == REG_EXPAND_SZ) {
    std::vector<wchar_t> expanded(32768); const auto count = ExpandEnvironmentStringsW(result.c_str(),expanded.data(),static_cast<DWORD>(expanded.size()));
    if (!count || count > expanded.size()) Error("Cannot expand registry path",name);
    result = expanded.data();
  }
  return result;
}
Json Snapshot(const Json& options) {
  std::set<std::wstring,Less> dirs;
  Json result{{"schema","vegas-installation-status/1"},{"hosts",Json::array()},{"errors",Json::array()}};
  auto& errors = result["errors"]; Budget budget;
  auto add = [&](const std::wstring& path) {
    if (path.empty()) return;
    if (dirs.size() >= 128) throw std::runtime_error("VEGAS discovery exceeded 128 candidate directories.");
    dirs.insert(Full(path));
  };
  for (const auto& path : options.at("directories")) try { add(Wide(path.get<std::string>())); } catch (const std::exception& e) { errors.push_back(e.what()); }
  if (options.at("registry").get<bool>()) for (const auto hive : {HKEY_LOCAL_MACHINE,HKEY_CURRENT_USER}) for (const auto view : {KEY_WOW64_64KEY,KEY_WOW64_32KEY}) {
    for (const auto kind : {L"Uninstall",L"App Paths"}) {
      const auto location = std::wstring(L"Software\\Microsoft\\Windows\\CurrentVersion\\")+kind;
      try {
        Key key; auto code = RegOpenKeyExW(hive,location.c_str(),0,KEY_READ | view,&key.value);
        if (code == ERROR_FILE_NOT_FOUND || code == ERROR_PATH_NOT_FOUND) continue;
        if (code != ERROR_SUCCESS) Error("Cannot open registry key",location,code);
        for (DWORD index = 0;; ++index) {
          budget.Check(); wchar_t name[256]{}; DWORD size = 256;
          code = RegEnumKeyExW(key.value,index,name,&size,nullptr,nullptr,nullptr,nullptr);
          if (code == ERROR_NO_MORE_ITEMS) break;
          if (code != ERROR_SUCCESS || index >= 16384) Error("Cannot enumerate registry key",location,code == ERROR_SUCCESS ? ERROR_MORE_DATA : code);
          const bool appPath = wcscmp(kind,L"App Paths") == 0;
          if (appPath && !HostName(name)) continue;
          try {
            Key entry; code = RegOpenKeyExW(key.value,name,0,KEY_READ | view,&entry.value);
            if (code != ERROR_SUCCESS) Error("Cannot open registry entry",location+L"\\"+name,code);
            if (appPath) {
              auto exe = RegString(entry.value,L"");
              if (exe.size() > 1 && exe.front() == L'"' && exe.back() == L'"') exe = exe.substr(1,exe.size()-2);
              if (!exe.empty()) add(fs::path(exe).parent_path().wstring());
            } else {
              auto display = RegString(entry.value,L"DisplayName");
              std::transform(display.begin(),display.end(),display.begin(),[](wchar_t c) { return static_cast<wchar_t>(towlower(c)); });
              const auto vegas = display.find(L"vegas"), pro = display.find(L"pro",vegas == std::wstring::npos ? 0 : vegas+5);
              if (vegas != std::wstring::npos && pro != std::wstring::npos) add(RegString(entry.value,L"InstallLocation"));
            }
          } catch (const std::exception& e) { errors.push_back(e.what()); }
        }
      } catch (const std::exception& e) { errors.push_back(e.what()); }
    }
  }
  for (const auto& root : dirs) try {
    budget.Check(); bool found = false;
    for (const auto& name : Entries(root,L"vegas*.exe",256)) {
      if (!HostName(name)) continue;
      found = true; const auto exe = root+L"\\"+name, plugin = root+L"\\FileIO Plug-Ins\\vegas-encoder";
      if (result["hosts"].size() >= 64) throw std::runtime_error("VEGAS discovery exceeded 64 hosts.");
      Json row{{"name","VEGAS Pro"},{"version","Unknown"},{"executable",Utf8(exe)},{"x64",false},
        {"exporterPath",Utf8(plugin+L"\\vegas-encoder.dll")},{"discoveryPath",Utf8(root+L"\\VegasEncoder-x64.fio2007-config")},
        {"manifestPath",Utf8(plugin+L"\\install-manifest.json")},{"exporterVersion",nullptr},{"state","unverified"},{"details",Json::array()}};
      try {
        row["x64"] = X64(exe); const auto version = FileVersion(exe);
        if (!version.name.empty()) row["name"] = version.name;
        if (!version.version.empty()) row["version"] = version.version;
        Inspect(row,root,budget);
      } catch (const std::exception& e) { row["state"] = "unreadable"; row["details"].push_back(e.what()); }
      result["hosts"].push_back(std::move(row));
    }
    if (!found) errors.push_back("No VEGAS executable found in registered/candidate directory: "+Utf8(root));
  } catch (const std::exception& e) { errors.push_back(e.what()); }
  return result;
}
}
// A bounded, counted UTF-8 JSON ABI. Dart calls on a worker isolate. All handles
// close before return; missing paths differ from denied/failed inspection.
extern "C" __declspec(dllexport) int32_t ve_vegas_installations(const uint8_t* input, uint32_t length, uint8_t* output, uint32_t capacity) noexcept {
  if (!input || !length || length > 65536 || !output || !capacity || capacity > 1048576) return -1;
  try {
    const auto options = Json::parse(input,input+length);
    if (!options.is_object() || !options.contains("directories") || !options.at("directories").is_array() || options.at("directories").size() > 128 || !options.contains("registry") || !options.at("registry").is_boolean()) return -1;
    const auto encoded = Snapshot(options).dump();
    if (encoded.size() > capacity) return -2;
    memcpy(output,encoded.data(),encoded.size()); return static_cast<int32_t>(encoded.size());
  } catch (...) { return -3; }
}
