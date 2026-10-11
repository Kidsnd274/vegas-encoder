#include "template_draft.h"

#include <stdexcept>

namespace vegas_encoder::configuration {
namespace {

void RequireProductMarker(const host::Tpl& value) {
  // Bound the complete owned span before interpreting any payload fields.
  if (!host::Tpl::Valid(value.Ptr(), value.b.size()) ||
      value.U32(sfio::tpl::cbExtra) != 64 ||
      value.U32(sfio::tpl::abExtra) != 0x434e4556 ||  // current "VENC" marker
      value.U32(sfio::tpl::abExtra + 4) != 1)
    throw std::invalid_argument("unrecognized Vegas Encoder proof template");
}

}  // namespace

settings::DiagnosticSettings ReadProofSettings(const host::Tpl& value) {
  RequireProductMarker(value);
  if (value.Zero(kProofOffset, 12)) return {};  // untouched 0.1.0-dev marker
  if (value.U32(kProofOffset) != kProofMagic || value.U32(kProofOffset + 4) != 1 ||
      value.U32(kProofOffset + 8) > 1)
    throw std::invalid_argument("unrecognized diagnostic setting proof bytes");
  return {value.U32(kProofOffset + 8) != 0};
}

host::Tpl WithProofSettings(const host::Tpl& value, settings::DiagnosticSettings settings) {
  (void)ReadProofSettings(value);  // never overwrite an unknown reserved format
  host::Tpl edited = value;
  edited.SetU32(kProofOffset, kProofMagic);
  edited.SetU32(kProofOffset + 4, 1);
  edited.SetU32(kProofOffset + 8, settings.extraReport ? 1 : 0);
  return edited;
}

TemplateDraft::TemplateDraft(const host::Tpl& value)
    : base_(value), committed_(ReadProofSettings(base_)), pending_(committed_) {}

host::Tpl TemplateDraft::Prepare() const { return WithProofSettings(base_, pending_); }

void TemplateDraft::Accept(host::Tpl& committedValue) noexcept {
  base_.b.swap(committedValue.b);
  committed_ = pending_;
}

}  // namespace vegas_encoder::configuration
