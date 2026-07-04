package imgui_impl_wgpu

import im "./../"

import "vendor:wgpu"

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

// Initialization data, for ImGui_ImplWGPU_Init()
InitInfo :: struct {
    Device:                   wgpu.Device,
    NumFramesInFlight:        i32,
    RenderTargetFormat:       wgpu.TextureFormat,
    DepthStencilFormat:       wgpu.TextureFormat,
    PipelineMultisampleState: wgpu.MultisampleState,
}

DEFAULT_INIT_INFO :: InitInfo {
	NumFramesInFlight = 3,
	RenderTargetFormat = .Undefined,
	DepthStencilFormat = .Undefined,
	PipelineMultisampleState = {
		count = 1,
		mask = max(u32),
		alphaToCoverageEnabled = false,
	},
}

@(default_calling_convention = "c", link_prefix = "ImGui_ImplWGPU_")
foreign imguilib {
	// Follow "Getting Started" link and check examples/ folder to learn about using backends!
	Init :: proc(init_info: ^InitInfo) -> bool ---
	Shutdown :: proc() ---
	NewFrame :: proc() ---
	RenderDrawData :: proc(
		draw_data: ^im.DrawData,
		pass_encoder: wgpu.RenderPassEncoder) ---

	// Use if you want to reset your rendering device without losing Dear ImGui state.
	CreateDeviceObjects :: proc() -> bool ---
	InvalidateDeviceObjects :: proc() ---

	// (Advanced) Use e.g. if you need to precisely control the timing of texture
	// updates (e.g. for staged rendering), by setting ImDrawData::Textures = nullptr
	// to handle this manually.
	UpdateTexture :: proc(
		tex: ^im.TextureData) ---
}
