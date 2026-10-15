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

// What to ask for in the Save dialog. Strings are UTF-8.
struct SaveFileRequest {
  std::string title;
  // The suggested file name, for example "YouTube upload.vepreset".
  std::string file_name;
  // The filter's name and pattern, for example "Vegas Encoder preset" and
  // "*.vepreset"; the extension without the dot, for example "vepreset", is
  // added when the user types a name without one.
  std::string filter_name;
  std::string filter_pattern;
  std::string default_extension;
};

// Shows the Windows Save dialog, modal to |owner|. It asks before replacing
// an existing file. Returns the chosen full path in UTF-8, or nothing if the
// user cancelled or the dialog failed. Writes nothing itself.
std::optional<std::string> ShowSaveFileDialog(HWND owner,
                                              const SaveFileRequest& request);

#endif  // RUNNER_FILE_DIALOG_H_
