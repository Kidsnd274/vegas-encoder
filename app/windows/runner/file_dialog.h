#ifndef RUNNER_FILE_DIALOG_H_
#define RUNNER_FILE_DIALOG_H_

#include <windows.h>

#include <optional>
#include <string>

// What to ask for in the Open dialog. Strings are UTF-8.
struct OpenFileRequest {
  std::string title;
  // The filter's name and pattern, for example "FFmpeg" and "ffmpeg.exe".
  std::string filter_name;
  std::string filter_pattern;
};

// Shows the Windows Open dialog, modal to |owner|, for one existing file.
// Returns its full path in UTF-8, or nothing if the user cancelled or the
// dialog failed. Runs on the window's thread (COM is initialized STA there).
std::optional<std::string> ShowOpenFileDialog(HWND owner,
                                              const OpenFileRequest& request);

#endif  // RUNNER_FILE_DIALOG_H_
