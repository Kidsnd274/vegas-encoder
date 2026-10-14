// Authored B3 machine-local helper. No VEGAS calls or portable-core dependency
// except the already-attributed MIT JSON header. DXGI ownership follows Microsoft
// EnumAdapters1; driver version is queried for IDXGIDevice, not D3D11 support.
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#include <dxgi.h>
#include <wrl/client.h>
#include <cstdint>
#include <cstring>
#include <string>
#include "../core/third_party/nlohmann/json.hpp"

namespace {
std::string Utf8(const wchar_t* text) {
    size_t length = 0; while (length < 128 && text[length]) ++length;
    const int size = WideCharToMultiByte(CP_UTF8,WC_ERR_INVALID_CHARS,text,static_cast<int>(length),nullptr,0,nullptr,nullptr);
    if (size <= 0) throw std::runtime_error("Invalid adapter name");
    std::string value(static_cast<size_t>(size),'\0');
    if (!WideCharToMultiByte(CP_UTF8,WC_ERR_INVALID_CHARS,text,static_cast<int>(length),value.data(),size,nullptr,nullptr)) throw std::runtime_error("Cannot encode adapter name");
    return value;
}
}
extern "C" __declspec(dllexport) int32_t ve_gpu_snapshot(uint8_t* destination, uint32_t capacity) noexcept {
    try {
        Microsoft::WRL::ComPtr<IDXGIFactory1> factory;
        if (FAILED(CreateDXGIFactory1(IID_PPV_ARGS(&factory)))) return -1;
        nlohmann::ordered_json result{{"adapters",nlohmann::ordered_json::array()},{"cacheable",true}};
        for (UINT index = 0; index <= 64; ++index) {
            Microsoft::WRL::ComPtr<IDXGIAdapter1> adapter;
            const auto hr = factory->EnumAdapters1(index,&adapter);
            if (hr == DXGI_ERROR_NOT_FOUND) break;
            if (FAILED(hr) || index == 64) return -2;
            DXGI_ADAPTER_DESC1 description{};
            if (FAILED(adapter->GetDesc1(&description))) return -3;
            if (description.Flags & DXGI_ADAPTER_FLAG_SOFTWARE) continue;
            LARGE_INTEGER version{};
            const bool known = SUCCEEDED(adapter->CheckInterfaceSupport(__uuidof(IDXGIDevice),&version));
            if (!known) result["cacheable"] = false;
            const std::string driver = known ? std::to_string(HIWORD(version.HighPart)) + "." + std::to_string(LOWORD(version.HighPart)) + "." +
                std::to_string(HIWORD(version.LowPart)) + "." + std::to_string(LOWORD(version.LowPart)) : "";
            result["adapters"].push_back({{"name",Utf8(description.Description)},{"vendorId",description.VendorId},
                {"deviceId",description.DeviceId},{"luid",std::to_string(description.AdapterLuid.HighPart) + ":" + std::to_string(description.AdapterLuid.LowPart)},
                {"driver",known ? nlohmann::ordered_json(driver) : nlohmann::ordered_json(nullptr)}});
        }
        const auto json = result.dump();
        if (!destination || json.size() > capacity || json.size() > 65536) return -4;
        std::memcpy(destination,json.data(),json.size()); return static_cast<int32_t>(json.size());
    } catch (...) { return -5; }
}
