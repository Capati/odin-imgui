#+build windows
package imgui_impl_dx11

import im "./../../"
import "vendor:directx/d3d11"

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

@(default_calling_convention = "c", link_prefix = "ImGui_ImplDX11_")
foreign imguilib {
	// Follow "Getting Started" link and check examples/ folder to learn about using backends!
	Init :: proc(
		device: ^d3d11.IDevice,
		device_context: ^d3d11.IDeviceContext) -> bool ---
	Shutdown :: proc() ---
	NewFrame :: proc() ---
	RenderDrawData :: proc(
		draw_data: ^im.DrawData) ---

	// Use if you want to reset your rendering device without losing Dear ImGui state.
	CreateDeviceObjects :: proc() -> bool ---
	InvalidateDeviceObjects :: proc() ---

	// (Advanced) Use e.g. if you need to precisely control the timing of texture
	// updates (e.g. for staged rendering), by setting ImDrawData::Textures = nullptr
	// to handle this manually.
	UpdateTexture :: proc(tex: ^im.TextureData) ---
}
