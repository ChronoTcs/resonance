#include "system_tray_manager.h"
#include "resource.h"

#include <dwmapi.h>
#include <uxtheme.h>
#include <vector>

enum TrayMenuCommand {
  kMenuNowPlaying = 1001,
  kMenuPlayPause = 1002,
  kMenuNext = 1003,
  kMenuPrev = 1004,
  kMenuRestore = 1005,
  kMenuExit = 1006,
};

enum class PreferredAppMode {
  Default,
  AllowDark,
  ForceDark,
  ForceLight,
  Max
};

using fnSetPreferredAppMode = PreferredAppMode(WINAPI*)(PreferredAppMode appMode);
using fnAllowDarkModeForWindow = BOOL(WINAPI*)(HWND hWnd, BOOL allow);
using fnFlushMenuThemes = void(WINAPI*)();
using fnSetWindowTheme = HRESULT(WINAPI*)(HWND hwnd, LPCWSTR pszSubAppName, LPCWSTR pszSubIdList);

static fnSetPreferredAppMode g_SetPreferredAppMode = nullptr;
static fnAllowDarkModeForWindow g_AllowDarkModeForWindow = nullptr;
static fnFlushMenuThemes g_FlushMenuThemes = nullptr;
static fnSetWindowTheme g_SetWindowTheme = nullptr;
static bool g_uxtheme_loaded = false;

static void EnsureUxThemeLoaded() {
  if (g_uxtheme_loaded) return;
  HMODULE uxtheme = ::LoadLibraryExW(L"uxtheme.dll", nullptr, LOAD_LIBRARY_SEARCH_SYSTEM32);
  if (uxtheme) {
    g_SetPreferredAppMode = reinterpret_cast<fnSetPreferredAppMode>(
        ::GetProcAddress(uxtheme, MAKEINTRESOURCEA(135)));
    g_AllowDarkModeForWindow = reinterpret_cast<fnAllowDarkModeForWindow>(
        ::GetProcAddress(uxtheme, MAKEINTRESOURCEA(133)));
    g_FlushMenuThemes = reinterpret_cast<fnFlushMenuThemes>(
        ::GetProcAddress(uxtheme, MAKEINTRESOURCEA(136)));
    g_SetWindowTheme = reinterpret_cast<fnSetWindowTheme>(
        ::GetProcAddress(uxtheme, "SetWindowTheme"));
  }
  g_uxtheme_loaded = true;
}

static std::wstring Utf8ToWide(const std::string& str) {
  if (str.empty()) return std::wstring();
  int size = MultiByteToWideChar(CP_UTF8, 0, str.c_str(), -1, nullptr, 0);
  if (size <= 0) return std::wstring();
  std::wstring result(size - 1, 0);
  MultiByteToWideChar(CP_UTF8, 0, str.c_str(), -1, &result[0], size);
  return result;
}

SystemTrayManager::SystemTrayManager() = default;

SystemTrayManager::~SystemTrayManager() {
  Destroy();
}

void SystemTrayManager::Initialize(HWND window, flutter::BinaryMessenger* messenger) {
  window_ = window;
  taskbar_created_msg_ = ::RegisterWindowMessage(L"TaskbarCreated");

  ApplyTheme();

  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      messenger,
      "com.chronostudio.resonance/system_tray",
      &flutter::StandardMethodCodec::GetInstance());

  channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "init") {
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (args) {
            auto it_dark = args->find(flutter::EncodableValue("isDark"));
            if (it_dark != args->end() && std::holds_alternative<bool>(it_dark->second)) {
              is_dark_mode_ = std::get<bool>(it_dark->second);
            }
          }
          ApplyTheme();
          AddTrayIcon();
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "setTheme") {
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (args) {
            auto it_dark = args->find(flutter::EncodableValue("isDark"));
            if (it_dark != args->end() && std::holds_alternative<bool>(it_dark->second)) {
              SetTheme(std::get<bool>(it_dark->second));
            }
          }
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "updateMetadata") {
          const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
          if (!args) {
            result->Error("INVALID_ARGUMENT", "Expected map argument");
            return;
          }

          std::wstring tooltip = tooltip_;
          std::wstring title = now_playing_title_;
          bool is_playing = is_playing_;

          auto it_tt = args->find(flutter::EncodableValue("tooltip"));
          if (it_tt != args->end() && std::holds_alternative<std::string>(it_tt->second)) {
            tooltip = Utf8ToWide(std::get<std::string>(it_tt->second));
          }

          auto it_t = args->find(flutter::EncodableValue("title"));
          if (it_t != args->end() && std::holds_alternative<std::string>(it_t->second)) {
            title = Utf8ToWide(std::get<std::string>(it_t->second));
          }

          auto it_p = args->find(flutter::EncodableValue("isPlaying"));
          if (it_p != args->end() && std::holds_alternative<bool>(it_p->second)) {
            is_playing = std::get<bool>(it_p->second);
          }

          auto it_dark = args->find(flutter::EncodableValue("isDark"));
          if (it_dark != args->end() && std::holds_alternative<bool>(it_dark->second)) {
            is_dark_mode_ = std::get<bool>(it_dark->second);
            ApplyTheme();
          }

          UpdateMetadata(tooltip, title, is_playing);
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "destroy") {
          RemoveTrayIcon();
          result->Success(flutter::EncodableValue(true));
        } else {
          result->NotImplemented();
        }
      });
}

void SystemTrayManager::ApplyTheme() {
  EnsureUxThemeLoaded();

  if (g_SetPreferredAppMode) {
    g_SetPreferredAppMode(is_dark_mode_ ? PreferredAppMode::ForceDark : PreferredAppMode::ForceLight);
  }

  if (window_) {
    if (g_AllowDarkModeForWindow) {
      g_AllowDarkModeForWindow(window_, is_dark_mode_ ? TRUE : FALSE);
    }

    if (g_SetWindowTheme) {
      g_SetWindowTheme(window_, is_dark_mode_ ? L"DarkMode_Explorer" : L"Explorer", nullptr);
    }

    BOOL dwm_dark = is_dark_mode_ ? TRUE : FALSE;
    ::DwmSetWindowAttribute(window_, 20 /* DWMWA_USE_IMMERSIVE_DARK_MODE */, &dwm_dark, sizeof(dwm_dark));
  }

  if (g_FlushMenuThemes) {
    g_FlushMenuThemes();
  }
}

void SystemTrayManager::SetTheme(bool is_dark) {
  is_dark_mode_ = is_dark;
  ApplyTheme();
}

void SystemTrayManager::AddTrayIcon() {
  if (!window_ || is_icon_added_) return;

  if (!icon_) {
    icon_ = (HICON)::LoadImage(
        ::GetModuleHandle(nullptr),
        MAKEINTRESOURCE(IDI_APP_ICON),
        IMAGE_ICON,
        ::GetSystemMetrics(SM_CXSMICON),
        ::GetSystemMetrics(SM_CYSMICON),
        LR_DEFAULTCOLOR);
    if (!icon_) {
      icon_ = ::LoadIcon(::GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_APP_ICON));
    }
  }

  memset(&nid_, 0, sizeof(NOTIFYICONDATAW));
  nid_.cbSize = sizeof(NOTIFYICONDATAW);
  nid_.hWnd = window_;
  nid_.uID = 1;
  nid_.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
  nid_.uCallbackMessage = WM_TRAYICON;
  nid_.hIcon = icon_;
  wcsncpy_s(nid_.szTip, tooltip_.c_str(), _TRUNCATE);

  if (::Shell_NotifyIconW(NIM_ADD, &nid_)) {
    is_icon_added_ = true;
  }
}

void SystemTrayManager::UpdateMetadata(const std::wstring& tooltip,
                                      const std::wstring& now_playing_title,
                                      bool is_playing) {
  tooltip_ = tooltip.empty() ? L"Resonance" : tooltip;
  now_playing_title_ = now_playing_title;
  is_playing_ = is_playing;

  if (is_icon_added_ && window_) {
    wcsncpy_s(nid_.szTip, tooltip_.c_str(), _TRUNCATE);
    nid_.uFlags = NIF_TIP;
    ::Shell_NotifyIconW(NIM_MODIFY, &nid_);
    nid_.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
  }
}

void SystemTrayManager::RemoveTrayIcon() {
  if (is_icon_added_ && window_) {
    ::Shell_NotifyIconW(NIM_DELETE, &nid_);
    is_icon_added_ = false;
  }
  if (icon_) {
    ::DestroyIcon(icon_);
    icon_ = nullptr;
  }
}

void SystemTrayManager::Destroy() {
  RemoveTrayIcon();
  channel_ = nullptr;
  window_ = nullptr;
}

void SystemTrayManager::ShowContextMenu() {
  if (!window_) return;

  // Ensure menu theme matches active dark/light preference
  ApplyTheme();

  POINT pt;
  if (!::GetCursorPos(&pt)) return;

  HMENU hmenu = ::CreatePopupMenu();
  if (!hmenu) return;

  // Use static musical note symbol: 🎵 (U+1F3B5)
  std::wstring now_playing_text;
  if (now_playing_title_.empty()) {
    now_playing_text = L"Resonance";
  } else {
    now_playing_text = L"\U0001F3B5 " + now_playing_title_;
  }

  // Clickable header: opens Now Playing view in the app
  ::AppendMenuW(hmenu, MF_STRING, kMenuNowPlaying, now_playing_text.c_str());
  ::AppendMenuW(hmenu, MF_SEPARATOR, 0, nullptr);

  std::wstring play_pause_text = is_playing_ ? L"Pause" : L"Play";
  ::AppendMenuW(hmenu, MF_STRING, kMenuPlayPause, play_pause_text.c_str());
  ::AppendMenuW(hmenu, MF_STRING, kMenuNext, L"Next Track");
  ::AppendMenuW(hmenu, MF_STRING, kMenuPrev, L"Previous Track");
  ::AppendMenuW(hmenu, MF_SEPARATOR, 0, nullptr);
  ::AppendMenuW(hmenu, MF_STRING, kMenuRestore, L"Open Resonance");
  ::AppendMenuW(hmenu, MF_STRING, kMenuExit, L"Exit");

  ::SetForegroundWindow(window_);
  UINT cmd = ::TrackPopupMenuEx(hmenu, TPM_RIGHTBUTTON | TPM_NONOTIFY | TPM_RETURNCMD, pt.x, pt.y, window_, nullptr);
  ::PostMessage(window_, WM_NULL, 0, 0);
  ::DestroyMenu(hmenu);

  if (cmd != 0 && channel_) {
    std::string action;
    switch (cmd) {
      case kMenuNowPlaying:
        action = "open_now_playing";
        break;
      case kMenuPlayPause:
        action = "play_pause";
        break;
      case kMenuNext:
        action = "skip_next";
        break;
      case kMenuPrev:
        action = "skip_prev";
        break;
      case kMenuRestore:
        action = "restore";
        break;
      case kMenuExit:
        action = "exit";
        break;
      default:
        break;
    }
    if (!action.empty()) {
      channel_->InvokeMethod("onMenuItemSelected", std::make_unique<flutter::EncodableValue>(action));
    }
  }
}

bool SystemTrayManager::HandleMessage(HWND window, UINT message, WPARAM wparam, LPARAM lparam, LRESULT* result) {
  if (taskbar_created_msg_ != 0 && message == taskbar_created_msg_) {
    is_icon_added_ = false;
    AddTrayIcon();
    return false;
  }

  if (message == WM_TRAYICON) {
    switch (lparam) {
      case WM_LBUTTONUP:
      case WM_LBUTTONDBLCLK:
        if (channel_) {
          channel_->InvokeMethod("onTrayIconClicked", nullptr);
        }
        if (result) *result = 0;
        return true;

      case WM_RBUTTONUP:
      case WM_CONTEXTMENU:
        ShowContextMenu();
        if (result) *result = 0;
        return true;

      default:
        break;
    }
  }

  return false;
}
