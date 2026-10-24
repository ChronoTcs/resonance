#ifndef RUNNER_SYSTEM_TRAY_MANAGER_H_
#define RUNNER_SYSTEM_TRAY_MANAGER_H_

#include <windows.h>
#include <shellapi.h>
#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <string>

// Message identifier for system tray notifications
constexpr UINT WM_TRAYICON = WM_APP + 2;

class SystemTrayManager {
 public:
  SystemTrayManager();
  ~SystemTrayManager();

  // Disallow copy and assign
  SystemTrayManager(const SystemTrayManager&) = delete;
  SystemTrayManager& operator=(const SystemTrayManager&) = delete;

  // Initializes the tray manager, creates method channel, and registers handlers
  void Initialize(HWND window, flutter::BinaryMessenger* messenger);

  // Updates tooltip, now playing title, and play/pause state
  void UpdateMetadata(const std::wstring& tooltip,
                      const std::wstring& now_playing_title,
                      bool is_playing);

  // Updates theme mode (dark vs light)
  void SetTheme(bool is_dark);

  // Removes tray icon from taskbar notification area
  void Destroy();

  // Handles window proc messages. Returns true if message was handled.
  bool HandleMessage(HWND window, UINT message, WPARAM wparam, LPARAM lparam, LRESULT* result);

  // Displays Win32 popup context menu at current cursor location
  void ShowContextMenu();

 private:
  void AddTrayIcon();
  void RemoveTrayIcon();
  void ApplyTheme();

  HWND window_ = nullptr;
  NOTIFYICONDATAW nid_ = {};
  HICON icon_ = nullptr;
  bool is_icon_added_ = false;
  UINT taskbar_created_msg_ = 0;

  std::wstring tooltip_ = L"Resonance";
  std::wstring now_playing_title_ = L"";
  bool is_playing_ = false;
  bool is_dark_mode_ = true;

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_ = nullptr;
};

#endif  // RUNNER_SYSTEM_TRAY_MANAGER_H_
