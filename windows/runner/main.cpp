#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include <shobjidl.h>

#include "flutter_window.h"
#include "utils.h"

// Unique application mutex identifier per user session
static constexpr const wchar_t kSingleInstanceMutexName[] =
    L"Local\\Resonance_SingleInstance_Mutex_8B9E9A9B9C9D";
static constexpr const wchar_t kRegisteredMessageName[] =
    L"WM_SHOW_RESONANCE_INSTANCE";

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // ── Single-Instance Check ──────────────────────────────────────────────────
  HANDLE mutex = ::CreateMutex(nullptr, TRUE, kSingleInstanceMutexName);
  if (::GetLastError() == ERROR_ALREADY_EXISTS) {
    // Another instance is already running!
    const UINT wm_show_instance = ::RegisterWindowMessage(kRegisteredMessageName);

    // Find the existing Resonance window (Class name is "Resonance")
    HWND existing_hwnd = ::FindWindow(L"Resonance", nullptr);
    if (existing_hwnd) {
      // 1. Post message to notify internal message handlers
      ::PostMessage(existing_hwnd, wm_show_instance, 0, 0);

      // 2. Un-hide from tray if hidden (SW_HIDE -> SW_SHOW)
      ::ShowWindow(existing_hwnd, SW_SHOW);

      // 3. Restore if minimized
      if (::IsIconic(existing_hwnd)) {
        ::ShowWindow(existing_hwnd, SW_RESTORE);
      }

      // 4. Bring existing window to foreground
      ::SetForegroundWindow(existing_hwnd);
      ::BringWindowToTop(existing_hwnd);
      ::SetFocus(existing_hwnd);
    }

    if (mutex) {
      ::CloseHandle(mutex);
    }
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // Force Win32 shell to identify the App UserModelID, fixing SMTC "Unknown app" labels
  SetCurrentProcessExplicitAppUserModelID(L"com.chronostudio.Resonance");

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);
  if (!window.Create(L"Resonance", origin, size)) {
    if (mutex) {
      ::ReleaseMutex(mutex);
      ::CloseHandle(mutex);
    }
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  if (mutex) {
    ::ReleaseMutex(mutex);
    ::CloseHandle(mutex);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
