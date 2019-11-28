# Winuser.h
require "c/win_def"

@[Link("User32")]
lib LibC
  WM_CLOSE = 0x0010
  WM_QUIT  = 0x0012

  fun PostMessageW(
    hWnd : HWND,
    msg : UINT,
    wParam : WPARAM,
    lParam : LPARAM
  ) : BOOL

  fun PostThreadMessageW(
    idThread : DWORD,
    msg : UINT,
    wParam : WPARAM,
    lParam : LPARAM
  ) : BOOL

  alias WNDENUMPROC = (HWND, LPARAM -> BOOL)

  fun EnumWindows(
    lpEnumFunc : WNDENUMPROC,
    lParam : LPARAM
  ) : BOOL

  fun GetWindowThreadProcessId(
    hWnd : HWND,
    lpdwProcessId : LPDWORD
  ) : DWORD

  GW_OWNER = 4

  fun GetWindow(
    hWnd : HWND,
    uCmd : UINT
  ) : HWND

  fun IsWindowVisible(hWnd : HWND) : BOOL
end
