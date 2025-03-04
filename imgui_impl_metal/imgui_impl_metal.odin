#+build darwin
package imgui_impl_metal

import im "../"
import mtl "vendor:darwin/Metal"

// NOTE[TS]: This is a workaround to force link with QuartzCore, as required by the imgui metal
// implementation. Else you'd have to manually link. We also depend on libcxx, which we can
// hackily depend on by attaching it to this import.
@(require, extra_linker_flags = "-lc++")
foreign import "system:QuartzCore.framework"

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
	@(link_name = "ImGui_ImplMetal_Init")
	init :: proc(device: ^mtl.Device) -> bool ---
	@(link_name = "ImGui_ImplMetal_Shutdown")
	shutdown :: proc() ---
	@(link_name = "ImGui_ImplMetal_NewFrame")
	new_frame :: proc(renderPassDescriptor: ^mtl.RenderPassDescriptor) ---
	@(link_name = "ImGui_ImplMetal_RenderDrawData")
	render_draw_data :: proc(draw_data: ^Draw_Data, commandBuffer: ^mtl.CommandBuffer, commandEncoder: ^mtl.RenderCommandEncoder) ---
	// Called by Init/NewFrame/Shutdown
	@(link_name = "ImGui_ImplMetal_CreateFontsTexture")
	create_fonts_texture :: proc(device: ^mtl.Device) -> bool ---
	@(link_name = "ImGui_ImplMetal_DestroyFontsTexture")
	destroy_fonts_texture :: proc() ---
	@(link_name = "ImGui_ImplMetal_CreateDeviceObjects")
	create_device_objects :: proc(device: ^mtl.Device) -> bool ---
	@(link_name = "ImGui_ImplMetal_DestroyDeviceObjects")
	destroy_device_objects :: proc() ---
}
