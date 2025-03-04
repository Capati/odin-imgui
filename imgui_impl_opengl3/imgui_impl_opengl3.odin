package imgui_impl_opengl3

import im "./../"

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

Draw_Data :: im.Draw_Data

@(default_calling_convention = "c")
foreign lib {
	// Follow "Getting Started" link and check examples/ folder to learn about using backends!
	@(link_name = "ImGui_ImplOpenGL3_Init")
	init :: proc(glsl_version: cstring = nil) -> bool ---
	@(link_name = "ImGui_ImplOpenGL3_Shutdown")
	shutdown :: proc() ---
	@(link_name = "ImGui_ImplOpenGL3_NewFrame")
	new_frame :: proc() ---
	@(link_name = "ImGui_ImplOpenGL3_RenderDrawData")
	render_draw_data :: proc(draw_data: ^Draw_Data) ---
	// (Optional) Called by Init/NewFrame/Shutdown
	@(link_name = "ImGui_ImplOpenGL3_CreateFontsTexture")
	create_fonts_texture :: proc() -> bool ---
	@(link_name = "ImGui_ImplOpenGL3_DestroyFontsTexture")
	destroy_fonts_texture :: proc() ---
	@(link_name = "ImGui_ImplOpenGL3_CreateDeviceObjects")
	create_device_objects :: proc() -> bool ---
	@(link_name = "ImGui_ImplOpenGL3_DestroyDeviceObjects")
	destroy_device_objects :: proc() ---
}
