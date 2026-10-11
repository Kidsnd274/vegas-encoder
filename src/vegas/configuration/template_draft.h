// Owned-template editing scaffold for A5/A6; not connected to VEGAS yet.
#pragma once

#include "../host/template.h"
#include "../../settings/diagnostic_settings.h"

namespace vegas_encoder::configuration {

// Provisional proof bytes inside the current 64-byte VENC marker's reserved
// region. This is not the A7 recipe schema and is not emitted by the exporter.
inline constexpr size_t kProofOffset = sfio::tpl::abExtra + 12;
inline constexpr DWORD kProofMagic = 0x31474643;  // "CFG1"

settings::DiagnosticSettings ReadProofSettings(const host::Tpl& value);
host::Tpl WithProofSettings(const host::Tpl& value, settings::DiagnosticSettings settings);

class TemplateDraft final {
 public:
  explicit TemplateDraft(const host::Tpl& value);
  bool ExtraReport() const noexcept { return pending_.extraReport; }
  void SetExtraReport(bool enabled) noexcept { pending_.extraReport = enabled; }
  bool Dirty() const noexcept { return pending_.extraReport != committed_.extraReport; }
  host::Tpl Prepare() const;
  // Accept only after the store reports a committed copy. Swapping is noexcept,
  // so an allocation/commit failure cannot incorrectly mark the draft clean.
  void Accept(host::Tpl& committedValue) noexcept;

 private:
  host::Tpl base_;
  settings::DiagnosticSettings committed_, pending_;
};

}  // namespace vegas_encoder::configuration
