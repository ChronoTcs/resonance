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
    double button_width = 46.0 * dpi_scale;
    
    double max_btn_left = rect.right - (button_width * 2);
    double max_btn_right = rect.right - button_width;

    if (pt.y >= 0 && pt.y <= title_bar_height && pt.x >= max_btn_left && pt.x <= max_btn_right) {
      UpdateHoverState(parent, true);
      return HTTRANSPARENT; // Let hit testing pass to the parent window
    } else {
      UpdateHoverState(parent, false);
    }
  }
  return DefSubclassProc(hwnd, uMsg, wParam, lParam);
}

static LRESULT CALLBACK WindowSubclassProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam, UINT_PTR uIdSubclass, DWORD_PTR dwRefData) {
  if (uMsg == WM_NCCALCSIZE) {
    if (wParam == TRUE) {
      NCCALCSIZE_PARAMS* sz = reinterpret_cast<NCCALCSIZE_PARAMS*>(lParam);
      
      // Check if window is in fullscreen mode (no titlebar and no thick resize borders)
      DWORD style = GetWindowLong(hwnd, GWL_STYLE);
      bool is_fullscreen = !(style & WS_CAPTION) && !(style & WS_THICKFRAME);
      if (is_fullscreen) {
        return 0; // Return 0 with no offsets to let client area cover the entire screen
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
      
      // If not maximized and not fullscreen, let client area cover the whole window but preserve resize borders (8px)
      sz->rgrc[0].left += 8;
      sz->rgrc[0].right -= 8;
      sz->rgrc[0].bottom -= 8;
      return 0;
    }
    return 0;
  }

  if (uMsg == WM_NCMOUSELEAVE || uMsg == WM_MOUSELEAVE) {
    UpdateHoverState(hwnd, false);
  }

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
    
    double max_btn_left = rect.right - (button_width * 2);
    double max_btn_right = rect.right - button_width;

    if (pt.y >= 0 && pt.y <= title_bar_height && pt.x >= max_btn_left && pt.x <= max_btn_right) {
      return HTMAXBUTTON;
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

  // Initialize MethodChannel for hover events
  g_hover_channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(),
      "resonance/titlebar_hover",
      &flutter::StandardMethodCodec::GetInstance());

  // Reset subclass status on creation
  g_subclassed = false;
  g_child_subclassed = false;
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
    RemoveWindowSubclass(GetHandle(), WindowSubclassProc, 1);
    g_subclassed = false;
  }
  if (g_child_subclassed && flutter_controller_ && flutter_controller_->view()) {
    RemoveWindowSubclass(flutter_controller_->view()->GetNativeWindow(), ChildSubclassProc, 1);
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
  if (message == WM_SHOWWINDOW) {
    if (!g_subclassed) {
      SetWindowSubclass(hwnd, WindowSubclassProc, 1, 0);
      g_subclassed = true;
    }
    if (!g_child_subclassed && flutter_controller_ && flutter_controller_->view()) {
      SetWindowSubclass(flutter_controller_->view()->GetNativeWindow(), ChildSubclassProc, 1, 0);
      g_child_subclassed = true;
    }
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
