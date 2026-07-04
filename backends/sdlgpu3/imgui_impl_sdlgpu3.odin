package imgui_impl_sdlgpu3

import im "../.."

import "vendor:sdl3"

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

// Initialization data, for ImGui_ImplSDLGPU_Init()
//
// - Remember to set ColorTargetFormat to the correct format. If you're
//   rendering to the swapchain, call SDL_GetGPUSwapchainTextureFormat() to
//   query the right value
InitInfo :: struct {
    Device:               ^sdl3.GPUDevice,
    ColorTargetFormat:    sdl3.GPUTextureFormat,
    MSAASamples:          sdl3.GPUSampleCount,
    // Only used in multi-viewports mode.
    SwapchainComposition: sdl3.GPUSwapchainComposition,
    // Only used in multi-viewports mode.
    PresentMode:          sdl3.GPUPresentMode,
}

DEFAULT_INIT_INFO :: InitInfo {
	Device               = nil,
	ColorTargetFormat    = .INVALID,
	MSAASamples          = ._1,
	SwapchainComposition = .SDR,
	PresentMode          = .VSYNC,
}

@(default_calling_convention = "c", link_prefix = "ImGui_ImplSDLGPU3_")
foreign imguilib {
	// Follow "Getting Started" link and check examples/ folder to learn about using backends!
	Init :: proc(info: ^InitInfo) -> bool ---
	Shutdown :: proc() ---
	NewFrame :: proc() ---
	PrepareDrawData :: proc(
		draw_data: ^im.DrawData,
		command_buffer: ^sdl3.GPUCommandBuffer) ---
	RenderDrawData :: proc(
		draw_data: ^im.DrawData,
		command_buffer: ^sdl3.GPUCommandBuffer,
		render_pass: ^sdl3.GPURenderPass,
		pipeline: ^sdl3.GPUGraphicsPipeline = nil) ---

	// Use if you want to reset your rendering device without losing Dear ImGui state.
	CreateDeviceObjects :: proc() ---
	DestroyDeviceObjects :: proc() ---

	// (Advanced) Use e.g. if you need to precisely control the timing of texture
	// updates (e.g. for staged rendering), by setting ImDrawData::Textures = nullptr
	// to handle this manually.
	UpdateTexture :: proc(tex: ^im.TextureData) ---
}
