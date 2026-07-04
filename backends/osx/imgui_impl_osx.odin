#+build darwin
package imgui_impl_osx

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

@(default_calling_convention = "c", link_prefix = "ImGui_ImplOSX_")
foreign imguilib {
	// Follow "Getting Started" link and check examples/ folder to learn about using backends!
	Init :: proc(
		view: rawptr) -> bool ---
	Shutdown :: proc() ---
	NewFrame :: proc(
		view: rawptr) ---
}
