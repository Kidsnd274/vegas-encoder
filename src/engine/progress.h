#pragma once
#include "../core/core.h"
#include <functional>

namespace vegas_encoder {
// Incremental bounded parser. Unknown/invalid metrics remain null; only complete
// progress=continue/end records are observed. Never buffers an entire stdout log.
class ProgressParser {
 public:
  using Observer = std::function<void(const ve::Json&)>;
  explicit ProgressParser(Observer observer) : observer_(std::move(observer)) {}
  void Feed(const char* bytes, size_t count);
  size_t Buffered() const { return line_.size(); }
 private:
  void Line();
  Observer observer_;
  std::string line_;
  bool discard_ = false;
  ve::Json metrics_ = ve::Json::object();
};
} // namespace vegas_encoder
