#include "flutter_window.h"

#include <optional>
#include <commctrl.h>

#include "flutter/generated_plugin_registrant.h"

#pragma comment(lib, "comctl32.lib")

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

static bool g_subclassed = false;
static bool g_child_subclassed = false;
static bool g_is_hovered_state = false;
// Unique ID avoids collision with window_manager's internal subclass (ID=1).
static constexpr UINT_PTR kSubclassId = 100;

std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> g_hover_channel = nullptr;

static void UpdateHoverState(HWND parent, bool hovered) {
  if (g_is_hovered_state != hovered) {
    g_is_hovered_state = hovered;
    if (g_hover_channel) {
      g_hover_channel->InvokeMethod("setHovered", std::make_unique<flutter::EncodableValue>(hovered));
    }
    
    if (hovered) {
      TRACKMOUSEEVENT tme;
      tme.cbSize = sizeof(TRACKMOUSEEVENT);
      tme.dwFlags = TME_LEAVE | TME_NONCLIENT;
      tme.hwndTrack = parent;
      tme.dwHoverTime = HOVER_DEFAULT;
      TrackMouseEvent(&tme);
    }
  }
}

static LRESULT CALLBACK ChildSubclassProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam, UINT_PTR uIdSubclass, DWORD_PTR dwRefData) {
  if (uMsg == WM_NCHITTEST) {
    POINT pt = { (int)(short)LOWORD(lParam), (int)(short)HIWORD(lParam) };
    HWND parent = GetParent(hwnd);
    ScreenToClient(parent, &pt);
    RECT rect;
    GetClientRect(parent, &rect);
    
    UINT dpi = GetDpiForWindow(parent);
    double dpi_scale = dpi / 96.0;
    
    double title_bar_height = 32.0 * dpi_scale;
    double button_width     = 46.0 * dpi_scale;
    double resize_border    = 8.0  * dpi_scale;
    
    double max_btn_left  = rect.right - (button_width * 2);
    double max_btn_right = rect.right - button_width;

    // Top resize border: return HTTRANSPARENT so parent's WindowSubclassProc
    // can return HTTOP/HTTOPLEFT/HTTOPRIGHT. Without this, HTCLIENT swallows the hit.
    WINDOWPLACEMENT wp;
    wp.length = sizeof(WINDOWPLACEMENT);
    bool is_maximized = GetWindowPlacement(parent, &wp) && wp.showCmd == SW_SHOWMAXIMIZED;
    if (!is_maximized && pt.y >= 0 && pt.y < resize_border) {
      return HTTRANSPARENT;
    }

    // Maximize button zone: let parent handle Snap Layouts hover.
    if (pt.y >= 0 && pt.y <= title_bar_height && pt.x >= max_btn_left && pt.x <= max_btn_right) {
      UpdateHoverState(parent, true);
      return HTTRANSPARENT;
    } else {
      UpdateHoverState(parent, false);
    }
  }
  return DefSubclassProc(hwnd, uMsg, wParam, lParam);
}


// Helper: check if hwnd currently covers its monitor (i.e. is truly fullscreen).
// O(1), called from NCHITTEST and NCLBUTTONDOWN guards.
static bool IsWindowFullscreen(HWND hwnd) {
  RECT wr;
  if (!GetWindowRect(hwnd, &wr)) return false;
  HMONITOR mon = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
  if (!mon) return false;
  MONITORINFO mi;
  mi.cbSize = sizeof(MONITORINFO);
  if (!GetMonitorInfo(mon, &mi)) return false;
  return wr.left == mi.rcMonitor.left && wr.top == mi.rcMonitor.top &&
         wr.right == mi.rcMonitor.right && wr.bottom == mi.rcMonitor.bottom;
}

static LRESULT CALLBACK WindowSubclassProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam, UINT_PTR uIdSubclass, DWORD_PTR dwRefData) {
  if (uMsg == WM_NCCALCSIZE) {
    if (wParam == TRUE) {
      NCCALCSIZE_PARAMS* sz = reinterpret_cast<NCCALCSIZE_PARAMS*>(lParam);

      // Use the PROPOSED new rect (sz->rgrc[0]) — not GetWindowRect — to avoid a
      // timing race where GetWindowRect still holds the old position during SetWindowPos.
      // MonitorFromRect resolves multi-monitor correctly on the proposed bounds.
      HMONITOR mon = MonitorFromRect(&sz->rgrc[0], MONITOR_DEFAULTTONEAREST);
      if (mon) {
        MONITORINFO mi;
        mi.cbSize = sizeof(MONITORINFO);
        if (GetMonitorInfo(mon, &mi)) {
          if (sz->rgrc[0].left   == mi.rcMonitor.left   &&
              sz->rgrc[0].top    == mi.rcMonitor.top    &&
              sz->rgrc[0].right  == mi.rcMonitor.right  &&
              sz->rgrc[0].bottom == mi.rcMonitor.bottom) {
            return 0; // Proposed rect fills monitor exactly — bypass all border offsets.
          }
        }
      }

      // If maximized, adjust rect to the monitor's work area so content is not cut off at screen edges
      WINDOWPLACEMENT wp;
      wp.length = sizeof(WINDOWPLACEMENT);
      if (GetWindowPlacement(hwnd, &wp) && wp.showCmd == SW_SHOWMAXIMIZED) {
        HMONITOR monitor = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
        if (monitor) {
          MONITORINFO mi;
          mi.cbSize = sizeof(MONITORINFO);
          if (GetMonitorInfo(monitor, &mi)) {
            sz->rgrc[0] = mi.rcWork;
            return 0;
          }
        }
      }

      // Normal window: preserve 8px resize border shadow on left/right/bottom.
      sz->rgrc[0].left   += 8;
      sz->rgrc[0].right  -= 8;
      sz->rgrc[0].bottom -= 8;
      return 0;
    }
    return 0;
  }

  if (uMsg == WM_NCMOUSELEAVE || uMsg == WM_MOUSELEAVE) {
    UpdateHoverState(hwnd, false);
  }

  // Guard: only intercept maximize-button zone when NOT in fullscreen.
  // In fullscreen the title bar is hidden — clicks in that coordinate would otherwise
  // trigger SC_RESTORE/SC_MAXIMIZE and corrupt the window state machine.
  if (!IsWindowFullscreen(hwnd)) {
    if (uMsg == WM_NCLBUTTONDOWN && wParam == HTMAXBUTTON) {
      WINDOWPLACEMENT wp;
      wp.length = sizeof(WINDOWPLACEMENT);
      if (GetWindowPlacement(hwnd, &wp)) {
        if (wp.showCmd == SW_SHOWMAXIMIZED) {
          PostMessage(hwnd, WM_SYSCOMMAND, SC_RESTORE, 0);
        } else {
          PostMessage(hwnd, WM_SYSCOMMAND, SC_MAXIMIZE, 0);
        }
      }
      return 0;
    }

    if (uMsg == WM_NCHITTEST) {
      POINT pt = { (int)(short)LOWORD(lParam), (int)(short)HIWORD(lParam) };
      ScreenToClient(hwnd, &pt);
      RECT rect;
      GetClientRect(hwnd, &rect);

      UINT dpi = GetDpiForWindow(hwnd);
      double dpi_scale = dpi / 96.0;

      double title_bar_height = 32.0 * dpi_scale;
      double button_width = 46.0 * dpi_scale;
      // 8px top resize border (matches left/right/bottom), 16px corner zones.
      double resize_border = 8.0 * dpi_scale;
      double corner_width  = 16.0 * dpi_scale;

      double max_btn_left  = rect.right - (button_width * 2);
      double max_btn_right = rect.right - button_width;

      // Top resize border — skip when maximized (no resize possible).
      WINDOWPLACEMENT wp_chk;
      wp_chk.length = sizeof(WINDOWPLACEMENT);
      bool is_maximized = GetWindowPlacement(hwnd, &wp_chk) && wp_chk.showCmd == SW_SHOWMAXIMIZED;

      if (!is_maximized && pt.y >= 0 && pt.y < resize_border) {
        if (pt.x < corner_width)                   return HTTOPLEFT;
        if (pt.x > rect.right - corner_width)      return HTTOPRIGHT;
        return HTTOP;
      }

      // Maximize button zone — Windows 11 Snap Layouts hover.
      if (pt.y >= 0 && pt.y <= title_bar_height &&
          pt.x >= max_btn_left && pt.x <= max_btn_right) {
        return HTMAXBUTTON;
      }
    }

  }
  return DefSubclassProc(hwnd, uMsg, wParam, lParam);
}

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Install subclasses with unique ID so window_manager's ID=1 never collides.
  SetWindowSubclass(GetHandle(), WindowSubclassProc, kSubclassId, 0);
  SetWindowSubclass(flutter_controller_->view()->GetNativeWindow(), ChildSubclassProc, kSubclassId, 0);
  g_subclassed = true;
  g_child_subclassed = true;

  // Initialize MethodChannel for hover events
  g_hover_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "resonance/titlebar_hover",
      &flutter::StandardMethodCodec::GetInstance());

  g_is_hovered_state = false;

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    // Keep window hidden initially; Dart window_manager will show it after configuring hidden titlebar style.
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (g_subclassed) {
    RemoveWindowSubclass(GetHandle(), WindowSubclassProc, kSubclassId);
    g_subclassed = false;
  }
  if (g_child_subclassed && flutter_controller_ && flutter_controller_->view()) {
    RemoveWindowSubclass(flutter_controller_->view()->GetNativeWindow(), ChildSubclassProc, kSubclassId);
    g_child_subclassed = false;
  }

  g_hover_channel = nullptr;

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // 1. Let window_manager process messages first (it may install its own subclass on WM_SHOWWINDOW).
  std::optional<LRESULT> flutter_result;
  if (flutter_controller_) {
    flutter_result = flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam, lparam);
  }

  // 2. After window_manager has had its turn, re-install our subclass with unique ID
  //    so we are LAST in the chain (= FIRST to run), surviving style transitions.
  if (message == WM_SHOWWINDOW) {
    SetWindowSubclass(hwnd, WindowSubclassProc, kSubclassId, 0);
    g_subclassed = true;
    if (flutter_controller_ && flutter_controller_->view()) {
      SetWindowSubclass(flutter_controller_->view()->GetNativeWindow(), ChildSubclassProc, kSubclassId, 0);
      g_child_subclassed = true;
    }
  }

  if (flutter_result) {
    return *flutter_result;
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
