// Installer-only Windows helper. No app/core dependency; never runs FFmpeg or VEGAS.
// JSON uses the project's existing nlohmann/json (MIT; notice ships with the app).
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <bcrypt.h>
#include <sddl.h>
#include <shlobj.h>
#include <tlhelp32.h>
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
  plain(p); need(fs::is_regular_file(p) && hash(p) == sha.get<std::string>(), "Owned file is missing or changed; restore it before continuing: " + utf(p));
}
static std::wstring ini(const fs::path& file, const wchar_t* key) {
  wchar_t buf[32768]; GetPrivateProfileStringW(L"setup", key, L"", buf, 32768, file.c_str()); return buf;
}
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
static void closed(const std::vector<fs::path>& roots) {
  HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0); need(snapshot != INVALID_HANDLE_VALUE, "Cannot inspect running processes.");
  PROCESSENTRY32W e{}; e.dwSize = sizeof e; bool busy = false;
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
      if (QueryFullProcessImageNameW(process, 0, path, &len)) for (auto& r : roots) if (inside(path, r)) busy = true;
      CloseHandle(process);
    } else if (lower(e.szExeFile) == L"vegas2026.exe" || lower(e.szExeFile) == L"vegasencoder.exe") busy = true;
  } while (Process32NextW(snapshot, &e));
  CloseHandle(snapshot); need(!busy, "Close Vegas Encoder and VEGAS 2026 before installing or removing files.");
}
static std::string hostVersion(const fs::path& root) {
  auto exe = plain(root / "vegas2026.exe"); need(fs::is_regular_file(exe), "Select the VEGAS Pro 2026 folder containing vegas2026.exe.");
#ifdef VE_SETUP_TESTING
  return "2026.0.3.189 (fixture)";
#else
  std::ifstream file(exe, std::ios::binary); IMAGE_DOS_HEADER dos{}; file.read(reinterpret_cast<char*>(&dos), sizeof dos);
  need(file && dos.e_magic == IMAGE_DOS_SIGNATURE && dos.e_lfanew >= sizeof dos, "Invalid VEGAS executable.");
  file.seekg(dos.e_lfanew); DWORD signature = 0; IMAGE_FILE_HEADER pe{}; file.read(reinterpret_cast<char*>(&signature), sizeof signature); file.read(reinterpret_cast<char*>(&pe), sizeof pe);
  need(file && signature == IMAGE_NT_SIGNATURE && pe.Machine == IMAGE_FILE_MACHINE_AMD64, "VEGAS must be Windows x64.");
  DWORD unused = 0; auto size = GetFileVersionInfoSizeW(exe.c_str(), &unused); need(size > 0, "Cannot read VEGAS version.");
  std::vector<unsigned char> data(size); need(GetFileVersionInfoW(exe.c_str(), 0, size, data.data()) != 0, "Cannot read VEGAS version.");
  VS_FIXEDFILEINFO* info = nullptr; UINT bytes = 0;
  need(VerQueryValueW(data.data(), L"\\", reinterpret_cast<void**>(&info), &bytes) && bytes >= sizeof(*info) && HIWORD(info->dwFileVersionMS) == 2026, "Only VEGAS Pro 2026 is supported.");
  return std::to_string(HIWORD(info->dwFileVersionMS)) + "." + std::to_string(LOWORD(info->dwFileVersionMS)) + "." + std::to_string(HIWORD(info->dwFileVersionLS)) + "." + std::to_string(LOWORD(info->dwFileVersionLS));
#endif
}
static fs::path plugin(const fs::path& host) { return host / "FileIO Plug-Ins" / "vegas-encoder"; }
static fs::path config(const fs::path& host) { return host / "VegasEncoder-x64.fio2007-config"; }
static fs::path appManifest(const fs::path& app) { return app / "vegas-encoder-setup.json"; }
// Component identities are independent of Inno's bundle/uninstaller AppId.
// One record per instance permits future host families and independent versions.
static constexpr auto bundleId = "{0CF24E60-C0F5-4242-96AD-13FF2F9BF313}";
static constexpr auto appComponent = "vegas-encoder.app.windows-x64";
static constexpr auto coreComponent = "vegas-encoder.core.vegas2026.windows-x64";
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
static void checkRecord(const J& record, const char* component, const fs::path& dir, const fs::path& manifest) {
  recordPath(record);
  need(record.at("schema") == "vegas-encoder-component/1" && record.at("componentId") == component &&
    record.at("bundleId") == bundleId && record.at("architecture") == "x64" &&
    same(fs::u8path(record.at("installDir").get<std::string>()), dir) &&
    same(fs::u8path(record.at("manifest").get<std::string>()), manifest) &&
    !record.at("version").get<std::string>().empty(), "Installation record does not match its component.");
}
static void checkCatalog(const J& state, const char* component, const fs::path& dir, const fs::path& manifest) {
  if (!state.contains("installation")) return; // Hash-verified pre-catalog installs can be adopted.
  const auto& record = state.at("installation"); checkRecord(record, component, dir, manifest);
  need(json(recordPath(record)) == record, "Installation catalog is missing or changed; restore it before continuing.");
}
static J makeRecord(const J& state, const char* component, const fs::path& dir, const fs::path& manifest, const std::string& version) {
  J record = state.is_object() && state.contains("installation") ? state.at("installation") :
    J{{"schema", "vegas-encoder-component/1"}, {"componentId", component}, {"instanceId", newId()},
      {"bundleId", bundleId}, {"architecture", "x64"}, {"installDir", utf(dir)}, {"manifest", utf(manifest)}};
  record["version"] = version; checkRecord(record, component, dir, manifest); return record;
}
static J appState(const fs::path& app) {
  auto manifest = appManifest(app);
  if (!fs::exists(manifest)) {
    need(!fs::exists(app) || fs::is_empty(app), "The app folder contains an unrecognized installation. Choose an empty folder or restore its ownership manifest.");
    return J{{"schema", "vegas-encoder-setup/1"}, {"files", J::array()}, {"host", ""}};
  }
  auto state = json(plain(manifest)); need(state.at("schema") == "vegas-encoder-setup/1", "Unknown app ownership manifest.");
  checkCatalog(state, appComponent, app, manifest);
  std::set<std::wstring> seen;
  for (const auto& f : state.at("files")) {
    auto p = app / relative(f.at("file")); need(seen.insert(lower(p.wstring())).second, "Duplicate owned file."); matches(p, f.at("sha256"));
  }
  return state;
}
static J hostState(const fs::path& host, bool requireExecutable = false) {
  if (requireExecutable) hostVersion(host);
  auto dir = plain(plugin(host)), conf = plain(config(host));
  if (!fs::exists(dir)) { need(!fs::exists(conf), "Unrecognized VEGAS discovery file; no files were replaced."); return J(); }
  auto manifest = plain(dir / "install-manifest.json");
  need(fs::is_regular_file(manifest), "Unrecognized VEGAS exporter; no files were replaced.");
  auto state = json(manifest);
  checkCatalog(state, coreComponent, dir, manifest);
  need(state.at("schema") == "vegas-encoder-install/1" && state.at("product") == "Vegas Encoder" && same(fs::u8path(state.at("vegasDir").get<std::string>()), host) && same(fs::u8path(state.at("pluginDir").get<std::string>()), dir) && same(fs::u8path(state.at("vegasExe").get<std::string>()), host / "vegas2026.exe") && same(fs::u8path(state.at("config").get<std::string>()), conf), "VEGAS ownership manifest paths do not match.");
  matches(conf, state.at("configSha256")); std::set<std::wstring> seen;
  for (const auto& f : state.at("files")) {
    auto p = plain(fs::u8path(f.at("file").get<std::string>())); auto name = lower(p.filename().wstring());
    need(same(p.parent_path(), dir) && (name == L"vegas-encoder.dll" || name == L"vegas-encoder.ini" || name == L"vegas-encoder.pdb") && seen.insert(name).second, "Invalid VEGAS owned file."); matches(p, f.at("sha256"));
  }
  need(seen.count(L"vegas-encoder.dll") && seen.count(L"vegas-encoder.ini"), "Incomplete VEGAS ownership manifest.");
  for (const auto& e : fs::directory_iterator(dir)) need(fs::is_regular_file(plain(e.path())) && (seen.count(lower(e.path().filename().wstring())) || e.path().filename() == "install-manifest.json"), "Unknown file in VEGAS exporter folder; preserve or move it first.");
  return state;
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
static std::vector<fs::path> hosts(const J& old, const std::wstring& selected) {
  std::vector<fs::path> result;
  auto previous = old.value("host", std::string());
  if (!previous.empty()) result.push_back(plain(fs::u8path(previous)));
  if (!selected.empty()) { auto p = plain(selected); if (result.empty() || !same(p, result[0])) result.push_back(p); }
  return result;
}
static void saveJournal(const fs::path& folder, const J& t) { write(folder / "transaction.json", t.dump(2)); }
static fs::path prepare(const fs::path& app, const std::wstring& selected, const fs::path& payload, bool removal = false) {
  auto old = appState(app); auto targets = hosts(old, selected); auto roots = targets; roots.push_back(app); closed(roots);
  for (auto& host : targets) { need(!same(app, host) && !inside(app, host) && !inside(host, app), "The app and VEGAS folders must be separate."); hostState(host, !selected.empty() && same(host, fs::path(selected))); }
  auto package = removal ? J{{"files", J::array()}} : json(plain(payload / "payload.json"));
  if (!removal) {
  need(package.at("schema") == "vegas-encoder-payload/1", "Unknown setup payload.");
  // Payload hashes are embedded inside the signed/compiled setup, never read from a live build.
  matches(payload / "vegas-encoder.dll", package.at("pluginSha256")); matches(payload / "vegas-encoder.ini.in", package.at("iniSha256")); matches(payload / "VegasEncoder-x64.fio2007-config", package.at("configSha256"));
  }
  secureRoot();
  for (const auto& e : fs::directory_iterator(rootData())) if (e.is_directory() && fs::exists(e.path() / "transaction.json")) {
    auto prior = json(plain(e.path() / "transaction.json"));
    need(prior.value("status", "") != "pending" || !same(fs::u8path(prior.at("app").get<std::string>()), app), "An interrupted setup needs rollback first: " + utf(e.path()));
  }
  GUID id{}; need(SUCCEEDED(CoCreateGuid(&id)), "Cannot create transaction."); wchar_t idText[40]; StringFromGUID2(id, idText, 40);
  auto folder = rootData() / idText; fs::create_directory(folder);
  J t{{"schema", "vegas-encoder-transaction/1"}, {"status", "preparing"}, {"app", utf(app)}, {"selected", utf(fs::path(selected))}, {"payload", utf(payload)}, {"package", package}, {"previous", old}, {"hosts", J::array()}, {"files", J::array()}};
  auto appRecord = makeRecord(old, appComponent, app, appManifest(app), removal ? old.value("version", "unknown") : package.at("version").get<std::string>());
  t["registrations"] = J::array({appRecord});
  for (const auto& host : targets) {
    auto state = hostState(host);
    auto record = makeRecord(state, coreComponent, plugin(host), plugin(host) / "install-manifest.json",
      removal ? (state.is_object() ? state.value("version", "unknown") : "unknown") : package.value("coreVersion", package.at("version").get<std::string>()));
    if (record.contains("appInstanceId")) need(record.at("appInstanceId") == appRecord.at("instanceId"), "This VEGAS core belongs to another app installation; nothing replaced.");
    record["appInstanceId"] = appRecord.at("instanceId");
    record["hostDir"] = utf(host); record["hostFamily"] = "vegas2026";
    t["registrations"].push_back(record);
  }
  for (const auto& record : t["registrations"]) snapshot(t, recordPath(record), folder);
  for (const auto& f : old["files"]) snapshot(t, app / relative(f.at("file")), folder);
  std::set<std::wstring> owned; for (const auto& f : old["files"]) owned.insert(lower(relative(f.at("file")).wstring()));
  std::set<std::wstring> incoming;
  for (const auto& f : package.at("files")) {
    auto rel = relative(f.at("file")); need(incoming.insert(lower(rel.wstring())).second, "Duplicate payload file.");
    need(!fs::exists(app / rel) || owned.count(lower(rel.wstring())), "An unknown file would be overwritten: " + utf(app / rel)); snapshot(t, app / rel, folder);
  }
  snapshot(t, appManifest(app), folder);
  for (const auto& host : targets) {
    t["hosts"].push_back(utf(host));
    for (auto name : {L"vegas-encoder.dll", L"vegas-encoder.ini", L"vegas-encoder.pdb", L"install-manifest.json"}) snapshot(t, plugin(host) / name, folder);
    snapshot(t, config(host), folder);
  }
  t["status"] = "pending"; saveJournal(folder, t); return folder;
}
static J transaction(const fs::path& folder) {
  need(same(folder.parent_path(), rootData()), "Rollback path is outside Setup's protected backup directory.");
  auto t = json(plain(folder / "transaction.json")); need(t.at("schema") == "vegas-encoder-transaction/1", "Unknown rollback journal.");
  auto app = plain(fs::u8path(t.at("app").get<std::string>()));
  auto registrations = t.value("registrations", J::array()); // Older journals remain recoverable.
  for (const auto& record : registrations) {
    if (record.at("componentId") == appComponent) checkRecord(record, appComponent, app, appManifest(app));
    else {
      bool found = false;
      for (const auto& v : t.at("hosts")) {
        auto host = plain(fs::u8path(v.get<std::string>()));
        if (same(fs::u8path(record.at("installDir").get<std::string>()), plugin(host))) {
          checkRecord(record, coreComponent, plugin(host), plugin(host) / "install-manifest.json"); found = true;
        }
      }
      need(found, "Catalog rollback target escapes its owned hosts.");
    }
  }
  for (const auto& f : t.at("files")) {
    auto p = plain(fs::u8path(f.at("path").get<std::string>())); bool allowed = inside(p, app);
    for (const auto& record : registrations) allowed = allowed || same(p, recordPath(record));
    for (const auto& v : t.at("hosts")) { auto h = plain(fs::u8path(v.get<std::string>())); allowed = allowed || same(p, config(h)) || (same(p.parent_path(), plugin(h)) && (p.filename() == "vegas-encoder.dll" || p.filename() == "vegas-encoder.ini" || p.filename() == "vegas-encoder.pdb" || p.filename() == "install-manifest.json")); }
    need(allowed, "Rollback target escapes its owned roots.");
    if (!f.at("old").is_null()) matches(folder / relative(f.at("backup")), f.at("old"));
  }
  return t;
}
static void rollback(const fs::path& folder, bool allowCommitted) {
  auto t = transaction(folder); need(t["status"] == "pending" || (allowCommitted && t["status"] == "committed"), "This transaction is not available for rollback.");
  std::vector<fs::path> roots{fs::u8path(t["app"].get<std::string>())}; for (const auto& h : t["hosts"]) roots.push_back(fs::u8path(h.get<std::string>())); closed(roots);
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
static void commit(const fs::path& folder) {
  auto t = transaction(folder); need(t["status"] == "pending", "Setup transaction is not pending.");
  auto app = plain(fs::u8path(t["app"].get<std::string>())); auto payload = plain(fs::u8path(t["payload"].get<std::string>())); auto& package = t["package"];
  for (const auto& f : package["files"]) matches(app / relative(f["file"]), f["sha256"]);
  std::vector<fs::path> roots{app}; for (const auto& h : t["hosts"]) roots.push_back(fs::u8path(h.get<std::string>())); closed(roots);
  auto selected = fs::u8path(t["selected"].get<std::string>());
  auto appRecord = t.at("registrations").at(0);
  for (const auto& h : t["hosts"]) {
    auto host = plain(fs::u8path(h.get<std::string>())); hostState(host, same(selected, host));
    if (same(selected, host)) {
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
      J state{{"schema", "vegas-encoder-install/1"}, {"product", "Vegas Encoder"}, {"installedBy", "Setup"}, {"vegasDir", utf(host)}, {"pluginDir", utf(plugin(host))}, {"vegasExe", utf(host / "vegas2026.exe")}, {"vegasVersion", hostVersion(host)}, {"config", utf(config(host))}, {"configSha256", hash(config(host))}, {"files", J::array()}};
      for (const auto& record : t.at("registrations")) if (record.at("componentId") == coreComponent && same(fs::u8path(record.at("installDir").get<std::string>()), plugin(host))) {
        state["installation"] = record; state["version"] = record.at("version"); write(recordPath(record), record.dump(2));
      }
      for (auto name : {"vegas-encoder.dll", "vegas-encoder.ini"}) { auto p = plugin(host) / name; state["files"].push_back({{"file", utf(p)}, {"sha256", hash(p)}}); }
      write(plugin(host) / "install-manifest.json", state.dump(2)); hostState(host);
    } else {
      for (const auto& record : t.at("registrations")) if (record.at("componentId") == coreComponent && same(fs::u8path(record.at("installDir").get<std::string>()), plugin(host))) fs::remove(recordPath(record));
      for (auto name : {L"vegas-encoder.dll", L"vegas-encoder.ini", L"vegas-encoder.pdb", L"install-manifest.json"}) fs::remove(plugin(host) / name);
      fs::remove(config(host)); if (fs::exists(plugin(host)) && fs::is_empty(plugin(host))) fs::remove(plugin(host));
    }
  }
  std::set<std::wstring> incoming; for (auto& f : package["files"]) incoming.insert(lower(relative(f["file"]).wstring()));
  for (auto& f : t["previous"]["files"]) { auto r = relative(f["file"]); if (!incoming.count(lower(r.wstring()))) fs::remove(app / r); }
  J state{{"schema", "vegas-encoder-setup/1"}, {"version", package["version"]}, {"host", utf(selected)}, {"files", package["files"]}, {"rollback", utf(folder)}};
  state["installation"] = appRecord; write(recordPath(appRecord), appRecord.dump(2));
  write(appManifest(app), state.dump(2));
  for (auto& f : t["files"]) { auto p = fs::u8path(f["path"].get<std::string>()); f["new"] = fs::exists(p) ? J(hash(p)) : J(); }
  t["status"] = "committed"; saveJournal(folder, t);
}
static void uninstallCheck(const fs::path& app) {
  auto state = appState(app); need(fs::exists(appManifest(app)), "Missing app ownership manifest; nothing removed.");
  auto targets = hosts(state, L""); auto roots = targets; roots.push_back(app); closed(roots);
  for (auto& h : targets) {
    auto core = hostState(h);
    if (core.is_object() && core.contains("installation")) need(state.contains("installation") &&
      core.at("installation").at("appInstanceId") == state.at("installation").at("instanceId"),
      "This VEGAS core belongs to another app installation; nothing removed.");
  }
}
static void uninstall(const fs::path& folder) {
  auto t = transaction(folder); need(t["status"] == "pending", "Removal transaction is not pending.");
  auto app = plain(fs::u8path(t["app"].get<std::string>()));
  uninstallCheck(app); auto state = appState(app);
  // Keep the last setup transaction and all user data. Only manifest-owned plug-in files are removed.
  auto targets = hosts(state, L"");
  for (auto& host : targets) {
    auto old = hostState(host); if (old.is_null()) continue;
    if (old.contains("installation")) fs::remove(recordPath(old.at("installation")));
    for (auto& f : old["files"]) fs::remove(plain(fs::u8path(f["file"].get<std::string>())));
    fs::remove(plugin(host) / "install-manifest.json"); fs::remove(config(host)); if (fs::is_empty(plugin(host))) fs::remove(plugin(host));
  }
  if (state.contains("installation")) fs::remove(recordPath(state.at("installation")));
  fs::remove(appManifest(app));
}
static void discover(const fs::path& output) {
  std::set<std::wstring> found;
#ifndef VE_SETUP_TESTING
  for (auto hive : {HKEY_LOCAL_MACHINE, HKEY_CURRENT_USER}) for (REGSAM view : {KEY_WOW64_64KEY, KEY_WOW64_32KEY}) {
    HKEY key = nullptr;
    if (RegOpenKeyExW(hive, L"Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall", 0, KEY_READ | view, &key) == ERROR_SUCCESS) {
      wchar_t name[1024]; DWORD len = 1024;
      for (DWORD i = 0; RegEnumKeyExW(key, i, name, &len, nullptr, nullptr, nullptr, nullptr) == ERROR_SUCCESS; ++i, len = 1024) {
        HKEY child = nullptr;
        if (RegOpenKeyExW(key, name, 0, KEY_READ | view, &child) == ERROR_SUCCESS) {
          wchar_t path[32768]; DWORD size = sizeof path, type = 0;
          if (RegQueryValueExW(child, L"InstallLocation", nullptr, &type, reinterpret_cast<BYTE*>(path), &size) == ERROR_SUCCESS && type == REG_SZ && size >= sizeof(wchar_t) && size <= sizeof path) { path[32767] = 0; try { auto p = plain(path); hostVersion(p); found.insert(p.wstring()); } catch (...) {} }
          RegCloseKey(child);
        }
      }
      RegCloseKey(key);
    }
    wchar_t exe[32768]; DWORD size = sizeof exe;
    if (RegGetValueW(hive, L"Software\\Microsoft\\Windows\\CurrentVersion\\App Paths\\vegas2026.exe", nullptr, RRF_RT_REG_SZ | (view == KEY_WOW64_64KEY ? RRF_SUBKEY_WOW6464KEY : RRF_SUBKEY_WOW6432KEY), nullptr, exe, &size) == ERROR_SUCCESS) try { auto p = plain(fs::path(exe).parent_path()); hostVersion(p); found.insert(p.wstring()); } catch (...) {}
  }
  for (auto p : {L"C:\\Program Files\\BorisFX\\Vegas Pro 2026", L"C:\\Program Files\\VEGAS\\VEGAS Pro 2026"}) try { hostVersion(plain(p)); found.insert(p); } catch (...) {}
#endif
  int index = 0;
  for (auto& p : found) { auto key = L"host" + std::to_wstring(index++); WritePrivateProfileStringW(L"setup", key.c_str(), p.c_str(), output.c_str()); }
  WritePrivateProfileStringW(L"setup", L"count", std::to_wstring(index).c_str(), output.c_str());
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
    if (op == L"inspect") discover(result);
    else if (op == L"validate") { auto version = wide(hostVersion(plain(ini(request, L"host")))); WritePrivateProfileStringW(L"setup", L"version", version.c_str(), result.c_str()); }
    else if (op == L"prepare") { auto folder = prepare(plain(ini(request, L"app")), ini(request, L"host"), plain(ini(request, L"payload"))); WritePrivateProfileStringW(L"setup", L"transaction", folder.c_str(), result.c_str()); }
    else if (op == L"commit") commit(plain(ini(request, L"transaction")));
    else if (op == L"rollback") rollback(plain(ini(request, L"transaction")), false);
    else if (op == L"restore") rollback(plain(ini(request, L"transaction")), true);
    else if (op == L"uninstall-check") uninstallCheck(plain(ini(request, L"app")));
    else if (op == L"uninstall-prepare") { auto folder = prepare(plain(ini(request, L"app")), L"", {}, true); WritePrivateProfileStringW(L"setup", L"transaction", folder.c_str(), result.c_str()); }
    else if (op == L"uninstall") uninstall(plain(ini(request, L"transaction")));
    else if (op == L"finish-removal") {
      auto folder = plain(ini(request, L"transaction")); auto t = transaction(folder); need(t["status"] == "pending", "Removal transaction is not pending.");
      for (auto& f : t["files"]) { auto p = fs::u8path(f["path"].get<std::string>()); f["new"] = fs::exists(p) ? J(hash(p)) : J(); }
      t["status"] = "committed"; saveJournal(folder, t);
    }
    else throw std::runtime_error("Unknown setup operation.");
    WritePrivateProfileStringW(L"setup", L"ok", L"1", result.c_str()); return 0;
  } catch (const std::exception& e) { auto message = wide(e.what()); WritePrivateProfileStringW(L"setup", L"message", message.c_str(), result.c_str()); return 1; }
}
