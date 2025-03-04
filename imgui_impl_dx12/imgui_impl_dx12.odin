#+build windows
package imgui_impl_dx12

import im "./../"
import "vendor:directx/d3d12"
import "vendor:directx/dxgi"

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

// Initialization data, for ImGui_ImplDX12_Init()
Init_Info :: struct {
	device:                  ^d3d12.IDevice,
	command_queue:           ^d3d12.ICommandQueue,
	num_frames_in_flight:    i32,
	rtv_format:              dxgi.FORMAT, // RenderTarget format.
	dsv_format:              dxgi.FORMAT, // DepthStencilView format.
	user_data:               rawptr,
	srv_descriptor_heap:     ^d3d12.IDescriptorHeap,
	srv_descriptor_alloc_fn: proc "c" (
		info: ^Init_Info,
		out_cpu_desc_handle: ^d3d12.CPU_DESCRIPTOR_HANDLE,
		out_gpu_desc_handle: ^d3d12.GPU_DESCRIPTOR_HANDLE,
	),
	srv_descriptor_free_fn:  proc "c" (
		info: ^Init_Info,
		cpu_desc_handle: d3d12.CPU_DESCRIPTOR_HANDLE,
		gpu_desc_handle: d3d12.GPU_DESCRIPTOR_HANDLE,
	),
}

@(default_calling_convention = "c")
foreign lib {
	// Follow "Getting Started" link and check examples/ folder to learn about using backends!
	@(link_name = "ImGui_ImplDX12_Init")
	init :: proc(info: ^Init_Info) -> bool ---
	@(link_name = "ImGui_ImplDX12_Shutdown")
	shutdown :: proc() ---
	@(link_name = "ImGui_ImplDX12_NewFrame")
	new_frame :: proc() ---
	@(link_name = "ImGui_ImplDX12_RenderDrawData")
	render_draw_data :: proc(draw_data: ^Draw_Data, graphics_command_list: ^d3d12.IGraphicsCommandList) ---
	// Use if you want to reset your rendering device without losing Dear ImGui state.
	@(link_name = "ImGui_ImplDX12_CreateDeviceObjects")
	create_device_objects :: proc() -> bool ---
	@(link_name = "ImGui_ImplDX12_InvalidateDeviceObjects")
	invalidate_device_objects :: proc() ---
}
