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

// Matches C ImVector<VkDynamicState>
ImVector_DynamicState :: struct {
	size:     i32,
	capacity: i32,
	data:     ^vk.DynamicState,
}

// Matches C ImGui_ImplVulkan_PipelineInfo
// [Please zero-clear before use!]
Pipeline_Info :: struct {
	render_pass:                     vk.RenderPass,                     // Ignored if using dynamic rendering
	subpass:                         u32,                               //
	msaa_samples:                    vk.SampleCountFlag,                // 0 defaults to VK_SAMPLE_COUNT_1_BIT
	extra_dynamic_states:            ImVector_DynamicState,             // Optional, allows to insert more dynamic states into our VkPipeline
	pipeline_rendering_create_info:  vk.PipelineRenderingCreateInfoKHR, // Valid if .sType == VK_STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO_KHR
	swap_chain_image_usage:          vk.ImageUsageFlags,                // Extra flags for secondary viewports
}

// Matches C ImGui_ImplVulkan_InitInfo
// [Please zero-clear before use!]
// - About descriptor pool:
//   - A descriptor_pool should be created with VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT,
//     and must contain a pool size large enough to hold a small number of VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER descriptors.
//   - As an convenience, by setting descriptor_pool_size > 0 the backend will create one for you.
// - About dynamic rendering:
//   - When using dynamic rendering, set use_dynamic_rendering=true and fill Pipeline_Info.pipeline_rendering_create_info structure.
Init_Info :: struct {
	api_version:                    u32,
	instance:                       vk.Instance,
	physical_device:                vk.PhysicalDevice,
	device:                         vk.Device,
	queue_family:                   u32,
	queue:                          vk.Queue,
	descriptor_pool:                vk.DescriptorPool,          // Ignored if using descriptor_pool_size > 0
	descriptor_pool_size:           u32,                        // Optional: set to create internal pool automatically
	min_image_count:                u32,                        // >= 2
	image_count:                    u32,                        // >= min_image_count
	pipeline_cache:                 vk.PipelineCache,           // Optional

	// Pipeline
	pipeline_info_main:             Pipeline_Info,              // Infos for Main Viewport (created by app/user)
	pipeline_info_for_viewports:    Pipeline_Info,              // Infos for Secondary Viewports (created by backend)

	// Dynamic Rendering
	use_dynamic_rendering:          bool,

	// Allocation, Debugging
	allocator:                      ^vk.AllocationCallbacks,
	check_vk_result_fn:             proc "c" (err: vk.Result),
	min_allocation_size:            vk.DeviceSize,              // Minimum allocation size. Set to 1024*1024 to satisfy zealous best practices validation layer and waste a little memory.

	// Custom shaders
	custom_shader_vert_create_info: vk.ShaderModuleCreateInfo,
	custom_shader_frag_create_info: vk.ShaderModuleCreateInfo,
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
	// To override MinImageCount after initialization (e.g. if swap chain is recreated)
	@(link_name = "ImGui_ImplVulkan_SetMinImageCount")
	set_min_image_count :: proc(min_image_count: u32) ---
	// Register a texture (VkDescriptorSet == ImTextureID)
	// Note: The C library has two overloads (with and without sampler). The sampler version is obsolete.
	// Both link to "ImGui_ImplVulkan_AddTexture", so we only declare the current signature.
	@(link_name = "ImGui_ImplVulkan_AddTexture")
	add_texture :: proc(image_view: vk.ImageView, image_layout: vk.ImageLayout) -> vk.DescriptorSet ---
	@(link_name = "ImGui_ImplVulkan_RemoveTexture")
	remove_texture :: proc(descriptor_set: vk.DescriptorSet) ---
	// Optional: load Vulkan functions with a custom function loader
	@(link_name = "ImGui_ImplVulkan_LoadFunctions")
	load_functions :: proc(api_version: u32, loader_func: proc "c" (function_name: cstring, user_data: rawptr) -> vk.ProcVoidFunction, user_data: rawptr = nil) -> bool ---
	// Create main pipeline (e.g. if you need to recreate without reinitializing)
	@(link_name = "ImGui_ImplVulkan_CreateMainPipeline")
	create_main_pipeline :: proc(info: ^Pipeline_Info) ---
	// Update texture
	@(link_name = "ImGui_ImplVulkan_UpdateTexture")
	update_texture :: proc(tex: ^im.Texture_Data) ---
}
