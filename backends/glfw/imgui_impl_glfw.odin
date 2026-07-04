package imgui_impl_glfw

import "vendor:glfw"

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

@(default_calling_convention = "c", link_prefix = "ImGui_ImplGlfw_")
foreign imguilib {
	// Follow "Getting Started" link and check examples/ folder to learn about using backends!
	InitForOpenGL :: proc(
		window: glfw.WindowHandle,
		install_callbacks: bool) -> bool ---
	InitForVulkan :: proc(
		window: glfw.WindowHandle,
		install_callbacks: bool) -> bool ---
	InitForOther :: proc(
		window: glfw.WindowHandle,
		install_callbacks: bool) -> bool ---
	Shutdown :: proc() ---
	NewFrame :: proc() ---

	InstallEmscriptenCallbacks :: proc(
		window: glfw.WindowHandle,
		canvas_selector: cstring) ---

	// GLFW callbacks install
	//
	// - When calling Init with 'install_callbacks=true': InstallCallbacks() is called.
	//   GLFW callbacks will be installed for you. They will chain-call user's
	//   previously installed callbacks, if any.
	// - When calling Init with 'install_callbacks=false': GLFW callbacks won't be
	//   installed. You will need to call individual function yourself from your own
	//   GLFW callbacks.
	InstallCallbacks :: proc(
		window: glfw.WindowHandle) ---
	RestoreCallbacks :: proc(
		window: glfw.WindowHandle) ---

	// GLFW callbacks options:
	//
	// - Set 'chain_for_all_windows=true' to enable chaining callbacks for all windows
	//   (including secondary viewports created by backends or by user)
	SetCallbacksChainForAllWindows :: proc(chain_for_all_windows: bool) ---

	// GLFW callbacks (individual callbacks to call yourself if you didn't install callbacks)
	WindowFocusCallback :: proc(
	window: glfw.WindowHandle,
	focused: i32) ---        // Since 1.8
	CursorEnterCallback :: proc(
	window: glfw.WindowHandle,
	entered: i32) ---        // Since 1.8
	CursorPosCallback :: proc(
		window: glfw.WindowHandle,
		x: f64,
		y: f64) ---   // Since 1.8
	MouseButtonCallback :: proc(
		window: glfw.WindowHandle,
		button: i32,
		action: i32,
		mods: i32) ---
	ScrollCallback :: proc(
		window: glfw.WindowHandle,
		xoffset: f64,
		yoffset: f64) ---
	KeyCallback :: proc(
		window: glfw.WindowHandle,
		key: i32,
		scancode: i32,
		action: i32,
		mods: i32) ---
	CharCallback :: proc(
		window: glfw.WindowHandle,
		c: u32) ---
	MonitorCallback :: proc(monitor: glfw.MonitorHandle, event: i32) ---

	// GLFW helpers
	Sleep :: proc(milliseconds: i32) ---
	GetContentScaleForWindow :: proc(
		window: glfw.WindowHandle) -> f32 ---
	GetContentScaleForMonitor :: proc(monitor: glfw.MonitorHandle) -> f32 ---
}
