package imgui_impl_sdl2

import "vendor:sdl2"

when ODIN_OS == .Windows {
	when ODIN_ARCH == .amd64 {
		@export
		foreign import imguilib "../../imgui_windows_x64.lib"
	} else {
		@export
		foreign import imguilib "../../imgui_windows_arm64.lib"
	}
} else when ODIN_OS == .Linux {
	when ODIN_ARCH == .amd64 {
		@export
		foreign import imguilib "../../libimgui_linux_x64.a"
	} else {
		@export
		foreign import imguilib "../../libimgui_linux_arm64.a"
	}
} else when ODIN_OS == .Darwin {
	when ODIN_ARCH == .amd64 {
		@export
		foreign import imguilib "../../libimgui_macosx_x64.a"
	} else {
		@export
		foreign import imguilib "../../libimgui_macosx_arm64.a"
	}
}

// Gamepad selection automatically starts in AutoFirst mode, picking first
// available SDL_Gamepad. You may override this.
//
// When using manual mode, caller is responsible for opening/closing gamepad.
GamepadMode :: enum i32 {
	AutoFirst,
	AutoAll,
	Manual,
}

// (Advanced, for X11 users) Override Mouse Capture mode. Mouse capture allows
// receiving updated mouse position after clicking inside our window and
// dragging outside it. Having this 'Enabled' is in theory always better. But,
// on X11 if you crash/break to debugger while capture is active you may
// temporarily lose access to your mouse. The best solution is to setup your
// debugger to automatically release capture, e.g. 'setxkbmap -option
// grab:break_actions && xdotool key XF86Ungrab' or via a GDB script. See #3650.
// But you may independently decide on X11, when a debugger is attached, to set
// this value to MouseCaptureMode_Disabled.
MouseCaptureMode :: enum i32 {
	Enabled,
	EnabledAfterDrag,
	Disabled,
}

@(default_calling_convention = "c", link_prefix = "ImGui_ImplSDL2_")
foreign imguilib {
	// Follow "Getting Started" link and check examples/ folder to learn about using backends!
	InitForOpenGL :: proc(
		window: ^sdl2.Window,
		sdl_gl_context: rawptr) -> bool ---
	InitForVulkan :: proc(
		window: ^sdl2.Window) -> bool ---
	InitForD3D :: proc(
		window: ^sdl2.Window) -> bool ---
	InitForMetal :: proc(
		window: ^sdl2.Window) -> bool ---
	InitForSDLRenderer :: proc(
		window: ^sdl2.Window,
		renderer: ^sdl2.Renderer) -> bool ---
	InitForOther :: proc(
		window: ^sdl2.Window) -> bool ---
	Shutdown :: proc() ---
	NewFrame :: proc() ---
	ProcessEvent :: proc(
		event: ^sdl2.Event) -> bool ---

	// DPI-related helpers (optional)
	GetContentScaleForWindow :: proc(
		window: ^sdl2.Window) -> f32 ---
	GetContentScaleForDisplay :: proc(
		display_index: i32) -> f32 ---

	SetGamepadMode :: proc(
		mode: GamepadMode,
		manual_gamepads_array: [^]^sdl2.GameController = nil,
		manual_gamepads_count: i32 = -1) ---

	SetMouseCaptureMode :: proc(mode: MouseCaptureMode) ---
}
