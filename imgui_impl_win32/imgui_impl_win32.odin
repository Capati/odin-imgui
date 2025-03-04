#+build windows
package imgui_impl_win32

import win "core:sys/windows"

when ODIN_OS == .Windows {
	when ODIN_ARCH == .amd64 {
		foreign import lib "../imgui_windows_x64.lib"
	} else {
		foreign import lib "../imgui_windows_arm64.lib"
	}
} else when ODIN_OS == .Linux {
	when ODIN_ARCH == .amd64 {
		foreign import lib "../libimgui_linux_x64.a"
	} else {
		foreign import lib "../libimgui_linux_arm64.a"
	}
} else when ODIN_OS == .Darwin {
	when ODIN_ARCH == .amd64 {
		foreign import lib "../libimgui_macosx_x64.a"
	} else {
		foreign import lib "../libimgui_macosx_arm64.a"
	}
}

@(default_calling_convention = "c")
foreign lib {
    // Follow "Getting Started" link and check examples/ folder to learn about using backends!
    @(link_name = "ImGui_ImplWin32_Init")
    init :: proc(hwnd: rawptr) -> bool ---
    @(link_name = "ImGui_ImplWin32_InitForOpenGL")
    init_for_open_gl :: proc(hwnd: rawptr) -> bool ---
    @(link_name = "ImGui_ImplWin32_Shutdown")
    shutdown :: proc() ---
    @(link_name = "ImGui_ImplWin32_NewFrame")
    new_frame :: proc() ---
    @(link_name = "ImGui_ImplWin32_WndProcHandler")
    wnd_proc_handler :: proc(hWnd: win.HWND, msg: win.UINT, wParam: win.WPARAM, lParam: win.LPARAM) -> win.LRESULT ---
    // DPI-related helpers (optional)
    // - Use to enable DPI awareness without having to create an application manifest.
    // - Your own app may already do this via a manifest or explicit calls. This is mostly useful for our examples/ apps.
    // - In theory we could call simple functions from Windows SDK such as SetProcessDPIAware(), SetProcessDpiAwareness(), etc.
    //   but most of the functions provided by Microsoft require Windows 8.1/10+ SDK at compile time and Windows 8/10+ at runtime,
    //   neither we want to require the user to have. So we dynamically select and load those functions to avoid dependencies.
    @(link_name = "ImGui_ImplWin32_EnableDpiAwareness")
    enable_dpi_awareness :: proc() ---
    // HWND hwnd
    @(link_name = "ImGui_ImplWin32_GetDpiScaleForHwnd")
    get_dpi_scale_for_hwnd :: proc(hwnd: rawptr) -> f32 ---
    // HMONITOR monitor
    @(link_name = "ImGui_ImplWin32_GetDpiScaleForMonitor")
    get_dpi_scale_for_monitor :: proc(monitor: rawptr) -> f32 ---
    // Transparency related helpers (optional) [experimental]
    // - Use to enable alpha compositing transparency with the desktop.
    // - Use together with e.g. clearing your framebuffer with zero-alpha.
    // HWND hwnd
    @(link_name = "ImGui_ImplWin32_EnableAlphaCompositing")
    enable_alpha_compositing :: proc(hwnd: rawptr) ---
}
