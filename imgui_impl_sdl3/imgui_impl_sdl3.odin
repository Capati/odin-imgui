package imgui_impl_sdl3

import "vendor:sdl3"

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

// Gamepad selection automatically starts in AutoFirst mode, picking first available SDL_Gamepad. You may override this.
// When using manual mode, caller is responsible for opening/closing gamepad.
Gamepad_Mode :: enum i32 {
	Auto_First = 0,
	Auto_All   = 1,
	Manual     = 2,
}

@(default_calling_convention = "c")
foreign lib {
	// Follow "Getting Started" link and check examples/ folder to learn about using backends!
	@(link_name = "ImGui_ImplSDL3_InitForOpenGL")
	init_for_open_gl :: proc(window: ^sdl3.Window, sdl_gl_context: rawptr) -> bool ---
	@(link_name = "ImGui_ImplSDL3_InitForVulkan")
	init_for_vulkan :: proc(window: ^sdl3.Window) -> bool ---
	@(link_name = "ImGui_ImplSDL3_InitForD3D")
	init_for_d3d :: proc(window: ^sdl3.Window) -> bool ---
	@(link_name = "ImGui_ImplSDL3_InitForMetal")
	init_for_metal :: proc(window: ^sdl3.Window) -> bool ---
	@(link_name = "ImGui_ImplSDL3_InitForSDLRenderer")
	init_for_sdl_renderer :: proc(window: ^sdl3.Window, renderer: ^sdl3.Renderer) -> bool ---
	@(link_name = "ImGui_ImplSDL3_InitForSDLGPU")
	init_for_sdlgpu :: proc(window: ^sdl3.Window) -> bool ---
	@(link_name = "ImGui_ImplSDL3_InitForOther")
	init_for_other :: proc(window: ^sdl3.Window) -> bool ---
	@(link_name = "ImGui_ImplSDL3_Shutdown")
	shutdown :: proc() ---
	@(link_name = "ImGui_ImplSDL3_NewFrame")
	new_frame :: proc() ---
	@(link_name = "ImGui_ImplSDL3_ProcessEvent")
	process_event :: proc(event: ^sdl3.Event) -> bool ---
	@(link_name = "ImGui_ImplSDL3_SetGamepadMode")
	set_gamepad_mode :: proc(mode: Gamepad_Mode, manual_gamepads_array: [^]^sdl3.Gamepad = nil, manual_gamepads_count: i32 = -1) ---
}
