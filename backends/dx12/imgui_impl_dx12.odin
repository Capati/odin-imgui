#+build windows
package imgui_impl_dx12

import "vendor:directx/d3d12"
import "vendor:directx/dxgi"

import im "./../../"

when ODIN_OS == .Windows {
	when ODIN_ARCH == .amd64 {
		@export
		foreign import imguilib "../../imgui_windows_x64.lib"
	} else {
		@export
		foreign import imguilib "../../imgui_windows_arm64.lib"
	}
} else {
	#panic("Unsupported platform")
}

// Initialization data, for Init()
InitInfo :: struct {
    Device: ^d3d12.IDevice,
    // Command queue used for queuing texture uploads.
    CommandQueue: ^d3d12.ICommandQueue,
    NumFramesInFlight: i32,
    // RenderTarget format.
    RTVFormat: dxgi.FORMAT,
    // DepthStencilView format.
    DSVFormat: dxgi.FORMAT,
    UserData: rawptr,

    // Allocating SRV descriptors for textures is up to the application, so we
    // provide callbacks. (current version of the backend will only allocate one
    // descriptor, from 1.92 the backend will need to allocate more)
    SrvDescriptorHeap: ^d3d12.IDescriptorHeap,
    SrvDescriptorAllocFn: proc "c" (
    	info: ^InitInfo,
    	out_cpu_desc_handle: ^d3d12.CPU_DESCRIPTOR_HANDLE,
    	out_gpu_desc_handle: ^d3d12.GPU_DESCRIPTOR_HANDLE),
    SrvDescriptorFreeFn: proc "c" (
    	info: ^InitInfo,
    	cpu_desc_handle: d3d12.CPU_DESCRIPTOR_HANDLE,
    	gpu_desc_handle: d3d12.GPU_DESCRIPTOR_HANDLE),
}

@(default_calling_convention = "c", link_prefix = "ImGui_ImplDX12_")
foreign imguilib {
	// Follow "Getting Started" link and check examples/ folder to learn about using backends!
	Init :: proc(info: ^InitInfo) -> bool ---
	Shutdown :: proc() ---
	NewFrame :: proc() ---
	RenderDrawData :: proc(
		draw_data: ^im.DrawData,
		graphics_command_list: ^d3d12.IGraphicsCommandList) ---

	// Use if you want to reset your rendering device without losing Dear ImGui state.
	CreateDeviceObjects :: proc() -> bool ---
	InvalidateDeviceObjects :: proc() ---

	// (Advanced) Use e.g. if you need to precisely control the timing of texture
	// updates (e.g. for staged rendering), by setting ImDrawData::Textures = nullptr
	// to handle this manually.
	UpdateTexture :: proc(
		tex: ^im.TextureData) ---
}
