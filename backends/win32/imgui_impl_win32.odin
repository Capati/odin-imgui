#+build windows
package imgui_impl_win32

import win32 "core:sys/windows"

when ODIN_OS == .Windows {
	when ODIN_ARCH == .amd64 {
		@export
		foreign import imguilib "../../imgui_windows_x64.lib"
	} else {
		@export
		foreign import imguilib "../../imgui_windows_arm64.lib"
	}
} else {
	#panic("Unsupported platform")
}

@(default_calling_convention = "c", link_prefix = "ImGui_ImplWin32_")
foreign imguilib {
	// Follow "Getting Started" link and check examples/ folder to learn about using backends!
	Init :: proc(
		hwnd: rawptr) -> bool ---
	InitForOpenGL :: proc(
		hwnd: rawptr) -> bool ---
	Shutdown :: proc() ---
	NewFrame :: proc() ---

	// Win32 message handler your application needs to call.
	//
	// - Intentionally commented out in a '#if 0' block to avoid dragging dependencies
	//   on <windows.h> from this helper.
	// - You should COPY the line below into your .cpp code to forward declare the
	//   function and then you can call it.
	// - Call from your application's message handler. Keep calling your message
	//   handler unless this function returns TRUE.
	WndProcHandler :: proc(
		hWnd: win32.HWND,
		msg: win32.UINT,
		wParam: win32.WPARAM,
		lParam: win32.LPARAM) -> win32.LRESULT ---

	// DPI-related helpers (optional)
	//
	// - Use to enable DPI awareness without having to create an application
	//   manifest.
	// - Your own app may already do this via a manifest or explicit calls. This
	//   is mostly useful for our examples/ apps.
	// - In theory we could call simple functions from Windows SDK such as
	//   SetProcessDPIAware(), SetProcessDpiAwareness(), etc. but most of the
	//   functions provided by Microsoft require Windows 8.1/10+ SDK at compile
	//   time and Windows 8/10+ at runtime, neither of which we want to require
	//   the user to have. So we dynamically select and load those functions to
	//   avoid dependencies.
	EnableDpiAwareness :: proc() ---
	// HWND hwnd
	GetDpiScaleForHwnd :: proc(hwnd: rawptr) -> f32 ---
	// HMONITOR monitor
	GetDpiScaleForMonitor :: proc(monitor: rawptr) -> f32 ---

	// Transparency related helpers (optional) [experimental]
	//
	// - Use to enable alpha compositing transparency with the desktop.
	// - Use together with e.g. clearing your framebuffer with zero-alpha.
	//
	// HWND hwnd
	EnableAlphaCompositing :: proc(hwnd: rawptr) ---
}
