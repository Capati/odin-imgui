package imgui_impl_sdlrenderer3

import im "./../../"

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

@(default_calling_convention = "c", link_prefix = "ImGui_ImplSDLRenderer3_")
foreign imguilib {
	// Follow "Getting Started" link and check examples/ folder to learn about using backends!
	Init :: proc(renderer: ^sdl3.Renderer) -> bool ---
	Shutdown :: proc() ---
	NewFrame :: proc() ---
	RenderDrawData :: proc(
		draw_data: ^im.DrawData,
		renderer: ^sdl3.Renderer) ---

	// Called by Init/NewFrame/Shutdown
	CreateDeviceObjects :: proc() ---
	DestroyDeviceObjects :: proc() ---

	// (Advanced) Use e.g. if you need to precisely control the timing of texture
	// updates (e.g. for staged rendering), by setting ImDrawData::Textures = nullptr
	// to handle this manually.
	UpdateTexture :: proc(
		tex: ^im.TextureData) ---
}
