#include "progress.h"
#include <charconv>
#include <cmath>

namespace vegas_encoder {
void ProgressParser::Feed(const char* bytes, size_t count) {
  for (size_t i = 0; i < count; ++i) {
    if (bytes[i] == '\n') { if (!discard_) Line(); line_.clear(); discard_ = false; }
    else if (!discard_) {
      if (line_.size() == 4096) { line_.clear(); discard_ = true; }
      else line_ += bytes[i];
    }
  }
}
void ProgressParser::Line() {
  if (!line_.empty() && line_.back() == '\r') line_.pop_back();
  const auto equal = line_.find('=');
  if (equal == std::string::npos) return;
  const auto key = line_.substr(0, equal); auto value = line_.substr(equal + 1);
  if (key == "progress") {
    if (value == "continue" || value == "end") observer_(metrics_);
    metrics_ = ve::Json::object(); return;
  }
  const bool integer = key == "frame" || key == "total_size";
  const char* field = key == "frame" ? "framesDone" : key == "total_size" ? "bytesWritten" :
    key == "fps" ? "encodeFps" : key == "speed" ? "speed" : key == "bitrate" ? "bitrateKbps" : nullptr;
  if (!field) return;
  metrics_[field] = nullptr;
  if (integer) {
    int64_t number = 0;
    const auto parsed = std::from_chars(value.data(), value.data() + value.size(), number);
    if (parsed.ec == std::errc() && parsed.ptr == value.data() + value.size() && number >= 0) metrics_[field] = number;
    return;
  }
  if (key == "speed" && !value.empty() && value.back() == 'x') value.pop_back();
  if (key == "bitrate" && value.size() >= 7 && value.substr(value.size() - 7) == "kbits/s") value.resize(value.size() - 7);
  if (value.empty()) return;
  const auto first = value.find_first_not_of(" \t"), last = value.find_last_not_of(" \t");
  if (first == std::string::npos) return;
  // Machine protocol decimals must not depend on VEGAS's global C locale.
  double number = 0;
  const auto parsed = std::from_chars(value.data()+first,value.data()+last+1,number);
  if (parsed.ec == std::errc() && parsed.ptr == value.data()+last+1 && std::isfinite(number) && number >= 0) metrics_[field] = number;
}
} // namespace vegas_encoder
