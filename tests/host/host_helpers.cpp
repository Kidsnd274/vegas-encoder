// Focused internal-helper checks; does not launch or load VEGAS.
#include "../../src/vegas/host/template.h"
#include "../../src/vegas/host/frame_lease.h"

#include <cstdio>
#include <cstring>
#include <limits>
#include <stdexcept>
#include <type_traits>

using vegas_encoder::host::Tpl;
using vegas_encoder::host::Float32Record;
using vegas_encoder::host::FrameLease;

namespace {
int failures = 0;
void Check(bool success, const char* label) {
  printf("%s: %s\n", success ? "PASS" : "FAIL", label);
  if (!success) ++failures;
}
template <class Exception, class Action>
bool Throws(Action action) {
  try { action(); } catch (const Exception&) { return true; } catch (...) {}
  return false;
}

struct Video final : sfio::ISfReadVideoRenderStream {
  int releases = 0;
  LONG_PTR lastLock = 0;
  HRESULT releaseResult = S_OK;
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID, void** out) override {
    if (out) *out = nullptr;
    return E_NOINTERFACE;
  }
  ULONG STDMETHODCALLTYPE AddRef() override { return 1; }
  ULONG STDMETHODCALLTYPE Release() override { return 1; }
  HRESULT STDMETHODCALLTYPE GetFile(IUnknown**) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE Slot4(LONG*) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE Slot5(LONG*, LONG*, LONG*) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE GetStreamLength(LONGLONG*) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE Slot7(LONGLONG*) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE Slot8() override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE GetFrameCount(LONGLONG*) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE GetFormat10(void*) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE GetReadVideoFormat(void*) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE SetRenderFrameFormat(void*, const void*) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE Slot13(void*, LONG) override { return E_NOTIMPL; }
  HRESULT STDMETHODCALLTYPE GetRenderFrame(LONGLONG, sfio::SFMEMORYTOKEN*, LONG_PTR*, void*, LONG*) override {
    return E_NOTIMPL;
  }
  HRESULT STDMETHODCALLTYPE ReleaseRenderFrame(LONG_PTR lock) override {
    ++releases; lastLock = lock; return releaseResult;
  }
  HRESULT STDMETHODCALLTYPE Slot16(LONGLONG, const void*, const sfio::SFMEMORYTOKEN*, void*, LONG*) override {
    return E_NOTIMPL;
  }
};

void Templates() {
  Tpl t = Tpl::Make(L"Name \u03a9", L"Notes", 3);
  Check(Tpl::Valid(t.Ptr(), t.b.size()) && Tpl::Valid(t.Ptr()), "valid template with unaligned text");
  Check(t.Name() == L"Name \u03a9" && t.Notes() == L"Notes", "bounded UTF-16 name and notes");
  t.b[sfio::tpl::abExtra] = 0xa7;
  Tpl copy = Tpl::Copy(t.Ptr(), t.b.size());
  copy.b[sfio::tpl::abExtra] = 0x11;
  copy.SetU32(sfio::tpl::id, 19);
  Check(t.b[sfio::tpl::abExtra] == 0xa7 && t.U32(sfio::tpl::id) == 0 && copy.U32(sfio::tpl::id) == 19,
        "clone is independent and preserves private bytes");
  Check(!Tpl::Valid(nullptr) && !Tpl::Valid(t.Ptr(), sfio::tpl::fixedSize - 1) &&
        !Tpl::Valid(t.Ptr(), t.b.size() - 1), "reject null and truncated spans");
  Check(t.HasSpan(t.b.size(), 0) && !t.HasSpan(t.b.size(), 1) &&
        !t.HasSpan((std::numeric_limits<size_t>::max)(), 4), "span bounds avoid integer wraparound");
  Check(Throws<std::out_of_range>([&] { t.U32(t.b.size() - 3); }) &&
        Throws<std::out_of_range>([&] { t.SetF64(t.b.size() - 7, 0); }) &&
        Throws<std::out_of_range>([&] { t.Zero(t.b.size(), 1); }), "bounded field reads writes and zero checks");
  Check(Tpl{}.Name().empty() && Tpl{}.Notes().empty(), "empty storage has no text");
  Tpl host = Tpl::Make(L"", L"", 0);
  host.SetU32(sfio::tpl::cchAllocText, 0);
  Check(Tpl::Valid(host.Ptr(), host.b.size()) && host.Name().empty() && host.Notes().empty(),
        "accept evidenced host project with no declared text");
  Tpl malformed = t;
  malformed.SetU32(sfio::tpl::cbStruct, static_cast<DWORD>(Tpl::kMaxBytes + 1));
  Check(!Tpl::Valid(malformed.Ptr(), malformed.b.size()), "reject oversized declared allocation");
  malformed = t;
  malformed.SetU32(sfio::tpl::cbExtra, (std::numeric_limits<DWORD>::max)());
  Check(!Tpl::Valid(malformed.Ptr(), malformed.b.size()), "reject private-payload overflow");
  malformed = t;
  malformed.SetU32(sfio::tpl::cchAllocText, (std::numeric_limits<DWORD>::max)());
  Check(!Tpl::Valid(malformed.Ptr(), malformed.b.size()), "reject text-span overflow");
  malformed = Tpl::Make(L"", L"", 0);
  const wchar_t nonzero = L'x';
  memcpy(malformed.b.data() + sfio::tpl::abExtra + sizeof(wchar_t), &nonzero, sizeof nonzero);
  Check(!Tpl::Valid(malformed.Ptr(), malformed.b.size()) && malformed.Name().empty(),
        "reject missing notes terminator without reading outside text");
  Check(Throws<std::invalid_argument>([&] { Tpl::Copy(malformed.Ptr(), malformed.b.size()); }),
        "copy rejects malformed text");
  Check(Throws<std::length_error>([] { Tpl::Make(L"", L"", (std::numeric_limits<DWORD>::max)()); }) &&
        Throws<std::invalid_argument>([] { Tpl::Make(nullptr, L"", 0); }), "construction allocation and input bounds");
  const auto record = Float32Record(48000, 2);
  Check(record.cbRecord == 32 && record.format == sfio::SFAUDIO_FORMAT_FLOAT32 &&
        record.blockAlign == 8 && record.avgBytesPerSec == 384000 && !record.unknown10 &&
        !record.unknown14 && !record.unknown18, "float32 record matches evidenced fields");
  Check(Throws<std::invalid_argument>([] { Float32Record(48000, 16384); }) &&
        Throws<std::invalid_argument>([] { Float32Record((std::numeric_limits<DWORD>::max)(), 2); }) &&
        Throws<std::invalid_argument>([] { Float32Record(0, 2); }) &&
        Throws<std::invalid_argument>([] { Float32Record(48000, 0); }), "float32 record rejects narrowing and zero format");
}

void Leases() {
  static_assert(!std::is_copy_constructible_v<FrameLease> && !std::is_move_constructible_v<FrameLease>);
  Video video;
  LONGLONG outstanding = 0;
  {
    FrameLease lease(&video, 42, outstanding);
    Check(outstanding == 1 && lease.Release() == S_OK && outstanding == 0, "explicit lease release and accounting");
    Check(lease.Release() == S_FALSE && video.releases == 1, "repeat release is idempotent");
  }
  Check(video.releases == 1 && video.lastLock == 42, "destructor does not repeat explicit release");
  {
    FrameLease lease(&video, 43, outstanding);
  }
  Check(video.releases == 2 && outstanding == 0, "destructor releases a held lease");
  try {
    FrameLease lease(&video, 44, outstanding);
    throw std::runtime_error("exercise unwind");
  } catch (const std::runtime_error&) {}
  Check(video.releases == 3 && outstanding == 0 && video.lastLock == 44, "exception unwinding releases exactly once");
  video.releaseResult = E_FAIL;
  {
    FrameLease lease(&video, 45, outstanding);
    Check(lease.Release() == E_FAIL && outstanding == 1 && lease.Release() == S_FALSE,
          "failed release is recorded and not retried");
  }
  Check(video.releases == 4 && outstanding == 1, "failed host unlock remains unconfirmed in accounting");
  Check(Throws<std::invalid_argument>([&] { FrameLease lease(nullptr, 0, outstanding); }), "null lease rejected");
}
}  // namespace

int main() {
  Templates();
  Leases();
  printf("HOST HELPERS %s (%d failure(s))\n", failures ? "FAILED" : "PASSED", failures);
  return failures ? 1 : 0;
}
