#+build darwin
package imgui_impl_osx

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

@(default_calling_convention = "c")
foreign lib {
	@(link_name = "ImGui_ImplOSX_Init")
	init :: proc(view: rawptr) -> bool ---
	@(link_name = "ImGui_ImplOSX_Shutdown")
	shutdown :: proc() ---
	@(link_name = "ImGui_ImplOSX_NewFrame")
	new_frame :: proc(view: rawptr) ---
}
