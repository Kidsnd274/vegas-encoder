// Focused checks for exception containment and lock release during unwinding.
// No VEGAS interfaces, application launch or plug-in installation are involved.
#include "../../src/support/native_boundary.h"

#include <cstdio>
#include <new>
#include <stdexcept>
#include <type_traits>
#include <utility>

using vegas_encoder::BestEffortDiagnostic;
using vegas_encoder::NativeBoundary;
using vegas_encoder::ScopedExclusiveSrwLock;

namespace {
int failures = 0;
void Check(bool success, const char* label) {
  printf("%s: %s\n", success ? "PASS" : "FAIL", label);
  if (!success) ++failures;
}

struct ThrowingNativeCall {
  HRESULT operator()() const { throw std::bad_alloc(); }
};
struct ThrowingDiagnostic {
  void operator()() const { throw std::runtime_error("optional diagnostic"); }
};
static_assert(noexcept(NativeBoundary(std::declval<ThrowingNativeCall>())));
static_assert(noexcept(BestEffortDiagnostic(std::declval<ThrowingDiagnostic>())));
static_assert(!std::is_copy_constructible_v<ScopedExclusiveSrwLock>);

struct Cleanup {
  bool& ran;
  ~Cleanup() noexcept { ran = true; }
};

void CheckLockAvailable(SRWLOCK& lock, const char* label) {
  const bool acquired = TryAcquireSRWLockExclusive(&lock) != FALSE;
  Check(acquired, label);
  if (acquired) ReleaseSRWLockExclusive(&lock);
}
}  // namespace

int main() {
  Check(NativeBoundary([] { return S_OK; }) == S_OK &&
        NativeBoundary([] { return S_FALSE; }) == S_FALSE &&
        NativeBoundary([] { return E_POINTER; }) == E_POINTER,
        "successful and failed HRESULTs pass through unchanged");
  Check(NativeBoundary(ThrowingNativeCall{}) == E_OUTOFMEMORY,
        "allocation failure becomes E_OUTOFMEMORY");
  Check(NativeBoundary([]() -> HRESULT { throw std::invalid_argument("bad native request"); }) == E_UNEXPECTED &&
        NativeBoundary([]() -> HRESULT { throw 7; }) == E_UNEXPECTED,
        "standard and nonstandard C++ failures become E_UNEXPECTED");

  bool cleanupRan = false;
  Check(NativeBoundary([&]() -> HRESULT {
          Cleanup cleanup{cleanupRan};
          throw std::bad_alloc();
        }) == E_OUTOFMEMORY && cleanupRan,
        "native failure unwinds acquired local resources before returning");

  SRWLOCK lock = SRWLOCK_INIT;
  Check(NativeBoundary([&]() -> HRESULT {
          ScopedExclusiveSrwLock held(lock);
          throw std::bad_alloc();
        }) == E_OUTOFMEMORY,
        "allocation failure inside a locked native call is contained");
  CheckLockAvailable(lock, "native failure releases exclusive lock");
  BestEffortDiagnostic([&] {
    ScopedExclusiveSrwLock held(lock);
    throw std::runtime_error("formatting or map allocation failure");
  });
  CheckLockAvailable(lock, "optional diagnostic failure releases exclusive lock");

  const HRESULT result = NativeBoundary([&] {
    BestEffortDiagnostic(ThrowingDiagnostic{});
    BestEffortDiagnostic(ThrowingNativeCall{});
    return S_OK;
  });
  Check(result == S_OK, "optional diagnostic failures preserve a successful native result");
  bool diagnosticRan = false;
  BestEffortDiagnostic([&] { diagnosticRan = true; });
  Check(diagnosticRan, "diagnostics still execute when they succeed");

  printf("NATIVE BOUNDARY %s (%d failure(s))\n", failures ? "FAILED" : "PASSED", failures);
  return failures ? 1 : 0;
}
