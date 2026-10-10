// Internal containment for C++ failures at native HRESULT entry points.
// This does not catch structured exceptions or validate arbitrary host pointers.
#pragma once

#include <windows.h>
#include <new>

namespace vegas_encoder {

template <class Action>
HRESULT NativeBoundary(Action&& action) noexcept {
  try {
    return action();
  } catch (const std::bad_alloc&) {
    return E_OUTOFMEMORY;
  } catch (...) {
    return E_UNEXPECTED;
  }
}

// Build allocating diagnostic arguments inside this callback, so an optional
// log cannot change an otherwise successful native result or ownership transfer.
template <class Action>
void BestEffortDiagnostic(Action&& action) noexcept {
  try {
    action();
  } catch (...) {
    // Do not call logging recursively from a diagnostic failure handler.
  }
}

class ScopedExclusiveSrwLock final {
 public:
  explicit ScopedExclusiveSrwLock(SRWLOCK& lock) noexcept : lock_(lock) {
    AcquireSRWLockExclusive(&lock_);
  }
  ~ScopedExclusiveSrwLock() noexcept { ReleaseSRWLockExclusive(&lock_); }
  ScopedExclusiveSrwLock(const ScopedExclusiveSrwLock&) = delete;
  ScopedExclusiveSrwLock& operator=(const ScopedExclusiveSrwLock&) = delete;

 private:
  SRWLOCK& lock_;
};

}  // namespace vegas_encoder
