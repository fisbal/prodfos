#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // Single instance: double-clicking a PDF while ProDFOS is already open
  // hands the file to the running window instead of starting a second app.
  HANDLE instance_mutex =
      ::CreateMutexW(nullptr, TRUE, L"MartinB.ProDFOS.SingleInstance");
  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    HWND existing = ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"ProDFOS");
    if (existing) {
      std::vector<std::string> args = GetCommandLineArguments();
      std::string path = args.empty() ? std::string() : args[0];
      COPYDATASTRUCT cds{};
      cds.dwData = 0x50444653;  // 'PDFS'
      cds.cbData = static_cast<DWORD>(path.size() + 1);
      cds.lpData = const_cast<char*>(path.c_str());
      if (::IsIconic(existing)) ::ShowWindow(existing, SW_RESTORE);
      ::SetForegroundWindow(existing);
      ::SendMessageW(existing, WM_COPYDATA, 0, reinterpret_cast<LPARAM>(&cds));
      if (instance_mutex) ::CloseHandle(instance_mutex);
      ::CoUninitialize();
      return EXIT_SUCCESS;
    }
  }

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 860);
  if (!window.Create(L"ProDFOS", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  if (instance_mutex) ::CloseHandle(instance_mutex);
  ::CoUninitialize();
  return EXIT_SUCCESS;
}
