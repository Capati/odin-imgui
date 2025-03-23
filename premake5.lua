-- Check Premake version for compatibility
if _PREMAKE_VERSION < "5.0" then
    error("This script requires Premake 5.0 or later.")
end

-- Define command-line options
newoption {
    trigger = "backends",
    description = "List of backends to enable (comma separated)",
    value = "string"
}
newoption {
    trigger = "internal",
    description = "Include internal ImGui headers"
}
newoption {
    trigger = "instructions",
    description = "Show help instructions"
}

-- Define default versions
local defaultVersions = {
    imgui = "v1.91.9-docking",
    dearBindings = "f6e8ea7",
    glfw = "3.4",
    vulkan = "v1.4.307",
    wgpu = "97636ad",
    sdl2 = "release-2.28.3",
    sdl3 = "release-3.2.4"
}

-- Define options for each backend
newoption {
    trigger = "imgui-version",
    value = "VERSION",
    description = "Set ImGui library version",
    default = defaultVersions.imgui
}

newoption {
    trigger = "dear-bindings-version",
    value = "VERSION",
    description = "Set Dear Bindings library version",
    default = defaultVersions.dearBindings
}

newoption {
    trigger = "glfw-version",
    value = "VERSION",
    description = "Set GLFW library version",
    default = defaultVersions.glfw
}

newoption {
    trigger = "vulkan-version",
    value = "VERSION",
    description = "Set Vulkan-headers version",
    default = defaultVersions.vulkan
}

newoption {
    trigger = "wgpu-version",
    value = "VERSION",
    description = "Set WebGPU-headers version",
    default = defaultVersions.wgpu
}

newoption {
    trigger = "sdl2-version",
    value = "VERSION",
    description = "Set SDL2 library version",
    default = defaultVersions.sdl2
}

newoption {
    trigger = "sdl3-version",
    value = "VERSION",
    description = "Set SDL3 library version",
    default = defaultVersions.sdl3
}

-- Function to get the version, using command-line option or default
local function getVersion(optionName, defaultVersion)
    local version = _OPTIONS[optionName]
    return version or defaultVersion
end

-- Display usage instructions
local function showHelpInstructions()
    print(
        [[
To use this Premake5 script:

Run 'premake5 [action]' (e.g., 'vs2022', 'gmake2', 'xcode4') to generate project files

Options:
    --backends=[list]   Comma-separated list of backends to enable
    --internal          Include internal ImGui headers

Example:
    premake5 --backends=glfw,opengl3 --internal vs2022
    ]])
    os.exit(0, true)
end

local redirectNul = os.target() == "windows" and ">nul 2>&1" or ">/dev/null 2>&1"

-- Check if a command is available
local function hasCommand(cmd)
    return os.execute(cmd .. " " .. redirectNul)
end

-- Set up directory structure
local function setupDirectories()
    BUILD_DIR = path.translate("./build")
    DEPS_DIR = path.translate(BUILD_DIR .. "/deps")
    GENERATED_DIR = path.translate(BUILD_DIR .. "/generated")

    -- Create directories only if they don’t exist
    if not os.isdir(BUILD_DIR) then
        os.mkdir(BUILD_DIR)
    end
    if not os.isdir(DEPS_DIR) then
        os.mkdir(DEPS_DIR)
    end
    -- Clean generated files
    if os.isdir(GENERATED_DIR) then
        os.rmdir(GENERATED_DIR)
    end
    os.mkdir(GENERATED_DIR)
end

-- Define backend versions and repository info
local function defineBackends()
    IMGUI_VERSION = getVersion("imgui-version", defaultVersions.imgui)
    DEAR_BINDINGS_VERSION = getVersion("dear-bindings-version", defaultVersions.dearBindings)
    GLFW_VERSION = getVersion("glfw-version", defaultVersions.glfw)
    VULKAN_VERSION = getVersion("vulkan-version", defaultVersions.vulkan)
    WGPU_VERSION = getVersion("wgpu-version", defaultVersions.wgpu)
    SDL2_VERSION = getVersion("sdl2-version", defaultVersions.sdl2)
    SDL3_VERSION = getVersion("sdl3-version", defaultVersions.sdl3)

    REPOS = {
        glfw = {
            dir = path.translate(DEPS_DIR .. "/glfw"),
            url = "https://github.com/glfw/glfw.git",
            version = GLFW_VERSION,
            name = "GLFW"
        },
        vulkan = {
            dir = path.translate(DEPS_DIR .. "/vulkan_headers"),
            url = "https://github.com/KhronosGroup/Vulkan-Headers.git",
            version = VULKAN_VERSION,
            name = "Vulkan-Headers"
        },
        sdl2 = {
            dir = path.translate(DEPS_DIR .. "/sdl2"),
            url = "https://github.com/libsdl-org/SDL.git",
            version = SDL2_VERSION,
            name = "SDL2"
        },
        sdl3 = {
            dir = path.translate(DEPS_DIR .. "/sdl3"),
            url = "https://github.com/libsdl-org/SDL.git",
            version = SDL3_VERSION,
            name = "SDL3"
        },
        wgpu = {
            dir = path.translate(DEPS_DIR .. "/webgpu"),
            url = "https://github.com/webgpu-native/webgpu-headers.git",
            version = WGPU_VERSION,
            name = "WebGPU-Headers"
        }
    }

    REPOS.sdlrenderer2 = REPOS.sdl2
    REPOS.sdlrenderer3 = REPOS.sdl3

    -- Set aliases for SDL-based backends
    SDLRENDERER2_VERSION = SDL2_VERSION
    SDLRENDERER3_VERSION = SDL3_VERSION
    SDLGPU3_VERSION = SDL3_VERSION

    BACKENDS_LIST = {
        "dx9",
        "dx10",
        "dx11",
        "dx12",
        "glfw",
        "metal",
        "opengl3",
        "osx",
        "sdl2",
        "sdl3",
        "sdlgpu3",
        "sdlrenderer2",
        "sdlrenderer3",
        "vulkan",
        "wgpu",
        "win32"
    }
    ENABLED_BACKENDS = {}

    -- Parse backends from options
    if _OPTIONS["backends"] then
        for backend in string.gmatch(_OPTIONS["backends"], "([^,]+)") do
            backend = string.lower(backend)
            if table.contains(BACKENDS_LIST, backend) then
                table.insert(ENABLED_BACKENDS, backend)
            else
                print("Warning: Invalid backend '" .. backend .. "' specified. Skipping.")
            end
        end
    end
end

-- Clone or update repositories
local function downloadDependencies()
    -- Check for Git availability silently
    if not hasCommand("git --version ") then
        error("Git is not installed. Please install it and try again.")
    end

    -- Clone ImGui and Dear_Bindings
    IMGUI_DIR = path.translate(DEPS_DIR .. "/imgui")
    DEAR_BINDINGS_DIR = path.translate(DEPS_DIR .. "/dear_bindings")

    -- Helper function to clone a repository
    local function cloneRepo(repoName, repoDir, repoUrl, repoVersion)
        -- Ignore already cloned
        if not os.isdir(repoDir) then
            print("Cloning " .. repoName .. " " .. repoVersion .. "...")
            if not os.execute("git clone " .. repoUrl .. " " .. repoDir) then
                error("Failed to clone " .. repoName .. " repository.")
            end
            if not os.execute("cd " .. repoDir .. " && git checkout " .. repoVersion .. redirectNul) then
                error("Failed to checkout " .. repoVersion .. " for " .. repoName .. ".")
            end
        end
    end

    cloneRepo("ImGui", IMGUI_DIR, "https://github.com/ocornut/imgui.git", IMGUI_VERSION)
    cloneRepo(
        "Dear Bindings", DEAR_BINDINGS_DIR, "https://github.com/dearimgui/dear_bindings.git",
        DEAR_BINDINGS_VERSION)

    for _, backend in ipairs(ENABLED_BACKENDS) do
        local repo = REPOS[backend]
        if repo then
            cloneRepo(repo.name, repo.dir, repo.url, repo.version)
        end
    end
end

-- Set up Python virtual environment
local function setupPythonEnvironment()
    -- Check for Python 3 availability silently
    if not hasCommand("python3 --version") then
        error("Python 3 is not installed. Please install it and try again.")
    end

    VENV_DIR = path.translate(BUILD_DIR .. "/venv")

    -- Create virtual environment if it doesn’t exist
    if not os.isdir(VENV_DIR) then
        print("Creating Python virtual environment...")
        if not os.execute("python3 -m venv " .. VENV_DIR) then
            error("Failed to create virtual environment.")
        end
    end

    -- Define paths to Python and pip executables in the venv
    local isWindows = os.target() == "windows"
    local python = path.translate(
                       isWindows and VENV_DIR .. "/Scripts/python.exe" or VENV_DIR .. "/bin/python")
    local pip = path.translate(
                    isWindows and VENV_DIR .. "/Scripts/pip.exe" or VENV_DIR .. "/bin/pip")

    -- Install dependencies using the venv's pip
    print("Installing Python dependencies...")
    local pipCmd = pip .. " install -r " .. DEAR_BINDINGS_DIR .. "/requirements.txt"
    if not os.execute(pipCmd) then
        error("Failed to install Python dependencies.")
    end
end

-- Process ImGui headers to generate bindings
local function processImGuiHeaders()
    local isWindows = os.target() == "windows"
    local python = path.translate(
                       isWindows and VENV_DIR .. "/Scripts/python.exe" or VENV_DIR .. "/bin/python")
    local cmd = string.format(
                    '"%s" "%s" --nogeneratedefaultargfunctions -o "%s" "%s"', python,
                    path.translate(DEAR_BINDINGS_DIR .. "/dear_bindings.py"),
                    path.translate(GENERATED_DIR .. "/dcimgui"),
                    path.translate(IMGUI_DIR .. "/imgui.h"))
    if isWindows then
        cmd = 'cmd /c "' .. cmd .. '"'
    end
    print("Generating bindings for imgui.h...")
    if not os.execute(cmd) then
        error("Failed to generate ImGui bindings.")
    end
    print("Bindings generated successfully.")
end

-- Generate impl_enabled.odin after build
local function generateImplEnabledOdin()
    -- Open the file for writing
    local file = io.open("impl_enabled.odin", "w")
    if not file then
        error("Failed to open impl_enabled.odin for writing.")
    end

    -- Write the header
    file:write("package imgui\n\n")
    file:write("// This is a generated helper file that indicates which implementations\n")
    file:write("// have been compiled into the bindings.\n\n")

    -- Define all possible backends with their Odin constant names
    local backendFlags = {
        glfw         = "BACKEND_GLFW_ENABLED",
        opengl3      = "BACKEND_OPENGL3_ENABLED",
        sdl2         = "BACKEND_SDL2_ENABLED",
        sdl3         = "BACKEND_SDL3_ENABLED",
        sdlgpu3      = "BACKEND_SDLGPU3_ENABLED",
        sdlrenderer2 = "BACKEND_SDLRENDERER2_ENABLED",
        sdlrenderer3 = "BACKEND_SDLRENDERER3_ENABLED",
        vulkan       = "BACKEND_VULKAN_ENABLED",
        wgpu         = "BACKEND_WGPU_ENABLED",
        osx          = "BACKEND_OSX_ENABLED",
        metal        = "BACKEND_METAL_ENABLED",
        dx11         = "BACKEND_DX11_ENABLED",
        dx12         = "BACKEND_DX12_ENABLED",
        win32        = "BACKEND_WIN32_ENABLED",
        allegro5     = "BACKEND_ALLEGRO5_ENABLED",
        android      = "BACKEND_ANDROID_ENABLED",
        dx9          = "BACKEND_DX9_ENABLED",
        dx10         = "BACKEND_DX10_ENABLED",
        glut         = "BACKEND_GLUT_ENABLED",
        opengl2      = "BACKEND_OPENGL2_ENABLED"
    }

    -- Write each backend flag, set to true if in ENABLED_BACKENDS
    for backend, flag in pairs(backendFlags) do
        local enabled = table.contains(ENABLED_BACKENDS, backend) and "true" or "false"
        file:write(string.format("%s :: %s\n", flag, enabled))
    end

    file:close()
    print("Generated impl_enabled.odin successfully.")
end

local function generateBuildFile()
    local file = io.open(path.join(BUILD_DIR, "build.bat"), "w")
    if not file then
        error("Failed to create build.bat file.")
    end

    file:write("@echo off\n")
    file:write("setlocal enabledelayedexpansion\n\n")

    file:write(":: Setup tooling\n")
    file:write("call vcvars64.bat || exit /b 1\n\n")

    -- Configuration
    file:write(":: Configuration\n")
    file:write("set BUILD_DIR=.\\\n")
    file:write("set DEPS_DIR=", ".\\deps", "\n")
    file:write("set GENERATED_DIR=", ".\\generated", "\n")
    file:write("set IMGUI_DIR=", ".\\deps\\imgui", "\n\n")

    -- Define compilation variables based on backends
    file:write(":: Configure include paths based on enabled backends\n")
    file:write(
        "set INCLUDE_DIRS=/I\"!IMGUI_DIR!\" /I\"!GENERATED_DIR!\" /I\"!IMGUI_DIR!\\backends\"\n")

    -- Add backend-specific include directories
    if isBackendEnabled("glfw") then
        local glfw_dir = string.match(REPOS.glfw.dir, "[^/\\]+$")
        file:write("set INCLUDE_DIRS=!INCLUDE_DIRS! /I\"!DEPS_DIR!\\", glfw_dir, "\\include\"\n")
    end
    if isBackendEnabled("sdl2") or isBackendEnabled("sdlrenderer2") then
        local sdl2_dir = string.match(REPOS.sdl2.dir, "[^/\\]+$")
        file:write("set INCLUDE_DIRS=!INCLUDE_DIRS! /I\"!DEPS_DIR!\\", sdl2_dir, "\\include\"\n")
    end
    if isBackendEnabled("sdl3") or isBackendEnabled("sdlgpu3") or isBackendEnabled("sdlrenderer3") then
        local sdl3_dir = string.match(REPOS.sdl3.dir, "[^/\\]+$")
        file:write("set INCLUDE_DIRS=!INCLUDE_DIRS! /I\"!DEPS_DIR!\\", sdl3_dir, "\\include\"\n")
    end
    if isBackendEnabled("vulkan") then
        local vulkan_dir = string.match(REPOS.vulkan.dir, "[^/\\]+$")
        file:write("set INCLUDE_DIRS=!INCLUDE_DIRS! /I\"!DEPS_DIR!\\", vulkan_dir, "\\include\"\n")
    end
    if isBackendEnabled("wgpu") then
        local wgpu_dir = string.match(REPOS.wgpu.dir, "[^/\\]+$")
        file:write("set INCLUDE_DIRS=!INCLUDE_DIRS! /I\"!DEPS_DIR!", "\"\n")
    end

    -- Define source files
    file:write("\n:: Source files\n")
    file:write("set SOURCES=!IMGUI_DIR!\\*.cpp\n")
    file:write("set SOURCES=!SOURCES! \"!GENERATED_DIR!\\*.cpp\"\n")

    -- Add backend-specific source files
    local backendSources = {
        glfw = "imgui_impl_glfw.cpp",
        sdl2 = "imgui_impl_sdl2.cpp",
        sdlrenderer2 = "imgui_impl_sdlrenderer2.cpp",
        sdl3 = "imgui_impl_sdl3.cpp",
        sdlgpu3 = "imgui_impl_sdlgpu3.cpp",
        sdlrenderer3 = "imgui_impl_sdlrenderer3.cpp",
        vulkan = "imgui_impl_vulkan.cpp",
        wgpu = "imgui_impl_wgpu.cpp",
        dx9 = "imgui_impl_dx9.cpp",
        dx10 = "imgui_impl_dx10.cpp",
        dx11 = "imgui_impl_dx11.cpp",
        dx12 = "imgui_impl_dx12.cpp",
        opengl3 = "imgui_impl_opengl3.cpp",
        win32 = "imgui_impl_win32.cpp",
        osx = "imgui_impl_osx.cpp",
        metal = "imgui_impl_metal.cpp"
    }

    for backend, sourceFile in pairs(backendSources) do
        if isBackendEnabled(backend) then
            file:write("set SOURCES=!SOURCES! \"!IMGUI_DIR!\\backends\\", sourceFile, "\"\n")
        end
    end

    -- Configuration selection
    file:write("\n:: Set configuration (Debug/Release)\n")
    file:write("set CONFIG=Release\n")
    file:write("if /i \"%1\"==\"debug\" set CONFIG=Debug\n\n")

    -- Compiler flags based on configuration
    file:write(":: Compiler flags based on configuration\n")
    file:write("set CFLAGS=/MT /EHsc ")
    file:write("/D \"IMGUI_DISABLE_OBSOLETE_FUNCTIONS\" ")
    file:write("/D \"IMGUI_DISABLE_OBSOLETE_KEYIO\" ")
    file:write("/D \"IMGUI_IMPL_API=extern \\\"C\\\"\"")
    if isBackendEnabled("vulkan") then
        file:write(" /D \"VK_NO_PROTOTYPES\"")
    end
    if isBackendEnabled("wgpu") then
        file:write(" /D \"IMGUI_IMPL_WEBGPU_BACKEND_WGPU\"")
    end
    file:write("\n")
    file:write("if /i \"!CONFIG!\"==\"Debug\" (\n")
    file:write("    set CFLAGS=!CFLAGS! /Zi /D \"DEBUG\"\n")
    file:write(") else (\n")
    file:write("    set CFLAGS=!CFLAGS! /O2 /D \"NDEBUG\"\n")
    file:write(")\n")

    -- Output configurations
    file:write("\n:: Output configurations\n")
    file:write("set OUTPUT_DIR=.\\..\n")
    file:write("set TARGET=imgui_", target_os, "_", target_arch, ".lib\n")

    -- Compilation step
    file:write("\n:: Compile ImGui\n")
    file:write("echo Compiling ImGui...\n")
    file:write("cl /c !CFLAGS! !INCLUDE_DIRS! !SOURCES! /Fo!OUTPUT_DIR!\\\n")
    file:write("if %ERRORLEVEL% neq 0 (\n")
    file:write("    echo Compilation failed!\n")
    file:write("    exit /b 1\n")
    file:write(")\n")

    -- Link step (create static library)
    file:write("\n:: Create static library\n")
    file:write("echo Creating static library...\n")
    file:write("lib /OUT:!OUTPUT_DIR!\\!TARGET! !OUTPUT_DIR!\\*.obj\n")
    file:write("if %ERRORLEVEL% neq 0 (\n")
    file:write("    echo Library creation failed!\n")
    file:write("    exit /b 1\n")
    file:write(")\n")

    -- Cleanup
    file:write("\n:: Cleanup\n")
    file:write("del !OUTPUT_DIR!\\*.obj\n")
    file:write("echo Done.\n")

    file:close()
    print("Generated build.bat successfully.")
end

workspace "ImGui"
	if _OPTIONS["instructions"] then
		showHelpInstructions()
	end

	configurations { "Debug", "Release" }
	location("./build/make/" .. os.target() .. "/")
	targetdir("./")
	platforms { "x86_64", "x86", "arm64" }

	-- Detect architecture
	local arch_names = {
        x86 = "x86",
        x86_64 = "x64",
        arm = "arm",
        arm64 = "arm64"
    }

	if not os.architecture then
		function os.architecture()
			-- Check for ARM64 first
			local arch = os.getenv("PROCESSOR_ARCHITECTURE") or ""
			local archw6432 = os.getenv("PROCESSOR_ARCHITEW6432") or ""
			if arch:lower():find("arm64") or archw6432:lower():find("arm64") then
				return "arm64"
			end

			-- x64 or x86 detection
			if os.is64bit() then
				return "x64"
			else
				return "x86"
			end
		end
	end

	target_os = os.target()
    target_arch = os.architecture()

	-- When checking if a backend is enabled:
	function isBackendEnabled(backendName)
		for _, value in ipairs(ENABLED_BACKENDS) do
			if value == backendName then
				return true
			end
		end
		return false
	end

	setupDirectories()
	defineBackends()
	downloadDependencies()
	setupPythonEnvironment()
	processImGuiHeaders()
	generateImplEnabledOdin()
	generateBuildFile()

project "ImGui"
	kind "StaticLib"
	language "C++"
	targetdir "./"
	targetname ("imgui_" .. target_os .. "_" .. target_arch)
	cppdialect "C++11"

	includedirs {
		IMGUI_DIR,
		GENERATED_DIR,
		IMGUI_DIR .. "/backends"
	}

	defines {
		"IMGUI_DISABLE_OBSOLETE_FUNCTIONS",
		"IMGUI_DISABLE_OBSOLETE_KEYIO",
		"IMGUI_IMPL_API=extern \"C\""
	}

	files {
		IMGUI_DIR .. "/*.cpp",
		GENERATED_DIR .. "/*.cpp"
	}

	-- Use it in your conditional
	if isBackendEnabled("glfw") then
		includedirs {
			path.translate(REPOS.glfw.dir .. "/include")
		}
		files {
			path.translate(IMGUI_DIR .. "/backends/imgui_impl_glfw.cpp")
		}
	end

	if isBackendEnabled("sdl2") or isBackendEnabled("sdlrenderer2") then
		includedirs {
			path.translate(REPOS.sdlrenderer2.dir .. "/include")
		}
		files {
			path.translate(IMGUI_DIR .. "/backends/imgui_impl_sdl2.cpp"),
			path.translate(IMGUI_DIR .. "/backends/imgui_impl_sdlrenderer2.cpp")
		}
	end

	if isBackendEnabled("sdl3") or isBackendEnabled("sdlgpu3") or isBackendEnabled("sdlrenderer3") then
		includedirs {
			path.translate(REPOS.sdlrenderer3.dir .. "/include")
		}
		files {
			path.translate(IMGUI_DIR .. "/backends/imgui_impl_sdl3.cpp"),
			path.translate(IMGUI_DIR .. "/backends/imgui_impl_sdlgpu3.cpp"),
			path.translate(IMGUI_DIR .. "/backends/imgui_impl_sdlrenderer3.cpp")
		}
	end

	if isBackendEnabled("vulkan") then
		includedirs {
			path.translate(REPOS.vulkan.dir .. "/include")
		}
		files {
			path.translate(IMGUI_DIR .. "/backends/imgui_impl_vulkan.cpp")
		}
		defines {
			"VK_NO_PROTOTYPES"
		}
	end

	if isBackendEnabled("wgpu") then
		includedirs {
			DEPS_DIR
		}
		files {
			path.translate(IMGUI_DIR .. "/backends/imgui_impl_wgpu.cpp")
		}
		defines {
			"IMGUI_IMPL_WEBGPU_BACKEND_WGPU"
		}
	end

	-- Modify win32 impl to avoid error C2159
    if isBackendEnabled("win32") then
        local original_file = string.format("%s\\backends\\imgui_impl_win32.cpp", IMGUI_DIR)
        local backup_file = string.format("%s\\backends\\imgui_impl_win32.cpp.bak", IMGUI_DIR)

        -- Read the original file
        local file = io.open(original_file, "r")
        if not file then
            print("Error: Could not open " .. original_file)
            return
        end
        local lines = {}
        for line in file:lines() do
            table.insert(lines, line)
        end
        file:close()

        -- Ensure we have enough lines
        if #lines < 706 then
            print("Warning: " .. original_file .. " has fewer than 706 lines")
            return
        end

        -- Modify lines 706 and 707 (Lua 1-based: 705 and 706)
        lines[705] = lines[705]:gsub("^extern%s+IMGUI_IMPL_API", "IMGUI_IMPL_API")
        lines[706] = lines[706]:gsub("^extern%s+IMGUI_IMPL_API", "IMGUI_IMPL_API")

        -- Check if backup exists; create it only if it doesn't
        local backup_exists = io.open(backup_file, "r") ~= nil
        if not backup_exists then
            if not os.copyfile(original_file, backup_file) then
                print("Error: Could not create backup at " .. backup_file)
                return
            end
            print("Created backup at " .. backup_file)
        else
            print("Backup already exists at " .. backup_file .. "; skipping backup")
        end

        -- Write the modified content back to the original file
        local out_file = io.open(original_file, "w")
        if not out_file then
            print("Error: Could not write to " .. original_file)
            return
        end
        for _, line in ipairs(lines) do
            out_file:write(line .. "\n")
        end
        out_file:close()

        print("Modified " .. original_file .. " in place")
    end

	-- List of backends that only need source files
	local backends_with_sources = {
		"dx9",
		"dx10",
		"dx11",
		"dx12",
		"opengl3",
		"win32",
		"osx",
		"metal"
	}
	for _, backend in ipairs(backends_with_sources) do
		if isBackendEnabled(backend) then
			files {
				path.translate(IMGUI_DIR .. "/backends/imgui_impl_" .. backend .. ".cpp")
			}
		end
	end

	filter { "system:windows", "configurations:Debug or Release" }
    	buildoptions { "/MT" }

	filter "configurations:Debug"
		defines { "DEBUG" }
		symbols "On"

	filter "configurations:Release"
		defines { "NDEBUG" }
		optimize "On"
		symbols "Off"

	filter "system:windows"
		systemversion "latest"

	filter { "system:linux or system:macosx" }
        buildoptions {
			"-fPIC",
			"-fno-exceptions",
			"-fno-rtti",
			"-fno-threadsafe-statics",
		}
