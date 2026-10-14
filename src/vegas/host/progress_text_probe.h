#pragma once
#include "../abi/sfio_abi.h"
#include "../../support/native_boundary.h"

namespace vegas_encoder::host {

// B5 developer probe only. Exact CSfRenderProgress stores the pointer, not a
// copy (docs/NATIVE_PROGRESS.md). Never pass a temporary/dynamic string here.
// Literals remain valid after Render returns until the native module unloads.
inline constexpr wchar_t kProgressMarkerA[] = L"Vegas Encoder B5: text marker A";
inline constexpr wchar_t kProgressMarkerB[] = L"Vegas Encoder B5: text marker B";

inline bool IsInspectedProgress(sfio::ISfProgress* progress) noexcept {
  // Check the actual in-process implementation as well as the executable hash.
  // A wrapper or another progress class must not inherit this qualification.
  if (!progress) return false;
  const auto base = reinterpret_cast<uintptr_t>(GetModuleHandleW(nullptr));
  const auto table = *reinterpret_cast<const uintptr_t* const*>(progress);
  return reinterpret_cast<uintptr_t>(table) == base + 0xAAD890 &&
         table[3] == base + 0x263D30 && table[4] == base + 0x263D50;
}

class ProgressTextProbe final {
 public:
  ProgressTextProbe(sfio::ISfProgress* progress, int mode) noexcept
      : progress_(progress), mode_(mode), caller_(GetCurrentThreadId()) {}
  void Qualify(bool exactTarget) noexcept {
    if (!begun_ && !guardFailed_)
      enabled_ = exactTarget && progress_ && (mode_ == 3 || mode_ == 4);
  }
  void Begin(LONGLONG total, ULONGLONG now, LONGLONG locks) noexcept {
    if (begun_ || !enabled_) return;
    begun_ = true;
    if (!Guard(locks) || total <= 0) { enabled_ = false; return; }
    if (mode_ == 3) {
      // Initialize once before any frame/transport wait. Slot 3 resets position;
      // it must never be used for repeated status updates.
      Call([&] { return progress_->Slot3(kProgressMarkerA, total); }, now);
    }
  }
  void Update(ULONGLONG now, LONGLONG locks) noexcept {
    if (!enabled_ || !begun_ || mode_ != 4 || !Guard(locks)) return;
    if (calls_ && (now < lastMs_ || now - lastMs_ < 500)) return;
    const auto* text = calls_ % 2 ? kProgressMarkerB : kProgressMarkerA;
    Call([&] { return progress_->Slot4(text); }, now);
  }
  unsigned Calls() const noexcept { return calls_; }
  HRESULT LastResult() const noexcept { return lastHr_; }
  ULONGLONG MaxCallMs() const noexcept { return maxCallMs_; }
  bool GuardFailed() const noexcept { return guardFailed_; }
  bool Enabled() const noexcept { return enabled_; }

 private:
  bool Guard(LONGLONG locks) noexcept {
    if (GetCurrentThreadId() == caller_ && locks == 0) return true;
    guardFailed_ = true;
    enabled_ = false;
    return false;
  }
  template<class F> void Call(F&& call, ULONGLONG now) noexcept {
    const auto start = GetTickCount64();
    lastHr_ = NativeBoundary(call);
    const auto elapsed = GetTickCount64() - start;
    if (elapsed > maxCallMs_) maxCallMs_ = elapsed;
    lastMs_ = now;
    ++calls_;
    if (FAILED(lastHr_)) enabled_ = false; // Optional text never stops a render.
  }
  sfio::ISfProgress* progress_; // Render-scoped borrow; never sent to a worker.
  int mode_;
  DWORD caller_;
  bool enabled_ = false, begun_ = false, guardFailed_ = false;
  unsigned calls_ = 0;
  HRESULT lastHr_ = S_OK;
  ULONGLONG lastMs_ = 0, maxCallMs_ = 0;
};
} // namespace vegas_encoder::host
