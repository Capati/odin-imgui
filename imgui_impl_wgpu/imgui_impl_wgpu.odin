package imgui_impl_wgpu

import im "./../"
import "vendor:wgpu"

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

Init_Info :: struct {
	device:                     wgpu.Device,
	num_frames_in_flight:       i32,
	render_target_format:       wgpu.TextureFormat,
	depth_stencil_format:       wgpu.TextureFormat,
	pipeline_multisample_state: wgpu.MultisampleState,
}

INIT_INFO_DEFAULT :: Init_Info {
	num_frames_in_flight = 3,
	render_target_format = .Undefined,
	depth_stencil_format = .Undefined,
	pipeline_multisample_state = {count = 1, mask = max(u32), alphaToCoverageEnabled = false},
}

@(default_calling_convention = "c")
foreign lib {
	// Follow "Getting Started" link and check examples/ folder to learn about using backends!
	@(link_name = "ImGui_ImplWGPU_Init")
	init :: proc(init_info: ^Init_Info) -> bool ---
	@(link_name = "ImGui_ImplWGPU_Shutdown")
	shutdown :: proc() ---
	@(link_name = "ImGui_ImplWGPU_NewFrame")
	new_frame :: proc() ---
	@(link_name = "ImGui_ImplWGPU_RenderDrawData")
	render_draw_data :: proc(draw_data: ^Draw_Data, pass_encoder: wgpu.RenderPassEncoder) ---
	// Use if you want to reset your rendering device without losing Dear ImGui state.
	@(link_name = "ImGui_ImplWGPU_CreateDeviceObjects")
	create_device_objects :: proc() -> bool ---
	@(link_name = "ImGui_ImplWGPU_InvalidateDeviceObjects")
	invalidate_device_objects :: proc() ---
}
