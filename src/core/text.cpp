#include "core.h"
#include <cctype>

namespace ve {
std::vector<size_t> Utf16Map(const std::string& text) {
    std::vector<size_t> offsets(text.size()+1,0);
    for (size_t i = 0; i < text.size(); ++i) {
        const auto c = static_cast<unsigned char>(text[i]);
        offsets[i+1] = offsets[i] + ((c & 0xc0) == 0x80 ? 0 : c >= 0xf0 ? 2 : 1);
    }
    return offsets;
}
size_t Utf16Offset(const std::string& text, size_t byteOffset) {
    size_t count = 0;
    for (size_t i = 0; i < byteOffset && i < text.size(); ++i) {
        const auto c = static_cast<unsigned char>(text[i]);
        if ((c & 0xc0) != 0x80) count += c >= 0xf0 ? 2 : 1;
    }
    return count;
}
size_t Utf8Offset(const std::string& text, size_t position) {
    size_t units = 0, i = 0;
    while (i < text.size() && units < position) {
        const auto c = static_cast<unsigned char>(text[i]);
        units += c >= 0xf0 ? 2 : 1;
        i += c < 0x80 ? 1 : c < 0xe0 ? 2 : c < 0xf0 ? 3 : 4;
    }
    if (units != position) throw Error(VE_INVALID_ARGUMENT,"CARET-BOUNDARY","Caret splits a surrogate pair or lies outside the text.");
    return i;
}
std::vector<Word> Tokenize(const std::string& text) {
    std::vector<Word> words;
    size_t i = 0;
    while (i < text.size()) {
        while (i < text.size() && std::isspace(static_cast<unsigned char>(text[i]))) ++i;
        if (i == text.size()) break;
        // Continuations accepted for pasted cmd/PowerShell/bash commands.
        if ((text[i] == '^' || text[i] == '\\' || text[i] == '`') && i + 1 < text.size() &&
            (text[i+1] == '\r' || text[i+1] == '\n')) { ++i; continue; }
        Word word; word.start = i;
        bool quoted = false;
        while (i < text.size() && (quoted || !std::isspace(static_cast<unsigned char>(text[i])))) {
            if (text[i] == '\\') {
                const size_t start = i;
                while (i < text.size() && text[i] == '\\') ++i;
                const size_t slashCount = i - start;
                if (i < text.size() && text[i] == '"') {
                    word.text.append(slashCount / 2, '\\');
                    if (slashCount % 2) word.text += '"';
                    else if (quoted && i + 1 < text.size() && text[i+1] == '"') { word.text += '"'; ++i; }
                    else quoted = !quoted;
                    ++i;
                } else if (!quoted && slashCount == 1 && i < text.size() && (text[i] == '\r' || text[i] == '\n')) break;
                else word.text.append(slashCount, '\\');
            } else if (text[i] == '"') {
                if (quoted && i + 1 < text.size() && text[i+1] == '"') { word.text += '"'; i += 2; }
                else { quoted = !quoted; ++i; }
            } else if (!quoted && (text[i] == '^' || text[i] == '`') && i + 1 < text.size() && (text[i+1] == '\r' || text[i+1] == '\n')) { ++i; break; }
            else word.text += text[i++];
        }
        word.end = i;
        if (quoted) throw Error(VE_INVALID_ARGUMENT,"UNTERMINATED-QUOTE","Close the double quote in the command.");
        words.push_back(std::move(word));
        if (words.size() > 16384) throw Error(VE_LIMIT_EXCEEDED,"TOKEN-LIMIT","Command exceeds 16384 tokens.");
    }
    return words;
}
std::string Quote(const std::string& text) {
    if (!text.empty() && text.find_first_of(" \t\r\n\"") == std::string::npos) return text;
    std::string result = "\""; size_t slashes = 0;
    for (const char c : text) {
        if (c == '\\') { ++slashes; continue; }
        result.append(c == '"' ? slashes * 2 + 1 : slashes, '\\');
        slashes = 0; result += c;
    }
    result.append(slashes * 2, '\\'); result += '"'; return result;
}
std::string OptionKey(const std::string& name) {
    if (name.empty()) return "";
    const auto colon = name.find(':');
    std::string key = name.substr(name.front() == '-' ? 1 : 0, colon == std::string::npos ? name.size() : colon - (name.front() == '-' ? 1 : 0));
    if (key == "codec" || key == "vcodec" || key == "acodec") key = "c";
    if (key == "qscale") key = "q";
    return key;
}
bool IsOption(const std::string& text) {
    return text.size() > 1 && text[0] == '-' &&
           (std::isalpha(static_cast<unsigned char>(text[1])) || text[1] == '_');
}
} // namespace ve
