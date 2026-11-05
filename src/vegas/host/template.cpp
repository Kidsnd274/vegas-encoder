#include "template.h"

#include <cstring>
#include <cstdint>
#include <limits>
#include <stdexcept>

namespace vegas_encoder::host {
namespace {

template <class T>
T Read(const BYTE* p) {
  T value{};
  memcpy(&value, p, sizeof value);
  return value;
}

size_t BoundedTextLength(const wchar_t* text) {
  if (!text) throw std::invalid_argument("null template text");
  for (size_t n = 0; n < Tpl::kMaxBytes / sizeof(wchar_t); ++n)
    if (!text[n]) return n;
  throw std::length_error("template text exceeds maximum allocation");
}

uint64_t RoundedExtra(DWORD extra) { return (static_cast<uint64_t>(extra) + 3) / 4 * 4; }

// Where name\0notes\0 starts. VEGAS reads it at abExtra + cbExtra rounded up to
// four bytes, and saves templates in that layout with zero padding before the
// text (2026.0.3.189 and 23.0.0.278 runtime-observed; docs/LEGACY_NAMING.md).
// Older Vegas Encoder builds wrote WORD-padded private bytes with the text right
// after them; such bytes have no zero gap or no room for the rounded span, and
// keep their raw position. Every current writer makes cbExtra a multiple of 4,
// so both readings agree for new templates. Returns 0 if neither span fits.
uint64_t TextStart(const BYTE* bytes, DWORD cb, DWORD cch, DWORD extra) {
  const uint64_t raw = sfio::tpl::fixedSize + static_cast<uint64_t>(extra);
  const uint64_t rounded = sfio::tpl::fixedSize + RoundedExtra(extra);
  const uint64_t text = sizeof(wchar_t) * static_cast<uint64_t>(cch);
  if (rounded + text <= cb) {
    bool gapZero = true;
    for (uint64_t i = raw; i < rounded; ++i) gapZero = gapZero && bytes[i] == 0;
    if (gapZero) return rounded;
  }
  return raw + text <= cb ? raw : 0;
}

}  // namespace

bool Tpl::Valid(const sfio::SFTEMPLATE* t) {
  if (!t) return false;
  const auto* bytes = reinterpret_cast<const BYTE*>(t);
  return Valid(t, Read<DWORD>(bytes + sfio::tpl::cbStruct));
}

bool Tpl::Valid(const sfio::SFTEMPLATE* t, size_t availableBytes) {
  if (!t || availableBytes < sfio::tpl::fixedSize) return false;
  const auto* bytes = reinterpret_cast<const BYTE*>(t);
  const DWORD cb = Read<DWORD>(bytes + sfio::tpl::cbStruct);
  if (cb < sfio::tpl::fixedSize || cb > kMaxBytes || cb > availableBytes) return false;
  const DWORD cch = Read<DWORD>(bytes + sfio::tpl::cchAllocText);
  const DWORD extra = Read<DWORD>(bytes + sfio::tpl::cbExtra);
  if (static_cast<uint64_t>(extra) > cb) return false;
  const uint64_t start = TextStart(bytes, cb, cch, extra);
  if (!start) return false;
  // F-036's 540-byte host project template declares zero text characters.
  if (!cch) return true;
  if (cch < 2) return false;
  // Both name and notes must terminate inside the declared text span. Read via
  // memcpy so an odd private-payload length does not assume wchar_t alignment.
  unsigned terminated = 0;
  for (DWORD i = 0; i < cch; ++i) {
    if (!Read<wchar_t>(bytes + static_cast<size_t>(start) + sizeof(wchar_t) * i) && ++terminated == 2)
      return true;
  }
  return false;
}

Tpl Tpl::Copy(const sfio::SFTEMPLATE* t) {
  if (!Valid(t)) throw std::invalid_argument("invalid VEGAS template");
  const auto* bytes = reinterpret_cast<const BYTE*>(t);
  return Copy(t, Read<DWORD>(bytes + sfio::tpl::cbStruct));
}

Tpl Tpl::Copy(const sfio::SFTEMPLATE* t, size_t availableBytes) {
  if (!Valid(t, availableBytes)) throw std::invalid_argument("invalid VEGAS template span");
  const auto* bytes = reinterpret_cast<const BYTE*>(t);
  const DWORD cb = Read<DWORD>(bytes + sfio::tpl::cbStruct);
  Tpl result;
  result.b.assign(bytes, bytes + cb);
  return result;
}

Tpl Tpl::Make(const wchar_t* name, const wchar_t* notes, DWORD cbExtra) {
  const size_t nameChars = BoundedTextLength(name) + 1;
  const size_t notesChars = BoundedTextLength(notes) + 1;
  const uint64_t chars = static_cast<uint64_t>(nameChars) + notesChars;
  const uint64_t total = sfio::tpl::fixedSize + RoundedExtra(cbExtra) + sizeof(wchar_t) * chars;
  if (total > kMaxBytes) throw std::length_error("template exceeds maximum allocation");
  Tpl t;
  t.b.assign(static_cast<size_t>(total), 0);
  t.SetU32(sfio::tpl::cbStruct, static_cast<DWORD>(total));
  t.SetU32(sfio::tpl::dwVer, sfio::tpl::versionPlugin);
  t.SetU32(sfio::tpl::cchAllocText, static_cast<DWORD>(chars));
  t.SetU32(sfio::tpl::cbExtra, cbExtra);
  const size_t start = static_cast<size_t>(sfio::tpl::abExtra + RoundedExtra(cbExtra));
  memcpy(t.b.data() + start, name, sizeof(wchar_t) * nameChars);
  memcpy(t.b.data() + start + sizeof(wchar_t) * nameChars, notes, sizeof(wchar_t) * notesChars);
  return t;
}

bool Tpl::HasSpan(size_t off, size_t n) const noexcept {
  return off <= b.size() && n <= b.size() - off;
}

void Tpl::RequireSpan(size_t off, size_t n) const {
  if (!HasSpan(off, n)) throw std::out_of_range("VEGAS template field outside owned byte span");
}

DWORD Tpl::U32(size_t off) const { RequireSpan(off, sizeof(DWORD)); return Read<DWORD>(b.data() + off); }
void Tpl::SetU32(size_t off, DWORD v) { RequireSpan(off, sizeof v); memcpy(b.data() + off, &v, sizeof v); }
double Tpl::F64(size_t off) const { RequireSpan(off, sizeof(double)); return Read<double>(b.data() + off); }
void Tpl::SetF64(size_t off, double v) { RequireSpan(off, sizeof v); memcpy(b.data() + off, &v, sizeof v); }
GUID Tpl::Guid(size_t off) const { RequireSpan(off, sizeof(GUID)); return Read<GUID>(b.data() + off); }
void Tpl::SetGuid(size_t off, const GUID& v) { RequireSpan(off, sizeof v); memcpy(b.data() + off, &v, sizeof v); }
BITMAPINFOHEADER Tpl::Bih(size_t off) const {
  RequireSpan(off, sizeof(BITMAPINFOHEADER)); return Read<BITMAPINFOHEADER>(b.data() + off);
}
void Tpl::SetBih(size_t off, const BITMAPINFOHEADER& v) { RequireSpan(off, sizeof v); memcpy(b.data() + off, &v, sizeof v); }
sfio::SFAUDIORECORD Tpl::Audio(size_t off) const {
  RequireSpan(off, sizeof(sfio::SFAUDIORECORD)); return Read<sfio::SFAUDIORECORD>(b.data() + off);
}
void Tpl::SetAudio(size_t off, const sfio::SFAUDIORECORD& v) { RequireSpan(off, sizeof v); memcpy(b.data() + off, &v, sizeof v); }
bool Tpl::Zero(size_t off, size_t n) const {
  RequireSpan(off, n);
  for (size_t i = 0; i < n; ++i) if (b[off + i]) return false;
  return true;
}

size_t Tpl::TextOffset() const {
  if (!Valid(Ptr(), b.size())) throw std::invalid_argument("invalid VEGAS template");
  return static_cast<size_t>(TextStart(b.data(), U32(sfio::tpl::cbStruct), U32(sfio::tpl::cchAllocText), U32(sfio::tpl::cbExtra)));
}

std::wstring Tpl::TextField(unsigned which) const {
  if (!Valid(Ptr(), b.size())) return L"";
  const size_t start = TextOffset();
  const size_t cch = U32(sfio::tpl::cchAllocText);
  size_t i = 0;
  for (unsigned field = 0; field < which; ++field) {
    while (i < cch && Read<wchar_t>(b.data() + start + sizeof(wchar_t) * i)) ++i;
    if (i < cch) ++i;
  }
  std::wstring result;
  while (i < cch) {
    const wchar_t value = Read<wchar_t>(b.data() + start + sizeof(wchar_t) * i++);
    if (!value) break;
    result += value;
  }
  return result;
}
std::wstring Tpl::Name() const { return TextField(0); }
std::wstring Tpl::Notes() const { return TextField(1); }

sfio::SFAUDIORECORD Float32Record(DWORD rate, WORD channels) {
  const uint64_t align = 4ull * channels;
  const uint64_t average = align * rate;
  if (!rate || !channels || align > (std::numeric_limits<WORD>::max)() ||
      average > (std::numeric_limits<DWORD>::max)())
    throw std::invalid_argument("unrepresentable float32 audio record");
  sfio::SFAUDIORECORD result{};
  result.cbRecord = sizeof result;
  result.format = sfio::SFAUDIO_FORMAT_FLOAT32;
  result.sampleRate = rate;
  result.channels = channels;
  result.blockAlign = static_cast<WORD>(align);
  result.avgBytesPerSec = static_cast<DWORD>(average);
  return result;
}

}  // namespace vegas_encoder::host
