// Checked byte storage for the evidence-backed VEGAS template subset.
// Native layout evidence: investigation F-033/F-036. This is an internal helper.
#pragma once

#include "../abi/sfio_abi.h"

#include <cstddef>
#include <string>
#include <vector>

namespace vegas_encoder::host {

struct Tpl {
  static constexpr size_t kMaxBytes = 1u << 20;
  std::vector<BYTE> b;

  // The one-argument overload trusts that the host supplied readable header and
  // payload memory. A declared size cannot prove arbitrary pointer readability.
  static bool Valid(const sfio::SFTEMPLATE* t);
  static bool Valid(const sfio::SFTEMPLATE* t, size_t availableBytes);
  static Tpl Copy(const sfio::SFTEMPLATE* t);
  static Tpl Copy(const sfio::SFTEMPLATE* t, size_t availableBytes);
  static Tpl Make(const wchar_t* name, const wchar_t* notes, DWORD cbExtra);

  bool HasSpan(size_t off, size_t n) const noexcept;
  DWORD U32(size_t off) const;
  void SetU32(size_t off, DWORD v);
  double F64(size_t off) const;
  void SetF64(size_t off, double v);
  GUID Guid(size_t off) const;
  void SetGuid(size_t off, const GUID& g);
  BITMAPINFOHEADER Bih(size_t off) const;
  void SetBih(size_t off, const BITMAPINFOHEADER& h);
  sfio::SFAUDIORECORD Audio(size_t off) const;
  void SetAudio(size_t off, const sfio::SFAUDIORECORD& r);
  bool Zero(size_t off, size_t n) const;
  std::wstring Name() const;
  std::wstring Notes() const;
  const sfio::SFTEMPLATE* Ptr() const {
    return reinterpret_cast<const sfio::SFTEMPLATE*>(b.data());
  }

 private:
  void RequireSpan(size_t off, size_t n) const;
  std::wstring TextField(unsigned which) const;
};

// Reject unrepresentable fields instead of narrowing WORD/DWORD arithmetic.
sfio::SFAUDIORECORD Float32Record(DWORD rate, WORD channels);

}  // namespace vegas_encoder::host
