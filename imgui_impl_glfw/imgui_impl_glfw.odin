package imgui_impl_glfw

import "vendor:glfw"

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
	@(link_name = "ImGui_ImplGlfw_InitForOpenGL")
	init_for_open_gl :: proc(window: glfw.WindowHandle, install_callbacks: bool) -> bool ---
	@(link_name = "ImGui_ImplGlfw_InitForVulkan")
	init_for_vulkan :: proc(window: glfw.WindowHandle, install_callbacks: bool) -> bool ---
	@(link_name = "ImGui_ImplGlfw_InitForOther")
	init_for_other :: proc(window: glfw.WindowHandle, install_callbacks: bool) -> bool ---
	@(link_name = "ImGui_ImplGlfw_Shutdown")
	shutdown :: proc() ---
	@(link_name = "ImGui_ImplGlfw_NewFrame")
	new_frame :: proc() ---
	@(link_name = "ImGui_ImplGlfw_InstallEmscriptenCallbacks")
	install_emscripten_callbacks :: proc(window: glfw.WindowHandle, canvas_selector: cstring) ---
	// GLFW callbacks install
	// - When calling Init with 'install_callbacks=true': ImGui_ImplGlfw_InstallCallbacks() is called. GLFW callbacks will be installed for you. They will chain-call user's previously installed callbacks, if any.
	// - When calling Init with 'install_callbacks=false': GLFW callbacks won't be installed. You will need to call individual function yourself from your own GLFW callbacks.
	@(link_name = "ImGui_ImplGlfw_InstallCallbacks")
	install_callbacks :: proc(window: glfw.WindowHandle) ---
	@(link_name = "ImGui_ImplGlfw_RestoreCallbacks")
	restore_callbacks :: proc(window: glfw.WindowHandle) ---
	// GFLW callbacks options:
	// - Set 'chain_for_all_windows=true' to enable chaining callbacks for all windows (including secondary viewports created by backends or by user)
	@(link_name = "ImGui_ImplGlfw_SetCallbacksChainForAllWindows")
	set_callbacks_chain_for_all_windows :: proc(chain_for_all_windows: bool) ---
	// GLFW callbacks (individual callbacks to call yourself if you didn't install callbacks)
	// Since 1.84
	@(link_name = "ImGui_ImplGlfw_WindowFocusCallback")
	window_focus_callback :: proc(window: glfw.WindowHandle, focused: i32) ---
	// Since 1.84
	@(link_name = "ImGui_ImplGlfw_CursorEnterCallback")
	cursor_enter_callback :: proc(window: glfw.WindowHandle, entered: i32) ---
	// Since 1.87
	@(link_name = "ImGui_ImplGlfw_CursorPosCallback")
	cursor_pos_callback :: proc(window: glfw.WindowHandle, x: f64, y: f64) ---
	@(link_name = "ImGui_ImplGlfw_MouseButtonCallback")
	mouse_button_callback :: proc(window: glfw.WindowHandle, button: i32, action: i32, mods: i32) ---
	@(link_name = "ImGui_ImplGlfw_ScrollCallback")
	scroll_callback :: proc(window: glfw.WindowHandle, xoffset: f64, yoffset: f64) ---
	@(link_name = "ImGui_ImplGlfw_KeyCallback")
	key_callback :: proc(window: glfw.WindowHandle, key: i32, scancode: i32, action: i32, mods: i32) ---
	@(link_name = "ImGui_ImplGlfw_CharCallback")
	char_callback :: proc(window: glfw.WindowHandle, c: u32) ---
	@(link_name = "ImGui_ImplGlfw_MonitorCallback")
	monitor_callback :: proc(monitor: glfw.MonitorHandle, event: i32) ---
}
