// Reads a template's name the way VEGAS does, independently of host::Tpl, so a
// regression shared by the exporter's own reader and writer cannot hide itself.
//
// VEGAS 2026.0.3.189, 23.0.0.278 and 22 read name\0notes\0 at abExtra plus
// cbExtra rounded up to four bytes (23 RVA 0x2DCC80, research F-059; 2026 and
// 22 runtime-observed). Names whose cbExtra % 4 == 2 lost their first letter
// ("H.264 (CPU)" shown as ".264 (CPU)") until private bytes were DWORD-padded.
#pragma once

#include "../../src/vegas/host/template.h"

#include <cstring>
#include <stdexcept>
#include <string>

namespace vegas_encoder::test {
inline std::wstring VegasDisplayName(const host::Tpl& value) {
  DWORD extra = 0;
  if (value.b.size() < sfio::tpl::fixedSize) throw std::runtime_error("template header is truncated");
  std::memcpy(&extra, value.b.data() + sfio::tpl::cbExtra, sizeof extra);
  std::wstring name;
  for (size_t at = sfio::tpl::abExtra + (static_cast<size_t>(extra) + 3) / 4 * 4; at + sizeof(wchar_t) <= value.b.size(); at += sizeof(wchar_t)) {
    wchar_t c = 0;
    std::memcpy(&c, value.b.data() + at, sizeof c);
    if (!c) return name;
    name += c;
  }
  throw std::runtime_error("template name is not terminated where VEGAS reads it");
}
}  // namespace vegas_encoder::test
