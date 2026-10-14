// B5 fake interface checks; no host launch, UI, installation or COM marshaling.
#include "../../src/vegas/host/progress_text_probe.h"
#include <cstdio>
#include <cwchar>
#include <stdexcept>
#include <thread>

using namespace vegas_encoder::host;
using namespace sfio;
namespace {
int failures = 0, checks = 0;
void Check(bool value, const char* name) {
  ++checks;
  if (!value) { ++failures; printf("FAIL: %s\n", name); }
}
class Progress final : public ISfProgress {
 public:
  HRESULT STDMETHODCALLTYPE QueryInterface(REFIID, void**) override { return E_NOINTERFACE; }
  ULONG STDMETHODCALLTYPE AddRef() override { ++refs; return 1; }
  ULONG STDMETHODCALLTYPE Release() override { --refs; return 1; }
  HRESULT STDMETHODCALLTYPE Slot3(LPCWSTR p, LONGLONG t) override {
    ++init; text = p; total = t; position = 0; return result;
  }
  HRESULT STDMETHODCALLTYPE Slot4(LPCWSTR p) override {
    ++updates;
    if (throws) throw std::runtime_error("text unavailable");
    text = p; return result;
  }
  HRESULT STDMETHODCALLTYPE SetTotal(LONGLONG t) override { total = t; return S_OK; }
  HRESULT STDMETHODCALLTYPE SetPosition(LONGLONG p) override { position = p; return result; }
  HRESULT STDMETHODCALLTYPE CheckCancel() override { return result; }
  HRESULT STDMETHODCALLTYPE Slot8(LONG) override { return E_NOTIMPL; }
  int refs = 0, init = 0, updates = 0;
  LPCWSTR text = nullptr;
  LONGLONG total = 90, position = 42;
  HRESULT result = S_OK;
  bool throws = false;
};
}
int main() {
  Progress p;
  Check(!IsInspectedProgress(&p) && !IsInspectedProgress(nullptr),
        "runtime identity rejects a fake/wrapper/null progress object");
  for (int mode : {0, 1, 5, -1}) {
    ProgressTextProbe probe(&p, mode); probe.Qualify(true);
    probe.Begin(90, 0, 0); probe.Update(1000, 0);
    Check(probe.Calls() == 0, "off/invalid mode makes no host text calls");
  }
  ProgressTextProbe unknown(&p, 4); unknown.Qualify(false);
  unknown.Begin(90, 0, 0); unknown.Update(1000, 0);
  Check(unknown.Calls() == 0, "unqualified host makes no text calls");
  ProgressTextProbe absent(nullptr, 4); absent.Qualify(true);
  absent.Begin(90, 0, 0); absent.Update(1000, 0);
  Check(absent.Calls() == 0, "missing progress is safe");
  {
    ProgressTextProbe probe(&p, 4); probe.Qualify(true);
    probe.Update(0, 0);
    Check(p.updates == 0, "no text calls before Begin");
    probe.Begin(90, 0, 0); probe.Update(0, 0);
    Check(p.updates == 1 && p.text == kProgressMarkerA, "first text marker is immediate and immutable");
    for (ULONGLONG t = 1; t < 500; ++t) probe.Update(t, 0);
    Check(probe.Calls() == 1, "repeated wait polls throttle below 500 ms");
    probe.Update(500, 0);
    Check(probe.Calls() == 2 && p.text == kProgressMarkerB, "500 ms boundary alternates marker");
    probe.Update(499, 0);
    Check(probe.Calls() == 2, "regressed time never bypasses throttle");
    probe.Update(1000, 0);
    Check(probe.Calls() == 3 && p.text == kProgressMarkerA, "third update preserves static lifetime");
    Check(p.total == 90 && p.position == 42 && p.init == 0, "slot 4 preserves numeric progress");
  }
  Check(std::wcscmp(p.text, kProgressMarkerA) == 0 && p.refs == 0,
        "host-retained marker survives probe destruction without reference leak");
  {
    ProgressTextProbe probe(&p, 3); probe.Qualify(true);
    probe.Begin(120, 0, 0); p.position = 7;
    probe.Begin(120, 1000, 0); probe.Update(2000, 0);
    Check(probe.Calls() == 1 && p.init == 1 && p.total == 120 && p.position == 7,
          "slot 3 only initializes once and never resets running progress");
  }
  for (int mode : {3, 4}) {
    ProgressTextProbe locked(&p, mode); locked.Qualify(true);
    locked.Begin(90, 0, 1); locked.Update(1000, 0);
    Check(locked.GuardFailed() && locked.Calls() == 0, "held host frame disables probe");
    ProgressTextProbe empty(&p, mode); empty.Qualify(true);
    empty.Begin(0, 0, 0); empty.Update(1000, 0);
    Check(empty.Calls() == 0, "nonpositive total disables probe");
    ProgressTextProbe other(&p, mode); other.Qualify(true);
    std::thread worker([&] { other.Begin(90, 0, 0); other.Update(1000, 0); });
    worker.join();
    Check(other.GuardFailed() && other.Calls() == 0, "non-caller thread never reaches host");
    for (HRESULT hr : {E_ACCESSDENIED, SF_E_PROGRESS_CANCELLED}) {
      p.result = hr;
      ProgressTextProbe failed(&p, mode); failed.Qualify(true);
      failed.Begin(90, 0, 0); failed.Update(0, 0); failed.Update(1000, 0);
      failed.Qualify(true); failed.Update(2000, 0);
      Check(failed.Calls() == 1 && !failed.Enabled() && failed.LastResult() == hr,
            "text failure disables future calls without becoming render cancellation");
    }
  }
  p.result = S_OK;
  ProgressTextProbe lateLock(&p, 4); lateLock.Qualify(true);
  lateLock.Begin(90, 0, 0); lateLock.Update(0, 1); lateLock.Update(500, 0);
  Check(lateLock.Calls() == 0 && lateLock.GuardFailed(), "later frame lease cannot reach text slot");
  ProgressTextProbe lateThread(&p, 4); lateThread.Qualify(true);
  lateThread.Begin(90, 0, 0);
  std::thread updater([&] { lateThread.Update(0, 0); }); updater.join();
  Check(lateThread.Calls() == 0 && lateThread.GuardFailed(), "later worker update cannot reach text slot");
  p.result = S_FALSE;
  ProgressTextProbe nonfailure(&p, 4); nonfailure.Qualify(true);
  nonfailure.Begin(90, 0, 0); nonfailure.Update(0, 0); nonfailure.Update(500, 0);
  Check(nonfailure.Enabled() && nonfailure.Calls() == 2, "successful non-S_OK is retained");
  p.throws = true;
  ProgressTextProbe throwing(&p, 4); throwing.Qualify(true);
  throwing.Begin(90, 0, 0); throwing.Update(0, 0); throwing.Update(500, 0);
  Check(throwing.Calls() == 1 && throwing.LastResult() == E_UNEXPECTED && !throwing.Enabled(),
        "optional C++ exception is contained");
  printf("NATIVE PROGRESS %s: %d checks, %d failures (fake interface)\n",
         failures ? "FAILED" : "PASSED", checks, failures);
  return failures ? 1 : 0;
}
