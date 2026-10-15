#include "file_dialog.h"

#include <shobjidl.h>

#include "utils.h"

namespace {

std::wstring Utf16FromUtf8(const std::string& text) {
  if (text.empty()) {
    return std::wstring();
  }
  const int length = MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS,
                                         text.data(),
                                         static_cast<int>(text.size()),
                                         nullptr, 0);
  if (length <= 0) {
    return std::wstring();
  }
  std::wstring wide(static_cast<size_t>(length), L'\0');
  MultiByteToWideChar(CP_UTF8, MB_ERR_INVALID_CHARS, text.data(),
                      static_cast<int>(text.size()), wide.data(), length);
  return wide;
}

// Releases a COM interface when it goes out of scope.
template <typename T>
class ComPtr {
 public:
  ~ComPtr() {
    if (ptr_ != nullptr) {
      ptr_->Release();
    }
  }
  T** put() { return &ptr_; }
  T* operator->() const { return ptr_; }

 private:
  T* ptr_ = nullptr;
};

// The file-system path of a dialog's result, in UTF-8.
std::optional<std::string> PathOf(ComPtr<IShellItem>& item) {
  PWSTR path = nullptr;
  if (FAILED(item->GetDisplayName(SIGDN_FILESYSPATH, &path)) ||
      path == nullptr) {
    return std::nullopt;
  }
  std::string utf8 = Utf8FromUtf16(path);
  CoTaskMemFree(path);
  if (utf8.empty()) {
    return std::nullopt;
  }
  return utf8;
}

}  // namespace

std::optional<std::string> ShowOpenFileDialog(HWND owner,
                                              const OpenFileRequest& request) {
  ComPtr<IFileOpenDialog> dialog;
  if (FAILED(CoCreateInstance(CLSID_FileOpenDialog, nullptr,
                              CLSCTX_INPROC_SERVER,
                              IID_PPV_ARGS(dialog.put())))) {
    return std::nullopt;
  }
  FILEOPENDIALOGOPTIONS options = 0;
  dialog->GetOptions(&options);
  dialog->SetOptions(options | FOS_FORCEFILESYSTEM | FOS_FILEMUSTEXIST |
                     FOS_PATHMUSTEXIST);

  const std::wstring title = Utf16FromUtf8(request.title);
  if (!title.empty()) {
    dialog->SetTitle(title.c_str());
  }
  const std::wstring filter_name = Utf16FromUtf8(request.filter_name);
  const std::wstring filter_pattern = Utf16FromUtf8(request.filter_pattern);
  if (!filter_pattern.empty()) {
    const COMDLG_FILTERSPEC filters[] = {
        {filter_name.empty() ? filter_pattern.c_str() : filter_name.c_str(),
         filter_pattern.c_str()},
        {L"Programs", L"*.exe"},
    };
    dialog->SetFileTypes(2, filters);
    dialog->SetFileTypeIndex(1);
  }

  // Show runs its own message loop until the dialog closes; HRESULT_FROM_WIN32
  // (ERROR_CANCELLED) means the user cancelled.
  if (FAILED(dialog->Show(owner))) {
    return std::nullopt;
  }
  ComPtr<IShellItem> item;
  if (FAILED(dialog->GetResult(item.put()))) {
    return std::nullopt;
  }
  return PathOf(item);
}

std::optional<std::string> ShowSaveFileDialog(HWND owner,
                                              const SaveFileRequest& request) {
  ComPtr<IFileSaveDialog> dialog;
  if (FAILED(CoCreateInstance(CLSID_FileSaveDialog, nullptr,
                              CLSCTX_INPROC_SERVER,
                              IID_PPV_ARGS(dialog.put())))) {
    return std::nullopt;
  }
  FILEOPENDIALOGOPTIONS options = 0;
  dialog->GetOptions(&options);
  dialog->SetOptions(options | FOS_FORCEFILESYSTEM | FOS_OVERWRITEPROMPT |
                     FOS_PATHMUSTEXIST | FOS_NOREADONLYRETURN);

  const std::wstring title = Utf16FromUtf8(request.title);
  if (!title.empty()) {
    dialog->SetTitle(title.c_str());
  }
  const std::wstring filter_name = Utf16FromUtf8(request.filter_name);
  const std::wstring filter_pattern = Utf16FromUtf8(request.filter_pattern);
  if (!filter_pattern.empty()) {
    const COMDLG_FILTERSPEC filters[] = {
        {filter_name.empty() ? filter_pattern.c_str() : filter_name.c_str(),
         filter_pattern.c_str()},
    };
    dialog->SetFileTypes(1, filters);
    dialog->SetFileTypeIndex(1);
  }
  const std::wstring extension = Utf16FromUtf8(request.default_extension);
  if (!extension.empty()) {
    dialog->SetDefaultExtension(extension.c_str());
  }
  const std::wstring file_name = Utf16FromUtf8(request.file_name);
  if (!file_name.empty()) {
    dialog->SetFileName(file_name.c_str());
  }

  if (FAILED(dialog->Show(owner))) {
    return std::nullopt;
  }
  ComPtr<IShellItem> item;
  if (FAILED(dialog->GetResult(item.put()))) {
    return std::nullopt;
  }
  return PathOf(item);
}
