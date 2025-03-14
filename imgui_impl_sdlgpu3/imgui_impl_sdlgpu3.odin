package imgui_impl_sdlgpu3

import im "../"
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

// Initialization data, for `imgui_impl_sdlgpu3.init()`.
// - Remember to set `color_target_format` to the correct format. If you're rendering to the
//   swapchain, call `sdl3.GetGPUSwapchainTextureFormat` to query the right value.
Init_Info :: struct {
	device:              ^sdl3.GPUDevice,
	color_target_format: sdl3.GPUTextureFormat,
	msaa_samples:        sdl3.GPUSampleCount,
}

@(default_calling_convention = "c")
foreign lib {
	// Follow "Getting Started" link and check examples/ folder to learn about using backends!
	@(link_name = "ImGui_ImplSDLGPU3_Init")
	init :: proc(info: ^Init_Info) -> bool ---
	@(link_name = "ImGui_ImplSDLGPU3_Shutdown")
	shutdown :: proc() ---
	@(link_name = "ImGui_ImplSDLGPU3_NewFrame")
	new_frame :: proc() ---
	@(link_name = "Imgui_ImplSDLGPU3_PrepareDrawData")
	prepare_draw_data :: proc(draw_data: ^im.Draw_Data, command_buffer: ^sdl3.GPUCommandBuffer) ---
	@(link_name = "ImGui_ImplSDLGPU3_RenderDrawData")
	render_draw_data :: proc(draw_data: ^im.Draw_Data, command_buffer: ^sdl3.GPUCommandBuffer, render_pass: ^sdl3.GPURenderPass, pipeline: ^sdl3.GPUGraphicsPipeline = nil) ---
	@(link_name = "ImGui_ImplSDLGPU3_CreateDeviceObjects")
	create_device_objects :: proc() ---
	@(link_name = "ImGui_ImplSDLGPU3_DestroyDeviceObjects")
	destroy_device_objects :: proc() ---
	@(link_name = "ImGui_ImplSDLGPU3_CreateFontsTexture")
	create_fonts_texture :: proc() ---
	@(link_name = "ImGui_ImplSDLGPU3_DestroyFontsTexture")
	destroy_fonts_texture :: proc() ---
}
