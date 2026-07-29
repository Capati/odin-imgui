package example_glfw_vulkan

import "base:runtime"
import "core:fmt"
import "core:strings"
import "core:slice"

import "vendor:glfw"
import vk "vendor:vulkan"

import im "../../"
import imglfw "../../backends/glfw"
import imvk "../../backends/vulkan"

// Data
g_instance_api_version: u32 = vk.API_VERSION_1_0
g_allocator:            ^vk.AllocationCallbacks = nil
g_instance:             vk.Instance = {}
g_physical_device:      vk.PhysicalDevice = {}
g_device:               vk.Device = {}
g_queue_family:         u32 = max(u32)
g_queue:                vk.Queue = {}
g_pipeline_cache:       vk.PipelineCache = {}
g_descriptor_pool:      vk.DescriptorPool = {}
g_main_window_data:     imvk.Window
g_min_image_count:      u32 = 2
g_swap_chain_rebuild:   bool = false

when ODIN_DEBUG {
    g_debug_messenger: vk.DebugUtilsMessengerEXT = {}
}

glfw_error_callback :: proc "c" (error: i32, description: cstring) {
	context = runtime.default_context()
	fmt.eprintfln("GLFW Error %d: %s", error, description)
}

check_vk_result :: proc(err: vk.Result, loc := #caller_location) {
	if err == .SUCCESS {
		return
	}
	fmt.eprintfln("[Vulkan] Error: vk.Result = %d", err)
	assert(i32(err) >= 0, loc = loc)
}

byte_arr_str :: proc(arr: ^[$N]byte) -> string {
	return strings.truncate_to_byte(string(arr[:]), 0)
}

is_extension_available :: proc(properties: []vk.ExtensionProperties, extension: string) -> bool {
	for &p in properties {
		if byte_arr_str(&p.extensionName) == extension {
			return true
		}
	}
	return false
}

debug_callback :: proc "system" (
    messageSeverity: vk.DebugUtilsMessageSeverityFlagsEXT,
    messageTypes: vk.DebugUtilsMessageTypeFlagsEXT,
    pCallbackData: ^vk.DebugUtilsMessengerCallbackDataEXT,
    pUserData: rawptr,
) -> b32 {
    context = runtime.default_context()

    if .WARNING in messageSeverity {
        fmt.printfln("[%v]: %s", messageTypes, pCallbackData.pMessage)
    } else if .ERROR in messageSeverity {
        fmt.eprintfln("[%v]: %s", messageTypes, pCallbackData.pMessage)
        runtime.debug_trap()
    } else {
        fmt.printfln("[%v]: %s", messageTypes, pCallbackData.pMessage)
    }

    return false // Applications must return false here
}

setup_vulkan :: proc() {
	vk.load_proc_addresses_global(auto_cast glfw.GetInstanceProcAddress)

	ta := context.temp_allocator
	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

	// Query current instance version
	// Instance implementation may be too old to support EnumerateInstanceVersion. We need
	// to check the function pointer before calling it, if the function doesn't exist,
	// then the instance version must be 1.0.
	if vk.EnumerateInstanceVersion != nil {
		res := vk.EnumerateInstanceVersion(&g_instance_api_version)
		if res != .SUCCESS {
			g_instance_api_version = vk.API_VERSION_1_0
		}
	}

	// Create Vulkan Instance
	{
		extensions := make([dynamic]cstring, 0, 8, ta)
		glfw_extensions := glfw.GetRequiredInstanceExtensions()
		append(&extensions, ..glfw_extensions)

		app_info := vk.ApplicationInfo {
			sType              = .APPLICATION_INFO,
			engineVersion      = vk.MAKE_VERSION(1, 0, 0),
			apiVersion         = g_instance_api_version,
			applicationVersion = vk.MAKE_VERSION(1, 0, 0),
		}

		create_info: vk.InstanceCreateInfo
		create_info.sType = .INSTANCE_CREATE_INFO
		create_info.pApplicationInfo = &app_info

		// Enumerate available extensions
		properties_count: u32 = ---
		vk.EnumerateInstanceExtensionProperties(nil, &properties_count, nil)
		properties := make([]vk.ExtensionProperties, properties_count, ta)
		check_vk_result(vk.EnumerateInstanceExtensionProperties(
			nil, &properties_count, raw_data(properties)))

		// Enable required extensions
		if is_extension_available(properties,
			vk.KHR_GET_PHYSICAL_DEVICE_PROPERTIES_2_EXTENSION_NAME,
		) {
			append(&extensions, vk.KHR_GET_PHYSICAL_DEVICE_PROPERTIES_2_EXTENSION_NAME)
		}
		if is_extension_available(properties, vk.KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME) {
			append(&extensions, vk.KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME)
			create_info.flags |= {.ENUMERATE_PORTABILITY_KHR}
		}

        // Enabling validation layers
		when ODIN_DEBUG {
			required_layers := []cstring{ "VK_LAYER_KHRONOS_validation" }

			layer_count: u32
			check_vk_result(vk.EnumerateInstanceLayerProperties(&layer_count, nil))

			available_layers := make([]vk.LayerProperties, layer_count, ta)
			check_vk_result(vk.EnumerateInstanceLayerProperties(
				&layer_count, raw_data(available_layers)))

			validation_layers_available := true
			CHECK_LAYER: for layer in required_layers {
			    for &available in available_layers {
			        layer_name := byte_arr_str(&available.layerName)
			        if layer_name == string(layer) {
				        continue CHECK_LAYER
			        }
			    }
		        validation_layers_available = false
		        break
			}

			debug_utils_available: bool
			messenger_create_info: vk.DebugUtilsMessengerCreateInfoEXT

			if validation_layers_available &&
				is_extension_available(properties, vk.EXT_DEBUG_UTILS_EXTENSION_NAME,
			) {
				debug_utils_available = true

		        create_info.enabledLayerCount = u32(len(required_layers))
		        create_info.ppEnabledLayerNames = raw_data(required_layers)
				append(&extensions, vk.EXT_DEBUG_UTILS_EXTENSION_NAME)

				messenger_create_info.sType           = .DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT
				messenger_create_info.messageSeverity = { .WARNING, .ERROR }
				messenger_create_info.messageType     = { .GENERAL, .VALIDATION, .PERFORMANCE }
				messenger_create_info.pfnUserCallback = debug_callback

				create_info.pNext = &messenger_create_info
			}
		}

		// Create Vulkan Instance
        create_info.enabledExtensionCount = u32(len(extensions))
        create_info.ppEnabledExtensionNames = raw_data(extensions)
        check_vk_result(vk.CreateInstance(&create_info, g_allocator, &g_instance))

        vk.load_proc_addresses_instance(g_instance)

        when ODIN_DEBUG {
        	if debug_utils_available {
				debug_utils_create_info := vk.DebugUtilsMessengerCreateInfoEXT {
					sType           = .DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
					messageSeverity = { .WARNING, .ERROR },
					messageType     = { .GENERAL, .VALIDATION, .PERFORMANCE },
					pfnUserCallback = debug_callback,
				}

				check_vk_result(vk.CreateDebugUtilsMessengerEXT(
					g_instance, &debug_utils_create_info, nil, &g_debug_messenger))
        	}
        }
	}

	// Load Vulkan functions for use in ImGUI
	imvk.LoadFunctions(
		g_instance_api_version,
	    proc "c" (function_name: cstring, user_data: rawptr) -> vk.ProcVoidFunction {
	        return vk.ProcVoidFunction(glfw.GetInstanceProcAddress(g_instance, function_name))
	    },
	    nil,
	)

	// Select Physical Device (GPU)
    g_physical_device = imvk.SelectPhysicalDevice(g_instance)
    assert(g_physical_device != {})

    // Select graphics queue family
    g_queue_family = imvk.SelectQueueFamilyIndex(g_physical_device)
    assert(g_queue_family != max(u32))

    // Create Logical Device (with 1 queue)
    {
		extensions := make([dynamic]cstring, 0, 8, ta)
		append(&extensions, vk.KHR_SWAPCHAIN_EXTENSION_NAME)

		// Enumerate physical device extension
		properties_count: u32 = ---
        vk.EnumerateDeviceExtensionProperties(g_physical_device, nil, &properties_count, nil)
        properties := make([]vk.ExtensionProperties, properties_count, ta)
        vk.EnumerateDeviceExtensionProperties(
        	g_physical_device, nil, &properties_count, raw_data(properties))
        if is_extension_available(properties, vk.KHR_PORTABILITY_SUBSET_EXTENSION_NAME) {
			append(&extensions, vk.KHR_PORTABILITY_SUBSET_EXTENSION_NAME)
		}

        queue_priority := []f32{ 1.0 }
        queue_info: [1]vk.DeviceQueueCreateInfo
        queue_info[0].sType = .DEVICE_QUEUE_CREATE_INFO
        queue_info[0].queueFamilyIndex = g_queue_family
        queue_info[0].queueCount = 1
        queue_info[0].pQueuePriorities = raw_data(queue_priority)
        create_info: vk.DeviceCreateInfo
        create_info.sType = .DEVICE_CREATE_INFO
        create_info.queueCreateInfoCount = len(queue_info)
        create_info.pQueueCreateInfos = raw_data(queue_info[:])
        create_info.enabledExtensionCount = u32(len(extensions))
        create_info.ppEnabledExtensionNames = raw_data(extensions)
        check_vk_result(vk.CreateDevice(g_physical_device, &create_info, nil, &g_device))
        vk.load_proc_addresses_device(g_device)
        vk.GetDeviceQueue(g_device, g_queue_family, 0, &g_queue)
    }

	pool_sizes := []vk.DescriptorPoolSize {
	    { .SAMPLED_IMAGE, imvk.MINIMUM_SAMPLED_IMAGE_POOL_SIZE },
	    { .SAMPLER,       imvk.MINIMUM_SAMPLER_POOL_SIZE },
	}

	pool_info := vk.DescriptorPoolCreateInfo {
	    sType         = .DESCRIPTOR_POOL_CREATE_INFO,
	    flags         = {.FREE_DESCRIPTOR_SET},
	    poolSizeCount = u32(len(pool_sizes)),
	    pPoolSizes    = raw_data(pool_sizes),
	}

	for &pool_size in pool_sizes {
	    pool_info.maxSets += pool_size.descriptorCount
	}

	check_vk_result(vk.CreateDescriptorPool(g_device, &pool_info, nil, &g_descriptor_pool))
}

APP_USE_UNLIMITED_FRAME_RATE :: #config(APP_USE_UNLIMITED_FRAME_RATE, true)

setup_vulkan_window :: proc(wd: ^imvk.Window, surface: vk.SurfaceKHR, width, height: i32) {
	assert(wd != nil)
	wd^ = imvk.DEFAULT_WINDOW

	// Check for WSI support
	res: b32
	vk.GetPhysicalDeviceSurfaceSupportKHR(g_physical_device, g_queue_family, surface, &res)
	ensure(bool(res), "Error no WSI support on physical device")

	// Select Surface Format
	request_surface_image_format := []vk.Format{
		.B8G8R8A8_UNORM, .R8G8B8A8_UNORM, .B8G8R8_UNORM, .R8G8B8_UNORM }
	request_surface_color_space := vk.ColorSpaceKHR.SRGB_NONLINEAR
    wd.Surface = surface
	wd.SurfaceFormat = imvk.SelectSurfaceFormat(
		g_physical_device,
		wd.Surface,
		raw_data(request_surface_image_format),
		i32(len(request_surface_image_format)),
		request_surface_color_space)

	// Select Present Mode
	when APP_USE_UNLIMITED_FRAME_RATE {
		present_modes := []vk.PresentModeKHR{ .MAILBOX, .IMMEDIATE, .FIFO }
	} else {
		present_modes := []vk.PresentModeKHR{ .FIFO }
	}
    wd.PresentMode = imvk.SelectPresentMode(
    	g_physical_device, wd.Surface, raw_data(present_modes), i32(len(present_modes)))
    fmt.printfln("[Vulkan] Selected PresentMode = %v", wd.PresentMode)

	// Create SwapChain, RenderPass, Framebuffer, etc.
    assert(g_min_image_count >= 2)
    imvk.CreateOrResizeWindow(
    	instance        = g_instance,
    	physical_device = g_physical_device,
    	device          = g_device,
    	wd              = wd,
    	queue_family    = g_queue_family,
    	allocator       = nil,
    	w               = width,
    	h               = height,
    	min_image_count = g_min_image_count,
    	image_usage     = {},
    )
}

cleanup_vulkan :: proc() {
	vk.DestroyDescriptorPool(g_device, g_descriptor_pool, nil)

	vk.DestroyDevice(g_device, nil)

	when ODIN_DEBUG {
		if g_debug_messenger != {} {
			vk.DestroyDebugUtilsMessengerEXT(g_instance, g_debug_messenger, nil)
		}
	}
	vk.DestroyInstance(g_instance, nil)
}

cleanup_vulkan_window :: proc(wd: ^imvk.Window) {
    imvk.DestroyWindow(g_instance, g_device, wd, nil)
    vk.DestroySurfaceKHR(g_instance, wd.Surface, nil)
}

frame_render :: proc(wd: ^imvk.Window, draw_data: ^im.DrawData) {
	frame_semaphores := slice.from_ptr(wd.FrameSemaphores.Data, int(wd.FrameSemaphores.Size))
    image_acquired_semaphore : = frame_semaphores[wd.SemaphoreIndex].ImageAcquiredSemaphore
    render_complete_semaphore := frame_semaphores[wd.SemaphoreIndex].RenderCompleteSemaphore
    err := vk.AcquireNextImageKHR(
    	g_device, wd.Swapchain, max(u64), image_acquired_semaphore, {}, &wd.FrameIndex)
    if err == .ERROR_OUT_OF_DATE_KHR || err == .SUBOPTIMAL_KHR {
        g_swap_chain_rebuild = true
    }
    if err == .ERROR_OUT_OF_DATE_KHR {
        return
    }
    if err != .SUBOPTIMAL_KHR {
        check_vk_result(err)
    }

	frames := slice.from_ptr(wd.Frames.Data, int(wd.Frames.Size))
    fd := &frames[wd.FrameIndex]
    {
    	// wait indefinitely instead of periodically checking
        check_vk_result(vk.WaitForFences(g_device, 1, &fd.Fence, true, max(u64)))
        check_vk_result(vk.ResetFences(g_device, 1, &fd.Fence))
    }
    {
        check_vk_result(vk.ResetCommandPool(g_device, fd.CommandPool, {}))
        info := vk.CommandBufferBeginInfo {
	        sType = .COMMAND_BUFFER_BEGIN_INFO,
	        flags = {.ONE_TIME_SUBMIT},
        }
        check_vk_result(vk.BeginCommandBuffer(fd.CommandBuffer, &info))
    }
    {
    	render_area := vk.Rect2D {
    		extent = { u32(wd.Width), u32(wd.Height) },
    	}
        info := vk.RenderPassBeginInfo {
	        sType           = .RENDER_PASS_BEGIN_INFO,
	        renderPass      = wd.RenderPass,
	        framebuffer     = fd.Framebuffer,
	        renderArea      = render_area,
	        clearValueCount = 1,
	        pClearValues    = &wd.ClearValue,
        }
        vk.CmdBeginRenderPass(fd.CommandBuffer, &info, .INLINE)
    }

    // Record dear imgui primitives into command buffer
    imvk.RenderDrawData(draw_data, fd.CommandBuffer)

    // Submit command buffer
    vk.CmdEndRenderPass(fd.CommandBuffer)
    {
        wait_stage := vk.PipelineStageFlags{.COLOR_ATTACHMENT_OUTPUT}
        info := vk.SubmitInfo {
	        sType                = .SUBMIT_INFO,
	        waitSemaphoreCount   = 1,
	        pWaitSemaphores      = &image_acquired_semaphore,
	        pWaitDstStageMask    = &wait_stage,
	        commandBufferCount   = 1,
	        pCommandBuffers      = &fd.CommandBuffer,
	        signalSemaphoreCount = 1,
	        pSignalSemaphores    = &render_complete_semaphore,
        }

        check_vk_result(vk.EndCommandBuffer(fd.CommandBuffer))
        check_vk_result(vk.QueueSubmit(g_queue, 1, &info, fd.Fence))
    }
}

frame_present :: proc(wd: ^imvk.Window) {
    if g_swap_chain_rebuild {
        return
    }
	frame_semaphores := slice.from_ptr(wd.FrameSemaphores.Data, int(wd.FrameSemaphores.Size))
    render_complete_semaphore := frame_semaphores[wd.SemaphoreIndex].RenderCompleteSemaphore
    info := vk.PresentInfoKHR {
	    sType              = .PRESENT_INFO_KHR,
	    waitSemaphoreCount = 1,
	    pWaitSemaphores    = &render_complete_semaphore,
	    swapchainCount     = 1,
	    pSwapchains        = &wd.Swapchain,
	    pImageIndices      = &wd.FrameIndex,
    }
    err := vk.QueuePresentKHR(g_queue, &info)
    if err == .ERROR_OUT_OF_DATE_KHR || err == .SUBOPTIMAL_KHR {
        g_swap_chain_rebuild = true
    }
    if err == .ERROR_OUT_OF_DATE_KHR {
        return
    }
    if err != .SUBOPTIMAL_KHR {
        check_vk_result(err)
    }
    // Now we can use the next set of semaphores
    wd.SemaphoreIndex = (wd.SemaphoreIndex + 1) % wd.SemaphoreCount
}

main :: proc() {
	glfw.SetErrorCallback(glfw_error_callback)
	ensure(bool(glfw.Init()))

	// Create window with Vulkan context
	glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
	main_scale := imglfw.GetContentScaleForMonitor(glfw.GetPrimaryMonitor())
	window := glfw.CreateWindow(
		i32(1280 * main_scale),
		i32(800 * main_scale),
		"Dear ImGui GLFW+Vulkan example",
		nil, nil)

	ensure(bool(glfw.VulkanSupported()), "GLFW: Vulkan Not Supported")

	setup_vulkan()

	// Create Window Surface using GLFW
	surface: vk.SurfaceKHR = ---
	check_vk_result(glfw.CreateWindowSurface(g_instance, window, nil, &surface))

	// Create Framebuffers
	w, h := glfw.GetFramebufferSize(window)
	wd := &g_main_window_data
	setup_vulkan_window(wd, surface, w, h)

	// Setup Dear ImGui context
	im.CHECKVERSION()
	im.CreateContext()
	io := im.GetIO()
	io.ConfigFlags |= {
		.NavEnableKeyboard, // Enable Keyboard Controls
		.NavEnableGamepad,  // Enable Gamepad Controls
		.DockingEnable,     // Enable Docking
		.ViewportsEnable,   // Enable Multi-Viewport / Platform Windows
	}
	// io.ConfigViewportsNoAutoMerge = true
	// io.ConfigViewportsNoTaskBarIcon = true

	// Setup Dear ImGui style
	im.StyleColorsDark()
	// im.StyleColorsLight()

	// Setup scaling
	style := im.GetStyle()
	// Bake a fixed style scale. (until we have a solution for dynamic style
	// scaling, changing this requires resetting Style + calling this again)
	im.Style_ScaleAllSizes(style, main_scale)
	// Set initial font scale. (in docking branch: using
	// io.ConfigDpiScaleFonts=true automatically overrides this for every window
	// depending on the current monitor)
	style.FontScaleDpi = main_scale
	// [Experimental] Automatically overwrite style.FontScaleDpi in Begin() when
	// Monitor DPI changes. This will scale fonts but _NOT_ scale sizes/padding
	// for now.
	io.ConfigDpiScaleFonts = true
	// [Experimental] Scale Dear ImGui and Platform Windows when Monitor DPI changes.
	io.ConfigDpiScaleViewports = true

	// When viewports are enabled we tweak WindowRounding/WindowBg so platform
	// windows can look identical to regular ones.
	if .ViewportsEnable in io.ConfigFlags {
	    style.WindowRounding = 0.0
	    style.Colors[im.Col.WindowBg].w = 1.0
	}

	// Setup Platform/Renderer backends
	imglfw.InitForVulkan(window, install_callbacks = true)
	init_info := imvk.InitInfo {
	    ApiVersion = g_instance_api_version,
	    Instance = g_instance,
	    PhysicalDevice = g_physical_device,
	    Device = g_device,
	    QueueFamily = g_queue_family,
	    Queue = g_queue,
	    DescriptorPool = g_descriptor_pool,
	    MinImageCount = g_min_image_count,
	    ImageCount = wd.ImageCount,
	    PipelineInfoMain = {
			RenderPass = wd.RenderPass,
			Subpass = 0,
			MSAASamples = {._1},
	    },
	    CheckVkResultFn = proc "c" (err: vk.Result) {
	    	context = runtime.default_context()
	    	check_vk_result(err)
	    },
	}
	imvk.Init(&init_info)

	// Our state
    show_demo_window := true
    show_another_window := false
    clear_color := im.Vec4{0.45, 0.55, 0.60, 1.00}

	for !glfw.WindowShouldClose(window) {
        // Poll and handle events (inputs, window resize, etc.) You can read the
        // io.WantCaptureMouse, io.WantCaptureKeyboard flags to tell if dear
        // imgui wants to use your inputs.
        //
        // - When io.WantCaptureMouse is true, do not dispatch mouse input data
        //   to your main application, or clear/overwrite your copy of the mouse
        //   data.
        // - When io.WantCaptureKeyboard is true, do not dispatch keyboard input
        //   data to your main application, or clear/overwrite your copy of the
        //   keyboard data.
        //
        // Generally you may always pass all inputs to dear imgui, and hide them
        // from your application based on those two flags.
		glfw.PollEvents()

        // Resize swap chain?
		fb_width, fb_height := glfw.GetFramebufferSize(window)
		needs_rebuild :=
		    g_swap_chain_rebuild ||
		    g_main_window_data.Width  != fb_width ||
		    g_main_window_data.Height != fb_height

		if fb_width > 0 && fb_height > 0 && needs_rebuild {
		    imvk.SetMinImageCount(g_min_image_count)
		    imvk.CreateOrResizeWindow(
		        g_instance,
		        g_physical_device,
		        g_device,
		        wd,
		        g_queue_family,
		        nil,
		        fb_width,
		        fb_height,
		        g_min_image_count,
		        {},
		    )
		    g_main_window_data.FrameIndex = 0
		    g_swap_chain_rebuild = false
		}
        if glfw.GetWindowAttrib(window, glfw.ICONIFIED) != 0 {
            imglfw.Sleep(10)
            continue
        }

        // Start the Dear ImGui frame
        imvk.NewFrame()
        imglfw.NewFrame()
        im.NewFrame()

        // 1. Show the big demo window (Most of the sample code is in
        //    im.ShowDemoWindow()! You can browse its code to learn more about
        //    Dear ImGui!).
        if show_demo_window {
            im.ShowDemoWindow(&show_demo_window)
        }

        // 2. Show a simple window that we create ourselves. We use a Begin/End
        //    pair to create a named window.
        {
            @static f: f32
            @static counter: i32

            // Create a window called "Hello, world!" and append into it.
            im.Begin("Hello, world!")

            // Display some text (you can use a format strings too)
            im.Text("This is some useful text.")
            // Edit bools storing our window open/close state
            im.Checkbox("Demo Window", &show_demo_window)
            im.Checkbox("Another Window", &show_another_window)

            // Edit 1 float using a slider from 0.0f to 1.0f
            im.SliderFloat("float", &f, 0.0, 1.0)
            // Edit 3 floats representing a color
            im.ColorEdit3("clear color", cast(^[3]f32)&clear_color)

            // Buttons return true when clicked (most widgets return true when
            // edited/activated)
            if im.Button("Button") {
                counter += 1
            }
            im.SameLine()
            im.Text("counter = %d", counter)

            im.Text("Application average %.3f ms/frame (%.1f FPS)",
            	1000.0 / io.Framerate, io.Framerate)
            im.End()
        }

        // 3. Show another simple window.
        if show_another_window {
        	// Pass a pointer to our bool variable (the window will have a
        	// closing button that will clear the bool when clicked)
            im.Begin("Another Window", &show_another_window)
            im.Text("Hello from another window!")
            if im.Button("Close Me") {
                show_another_window = false
            }
            im.End()
        }

        // Rendering
        im.Render()
        main_draw_data := im.GetDrawData()
        main_is_minimized :=
        	(main_draw_data.DisplaySize.x <= 0.0 || main_draw_data.DisplaySize.y <= 0.0)
        wd.ClearValue.color.float32[0] = clear_color.x * clear_color.w
        wd.ClearValue.color.float32[1] = clear_color.y * clear_color.w
        wd.ClearValue.color.float32[2] = clear_color.z * clear_color.w
        wd.ClearValue.color.float32[3] = clear_color.w
        if !main_is_minimized {
            frame_render(wd, main_draw_data)
        }

        // Update and Render additional Platform Windows
        if .ViewportsEnable in io.ConfigFlags {
            im.UpdatePlatformWindows()
            im.RenderPlatformWindowsDefault()
        }

        // Present Main Platform Window
        if !main_is_minimized {
            frame_present(wd)
        }
	}

    // Cleanup
	check_vk_result(vk.DeviceWaitIdle(g_device))
	imvk.Shutdown()
	imglfw.Shutdown()
	im.DestroyContext()

	cleanup_vulkan_window(wd)
	cleanup_vulkan()

	glfw.DestroyWindow(window)
	glfw.Terminate()
}
