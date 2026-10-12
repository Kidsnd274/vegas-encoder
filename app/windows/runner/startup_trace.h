#ifndef RUNNER_STARTUP_TRACE_H_
#define RUNNER_STARTUP_TRACE_H_

#include <string>

// Appends "<ms since process creation> <label>" lines to the file named by the
// VEGAS_ENCODER_STARTUP_TRACE environment variable. Does nothing when it is unset.
// Used to measure the TECH_ARCHITECTURE §9.3 start-time budget.
namespace startup_trace {

void Mark(const std::string& label);

}  // namespace startup_trace

#endif  // RUNNER_STARTUP_TRACE_H_
