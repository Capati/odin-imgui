package imgui_impl_vulkan

import im "./../../"
import vk "vendor:vulkan"

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

Vector_VkDynamicState :: struct {
    Size:     i32,
    Capacity: i32,
    Data:     ^vk.DynamicState,
}

// Specify settings to create pipeline and swapchain
PipelineInfo :: struct {
    // For Main viewport only
    // Ignored if using dynamic rendering
    RenderPass:                  vk.RenderPass,

    // For Main and Secondary viewports
    Subpass:                     u32,
    // 0 defaults to VK_SAMPLE_COUNT_1_BIT
    MSAASamples:                 vk.SampleCountFlags,
    // Optional, allows to insert more dynamic states into our VkPipeline
    ExtraDynamicStates:          Vector_VkDynamicState,
    // Optional, valid if .sType == VK_STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO_KHR
    PipelineRenderingCreateInfo: vk.PipelineRenderingCreateInfoKHR,

    // For Secondary viewports only (created/managed by backend)
    //
    // Extra flags for vkCreateSwapchainKHR() calls for secondary viewports. We
    // automatically add VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT. You can add e.g.
    // VK_IMAGE_USAGE_TRANSFER_SRC_BIT if you need to capture from viewports.
    SwapChainImageUsage:         vk.ImageUsageFlags,
}

// Initialization data, for Init()
//
// [Please zero-clear before use!]
//
// - About descriptor pool:
//
//   - A VkDescriptorPool should be created with
//     VK_DESCRIPTOR_POOL_CREATE_FREE_DESCRIPTOR_SET_BIT, and must contain a
//     pool size large enough to hold a small number of
//     VK_DESCRIPTOR_TYPE_COMBINED_IMAGE_SAMPLER descriptors.
//   - As an convenience, by setting DescriptorPoolSize > 0 the backend will
//     create one for you.
// - About dynamic rendering:
//   - When using dynamic rendering, set UseDynamicRendering=true + fill
//     PipelineInfoMain.PipelineRenderingCreateInfo structure.
InitInfo :: struct {
	// Fill with API version of Instance, e.g. VK_API_VERSION_1_3 or your value
	// of VkApplicationInfo::apiVersion. May be lower than header version
	// (VK_HEADER_VERSION_COMPLETE)
	ApiVersion:                  u32,
	Instance:                    vk.Instance,
	PhysicalDevice:              vk.PhysicalDevice,
	Device:                      vk.Device,
	QueueFamily:                 u32,
	Queue:                       vk.Queue,
	// See requirements in note above; ignored if using DescriptorPoolSize > 0
	DescriptorPool:              vk.DescriptorPool,
	// Optional: set to create internal ImageView descriptor pool automatically
	// instead of using DescriptorPool.
	DescriptorPoolSize:          u32,
	// >= 2
	MinImageCount:               u32,
	// >= MinImageCount
	ImageCount:                  u32,
	// Optional
	PipelineCache:               vk.PipelineCache,

	// Pipeline
	// Infos for Main Viewport (created by app/user)
	PipelineInfoMain:            PipelineInfo,
	// Infos for Secondary Viewports (created by backend)
	PipelineInfoForViewports:    PipelineInfo,

	// // --> Since 2025/09/26: set 'PipelineInfoMain.RenderPass' instead
	// RenderPass:                  vk.RenderPass,
	// // --> Since 2025/09/26: set 'PipelineInfoMain.Subpass' instead
	// Subpass:                     u32,
	// // --> Since 2025/09/26: set 'PipelineInfoMain.MSAASamples' instead
	// MSAASamples:                 vk.SampleCountFlags,
	// // Since 2025/09/26: set 'PipelineInfoMain.PipelineRenderingCreateInfo' instead
	// PipelineRenderingCreateInfo: vk.PipelineRenderingCreateInfoKHR,

	// (Optional) Dynamic Rendering Need to explicitly enable
	// VK_KHR_dynamic_rendering extension to use this, even for Vulkan 1.3 +
	// setup PipelineInfoMain.PipelineRenderingCreateInfo and
	// PipelineInfoViewports.PipelineRenderingCreateInfo.
	UseDynamicRendering:         bool,

	// (Optional) Allocation, Debugging
	Allocator:                   ^vk.AllocationCallbacks,
	CheckVkResultFn:             proc "c" (err: vk.Result),
	// Minimum allocation size. Set to 1024*1024 to satisfy zealous best
	// practices validation layer and waste a little memory.
	MinAllocationSize:           vk.DeviceSize,

	// (Optional) Customize default vertex/fragment shaders.
	//
	// - if .sType == VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO we use
	//   specified structs, otherwise we use defaults.
	// - Shader inputs/outputs need to match ours. Code/data pointed to by the
	//   structure needs to survive for whole during of backend usage.
	CustomShaderVertCreateInfo:  vk.ShaderModuleCreateInfo,
	CustomShaderFragCreateInfo:  vk.ShaderModuleCreateInfo,
}

@(default_calling_convention = "c", link_prefix = "ImGui_ImplVulkan_")
foreign imguilib {
	// Follow "Getting Started" link and check examples/ folder to learn about using backends!
	Init :: proc(info: ^InitInfo) -> bool ---
	Shutdown :: proc() ---
	NewFrame :: proc() ---
	RenderDrawData :: proc(
		draw_data: ^im.DrawData,
		command_buffer: vk.CommandBuffer,
		pipeline: vk.Pipeline = {}) ---
	// To override MinImageCount after initialization (e.g. if swap chain is recreated)
	SetMinImageCount :: proc(
		min_image_count: u32) ---

	// (Advanced) Use e.g. if you need to recreate pipeline without reinitializing the
	// backend (see #8110, #8111) The main window pipeline will be created by Init() if
	// possible (== RenderPass xor (UseDynamicRendering &&
	// PipelineRenderingCreateInfo->sType ==
	// VK_STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO_KHR)) Else, the pipeline can be
	// created, or re-created, using CreateMainPipeline() before rendering.
	CreateMainPipeline :: proc(
		#by_ptr info: PipelineInfo) ---

	// (Advanced) Use e.g. if you need to precisely control the timing of texture
	// updates (e.g. for staged rendering), by setting ImDrawData::Textures = nullptr
	// to handle this manually.
	UpdateTexture :: proc(
		tex: ^im.TextureData) ---

	// Register a texture (VkDescriptorSet for a VK_DESCRIPTOR_TYPE_SAMPLED_IMAGE == ImTextureID)
	AddTexture :: proc(
		image_view: vk.ImageView,
		image_layout: vk.ImageLayout) -> vk.DescriptorSet ---
	RemoveTexture :: proc(
		descriptor_set: vk.DescriptorSet) ---

	// // Ignore VkSampler
	// AddTexture :: proc(
	// 	sampler: vk.Sampler,
	// 	image_view: vk.ImageView,
	// 	image_layout: vk.ImageLayout) -> vk.DescriptorSet ---

	// Optional: load Vulkan functions with a custom function loader
	// This is only useful with IMGUI_IMPL_VULKAN_NO_PROTOTYPES / VK_NO_PROTOTYPES
	LoadFunctions :: proc(
		api_version: u32,
		loader_func: proc "c" (
			function_name: cstring,
			user_data: rawptr) -> vk.ProcVoidFunction,
		user_data: rawptr = nil) -> bool ---
}
