// Authored read-only library metadata scan. FindFirstFileExW supplies size/times
// in one enumeration; do not open/stat every preset. No VEGAS/core calls.
// Ownership/error rules: Microsoft Learn fileapi FindFirstFileExW/FindNextFileW.
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <algorithm>
#include <cstdint>
#include <cstring>
#include <limits>
#include <string>
#include "../core/third_party/nlohmann/json.hpp"

namespace {
using Json = nlohmann::ordered_json;
struct Search {
    HANDLE value = INVALID_HANDLE_VALUE;
    ~Search() { if (value != INVALID_HANDLE_VALUE) FindClose(value); }
};
uint64_t Time(const FILETIME& time) { return (static_cast<uint64_t>(time.dwHighDateTime) << 32) | time.dwLowDateTime; }
std::string Utf8(const std::wstring& text) {
    const int length = static_cast<int>(text.size());
    const int count = WideCharToMultiByte(CP_UTF8,WC_ERR_INVALID_CHARS,text.data(),length,nullptr,0,nullptr,nullptr);
    if (count <= 0) throw std::runtime_error("Invalid filename");
    std::string result(static_cast<size_t>(count),'\0');
    if (!WideCharToMultiByte(CP_UTF8,WC_ERR_INVALID_CHARS,text.data(),length,result.data(),count,nullptr,nullptr)) throw std::runtime_error("Cannot encode filename");
    return result;
}
}

// Returns counted UTF-8 JSON into caller storage. -2 means optional fast-path
// bound exceeded (caller may use legacy enumeration), other negatives fail.
extern "C" __declspec(dllexport) int32_t ve_library_metadata(const uint16_t* directory, uint32_t length, uint8_t* destination, uint32_t capacity) noexcept {
    if (!directory || !length || length > 32700 || !destination || !capacity || capacity > 1048576) return -1;
    try {
        std::wstring root(reinterpret_cast<const wchar_t*>(directory),length);
        if (root.find(L'\0') != std::wstring::npos) return -1;
        std::replace(root.begin(),root.end(),L'/',L'\\');
        if (root.rfind(L"\\\\?\\",0) != 0) {
            if (root.rfind(L"\\\\",0) == 0) root = L"\\\\?\\UNC\\" + root.substr(2);
            else if (root.size() >= 3 && root[1] == L':' && (root[2] == L'\\' || root[2] == L'/')) root = L"\\\\?\\" + root;
            else return -1;
        }
        if (root.back() != L'\\' && root.back() != L'/') root += L'\\';
        root += L'*';
        WIN32_FIND_DATAW data{};
        Search search;
        search.value = FindFirstFileExW(root.c_str(),FindExInfoBasic,&data,FindExSearchNameMatch,nullptr,FIND_FIRST_EX_LARGE_FETCH);
        Json result{{"files",Json::array()},{"preferences",nullptr}};
        size_t retained = 0, visited = 0, estimatedBytes = 64;
        DWORD error = ERROR_SUCCESS;
        if (search.value == INVALID_HANDLE_VALUE) {
            error = GetLastError();
            if (error != ERROR_FILE_NOT_FOUND && error != ERROR_PATH_NOT_FOUND) return -3;
        } else for (;;) {
            if (++visited > 100000) return -2;
            const std::wstring name(data.cFileName);
            const bool preferences = _wcsicmp(name.c_str(),L"preferences.json") == 0;
            // preferences.json is opened even when it is not a regular file.
            // Do not turn an unreadable directory into cached default preferences.
            if (preferences && (data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)) return -3;
            // Match Dart's non-recursive, followLinks:false preset enumeration.
            const bool preset = name.size() >= 9 && name.compare(name.size()-9,9,L".vepreset") == 0;
            if (!(data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) && (preferences || preset)) {
                if (data.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT) {
                    return -2; // Let Dart preserve its exact reparse/link policy.
                } else {
                    const auto size = (static_cast<uint64_t>(data.nFileSizeHigh) << 32) | data.nFileSizeLow;
                    const auto modified = Time(data.ftLastWriteTime), created = Time(data.ftCreationTime);
                    const auto maxInteger = static_cast<uint64_t>(std::numeric_limits<int64_t>::max());
                    if (size > maxInteger || modified > maxInteger || created > maxInteger || ++retained > 8192) return -2;
                    const auto encoded = Utf8(name);
                    estimatedBytes += encoded.size() * 6 + 128; // Includes worst-case JSON escapes.
                    if (estimatedBytes > capacity) return -2;
                    Json stamp{{"name",encoded},{"size",size},{"modified",modified},{"created",created}};
                    if (preferences) result["preferences"] = std::move(stamp);
                    else result["files"].push_back(std::move(stamp));
                }
            }
            if (FindNextFileW(search.value,&data)) continue;
            error = GetLastError();
            if (error != ERROR_NO_MORE_FILES) return -3;
            break;
        }
        const auto encoded = result.dump();
        if (encoded.size() > capacity) return -2;
        std::memcpy(destination,encoded.data(),encoded.size());
        return static_cast<int32_t>(encoded.size());
    } catch (...) { return -4; }
}
