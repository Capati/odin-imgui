package imgui_impl_sdlrenderer2

import im "./../"
import "vendor:sdl2"

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
    @(link_name = "ImGui_ImplSDLRenderer2_Init")
    init :: proc(renderer: ^sdl2.Renderer) -> bool ---
    @(link_name = "ImGui_ImplSDLRenderer2_Shutdown")
    shutdown :: proc() ---
    @(link_name = "ImGui_ImplSDLRenderer2_NewFrame")
    new_frame :: proc() ---
    @(link_name = "ImGui_ImplSDLRenderer2_RenderDrawData")
    render_draw_data :: proc(draw_data: ^Draw_Data, renderer: ^sdl2.Renderer) ---
    // Called by Init/NewFrame/Shutdown
    @(link_name = "ImGui_ImplSDLRenderer2_CreateFontsTexture")
    create_fonts_texture :: proc() -> bool ---
    @(link_name = "ImGui_ImplSDLRenderer2_DestroyFontsTexture")
    destroy_fonts_texture :: proc() ---
    @(link_name = "ImGui_ImplSDLRenderer2_CreateDeviceObjects")
    create_device_objects :: proc() -> bool ---
    @(link_name = "ImGui_ImplSDLRenderer2_DestroyDeviceObjects")
    destroy_device_objects :: proc() ---
}
