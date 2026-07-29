package example_glfw_opengl3

import "base:runtime"
import "core:fmt"

import "vendor:glfw"
import gl "vendor:OpenGL"

import im "../../"
import imglfw "../../backends/glfw"
import imgl "../../backends/opengl3"

GLSL_VERSION :: "#version 150"

glfw_error_callback :: proc "c" (error: i32, description: cstring) {
	context = runtime.default_context()
	fmt.eprintfln("GLFW Error %d: %s", error, description)
}

main :: proc() {
	glfw.SetErrorCallback(glfw_error_callback)
	ensure(bool(glfw.Init()))

    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

    // Create window with graphics context
	main_scale := imglfw.GetContentScaleForMonitor(glfw.GetPrimaryMonitor())
	window := glfw.CreateWindow(
		i32(1280 * main_scale),
		i32(800 * main_scale),
		"Dear ImGui GLFW+OpenGL3 example",
		nil, nil)
	assert(window != nil)
    glfw.MakeContextCurrent(window)
    glfw.SwapInterval(1) // Enable vsync

    gl.load_up_to(3, 3, glfw.gl_set_proc_address)

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
    imglfw.InitForOpenGL(window, true)
    imgl.Init(GLSL_VERSION)

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

        if glfw.GetWindowAttrib(window, glfw.ICONIFIED) != 0 {
            imglfw.Sleep(10)
            continue
        }

        // Start the Dear ImGui frame
        imgl.NewFrame()
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
        display_w, display_h := glfw.GetFramebufferSize(window)
        gl.Viewport(0, 0, display_w, display_h)
        gl.ClearColor(
        	clear_color.x * clear_color.w,
        	clear_color.y * clear_color.w,
        	clear_color.z * clear_color.w,
        	clear_color.w)
        gl.Clear(gl.COLOR_BUFFER_BIT)
        imgl.RenderDrawData(im.GetDrawData())

        // Update and Render additional Platform Windows
        //
        // (Platform functions may change the current OpenGL context, so we
        // save/restore it to make it easier to paste this code elsewhere. For
        // this specific demo app we could also call
        // glfwMakeContextCurrent(window) directly)
        if .ViewportsEnable in io.ConfigFlags {
            backup_current_context := glfw.GetCurrentContext()
            im.UpdatePlatformWindows()
            im.RenderPlatformWindowsDefault()
            glfw.MakeContextCurrent(backup_current_context)
        }

        glfw.SwapBuffers(window)
	}

	// Cleanup
    imgl.Shutdown()
    imglfw.Shutdown()
    im.DestroyContext()

    glfw.DestroyWindow(window)
    glfw.Terminate()
}
