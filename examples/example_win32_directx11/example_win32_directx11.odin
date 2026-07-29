package example_win32_directx11

import "base:runtime"
import win32 "core:sys/windows"

import im "../../"
import imwin32 "../../backends/win32"
import imdx11 "../../backends/dx11"

import "vendor:directx/d3d11"
import "vendor:directx/dxgi"

// Data
g_pd3dDevice:           ^d3d11.IDevice
g_pd3dDeviceContext:    ^d3d11.IDeviceContext
g_pSwapChain:           ^dxgi.ISwapChain
g_SwapChainOccluded:    bool
g_ResizeWidth:          u32
g_ResizeHeight:         u32
g_mainRenderTargetView: ^d3d11.IRenderTargetView

main :: proc() {
	// Make process DPI aware and obtain main monitor scale
	imwin32.EnableDpiAwareness()
	main_scale := imwin32.GetDpiScaleForMonitor(
		win32.MonitorFromPoint(win32.POINT{0, 0}, .MONITOR_DEFAULTTOPRIMARY))

	// Create application window
	wc := win32.WNDCLASSEXW{
		cbSize        = size_of(win32.WNDCLASSEXW),
		style         = win32.CS_CLASSDC,
		lpfnWndProc   = wnd_proc,
		hInstance     = win32.HINSTANCE(win32.GetModuleHandleW(nil)),
		lpszClassName = win32.L("ImGui Example"),
	}
	win32.RegisterClassExW(&wc)
	defer win32.UnregisterClassW(wc.lpszClassName, wc.hInstance)

	hwnd := win32.CreateWindowW(
		wc.lpszClassName,
		win32.L("Dear ImGui DirectX11 Example"),
		win32.WS_OVERLAPPEDWINDOW,
		100, 100,
		i32(1280 * main_scale), i32(800 * main_scale),
		nil, nil, wc.hInstance, nil)
	defer win32.DestroyWindow(hwnd)

	// Initialize Direct3D
	if !create_device_d3d(hwnd) {
		cleanup_device_d3d()
		return
	}
	defer cleanup_device_d3d()

	// Show the window
	win32.ShowWindow(hwnd, win32.SW_SHOWDEFAULT)
	win32.UpdateWindow(hwnd)

	// Setup Dear ImGui context
	im.CHECKVERSION()
	im.CreateContext()
	defer im.DestroyContext()

	io := im.GetIO()
	io.ConfigFlags |= {
		.NavEnableKeyboard, // Enable Keyboard Controls
		.NavEnableGamepad,  // Enable Gamepad Controls
		.DockingEnable,     // Enable Docking
		.ViewportsEnable,   // Enable Multi-Viewport / Platform Windows
	}
	// io.ConfigViewportsNoAutoMerge = true
	// io.ConfigViewportsNoTaskBarIcon = true
	// io.ConfigDockingAlwaysTabBar = true
	// io.ConfigDockingTransparentPayload = true

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
	io.ConfigDpiScaleFonts = true     // [Experimental]
	io.ConfigDpiScaleViewports = true // [Experimental]

	// When viewports are enabled we tweak WindowRounding/WindowBg so platform
	// windows can look identical to regular ones.
	if .ViewportsEnable in io.ConfigFlags {
		style.WindowRounding = 0.0
		style.Colors[im.Col.WindowBg].w = 1.0
	}

	// Setup Platform/Renderer backends
	imwin32.Init(hwnd)
	defer imwin32.Shutdown()
	imdx11.Init(g_pd3dDevice, g_pd3dDeviceContext)
	defer imdx11.Shutdown()

	// Load Fonts
	// - If fonts are not explicitly loaded, Dear ImGui will select an embedded
	//   font: either AddFontDefaultVector() or AddFontDefaultBitmap().
	// - You can load multiple fonts and use im.PushFont()/PopFont() to select them.
	// - Read 'docs/FONTS.md' for more instructions and details.
	//style.FontSizeBase = 20.0
	//io.Fonts->AddFontDefaultVector()
	//io.Fonts->AddFontFromFileTTF("c:\\Windows\\Fonts\\segoeui.ttf")

	// Our state
	show_demo_window := true
	show_another_window := false
	clear_color := im.Vec4{0.45, 0.55, 0.60, 1.00}

	// Main loop
	done := false
	for !done {
		// Poll and handle messages (inputs, window resize, etc.)
		msg: win32.MSG
		for win32.PeekMessageW(&msg, nil, 0, 0, win32.PM_REMOVE) {
			win32.TranslateMessage(&msg)
			win32.DispatchMessageW(&msg)
			if msg.message == win32.WM_QUIT {
				done = true
			}
		}
		if done {
			break
		}

		// Handle window being minimized or screen locked
		if g_SwapChainOccluded && g_pSwapChain->Present(0, {.TEST}) == dxgi.STATUS_OCCLUDED {
			win32.Sleep(10)
			continue
		}
		g_SwapChainOccluded = false

		// Handle window resize (we don't resize directly in the WM_SIZE handler)
		if g_ResizeWidth != 0 && g_ResizeHeight != 0 {
			cleanup_render_target()
			g_pSwapChain->ResizeBuffers(0, g_ResizeWidth, g_ResizeHeight, .UNKNOWN, {})
			g_ResizeWidth, g_ResizeHeight = 0, 0
			create_render_target()
		}

		// Start the Dear ImGui frame
		imdx11.NewFrame()
		imwin32.NewFrame()
		im.NewFrame()

		// 1. Show the big demo window
		if show_demo_window {
			im.ShowDemoWindow(&show_demo_window)
		}

		// 2. Show a simple window that we create ourselves.
		{
			@static f: f32
			@static counter: i32

			im.Begin("Hello, world!")

			im.Text("This is some useful text.")
			im.Checkbox("Demo Window", &show_demo_window)
			im.Checkbox("Another Window", &show_another_window)

			im.SliderFloat("float", &f, 0.0, 1.0)
			im.ColorEdit3("clear color", cast(^[3]f32)&clear_color)

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
			im.Begin("Another Window", &show_another_window)
			im.Text("Hello from another window!")
			if im.Button("Close Me") {
				show_another_window = false
			}
			im.End()
		}

		// Rendering
		im.Render()
		clear_color_with_alpha := [4]f32{
			clear_color.x * clear_color.w,
			clear_color.y * clear_color.w,
			clear_color.z * clear_color.w,
			clear_color.w,
		}
		g_pd3dDeviceContext->OMSetRenderTargets(1, &g_mainRenderTargetView, nil)
		g_pd3dDeviceContext->ClearRenderTargetView(g_mainRenderTargetView, &clear_color_with_alpha)
		imdx11.RenderDrawData(im.GetDrawData())

		// Update and Render additional Platform Windows
		if .ViewportsEnable in io.ConfigFlags {
			im.UpdatePlatformWindows()
			im.RenderPlatformWindowsDefault()
		}

		// Present
		hr := g_pSwapChain->Present(1, {}) // Present with vsync
		//hr := g_pSwapChain->Present(g_pSwapChain, 0, {}) // Present without vsync
		g_SwapChainOccluded = (hr == dxgi.STATUS_OCCLUDED)
	}
}

// Helper functions
create_device_d3d :: proc(hwnd: win32.HWND) -> bool {
	// Setup swap chain
	// This is a basic setup. Optimally could use e.g. DXGI_SWAP_EFFECT_FLIP_DISCARD
	// and handle fullscreen mode differently. See imgui #8979 for suggestions.
	sd := dxgi.SWAP_CHAIN_DESC{
		BufferCount = 2,
		BufferDesc = {
			Width  = 0,
			Height = 0,
			Format = .R8G8B8A8_UNORM,
			RefreshRate = {Numerator = 60, Denominator = 1},
		},
		Flags       = {.ALLOW_MODE_SWITCH},
		BufferUsage = {.RENDER_TARGET_OUTPUT},
		OutputWindow = dxgi.HWND(hwnd),
		SampleDesc  = {Count = 1, Quality = 0},
		Windowed    = true,
		SwapEffect  = .DISCARD,
	}

	create_device_flags: d3d11.CREATE_DEVICE_FLAGS
	//create_device_flags += {.DEBUG}
	feature_level: d3d11.FEATURE_LEVEL
	feature_level_array := [2]d3d11.FEATURE_LEVEL{._11_0, ._10_0}

	res := d3d11.CreateDeviceAndSwapChain(
		nil, .HARDWARE, nil, create_device_flags,
		&feature_level_array[0], 2, d3d11.SDK_VERSION,
		&sd, &g_pSwapChain, &g_pd3dDevice, &feature_level, &g_pd3dDeviceContext)
	if res == dxgi.ERROR_UNSUPPORTED { // Try WARP software driver if hardware is not available.
		res = d3d11.CreateDeviceAndSwapChain(
			nil, .WARP, nil, create_device_flags,
			&feature_level_array[0], 2, d3d11.SDK_VERSION,
			&sd, &g_pSwapChain, &g_pd3dDevice, &feature_level, &g_pd3dDeviceContext)
	}
	if res != 0 {
		return false
	}

	// Disable DXGI's default Alt+Enter fullscreen behavior.
	//
	// - You are free to leave this enabled, but it will not work properly with
	//   multiple viewports.
	// - This must be done for all windows associated to the device. Our DX11
	//   backend does this automatically for secondary viewports that it
	//   creates.
	pSwapChainFactory: ^dxgi.IFactory
	if id := g_pSwapChain->GetParent(dxgi.IFactory_UUID, (^rawptr)(&pSwapChainFactory)); id >= 0 {
		pSwapChainFactory->MakeWindowAssociation(dxgi.HWND(hwnd), {.NO_ALT_ENTER})
		pSwapChainFactory->Release()
	}

	create_render_target()
	return true
}

cleanup_device_d3d :: proc() {
	cleanup_render_target()
	if g_pSwapChain != nil {
		g_pSwapChain->Release()
		g_pSwapChain = nil
	}
	if g_pd3dDeviceContext != nil {
		g_pd3dDeviceContext->Release()
		g_pd3dDeviceContext = nil
	}
	if g_pd3dDevice != nil {
		g_pd3dDevice->Release()
		g_pd3dDevice = nil
	}
}

create_render_target :: proc() {
	pBackBuffer: ^d3d11.ITexture2D
	g_pSwapChain->GetBuffer(0, d3d11.ITexture2D_UUID, (^rawptr)(&pBackBuffer))
	g_pd3dDevice->CreateRenderTargetView(
		(^d3d11.IResource)(pBackBuffer), nil, &g_mainRenderTargetView)
	pBackBuffer->Release()
}

cleanup_render_target :: proc() {
	if g_mainRenderTargetView != nil {
		g_mainRenderTargetView->Release()
		g_mainRenderTargetView = nil
	}
}

// Win32 message handler
// You can read the io.WantCaptureMouse, io.WantCaptureKeyboard flags to tell if
// dear imgui wants to use your inputs.
wnd_proc :: proc "system" (
	hwnd: win32.HWND,
	msg: win32.UINT,
	wparam: win32.WPARAM,
	lparam: win32.LPARAM,
) -> win32.LRESULT {
	context = runtime.default_context()

	if result := imwin32.WndProcHandler(hwnd, msg, wparam, lparam); result != 0 {
		return result
	}

	switch msg {
	case win32.WM_SIZE:
		if wparam == win32.SIZE_MINIMIZED {
			return 0
		}
		g_ResizeWidth = u32(win32.LOWORD(u32(lparam))) // Queue resize
		g_ResizeHeight = u32(win32.HIWORD(u32(lparam)))
		return 0
	case win32.WM_SYSCOMMAND:
		if (wparam & 0xfff0) == win32.SC_KEYMENU { // Disable ALT application menu
			return 0
		}
	case win32.WM_DESTROY:
		win32.PostQuitMessage(0)
		return 0
	}
	return win32.DefWindowProcW(hwnd, msg, wparam, lparam)
}
