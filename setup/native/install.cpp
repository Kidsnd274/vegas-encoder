// Installer-only Windows helper. No app/core dependency; never runs FFmpeg or VEGAS.
// JSON uses the project's existing nlohmann/json (MIT; notice ships with the app).
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <bcrypt.h>
#include <sddl.h>
#include <shlobj.h>
#include <tlhelp32.h>
#include <algorithm>
#include <filesystem>
#include <fstream>
#include <map>
#include <set>
#include <sstream>
#include <vector>
#ifdef VE_SETUP_TESTING
#include <process.h>
#endif
#include "../../src/core/third_party/nlohmann/json.hpp"
namespace fs = std::filesystem;
using J = nlohmann::ordered_json;
static fs::path testRoot;
static std::wstring wide(const std::string& s) { return fs::u8path(s).wstring(); }
static std::string utf(const fs::path& p) { return p.u8string(); }
static std::wstring lower(std::wstring s) { for (auto& c : s) c = static_cast<wchar_t>(towlower(c)); return s; }
static void need(bool ok, const std::string& message) { if (!ok) throw std::runtime_error(message); }
static bool same(const fs::path& a, const fs::path& b) { return lower(a.lexically_normal().wstring()) == lower(b.lexically_normal().wstring()); }
static bool inside(const fs::path& p, const fs::path& root) {
  auto a = lower(p.lexically_normal().wstring()), b = lower(root.lexically_normal().wstring());
  if (b.back() != L'\\') b += L'\\';
  return a.size() > b.size() && a.compare(0, b.size(), b) == 0;
}
static fs::path plain(fs::path p) {
  need(p.is_absolute() && p.has_root_name(), "Choose an absolute local drive path.");
  while (p.filename().empty() && p != p.root_path()) p = p.parent_path();
  auto s = p.wstring();
  need(s.size() > 3 && s[1] == L':' && s[2] == L'\\' && s.find(L':', 2) == s.npos, "Local drive paths only.");
  for (auto c : s) need(c >= 32 && c != L'"', "Control characters are not allowed in setup paths.");
  for (const auto& part : p.relative_path()) { auto n = part.wstring(); need(n != L".." && n != L"." && !n.empty() && n.back() != L'.' && n.back() != L' ', "Ambiguous setup path."); }
  p = p.lexically_normal();
  while (p.filename().empty()) p = p.parent_path();
  for (auto c = p; !c.empty(); c = c.parent_path()) {
    DWORD attr = GetFileAttributesW(c.c_str());
    need(attr == INVALID_FILE_ATTRIBUTES || !(attr & FILE_ATTRIBUTE_REPARSE_POINT), "Reparse points are not supported: " + utf(c));
    if (c == c.parent_path()) break;
  }
#ifdef VE_SETUP_TESTING
  need(!testRoot.empty() && (same(p, testRoot) || inside(p, testRoot)), "Test helper is confined to its fixture root.");
#endif
  return p;
}
static fs::path relative(const std::string& value) {
  auto p = fs::u8path(value);
  need(!value.empty() && !p.is_absolute() && !p.has_root_name() && value.find(':') == value.npos, "Invalid owned relative path.");
  for (const auto& part : p) need(part != ".." && part != "." && !part.empty(), "Escaping owned path.");
  return p;
}
static std::string read(const fs::path& p) {
  std::ifstream f(p, std::ios::binary); need(bool(f), "Cannot read " + utf(p));
  return {std::istreambuf_iterator<char>(f), {}};
}
static J json(const fs::path& p) { return J::parse(read(p)); }
static void write(const fs::path& p, const std::string& s) {
  plain(p); fs::create_directories(p.parent_path());
  auto tmp = p; tmp += L".ve-setup-new";
  need(!fs::exists(tmp), "A previous temporary file needs review: " + utf(tmp));
  { std::ofstream f(tmp, std::ios::binary); need(bool(f), "Cannot write " + utf(tmp)); f.write(s.data(), static_cast<std::streamsize>(s.size())); f.close(); need(bool(f), "Write failed: " + utf(tmp)); }
  need(MoveFileExW(tmp.c_str(), p.c_str(), MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH) != 0, "Cannot replace " + utf(p));
}
static std::string hash(const fs::path& p) {
  BCRYPT_ALG_HANDLE alg = nullptr; BCRYPT_HASH_HANDLE h = nullptr;
  need(BCryptOpenAlgorithmProvider(&alg, BCRYPT_SHA256_ALGORITHM, nullptr, 0) == 0, "SHA-256 unavailable.");
  std::string result;
  try {
    need(BCryptCreateHash(alg, &h, nullptr, 0, nullptr, 0, 0) == 0, "SHA-256 initialization failed.");
    std::ifstream f(p, std::ios::binary); need(bool(f), "Cannot hash " + utf(p)); char buffer[65536];
    while (f.read(buffer, sizeof buffer) || f.gcount()) need(BCryptHashData(h, reinterpret_cast<PUCHAR>(buffer), static_cast<ULONG>(f.gcount()), 0) == 0, "SHA-256 failed.");
    need(f.eof(), "Read failed: " + utf(p)); unsigned char digest[32];
    need(BCryptFinishHash(h, digest, sizeof digest, 0) == 0, "SHA-256 failed.");
    constexpr char hex[] = "0123456789ABCDEF";
    for (auto c : digest) { result += hex[c >> 4]; result += hex[c & 15]; }
  } catch (...) { if (h) BCryptDestroyHash(h); BCryptCloseAlgorithmProvider(alg, 0); throw; }
  BCryptDestroyHash(h); BCryptCloseAlgorithmProvider(alg, 0); return result;
}
static void matches(const fs::path& p, const J& sha) {
  plain(p); need(fs::is_regular_file(p) && hash(p) == sha.get<std::string>(), "File is missing or does not match this setup: " + utf(p));
}
static std::wstring ini(const fs::path& file, const std::wstring& key) {
  wchar_t buf[32768]; GetPrivateProfileStringW(L"setup", key.c_str(), L"", buf, 32768, file.c_str()); return buf;
}
static void put(const fs::path& file, const std::wstring& key, const std::wstring& value) { WritePrivateProfileStringW(L"setup", key.c_str(), value.c_str(), file.c_str()); }
static fs::path rootData() {
#ifdef VE_SETUP_TESTING
  return plain(testRoot / "transactions");
#else
  PWSTR raw = nullptr; need(SUCCEEDED(SHGetKnownFolderPath(FOLDERID_ProgramData, 0, nullptr, &raw)), "Cannot locate ProgramData.");
  fs::path p = fs::path(raw) / "VegasEncoder" / "Setup"; CoTaskMemFree(raw); return plain(p);
#endif
}
static void secureRoot() {
  auto p = rootData(); fs::create_directories(p);
  auto catalog = plain(p.parent_path() / "Installations"); fs::create_directories(catalog);
#ifndef VE_SETUP_TESTING
  PSECURITY_DESCRIPTOR sd = nullptr;
  need(ConvertStringSecurityDescriptorToSecurityDescriptorW(L"O:BAG:BAD:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)", SDDL_REVISION_1, &sd, nullptr) != 0, "Cannot secure rollback directory.");
  // Secure the product namespace too, so an unprivileged pre-created parent
  // cannot rename the protected Setup directory via DELETE_CHILD permission.
  BOOL ok = SetFileSecurityW(p.parent_path().c_str(), OWNER_SECURITY_INFORMATION | GROUP_SECURITY_INFORMATION | DACL_SECURITY_INFORMATION | PROTECTED_DACL_SECURITY_INFORMATION, sd);
  if (ok) ok = SetFileSecurityW(p.c_str(), OWNER_SECURITY_INFORMATION | GROUP_SECURITY_INFORMATION | DACL_SECURITY_INFORMATION | PROTECTED_DACL_SECURITY_INFORMATION, sd);
  if (ok) ok = SetFileSecurityW(catalog.c_str(), OWNER_SECURITY_INFORMATION | GROUP_SECURITY_INFORMATION | DACL_SECURITY_INFORMATION | PROTECTED_DACL_SECURITY_INFORMATION, sd);
  LocalFree(sd);
  need(ok != 0, "Cannot secure rollback directory. Run Setup as administrator.");
#endif
}
// VEGAS executables are vegas<digits>.exe: vegas2026.exe, vegas230.exe (VEGAS Pro 23).
static bool hostExe(const std::wstring& name) {
  auto n = lower(name);
  if (n.size() < 10 || n.compare(0, 5, L"vegas") || n.compare(n.size() - 4, 4, L".exe")) return false;
  return std::all_of(n.begin() + 5, n.end() - 4, [](wchar_t c) { return c >= L'0' && c <= L'9'; });
}
static std::string label(const std::string& family) { return "VEGAS Pro " + family.substr(5); }
static std::wstring friendly(const std::wstring& exe) {
  auto n = lower(exe);
  if (n == L"vegasencoder.exe") return L"Vegas Encoder";
  if (!hostExe(n)) return exe;
  auto digits = n.substr(5, n.size() - 9); if (digits.size() == 3) digits.pop_back();
  return L"VEGAS Pro " + digits;
}
static std::vector<std::wstring> running(const std::vector<fs::path>& roots) {
  HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0); need(snapshot != INVALID_HANDLE_VALUE, "Cannot inspect running processes.");
  PROCESSENTRY32W e{}; e.dwSize = sizeof e; std::set<std::wstring> busy;
  std::map<DWORD, DWORD> parents; std::set<DWORD> ancestors;
  if (Process32FirstW(snapshot, &e)) do { parents[e.th32ProcessID] = e.th32ParentProcessID; } while (Process32NextW(snapshot, &e));
  for (DWORD pid = GetCurrentProcessId(); parents.count(pid) && ancestors.size() < 32;) { pid = parents[pid]; if (!pid || !ancestors.insert(pid).second) break; }
  if (Process32FirstW(snapshot, &e)) do {
    if (e.th32ProcessID == GetCurrentProcessId()) continue;
    auto name = lower(e.szExeFile);
    // Inno may launch a temporary copy of itself. Its original uninstaller is
    // still an ancestor inside {app}; other processes there must remain closed.
    if (ancestors.count(e.th32ProcessID) && name.size() == 12 && name.substr(0, 5) == L"unins" && name.substr(8) == L".exe" && iswdigit(name[5]) && iswdigit(name[6]) && iswdigit(name[7])) continue;
    HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, e.th32ProcessID);
    wchar_t path[32768]; DWORD len = 32768;
    if (process) {
      if (QueryFullProcessImageNameW(process, 0, path, &len)) for (auto& r : roots) if (inside(path, r)) busy.insert(friendly(e.szExeFile));
      CloseHandle(process);
    } else if (hostExe(name) || name == L"vegasencoder.exe") busy.insert(friendly(e.szExeFile));
  } while (Process32NextW(snapshot, &e));
  CloseHandle(snapshot); return {busy.begin(), busy.end()};
}
static std::wstring joined(const std::vector<std::wstring>& items) { std::wstring s; for (auto& i : items) s += (s.empty() ? L"" : L", ") + i; return s; }
static void closed(const std::vector<fs::path>& roots) {
  auto busy = running(roots); need(busy.empty(), "Close these programs, then try again: " + utf(fs::path(joined(busy))));
}
// One VEGAS installation. The family (vegas2026, vegas23) comes from the file version, never the folder name.
struct Host { fs::path dir, exe; std::string family, version; };
static Host probe(const fs::path& path) {
  Host h; h.exe = plain(path); h.dir = h.exe.parent_path(); need(fs::is_regular_file(h.exe), "Missing VEGAS executable: " + utf(h.exe));
#ifdef VE_SETUP_TESTING
  auto digits = lower(h.exe.filename().wstring()); digits = digits.substr(5, digits.size() - 9); if (digits.size() == 3) digits.pop_back();
  h.family = "vegas" + utf(fs::path(digits)); h.version = h.family.substr(5) + ".0.3.189";
#else
  std::ifstream file(h.exe, std::ios::binary); IMAGE_DOS_HEADER dos{}; file.read(reinterpret_cast<char*>(&dos), sizeof dos);
  need(file && dos.e_magic == IMAGE_DOS_SIGNATURE && dos.e_lfanew >= sizeof dos, "Invalid VEGAS executable.");
  file.seekg(dos.e_lfanew); DWORD signature = 0; IMAGE_FILE_HEADER pe{}; file.read(reinterpret_cast<char*>(&signature), sizeof signature); file.read(reinterpret_cast<char*>(&pe), sizeof pe);
  need(file && signature == IMAGE_NT_SIGNATURE && pe.Machine == IMAGE_FILE_MACHINE_AMD64, "VEGAS must be Windows x64.");
  DWORD unused = 0; auto size = GetFileVersionInfoSizeW(h.exe.c_str(), &unused); need(size > 0, "Cannot read VEGAS version.");
  std::vector<unsigned char> data(size); need(GetFileVersionInfoW(h.exe.c_str(), 0, size, data.data()) != 0, "Cannot read VEGAS version.");
  VS_FIXEDFILEINFO* info = nullptr; UINT bytes = 0;
  need(VerQueryValueW(data.data(), L"\\", reinterpret_cast<void**>(&info), &bytes) && bytes >= sizeof(*info), "Cannot read VEGAS version.");
  h.family = "vegas" + std::to_string(HIWORD(info->dwFileVersionMS));
  h.version = std::to_string(HIWORD(info->dwFileVersionMS)) + "." + std::to_string(LOWORD(info->dwFileVersionMS)) + "." + std::to_string(HIWORD(info->dwFileVersionLS)) + "." + std::to_string(LOWORD(info->dwFileVersionLS));
#endif
  return h;
}
static std::vector<Host> hostsIn(const fs::path& dir) {
  std::vector<Host> result; std::error_code error;
  for (fs::directory_iterator it(dir, error), end; !error && it != end; it.increment(error))
    if (hostExe(it->path().filename().wstring())) try { result.push_back(probe(it->path())); } catch (...) {}
  return result;
}
// This bundle carries a core only for these families; other detected versions are listed as unsupported.
static bool supported(const std::string& family) { return family == "vegas2026"; }
static Host hostFor(const fs::path& dir, const std::string& family) {
  need(supported(family), label(family) + " is not supported by this release.");
  for (auto& h : hostsIn(plain(dir))) if (h.family == family) return h;
  throw std::runtime_error("Select the " + label(family) + " folder. No " + label(family) + " executable was found in " + utf(dir) + ".");
}
static fs::path plugin(const fs::path& host) { return host / "FileIO Plug-Ins" / "vegas-encoder"; }
static fs::path config(const fs::path& host) { return host / "VegasEncoder-x64.fio2007-config"; }
static fs::path appManifest(const fs::path& app) { return app / "vegas-encoder-setup.json"; }
// Component identities are independent of Inno's bundle/uninstaller AppId.
// The catalog under ProgramData is authoritative: one app record, one core record per VEGAS family.
static constexpr auto bundleId = "{0CF24E60-C0F5-4242-96AD-13FF2F9BF313}";
static constexpr auto appComponent = "vegas-encoder.app.windows-x64";
static std::string coreComponent(const std::string& family) { return "vegas-encoder.core." + family + ".windows-x64"; }
static bool isCore(const J& record) { return record.at("componentId").get<std::string>().rfind("vegas-encoder.core.", 0) == 0; }
static std::string newId() {
  GUID id{}; need(SUCCEEDED(CoCreateGuid(&id)), "Cannot create installation identity.");
  wchar_t text[40]; StringFromGUID2(id, text, 40); return utf(fs::path(text));
}
static fs::path catalogRoot() { return plain(rootData().parent_path() / "Installations"); }
static fs::path recordPath(const J& record) {
  auto id = record.at("instanceId").get<std::string>();
  GUID parsed{}; auto text = wide(id); wchar_t canonical[40];
  need(SUCCEEDED(CLSIDFromString(text.c_str(), &parsed)), "Invalid installation identity.");
  StringFromGUID2(parsed, canonical, 40);
  need(text == canonical, "Installation identity must be a canonical GUID.");
  return plain(catalogRoot() / (id + ".json"));
}
static void checkRecord(const J& record, const std::string& component, const fs::path& dir, const fs::path& manifest) {
  recordPath(record);
  need(record.at("schema") == "vegas-encoder-component/1" && record.at("componentId") == component &&
    record.at("bundleId") == bundleId && record.at("architecture") == "x64" &&
    same(fs::u8path(record.at("installDir").get<std::string>()), dir) &&
    same(fs::u8path(record.at("manifest").get<std::string>()), manifest) &&
    !record.at("version").get<std::string>().empty(), "Installation record does not match its component: " + record.at("instanceId").get<std::string>());
}
static void checkCore(const J& record) {
  auto host = plain(fs::u8path(record.at("hostDir").get<std::string>()));
  checkRecord(record, coreComponent(record.at("hostFamily").get<std::string>()), plugin(host), plugin(host) / "install-manifest.json");
}
static J catalog() {
  J all = J::array(); auto root = catalogRoot(); if (!fs::exists(root)) return all;
  for (const auto& e : fs::directory_iterator(root)) if (e.path().extension() == ".json") {
    auto record = json(plain(e.path())); need(same(recordPath(record), e.path()), "Installation record name does not match its identity: " + utf(e.path()));
    if (isCore(record)) checkCore(record);
    all.push_back(record);
  }
  return all;
}
static J newRecord(const std::string& component, const fs::path& dir, const fs::path& manifest) {
  return J{{"schema", "vegas-encoder-component/1"}, {"componentId", component}, {"instanceId", newId()},
    {"bundleId", bundleId}, {"architecture", "x64"}, {"installDir", utf(dir)}, {"manifest", utf(manifest)}};
}
// Release order: numeric parts, then a release beats its prerelease, then the +build number.
static int compareVersions(const std::string& a, const std::string& b) {
  auto split = [](const std::string& v, std::vector<long long>& parts, std::string& pre, long long& build) {
    auto plus = v.find('+'), dash = v.find('-'); auto core = v.substr(0, std::min(plus, dash));
    if (dash != v.npos && dash < plus) pre = v.substr(dash + 1, plus == v.npos ? v.npos : plus - dash - 1);
    build = plus == v.npos ? 0 : std::atoll(v.c_str() + plus + 1);
    std::stringstream s(core); std::string part; while (std::getline(s, part, '.')) parts.push_back(std::atoll(part.c_str()));
  };
  std::vector<long long> x, y; std::string xp, yp; long long xb = 0, yb = 0; split(a, x, xp, xb); split(b, y, yp, yb);
  for (size_t i = 0; i < std::max(x.size(), y.size()); ++i) { auto l = i < x.size() ? x[i] : 0, r = i < y.size() ? y[i] : 0; if (l != r) return l < r ? -1 : 1; }
  if (xp != yp) { if (xp.empty()) return 1; if (yp.empty()) return -1; return xp < yp ? -1 : 1; }
  return xb == yb ? 0 : (xb < yb ? -1 : 1);
}
static J appState(const fs::path& app) {
  auto manifest = appManifest(app);
  if (!fs::exists(manifest)) {
    need(!fs::exists(app) || fs::is_empty(app), "The app folder contains an unrecognized installation. Choose an empty folder or restore its ownership manifest.");
    return J{{"schema", "vegas-encoder-setup/1"}, {"files", J::array()}};
  }
  auto state = json(plain(manifest)); need(state.at("schema") == "vegas-encoder-setup/1", "Unknown app ownership manifest.");
  // Repair replaces changed or missing app files, so only the listed paths are checked here.
  std::set<std::wstring> seen;
  for (const auto& f : state.at("files")) need(seen.insert(lower(relative(f.at("file")).wstring())).second, "Duplicate owned file.");
  return state;
}
static J appRecordFor(const fs::path& app, const J& state, const J& records) {
  for (const auto& r : records) if (r.at("componentId") == appComponent && same(fs::u8path(r.at("installDir").get<std::string>()), app)) return r;
  if (state.contains("installation")) { auto r = state.at("installation"); checkRecord(r, appComponent, app, appManifest(app)); return r; }
  return newRecord(appComponent, app, appManifest(app));
}
// Cores this app owns. Pre-catalog installs named their single VEGAS 2026 folder in the app manifest.
static std::vector<J> coresOf(const J& appRecord, const J& state, const J& records) {
  std::vector<J> cores;
  for (const auto& r : records) if (isCore(r) && r.value("appInstanceId", "") == appRecord.at("instanceId")) cores.push_back(r);
  auto legacy = state.value("host", std::string());
  bool known = std::any_of(cores.begin(), cores.end(), [](const J& r) { return r.at("hostFamily") == "vegas2026"; });
  if (!legacy.empty() && !known) {
    auto host = plain(fs::u8path(legacy)); J record;
    auto manifest = plugin(host) / "install-manifest.json";
    if (fs::is_regular_file(manifest)) { auto old = json(manifest); if (old.contains("installation") && old.at("installation").value("componentId", "") == coreComponent("vegas2026")) record = old.at("installation"); }
    if (record.is_null()) record = newRecord(coreComponent("vegas2026"), plugin(host), manifest);
    record["version"] = state.value("version", "unknown"); record["hostDir"] = utf(host); record["hostFamily"] = "vegas2026";
    cores.push_back(record);
  }
  return cores;
}
struct Target { std::string family; fs::path dir; };
// Request keys: count, family0, dir0, family1, dir1, ... One target per VEGAS family.
static std::vector<Target> targets(const fs::path& request) {
  std::vector<Target> result; std::set<std::string> families;
  auto count = _wtoi(ini(request, L"count").c_str()); need(count >= 0 && count < 32, "Invalid VEGAS selection.");
  for (int i = 0; i < count; ++i) {
    auto family = utf(fs::path(ini(request, L"family" + std::to_wstring(i)))); auto dir = ini(request, L"dir" + std::to_wstring(i));
    need(!dir.empty(), label(family) + " was not found. Choose its folder (for example /VEGASDIR" + family.substr(5) + "=\"path\").");
    auto host = hostFor(fs::path(dir), family);
    need(families.insert(family).second, "Choose one folder per VEGAS version.");
    result.push_back({family, host.dir});
  }
  return result;
}
static void snapshot(J& transaction, const fs::path& path, const fs::path& folder) {
  auto p = plain(path);
  for (const auto& f : transaction["files"]) if (same(fs::u8path(f["path"].get<std::string>()), p)) return;
  J entry{{"path", utf(p)}, {"old", nullptr}, {"new", nullptr}};
  if (fs::exists(p)) {
    need(fs::is_regular_file(p), "Expected a file: " + utf(p));
    auto name = std::to_string(transaction["files"].size()) + ".bak";
    fs::copy_file(p, folder / name); entry["old"] = hash(p); entry["backup"] = name;
  }
  transaction["files"].push_back(entry);
}
static constexpr const wchar_t* pluginFiles[] = {L"vegas-encoder.dll", L"vegas-encoder.ini", L"vegas-encoder.pdb", L"install-manifest.json"};
static bool pluginFile(const fs::path& p) { for (auto name : pluginFiles) if (lower(p.filename().wstring()) == name) return true; return false; }
static void saveJournal(const fs::path& folder, const J& t) { write(folder / "transaction.json", t.dump(2)); }
static fs::path prepare(const fs::path& app, const std::vector<Target>& wanted, const fs::path& payload, bool removal = false) {
  auto old = appState(app); auto records = catalog();
  auto package = removal ? J{{"files", J::array()}} : json(plain(payload / "payload.json"));
  if (!removal) {
    need(package.at("schema") == "vegas-encoder-payload/1", "Unknown setup payload.");
    // Payload hashes are embedded inside the signed/compiled setup, never read from a live build.
    matches(payload / "vegas-encoder.dll", package.at("pluginSha256")); matches(payload / "vegas-encoder.ini.in", package.at("iniSha256")); matches(payload / "VegasEncoder-x64.fio2007-config", package.at("configSha256"));
  }
  auto appRecord = appRecordFor(app, old, records);
  if (!removal && appRecord.contains("version"))
    need(compareVersions(appRecord.at("version").get<std::string>(), package.at("version").get<std::string>()) <= 0, "Vegas Encoder " + appRecord.at("version").get<std::string>() + " is installed. Uninstall it before installing this older version.");
  appRecord["version"] = removal ? appRecord.value("version", old.value("version", "unknown")) : package.at("version").get<std::string>();
  auto existing = coresOf(appRecord, old, records);
  std::vector<fs::path> hosts;
  auto addHost = [&](const fs::path& h) { for (auto& k : hosts) if (same(k, h)) return; hosts.push_back(h); };
  for (auto& r : existing) addHost(plain(fs::u8path(r.at("hostDir").get<std::string>())));
  for (auto& w : wanted) addHost(w.dir);
  auto roots = hosts; roots.push_back(app); closed(roots);
  for (auto& w : wanted) {
    need(!same(app, w.dir) && !inside(app, w.dir) && !inside(w.dir, app), "The app and VEGAS folders must be separate.");
    for (const auto& r : records) if (isCore(r) && r.value("appInstanceId", "") != appRecord.at("instanceId") && same(fs::u8path(r.at("hostDir").get<std::string>()), w.dir))
      throw std::runtime_error("This VEGAS exporter belongs to another app installation; nothing replaced: " + utf(w.dir));
  }
  secureRoot();
  for (const auto& e : fs::directory_iterator(rootData())) if (e.is_directory() && fs::exists(e.path() / "transaction.json")) {
    auto prior = json(plain(e.path() / "transaction.json"));
    need(prior.value("status", "") != "pending" || !same(fs::u8path(prior.at("app").get<std::string>()), app), "An interrupted setup needs rollback first: " + utf(e.path()));
  }
  GUID id{}; need(SUCCEEDED(CoCreateGuid(&id)), "Cannot create transaction."); wchar_t idText[40]; StringFromGUID2(id, idText, 40);
  auto folder = rootData() / idText; fs::create_directory(folder);
  J t{{"schema", "vegas-encoder-transaction/1"}, {"status", "preparing"}, {"app", utf(app)}, {"payload", utf(payload)}, {"package", package}, {"previous", old},
    {"hosts", J::array()}, {"targets", J::array()}, {"removed", J::array()}, {"files", J::array()}};
  t["registrations"] = J::array({appRecord});
  for (const auto& w : wanted) {
    J record;
    for (auto& r : existing) if (r.at("hostFamily") == w.family) record = r;
    if (record.is_null()) record = newRecord(coreComponent(w.family), plugin(w.dir), plugin(w.dir) / "install-manifest.json");
    record["installDir"] = utf(plugin(w.dir)); record["manifest"] = utf(plugin(w.dir) / "install-manifest.json");
    record["version"] = package.value("coreVersion", package.at("version").get<std::string>());
    record["appInstanceId"] = appRecord.at("instanceId"); record["hostDir"] = utf(w.dir); record["hostFamily"] = w.family;
    checkCore(record); t["registrations"].push_back(record); t["targets"].push_back({{"family", w.family}, {"dir", utf(w.dir)}});
  }
  for (auto& r : existing) if (std::none_of(wanted.begin(), wanted.end(), [&](const Target& w) { return r.at("hostFamily") == w.family; })) t["removed"].push_back(r);
  for (const auto& record : t["registrations"]) snapshot(t, recordPath(record), folder);
  for (const auto& record : t["removed"]) snapshot(t, recordPath(record), folder);
  for (const auto& f : old["files"]) snapshot(t, app / relative(f.at("file")), folder);
  std::set<std::wstring> owned; for (const auto& f : old["files"]) owned.insert(lower(relative(f.at("file")).wstring()));
  std::set<std::wstring> incoming;
  for (const auto& f : package.at("files")) {
    auto rel = relative(f.at("file")); need(incoming.insert(lower(rel.wstring())).second, "Duplicate payload file.");
    need(!fs::exists(app / rel) || owned.count(lower(rel.wstring())), "An unknown file would be overwritten: " + utf(app / rel)); snapshot(t, app / rel, folder);
  }
  snapshot(t, appManifest(app), folder);
  for (const auto& host : hosts) {
    t["hosts"].push_back(utf(host));
    for (auto name : pluginFiles) snapshot(t, plugin(host) / name, folder);
    snapshot(t, config(host), folder);
  }
  t["status"] = "pending"; saveJournal(folder, t); return folder;
}
static J transaction(const fs::path& folder) {
  need(same(folder.parent_path(), rootData()), "Rollback path is outside Setup's protected backup directory.");
  auto t = json(plain(folder / "transaction.json")); need(t.at("schema") == "vegas-encoder-transaction/1", "Unknown rollback journal.");
  auto app = plain(fs::u8path(t.at("app").get<std::string>()));
  std::vector<fs::path> hosts; for (const auto& v : t.at("hosts")) hosts.push_back(plain(fs::u8path(v.get<std::string>())));
  auto records = t.value("registrations", J::array()); // Older journals remain recoverable.
  for (const auto& r : t.value("removed", J::array())) records.push_back(r);
  for (const auto& record : records) {
    if (record.at("componentId") == appComponent) { checkRecord(record, appComponent, app, appManifest(app)); continue; }
    checkCore(record);
    need(std::any_of(hosts.begin(), hosts.end(), [&](const fs::path& h) { return same(fs::u8path(record.at("hostDir").get<std::string>()), h); }), "Catalog rollback target escapes its owned hosts.");
  }
  for (const auto& f : t.at("files")) {
    auto p = plain(fs::u8path(f.at("path").get<std::string>())); bool allowed = inside(p, app);
    for (const auto& record : records) allowed = allowed || same(p, recordPath(record));
    for (const auto& h : hosts) allowed = allowed || same(p, config(h)) || (same(p.parent_path(), plugin(h)) && pluginFile(p));
    need(allowed, "Rollback target escapes its owned roots.");
    if (!f.at("old").is_null()) matches(folder / relative(f.at("backup")), f.at("old"));
  }
  return t;
}
static std::vector<fs::path> roots(const J& t) {
  std::vector<fs::path> result{fs::u8path(t["app"].get<std::string>())}; for (const auto& h : t["hosts"]) result.push_back(fs::u8path(h.get<std::string>())); return result;
}
static void rollback(const fs::path& folder, bool allowCommitted) {
  auto t = transaction(folder); need(t["status"] == "pending" || (allowCommitted && t["status"] == "committed"), "This transaction is not available for rollback.");
  closed(roots(t));
  // Check every target before changing any. Protect edits made after setup/commit.
  if (t["status"] == "committed") for (const auto& f : t["files"]) {
    auto p = fs::u8path(f["path"].get<std::string>());
    need(f["new"].is_null() ? !fs::exists(p) : fs::exists(p) && hash(p) == f["new"], "A file changed after setup; manual recovery is required: " + utf(p));
  }
  for (const auto& f : t["files"]) {
    auto p = fs::u8path(f["path"].get<std::string>());
    if (f["old"].is_null()) { if (fs::exists(p)) fs::remove(p); }
    else write(p, read(folder / relative(f["backup"])));
  }
  for (const auto& h : t["hosts"]) { auto p = plugin(fs::u8path(h.get<std::string>())); if (fs::exists(p) && fs::is_empty(p)) fs::remove(p); }
  t["status"] = "rolled-back"; saveJournal(folder, t);
}
// Setup only removes its own file names; anything else in the folder stays.
static void removeCore(const fs::path& host) {
  for (auto name : pluginFiles) fs::remove(plugin(host) / name);
  fs::remove(config(host)); if (fs::exists(plugin(host)) && fs::is_empty(plugin(host))) fs::remove(plugin(host));
}
static void commit(const fs::path& folder) {
  auto t = transaction(folder); need(t["status"] == "pending", "Setup transaction is not pending.");
  auto app = plain(fs::u8path(t["app"].get<std::string>())); auto payload = plain(fs::u8path(t["payload"].get<std::string>())); auto& package = t["package"];
  for (const auto& f : package["files"]) matches(app / relative(f["file"]), f["sha256"]);
  closed(roots(t));
  for (const auto& h : t["hosts"]) {
    auto host = plain(fs::u8path(h.get<std::string>())); J target;
    for (const auto& w : t["targets"]) if (same(fs::u8path(w["dir"].get<std::string>()), host)) target = w;
    if (target.is_null()) { removeCore(host); continue; }
    auto vegas = hostFor(host, target["family"].get<std::string>());
    matches(payload / "vegas-encoder.dll", package["pluginSha256"]);
    write(plugin(host) / "vegas-encoder.dll", read(payload / "vegas-encoder.dll"));
#ifdef VE_SETUP_TESTING
    if (fs::exists(testRoot / "fail-commit")) throw std::runtime_error("Injected commit failure.");
#endif
    auto text = read(payload / "vegas-encoder.ini.in"); auto token = text.find("{app}"); need(token != text.npos && text.find("{app}", token + 5) == text.npos, "Invalid app path template.");
    text.replace(token, 5, utf(app));
    // The exporter's Windows INI reader needs UTF-16 for non-ASCII app paths.
    auto unicode = wide(text); std::string iniBytes("\xff\xfe", 2);
    iniBytes.append(reinterpret_cast<const char*>(unicode.data()), unicode.size() * sizeof(wchar_t));
    write(plugin(host) / "vegas-encoder.ini", iniBytes);
    write(config(host), read(payload / "VegasEncoder-x64.fio2007-config"));
    auto pdb = plugin(host) / "vegas-encoder.pdb"; if (fs::exists(pdb)) fs::remove(pdb);
    J state{{"schema", "vegas-encoder-install/1"}, {"product", "Vegas Encoder"}, {"installedBy", "Setup"}, {"vegasDir", utf(host)}, {"pluginDir", utf(plugin(host))}, {"vegasExe", utf(vegas.exe)}, {"vegasVersion", vegas.version}, {"config", utf(config(host))}, {"configSha256", hash(config(host))}, {"files", J::array()}};
    for (const auto& record : t.at("registrations")) if (isCore(record) && same(fs::u8path(record.at("hostDir").get<std::string>()), host)) {
      state["installation"] = record; state["version"] = record.at("version"); write(recordPath(record), record.dump(2));
    }
    for (auto name : {"vegas-encoder.dll", "vegas-encoder.ini"}) { auto p = plugin(host) / name; state["files"].push_back({{"file", utf(p)}, {"sha256", hash(p)}}); }
    write(plugin(host) / "install-manifest.json", state.dump(2));
  }
  for (const auto& record : t["removed"]) fs::remove(recordPath(record));
  std::set<std::wstring> incoming; for (auto& f : package["files"]) incoming.insert(lower(relative(f["file"]).wstring()));
  for (auto& f : t["previous"]["files"]) { auto r = relative(f["file"]); if (!incoming.count(lower(r.wstring()))) fs::remove(app / r); }
  auto appRecord = t.at("registrations").at(0);
  J state{{"schema", "vegas-encoder-setup/1"}, {"version", package["version"]}, {"files", package["files"]}, {"rollback", utf(folder)}};
  state["installation"] = appRecord; write(recordPath(appRecord), appRecord.dump(2));
  write(appManifest(app), state.dump(2));
  for (auto& f : t["files"]) { auto p = fs::u8path(f["path"].get<std::string>()); f["new"] = fs::exists(p) ? J(hash(p)) : J(); }
  t["status"] = "committed"; saveJournal(folder, t);
}
static std::vector<J> installedCores(const fs::path& app) {
  auto state = appState(app); auto records = catalog(); return coresOf(appRecordFor(app, state, records), state, records);
}
static void uninstallCheck(const fs::path& app) {
  need(fs::exists(appManifest(app)), "Missing app ownership manifest; nothing removed.");
  std::vector<fs::path> roots{app}; for (auto& r : installedCores(app)) roots.push_back(fs::u8path(r.at("hostDir").get<std::string>()));
  closed(roots);
}
static void uninstall(const fs::path& folder) {
  auto t = transaction(folder); need(t["status"] == "pending", "Removal transaction is not pending.");
  auto app = plain(fs::u8path(t["app"].get<std::string>()));
  uninstallCheck(app);
  // Keep the last setup transaction and all user data. Only setup's own file names are removed.
  for (const auto& h : t["hosts"]) removeCore(plain(fs::u8path(h.get<std::string>())));
  for (const auto& record : t["removed"]) fs::remove(recordPath(record));
  fs::remove(recordPath(t["registrations"].at(0)));
  fs::remove(appManifest(app));
}
// Read-only. Lists every VEGAS family found (one folder each, recorded folders first) and the installed app.
static void inspect(const fs::path& request, const fs::path& output) {
  J records = J::array(); bool readable = true;
  // Unelevated callers cannot read the protected catalog; Setup itself runs elevated.
  try { records = catalog(); } catch (const std::exception& e) { readable = false; put(output, L"catalogError", wide(e.what())); }
  put(output, L"catalog", readable ? L"1" : L"0");
  J appRecord; auto hint = ini(request, L"app");
  for (const auto& r : records) if (r.at("componentId") == appComponent && (appRecord.is_null() || (!hint.empty() && same(fs::u8path(r.at("installDir").get<std::string>()), fs::path(hint))))) appRecord = r;
  std::map<std::string, std::string> cores; std::vector<fs::path> candidates;
  if (!appRecord.is_null()) {
    auto setup = ini(request, L"version");
    put(output, L"appDir", wide(appRecord.at("installDir").get<std::string>())); put(output, L"appVersion", wide(appRecord.at("version").get<std::string>()));
    if (!setup.empty()) { auto c = compareVersions(appRecord.at("version").get<std::string>(), utf(fs::path(setup))); put(output, L"relation", c < 0 ? L"older" : c == 0 ? L"same" : L"newer"); }
    // A core whose DLL was deleted by hand counts as removed; the next run cleans up its record.
    for (const auto& r : records) if (isCore(r) && r.value("appInstanceId", "") == appRecord.at("instanceId")) {
      auto host = fs::u8path(r.at("hostDir").get<std::string>()); candidates.push_back(host);
      if (fs::is_regular_file(plugin(host) / "vegas-encoder.dll")) cores[r.at("hostFamily").get<std::string>()] = r.at("version").get<std::string>();
    }
  } else put(output, L"relation", L"none");
#ifdef VE_SETUP_TESTING
  for (int i = 0; !ini(request, L"candidate" + std::to_wstring(i)).empty(); ++i) candidates.push_back(ini(request, L"candidate" + std::to_wstring(i)));
#else
  for (auto hive : {HKEY_LOCAL_MACHINE, HKEY_CURRENT_USER}) for (REGSAM view : {KEY_WOW64_64KEY, KEY_WOW64_32KEY}) {
    HKEY key = nullptr;
    if (RegOpenKeyExW(hive, L"Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall", 0, KEY_READ | view, &key) == ERROR_SUCCESS) {
      wchar_t name[1024]; DWORD len = 1024;
      for (DWORD i = 0; RegEnumKeyExW(key, i, name, &len, nullptr, nullptr, nullptr, nullptr) == ERROR_SUCCESS; ++i, len = 1024) {
        HKEY child = nullptr;
        if (RegOpenKeyExW(key, name, 0, KEY_READ | view, &child) == ERROR_SUCCESS) {
          wchar_t display[1024]; DWORD dsize = sizeof display, type = 0; wchar_t path[32768]; DWORD size = sizeof path;
          if (RegQueryValueExW(child, L"DisplayName", nullptr, &type, reinterpret_cast<BYTE*>(display), &dsize) == ERROR_SUCCESS && type == REG_SZ) {
            display[1023] = 0; auto d = lower(display); auto v = d.find(L"vegas");
            if (v != d.npos && d.find(L"pro", v + 5) != d.npos && RegQueryValueExW(child, L"InstallLocation", nullptr, &type, reinterpret_cast<BYTE*>(path), &size) == ERROR_SUCCESS && type == REG_SZ && size >= sizeof(wchar_t) && size <= sizeof path) { path[32767] = 0; candidates.push_back(path); }
          }
          RegCloseKey(child);
        }
      }
      RegCloseKey(key);
    }
    if (RegOpenKeyExW(hive, L"Software\\Microsoft\\Windows\\CurrentVersion\\App Paths", 0, KEY_READ | view, &key) == ERROR_SUCCESS) {
      wchar_t name[256]; DWORD len = 256;
      for (DWORD i = 0; RegEnumKeyExW(key, i, name, &len, nullptr, nullptr, nullptr, nullptr) == ERROR_SUCCESS; ++i, len = 256) {
        wchar_t exe[32768]; DWORD size = sizeof exe;
        if (hostExe(name) && RegGetValueW(key, name, nullptr, RRF_RT_REG_SZ, nullptr, exe, &size) == ERROR_SUCCESS) { std::wstring e = exe; if (e.size() > 1 && e.front() == L'"' && e.back() == L'"') e = e.substr(1, e.size() - 2); candidates.push_back(fs::path(e).parent_path()); }
      }
      RegCloseKey(key);
    }
  }
  for (auto p : {L"C:\\Program Files\\BorisFX\\Vegas Pro 2026", L"C:\\Program Files\\VEGAS\\VEGAS Pro 2026"}) candidates.push_back(p);
#endif
  std::map<std::string, Host> found;
  for (auto& c : candidates) try { for (auto& h : hostsIn(plain(c))) found.emplace(h.family, h); } catch (...) {}
  struct Row { std::string family, dir, version; };
  std::vector<Row> rows;
  for (auto& [family, h] : found) rows.push_back({family, utf(h.dir), h.version});
  for (const auto& r : records) if (isCore(r) && cores.count(r.at("hostFamily").get<std::string>()) && !found.count(r.at("hostFamily").get<std::string>()) && r.value("appInstanceId", "") == appRecord.value("instanceId", ""))
    rows.push_back({r.at("hostFamily").get<std::string>(), r.at("hostDir").get<std::string>(), ""});
  for (auto family : {"vegas2026"}) if (std::none_of(rows.begin(), rows.end(), [&](const Row& r) { return r.family == family; })) rows.push_back({family, "", ""});
  // Supported versions first, newest first.
  std::sort(rows.begin(), rows.end(), [](const Row& a, const Row& b) {
    if (supported(a.family) != supported(b.family)) return supported(a.family);
    return std::atoi(a.family.c_str() + 5) > std::atoi(b.family.c_str() + 5);
  });
  for (size_t i = 0; i < rows.size(); ++i) {
    auto n = std::to_wstring(i); auto& r = rows[i];
    put(output, L"family" + n, wide(r.family)); put(output, L"label" + n, wide(label(r.family))); put(output, L"dir" + n, wide(r.dir));
    put(output, L"version" + n, wide(r.version)); put(output, L"supported" + n, supported(r.family) ? L"1" : L"0");
    put(output, L"core" + n, cores.count(r.family) ? wide(cores[r.family]) : L"");
  }
  put(output, L"count", std::to_wstring(rows.size()));
}
int wmain(int argc, wchar_t** argv) {
  if (argc != 4
#ifdef VE_SETUP_TESTING
      && argc != 5
#endif
  ) return 2;
#ifdef VE_SETUP_TESTING
  if (argc != 5) return 2;
  testRoot = fs::absolute(argv[4]).lexically_normal();
#endif
  fs::path request = argv[2], result = argv[3];
  // Unicode INI results are readable by Inno without lossy active-codepage conversion.
  { std::ofstream f(result, std::ios::binary); f.put('\xff'); f.put('\xfe'); }
  try {
    auto op = std::wstring(argv[1]);
#ifdef VE_SETUP_TESTING
    if (op == L"test-sleep") { Sleep(20000); return 0; }
    if (op == L"test-uninstall-parent" || op == L"test-uninstall-child") {
      auto next = plain(ini(request, op == L"test-uninstall-parent" ? L"proxy" : L"helper"));
      return static_cast<int>(_wspawnl(_P_WAIT, next.c_str(), next.c_str(),
        op == L"test-uninstall-parent" ? L"test-uninstall-child" : L"uninstall-check",
        request.c_str(), result.c_str(), testRoot.c_str(), nullptr));
    }
#endif
    if (op == L"inspect") inspect(request, result);
    else if (op == L"validate") put(result, L"version", wide(hostFor(fs::path(ini(request, L"host")), utf(fs::path(ini(request, L"family")))).version));
    else if (op == L"running") {
      // Reports open programs without failing, so the wizard can offer Retry.
      std::vector<fs::path> roots; auto app = ini(request, L"app");
      if (!app.empty()) { roots.push_back(plain(app)); for (auto& r : installedCores(plain(app))) roots.push_back(fs::u8path(r.at("hostDir").get<std::string>())); }
      for (auto& w : targets(request)) roots.push_back(w.dir);
      put(result, L"busy", joined(running(roots)));
    }
    else if (op == L"prepare") { auto folder = prepare(plain(ini(request, L"app")), targets(request), plain(ini(request, L"payload"))); put(result, L"transaction", folder.wstring()); }
    else if (op == L"commit") commit(plain(ini(request, L"transaction")));
    else if (op == L"rollback") rollback(plain(ini(request, L"transaction")), false);
    else if (op == L"restore") rollback(plain(ini(request, L"transaction")), true);
    else if (op == L"uninstall-check") uninstallCheck(plain(ini(request, L"app")));
    else if (op == L"uninstall-prepare") { auto folder = prepare(plain(ini(request, L"app")), {}, {}, true); put(result, L"transaction", folder.wstring()); }
    else if (op == L"uninstall") uninstall(plain(ini(request, L"transaction")));
    else if (op == L"finish-removal") {
      auto folder = plain(ini(request, L"transaction")); auto t = transaction(folder); need(t["status"] == "pending", "Removal transaction is not pending.");
      for (auto& f : t["files"]) { auto p = fs::u8path(f["path"].get<std::string>()); f["new"] = fs::exists(p) ? J(hash(p)) : J(); }
      t["status"] = "committed"; saveJournal(folder, t);
    }
    else throw std::runtime_error("Unknown setup operation.");
    put(result, L"ok", L"1"); return 0;
  } catch (const std::exception& e) { put(result, L"message", wide(e.what())); return 1; }
}
