// Caller-thread ownership of one successful GetRenderFrame acquisition.
// Native lifetime evidence: investigation F-030/F-031/F-045/F-048.
#pragma once

#include "../abi/sfio_abi.h"

#include <limits>
#include <stdexcept>

namespace vegas_encoder::host {

struct ComRelease {
  void operator()(IUnknown* p) const { if (p) p->Release(); }
};

class FrameLease {
 public:
  FrameLease(sfio::ISfReadVideoRenderStream* video, LONG_PTR lock, LONGLONG& outstanding)
      : video_(video), lock_(lock), outstanding_(outstanding) {
    if (!video_) throw std::invalid_argument("null frame lease stream");
    if (outstanding_ == (std::numeric_limits<LONGLONG>::max)())
      throw std::overflow_error("frame lease accounting overflow");
    ++outstanding_;
  }
  FrameLease(const FrameLease&) = delete;
  FrameLease& operator=(const FrameLease&) = delete;
  FrameLease(FrameLease&&) = delete;
  FrameLease& operator=(FrameLease&&) = delete;

  // Release is attempted once, even if the host reports failure. The counter
  // remains nonzero on failure because successful unlock is then unconfirmed.
  HRESULT Release() {
    if (!held_) return S_FALSE;
    held_ = false;
    const HRESULT hr = video_->ReleaseRenderFrame(lock_);
    if (SUCCEEDED(hr)) --outstanding_;
    return hr;
  }
  ~FrameLease() { if (held_) Release(); }

 private:
  sfio::ISfReadVideoRenderStream* video_;
  LONG_PTR lock_;
  LONGLONG& outstanding_;
  bool held_ = true;
};

}  // namespace vegas_encoder::host
