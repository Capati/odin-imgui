#+build darwin
package imgui_impl_metal

import im "../"

import mtl "vendor:darwin/Metal"

// NOTE: This is a workaround to force link with QuartzCore, as required by
// the imgui metal implementation. Else you'd have to manually link. We also
// depend on libcxx, which we can hackily depend on by attaching it to this import.
@(require, extra_linker_flags = "-lc++")
foreign import "system:QuartzCore.framework"

when ODIN_OS == .Darwin {
	when ODIN_ARCH == .amd64 {
		@export
		foreign import imguilib "../../libimgui_macosx_x64.a"
	} else {
		@export
		foreign import imguilib "../../libimgui_macosx_arm64.a"
	}
} else {
	#panic("Unsupported platform")
}

@(default_calling_convention = "c", link_prefix = "ImGui_ImplMetal_")
foreign imguilib {
	// Follow "Getting Started" link and check examples/ folder to learn about using backends!
	Init :: proc(device: ^mtl.Device) -> bool ---
	Shutdown :: proc() ---
	NewFrame :: proc(renderPassDescriptor: ^mtl.RenderPassDescriptor) ---
	RenderDrawData :: proc(
		drawData: ^im.DrawData,
		commandBuffer: ^mtl.CommandBuffer,
		commandEncoder: ^mtl.RenderCommandEncoder) ---

	// Called by Init/NewFrame/Shutdown
	CreateDeviceObjects :: proc(device: ^mtl.Device) -> bool ---
	DestroyDeviceObjects :: proc() ---

	// (Advanced) Use e.g. if you need to precisely control the timing of texture
	// updates (e.g. for staged rendering), by setting ImDrawData::Textures = nullptr
	// to handle this manually.
	UpdateTexture :: proc(
		tex: ^im.TextureData) ---
}
