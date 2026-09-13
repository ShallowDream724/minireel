#include "flutter_window.h"

#include <optional>
#include <wtsapi32.h>

#include "flutter/generated_plugin_registrant.h"

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
  system_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "app.minireel/window",
      &flutter::StandardMethodCodec::GetInstance());
  WTSRegisterSessionNotification(GetHandle(), NOTIFY_FOR_THIS_SESSION);
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  WTSUnRegisterSessionNotification(GetHandle());
  system_channel_.reset();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Desktop focus loss is normal multitasking. Lock/suspend are separate
  // playback holds so unlocking cannot override an explicit user pause.
  if (system_channel_) {
    if (message == WM_WTSSESSION_CHANGE) {
      if (wparam == WTS_SESSION_LOCK) {
        system_channel_->InvokeMethod("sessionLocked", nullptr);
      } else if (wparam == WTS_SESSION_UNLOCK) {
        system_channel_->InvokeMethod("sessionUnlocked", nullptr);
      }
    } else if (message == WM_POWERBROADCAST) {
      if (wparam == PBT_APMSUSPEND) {
        system_channel_->InvokeMethod("suspend", nullptr);
      } else if (wparam == PBT_APMRESUMEAUTOMATIC) {
        system_channel_->InvokeMethod("resume", nullptr);
      }
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
