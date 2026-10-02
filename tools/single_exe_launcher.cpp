#include <windows.h>
#include <shellapi.h>

#include <cstdint>
#include <algorithm>
#include <fstream>
#include <string>
#include <vector>

namespace {

constexpr char kMarker[] = "INFLUENCOR_PAYLOAD_V1";
constexpr std::size_t kMarkerLen = sizeof(kMarker) - 1;

std::wstring quote(const std::wstring& value) {
  std::wstring out = L"\"";
  for (wchar_t ch : value) {
    if (ch == L'"') out += L'\\';
    out += ch;
  }
  out += L"\"";
  return out;
}

std::wstring modulePath() {
  std::vector<wchar_t> buffer(MAX_PATH);
  while (true) {
    const DWORD len =
        GetModuleFileNameW(nullptr, buffer.data(), static_cast<DWORD>(buffer.size()));
    if (len == 0) return L"";
    if (len < buffer.size() - 1) return std::wstring(buffer.data(), len);
    buffer.resize(buffer.size() * 2);
  }
}

std::wstring localAppData() {
  DWORD needed = GetEnvironmentVariableW(L"LOCALAPPDATA", nullptr, 0);
  if (needed == 0) return L"";
  std::wstring value(needed, L'\0');
  GetEnvironmentVariableW(L"LOCALAPPDATA", &value[0], needed);
  while (!value.empty() && value.back() == L'\0') value.pop_back();
  return value;
}

bool extractPayload(const std::wstring& self, const std::wstring& zipPath) {
  std::ifstream in(self, std::ios::binary);
  if (!in) return false;
  in.seekg(0, std::ios::end);
  const std::streamoff fileSize = in.tellg();
  const std::streamoff trailerSize = static_cast<std::streamoff>(8 + kMarkerLen);
  if (fileSize <= trailerSize) return false;

  in.seekg(fileSize - static_cast<std::streamoff>(kMarkerLen));
  std::string marker(kMarkerLen, '\0');
  in.read(&marker[0], marker.size());
  if (marker != kMarker) return false;

  in.seekg(fileSize - trailerSize);
  std::uint64_t payloadSize = 0;
  in.read(reinterpret_cast<char*>(&payloadSize), sizeof(payloadSize));
  if (payloadSize == 0 ||
      payloadSize > static_cast<std::uint64_t>(fileSize - trailerSize)) {
    return false;
  }

  const std::streamoff payloadStart =
      fileSize - trailerSize - static_cast<std::streamoff>(payloadSize);
  in.seekg(payloadStart);

  std::ofstream out(zipPath, std::ios::binary | std::ios::trunc);
  if (!out) return false;

  std::vector<char> buffer(1024 * 1024);
  std::uint64_t remaining = payloadSize;
  while (remaining > 0) {
    const std::size_t want = static_cast<std::size_t>(
        std::min<std::uint64_t>(
            remaining, static_cast<std::uint64_t>(buffer.size())));
    in.read(buffer.data(), want);
    const std::streamsize got = in.gcount();
    if (got <= 0) return false;
    out.write(buffer.data(), got);
    remaining -= static_cast<std::uint64_t>(got);
  }
  return true;
}

bool runAndWait(const std::wstring& commandLine) {
  std::vector<wchar_t> mutableCommand(commandLine.begin(), commandLine.end());
  mutableCommand.push_back(L'\0');

  STARTUPINFOW startup{};
  startup.cb = sizeof(startup);
  PROCESS_INFORMATION process{};
  if (!CreateProcessW(nullptr, mutableCommand.data(), nullptr, nullptr, FALSE,
                      CREATE_NO_WINDOW, nullptr, nullptr, &startup, &process)) {
    return false;
  }
  WaitForSingleObject(process.hProcess, INFINITE);
  DWORD code = 1;
  GetExitCodeProcess(process.hProcess, &code);
  CloseHandle(process.hThread);
  CloseHandle(process.hProcess);
  return code == 0;
}

}  // namespace

int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int) {
  const std::wstring self = modulePath();
  const std::wstring appData = localAppData();
  if (self.empty() || appData.empty()) {
    MessageBoxW(nullptr, L"Impossible de preparer Influencor.", L"Influencor",
                MB_ICONERROR);
    return 1;
  }

  const std::wstring base = appData + L"\\Influencor\\WindowsApp";
  const std::wstring zip = appData + L"\\Influencor\\payload.zip";
  const std::wstring app = base + L"\\clipboard.exe";

  CreateDirectoryW((appData + L"\\Influencor").c_str(), nullptr);
  if (!extractPayload(self, zip)) {
    MessageBoxW(nullptr, L"Le package Influencor est invalide.", L"Influencor",
                MB_ICONERROR);
    return 1;
  }

  const std::wstring script =
      L"$ErrorActionPreference='Stop';"
      L"$base=" + quote(base) + L";"
      L"$zip=" + quote(zip) + L";"
      L"if(Test-Path -LiteralPath $base){Remove-Item -LiteralPath $base -Recurse -Force};"
      L"New-Item -ItemType Directory -Force -Path $base | Out-Null;"
      L"Expand-Archive -LiteralPath $zip -DestinationPath $base -Force";

  const std::wstring powershell =
      L"powershell.exe -NoProfile -ExecutionPolicy Bypass -Command " + quote(script);
  if (!runAndWait(powershell)) {
    MessageBoxW(nullptr, L"Impossible d'extraire Influencor.", L"Influencor",
                MB_ICONERROR);
    return 1;
  }

  ShellExecuteW(nullptr, L"open", app.c_str(), nullptr, base.c_str(), SW_SHOWNORMAL);
  return 0;
}
