#+build windows
package imgui_impl_dx11

import im "./../"
import "vendor:directx/d3d11"

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
	@(link_name = "ImGui_ImplDX11_Init")
	init :: proc(device: ^d3d11.IDevice, device_context: ^d3d11.IDeviceContext) -> bool ---
	@(link_name = "ImGui_ImplDX11_Shutdown")
	shutdown :: proc() ---
	@(link_name = "ImGui_ImplDX11_NewFrame")
	new_frame :: proc() ---
	@(link_name = "ImGui_ImplDX11_RenderDrawData")
	render_draw_data :: proc(draw_data: ^Draw_Data) ---
	// Use if you want to reset your rendering device without losing Dear ImGui state.
	@(link_name = "ImGui_ImplDX11_CreateDeviceObjects")
	create_device_objects :: proc() -> bool ---
	@(link_name = "ImGui_ImplDX11_InvalidateDeviceObjects")
	invalidate_device_objects :: proc() ---
}
