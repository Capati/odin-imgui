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

// Backend uses a small number of descriptors per font atlas + as many as
// additional calls done to imvk.AddTexture().
MINIMUM_SAMPLED_IMAGE_POOL_SIZE :: 8 // Minimum per atlas
MINIMUM_SAMPLER_POOL_SIZE       :: 2 // Minimum for linear + nearest

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

//------------------------------------------------------------------------------
// Internal / Miscellaneous Vulkan Helpers
// -------------------------------------------------------------------------
// Used by example's. Used by multi-viewport features. PROBABLY NOT used by your own engine/app.
//
// You probably do NOT need to use or care about those functions. WE DO NOT
// PROVIDE STRONG GUARANTEES OF BACKWARD/FORWARD COMPATIBILITY.
//
// Those functions only exist because:
//
// 1. they facilitate the readability and maintenance of the multiple main.cpp
//    examples files.
// 1. the multi-viewport / platform window implementation needs them internally.
//
// Generally we avoid exposing any kind of superfluous high-level helpers in the
// backends, but it is too much code to duplicate everywhere so we exceptionally
// expose them.
//
// Your engine/app will likely _already_ have code to setup all that stuff (swap
// chain, render pass, frame buffers, etc.). You may read this code if you are
// curious, but it is recommended you use your own custom tailored code to do
// equivalent work.
//
// The ImGui_ImplVulkanH_XXX functions should NOT interact with any of the state
// used by the regular ImGui_ImplVulkan_XXX functions.
// -------------------------------------------------------------------------

@(default_calling_convention = "c", link_prefix = "ImGui_ImplVulkanH_")
foreign imguilib {
	// Helpers
	CreateOrResizeWindow :: proc(
		instance: vk.Instance,
		physical_device: vk.PhysicalDevice,
		device: vk.Device,
		wd: ^Window,
		queue_family: u32,
		allocator: ^vk.AllocationCallbacks,
		w: i32,
		h: i32,
		min_image_count: u32,
		image_usage: vk.ImageUsageFlags) ---
	DestroyWindow :: proc(
		instance: vk.Instance,
		device: vk.Device,
		wd: ^Window,
		allocator: ^vk.AllocationCallbacks) ---
	SelectSurfaceFormat :: proc(
		physical_device: vk.PhysicalDevice,
		surface: vk.SurfaceKHR,
		request_formats: ^vk.Format,
		request_formats_count: i32,
		request_color_space: vk.ColorSpaceKHR) -> vk.SurfaceFormatKHR ---
	SelectPresentMode :: proc(
		physical_device: vk.PhysicalDevice,
		surface: vk.SurfaceKHR,
		request_modes: ^vk.PresentModeKHR,
		request_modes_count: i32) -> vk.PresentModeKHR ---
	SelectPhysicalDevice :: proc(
		instance: vk.Instance) -> vk.PhysicalDevice ---
	SelectQueueFamilyIndex :: proc(
		physical_device: vk.PhysicalDevice) -> u32 ---
	GetMinImageCountFromPresentMode :: proc(
		present_mode: vk.PresentModeKHR) -> i32 ---
	// Access to Vulkan objects associated with a viewport (e.g to export a screenshot)
	GetWindowDataFromViewport :: proc(
		viewport: ^im.Viewport) -> ^Window ---
}

// Helper structure to hold the data needed by one rendering frame (Used by
// example's main.cpp. Used by multi-viewport features. Probably NOT used by
// your own engine/app.) [Please zero-clear before use!]
Frame :: struct {
    CommandPool:    vk.CommandPool,
    CommandBuffer:  vk.CommandBuffer,
    Fence:          vk.Fence,
    Backbuffer:     vk.Image,
    BackbufferView: vk.ImageView,
    Framebuffer:    vk.Framebuffer,
}

FrameSemaphores :: struct {
    ImageAcquiredSemaphore:  vk.Semaphore,
    RenderCompleteSemaphore: vk.Semaphore,
}

Vector_Frame :: struct {
    Size:     i32,
    Capacity: i32,
    Data:     ^Frame,
}

Vector_FrameSemaphores :: struct {
    Size:     i32,
    Capacity: i32,
    Data:     ^FrameSemaphores,
}

// Helper structure to hold the data needed by one rendering context into one OS
// window. (Used by example's main.cpp. Used by multi-viewport features.
// Probably NOT used by your own engine/app.)
Window :: struct {
    // Input
    UseDynamicRendering:    bool,
    // Surface created and destroyed by caller.
    Surface:                vk.SurfaceKHR,
    SurfaceFormat:          vk.SurfaceFormatKHR,
    PresentMode:            vk.PresentModeKHR,
    // RenderPass creation: main attachment description.
    AttachmentDesc:         vk.AttachmentDescription,
    // RenderPass creation: clear value when using VK_ATTACHMENT_LOAD_OP_CLEAR.
    ClearValue:             vk.ClearValue,

    // Internal
    // Generally same as passed to CreateOrResizeWindow()
    Width:                  i32,
    Height:                 i32,
    Swapchain:              vk.SwapchainKHR,
    RenderPass:             vk.RenderPass,
    // Current frame being rendered to (0 <= FrameIndex < FrameInFlightCount)
    FrameIndex:             u32,
    // Number of simultaneous in-flight frames (returned by
    // vkGetSwapchainImagesKHR, usually derived from min_image_count)
    ImageCount:             u32,
    // Number of simultaneous in-flight frames + 1, to be able to use it in
    // vkAcquireNextImageKHR
    SemaphoreCount:         u32,
    // Current set of swapchain wait semaphores we're using (needs to be
    // distinct from per frame data)
    SemaphoreIndex:         u32,
    Frames:                 Vector_Frame,
    FrameSemaphores:        Vector_FrameSemaphores,
}

DEFAULT_WINDOW :: Window {
	PresentMode = .FIFO,
	AttachmentDesc = {
		// Will automatically use wd->SurfaceFormat.format.
        format         = .UNDEFINED,
        samples        = {._1},
        loadOp         = .CLEAR,
        storeOp        = .STORE,
        stencilLoadOp  = .DONT_CARE,
        stencilStoreOp = .DONT_CARE,
        initialLayout  = .UNDEFINED,
        finalLayout    = .PRESENT_SRC_KHR,
	},
}
