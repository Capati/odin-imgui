package imgui_impl_vulkan

import im "./../"
import vk "vendor:vulkan"

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

// Initialization data, for ImGui_ImplVulkan_Init()
// [Please zero-clear before use!]
// - About descriptor pool:
//   - A VkDescriptorPool should be created with VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT,
//     and must contain a pool size large enough to hold a small number of VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER descriptors.
//   - As an convenience, by setting DescriptorPoolSize > 0 the backend will create one for you.
// - About dynamic rendering:
//   - When using dynamic rendering, set UseDynamicRendering=true and fill PipelineRenderingCreateInfo structure.
Init_Info :: struct {
	api_version:                    u32,
	instance:                       vk.Instance,
	physical_device:                vk.PhysicalDevice,
	device:                         vk.Device,
	queue_family:                   u32,
	queue:                          vk.Queue,
	descriptor_pool:                vk.DescriptorPool, // See requirements in note above; ignored if using DescriptorPoolSize > 0
	render_pass:                    vk.RenderPass, // Ignored if using dynamic rendering
	min_image_count:                u32, // >= 2
	image_count:                    u32, // >= MinImageCount
	msaa_samples:                   vk.SampleCountFlag, // 0 defaults to VK_SAMPLE_COUNT_1_BIT
	pipeline_cache:                 vk.PipelineCache,
	subpass:                        u32,
	descriptor_pool_size:           u32,
	use_dynamic_rendering:          bool,
	pipeline_rendering_create_info: vk.PipelineRenderingCreateInfoKHR,
	allocator:                      ^vk.AllocationCallbacks,
	check_vk_result_fn:             proc "c" (err: vk.Result),
	min_allocation_size:            vk.DeviceSize, // Minimum allocation size. Set to 1024*1024 to satisfy zealous best practices validation layer and waste a little memory.
}

@(default_calling_convention = "c")
foreign lib {
	// Follow "Getting Started" link and check examples/ folder to learn about using backends!
	@(link_name = "ImGui_ImplVulkan_Init")
	init :: proc(info: ^Init_Info) -> bool ---
	@(link_name = "ImGui_ImplVulkan_Shutdown")
	shutdown :: proc() ---
	@(link_name = "ImGui_ImplVulkan_NewFrame")
	new_frame :: proc() ---
	@(link_name = "ImGui_ImplVulkan_RenderDrawData")
	render_draw_data :: proc(draw_data: ^Draw_Data, command_buffer: vk.CommandBuffer, pipeline: vk.Pipeline = {}) ---
	@(link_name = "ImGui_ImplVulkan_CreateFontsTexture")
	create_fonts_texture :: proc() -> bool ---
	@(link_name = "ImGui_ImplVulkan_DestroyFontsTexture")
	destroy_fonts_texture :: proc() ---
	// To override MinImageCount after initialization (e.g. if swap chain is recreated)
	@(link_name = "ImGui_ImplVulkan_SetMinImageCount")
	set_min_image_count :: proc(min_image_count: u32) ---
	// Register a texture (VkDescriptorSet == ImTextureID)
	// FIXME: This is experimental in the sense that we are unsure how to best design/tackle this problem
	// Please post to https://github.com/ocornut/imgui/pull/914 if you have suggestions.
	@(link_name = "ImGui_ImplVulkan_AddTexture")
	add_texture :: proc(sampler: vk.Sampler, image_view: vk.ImageView, image_layout: vk.ImageLayout) -> vk.DescriptorSet ---
	@(link_name = "ImGui_ImplVulkan_RemoveTexture")
	remove_texture :: proc(descriptor_set: vk.DescriptorSet) ---
	// Optional: load Vulkan functions with a custom function loader
	// This is only useful with IMGUI_IMPL_VULKAN_NO_PROTOTYPES / VK_NO_PROTOTYPES
	@(link_name = "ImGui_ImplVulkan_LoadFunctions")
	load_functions :: proc(api_version: u32, loader_func: proc "c" (function_name: cstring, user_data: rawptr) -> vk.ProcVoidFunction, user_data: rawptr = nil) -> bool ---
}
