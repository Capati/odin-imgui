@echo off
setLocal EnableDelayedExpansion

rem Check environment prerequisites
call :check_prerequisites || goto fail
rem Create build and dependencies directories
call :setup_directories || goto fail
rem Define all backend configurations
call :define_backends || goto fail
rem Parse command line arguments
call :parse_arguments %* || goto fail
rem Fetch core dependencies (ImGui and Dear_Bindings)
call :clone_core_repositories || goto fail
rem Setup Python virtual environment used by Dear_Bindings requirements
call :setup_python_environment || goto fail
rem Generate ImGui bindings
call :process_imgui_headers || goto fail
rem Build ImGui library
call :build_imgui || goto fail

echo All operations completed successfully.
goto end

:check_prerequisites
rem Check if git is available
where git >nul 2>&1 || (
    echo Error: git is not installed or not in PATH. Please install git and try again.
    exit /b 1
)

rem Check for MSVC compiler
where /Q cl.exe || (
    set __VSCMD_ARG_NO_LOGO=1
    for /f "tokens=*" %%i in ('"C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe" -latest -requires Microsoft.VisualStudio.Workload.NativeDesktop -property installationPath') do set VS=%%i
    if "!VS!" equ "" (
        echo ERROR: Visual Studio installation not found
        exit /b 1
    )
    call "!VS!\VC\Auxiliary\Build\vcvarsall.bat" amd64 || exit /b 1
)

if "%VSCMD_ARG_TGT_ARCH%" neq "x64" (
    if "%ODIN_IGNORE_MSVC_CHECK%" == "" (
        echo ERROR: please run this from MSVC x64 native tools command prompt, ^
			32-bit target is not supported!
        exit /b 1
    )
)
exit /b 0

:setup_directories
set "BUILD_DIR=.\build"
set "DEPS_DIR=%BUILD_DIR%\deps"
set "GENERATED_DIR=%BUILD_DIR%\generated"

if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%"
if not exist "%DEPS_DIR%" mkdir "%DEPS_DIR%"
if exist "%GENERATED_DIR%" rmdir /s /q "%GENERATED_DIR%"
mkdir "%GENERATED_DIR%"
exit /b 0

:define_backends
rem Backend definitions with their configurations
set "BACKENDS_LIST=dx11 dx12 glfw opengl3 sdl2 sdl3 sdlgpu3 sdlrenderer2 sdlrenderer3 vulkan wgpu win32"

rem Initialize versions
set "imgui_VERSION=v1.91.8-docking"
set "dear_bindings_VERSION=f6e8ea7"
set "glfw_VERSION=3.4"
set "vulkan_VERSION=v1.4.307"
set "wgpu_VERSION=aef5e42"
set "sdl2_VERSION=release-2.28.3"
set "sdl3_VERSION=release-3.2.4"

rem Initialize all backend flags to empty
for %%b in (%BACKENDS_LIST%) do set "BACKEND_%%b="

rem Define repository information
call :set_repo_info "GLFW" "glfw" "https://github.com/glfw/glfw.git" "%glfw_VERSION%"
call :set_repo_info "VULKAN" "vulkan_headers" ^
	"https://github.com/KhronosGroup/Vulkan-Headers.git" "%vulkan_VERSION%"
call :set_repo_info "SDL2" "sdl2" "https://github.com/libsdl-org/SDL.git" "%sdl2_VERSION%"
call :set_repo_info "SDL3" "sdl3" "https://github.com/libsdl-org/SDL.git" "%sdl3_VERSION%"
call :set_repo_info "WGPU" "webgpu" ^
	"https://github.com/webgpu-native/webgpu-headers.git" "%wgpu_VERSION%"

rem Set aliases for SDL-based backends
set "sdlrenderer2_VERSION=%sdl2_VERSION%"
set "sdlrenderer3_VERSION=%sdl3_VERSION%"
set "sdlgpu3_VERSION=%sdl3_VERSION%"
exit /b 0

:set_repo_info
set "%~1_DIR=%DEPS_DIR%\%~2"
set "%~1_URL=%~3"
set "%~1_VERSION=%~4"
set "%~1_NAME=%~1"
exit /b 0

:parse_arguments
set "DEBUG_BUILD="
set "INTERNAL="
:parse_args_loop
if "%~1"=="" exit /b 0
set "arg=%~1"

if /i "%arg%"=="debug" (
    set "DEBUG_BUILD=1"
) else if /i "%arg%"=="internal" (
    set "INTERNAL=1"
) else (
    rem Handle backend enabling
    for %%b in (%BACKENDS_LIST%) do (
        if /i "!arg!"=="%%b" set "BACKEND_%%b=1"
    )
)

shift
goto parse_args_loop

:clone_core_repositories
rem Clone ImGui and Dear_Bindings
set "imgui_DIR=%DEPS_DIR%\imgui"
set "DEAR_BINDINGS_DIR=%DEPS_DIR%\dear_bindings"

call :clone_repo "ImGui" "%imgui_DIR%" ^
	"https://github.com/ocornut/imgui.git" "%imgui_VERSION%" || exit /b 1
call :clone_repo "Dear_Bindings" "%DEAR_BINDINGS_DIR%" ^
	"https://github.com/dearimgui/dear_bindings.git" "%dear_bindings_VERSION%" || exit /b 1

rem Clone enabled backend repositories
for %%b in (%BACKENDS_LIST%) do (
    if defined BACKEND_%%b (
		rem Check url to ignore backends not enabled
		if defined %%b_URL (
			echo %%b backend enabled
			call :clone_repo !%%b_NAME! "!%%b_DIR!" "!%%b_URL!" "!%%b_VERSION!" || exit /b 1
        )
    )
)
exit /b 0

:clone_repo
setLocal
set "REPO_NAME=%~1"
set "REPO_DIR=%~2"
set "REPO_URL=%~3"
set "REPO_VERSION=%~4"

if not exist "%REPO_DIR%" (
    echo Cloning repository %REPO_NAME% %REPO_VERSION%...
    git clone "%REPO_URL%" "%REPO_DIR%" && (
        pushd "%REPO_DIR%" && (
            git checkout "%REPO_VERSION%" >nul 2>&1 && (
                popd
                endLocal
                exit /b 0
            )
            echo Failed to checkout version %REPO_VERSION%.
            popd
        )
    )
    echo Failed to clone repository.
    endLocal
    exit /b 1
)
endLocal
exit /b 0

:setup_python_environment
set "VENV_DIR=%BUILD_DIR%\venv"
set "PYTHON=%VENV_DIR%\Scripts\python.exe"
set "PIP=%VENV_DIR%\Scripts\pip.exe"
if not exist "%VENV_DIR%\Scripts\activate.bat" (
    echo Setting up Python virtual environment...
    python -m venv "%VENV_DIR%" && (
        call "%VENV_DIR%\Scripts\activate.bat" && (
            call %PIP% install -r "%DEAR_BINDINGS_DIR%\requirements.txt" || (
                echo Failed to install Python dependencies.
                exit /b 1
            )
        ) || (
            echo Failed to activate virtual environment.
            exit /b 1
        )
    ) || (
        echo Failed to create virtual environment.
        exit /b 1
    )
) else (
    call "%VENV_DIR%\Scripts\activate.bat" || (
        echo Failed to activate virtual environment.
        exit /b 1
    )
)
exit /b 0

:process_imgui_headers
set "DEAR_BINDINGS_CMD=%DEAR_BINDINGS_DIR%\dear_bindings.py"
set "DEAR_BINDINGS_COMMON_OPTIONS=--nogeneratedefaultargfunctions"

echo Processing imgui.h
call %PYTHON% %DEAR_BINDINGS_CMD% ^
    %DEAR_BINDINGS_COMMON_OPTIONS% ^
    -o %GENERATED_DIR%\dcimgui %imgui_DIR%\imgui.h || exit /b 1

if defined INTERNAL (
	echo Processing imgui_internal.h
	call %PYTHON% %DEAR_BINDINGS_CMD% ^
		%DEAR_BINDINGS_COMMON_OPTIONS% ^
		-o %GENERATED_DIR%\dcimgui_internal ^
		--include %imgui_DIR%\imgui.h %imgui_DIR%\imgui_internal.h || exit /b 1
)
exit /b 0

:build_imgui
echo Building ImGui...

set "OS_NAME=windows"
set "ARCH_NAME=x64"
if "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "ARCH_NAME=arm64"
set "LIB_EXTENSION=lib"

set "IMGUI_BACKENDS_DIR=%imgui_DIR%\backends"

rem Setup include directories
set "INCLUDE_DIRS=/I%imgui_DIR%"
set "INCLUDE_DIRS=%INCLUDE_DIRS% /I%GENERATED_DIR%"
set "INCLUDE_DIRS=%INCLUDE_DIRS% /I%IMGUI_BACKENDS_DIR%"

rem Setup defines
set "DEFINES=/D"IMGUI_DISABLE_OBSOLETE_FUNCTIONS""
set "DEFINES=%DEFINES% /D"IMGUI_DISABLE_OBSOLETE_KEYIO""
set "DEFINES=%DEFINES% /D"IMGUI_IMPL_API=extern\"C\"""

rem Add main source files
set "SOURCES="
for %%F in ("%imgui_DIR%\*.cpp" "%GENERATED_DIR%\*.cpp") do (
    set "SOURCES=!SOURCES! "%%F""
)

rem Add backend-specific configurations
call :add_backend_configs
if errorlevel 1 exit /b 1

rem Clean existing artifacts
del /Q *.obj > nul 2> nul

set "FILE_NAME=imgui_%OS_NAME%_%ARCH_NAME%.%LIB_EXTENSION%"

if defined DEBUG_BUILD (
    echo Building in debug mode...
    set "CL_OPTIONS=/c /MTd /Od /Zi /RTC1 /DEBUG /Fd"%FILE_NAME%.pdb""
) else (
    echo Building in release mode...
    set "CL_OPTIONS=/c /MT /O2"
)

rem Compile
cl %CL_OPTIONS% %INCLUDE_DIRS% %DEFINES% %SOURCES% || exit /b 1

rem Create library
lib /OUT:"%FILE_NAME%" *.obj || exit /b 1

rem Clean up
del /Q *.obj > nul 2> nul
exit /b 0

rem Add backend-specific include directories and source files
:add_backend_configs
for %%b in (sdl2 sdlrenderer2) do (
    if defined BACKEND_%%b (
        set "INCLUDE_DIRS=%INCLUDE_DIRS% /I"%sdl2_DIR%\include""
        set "SOURCES=%SOURCES% %IMGUI_BACKENDS_DIR%\imgui_impl_%%b.cpp"
    )
)

for %%b in (sdl3 sdlgpu3 sdlrenderer3) do (
    if defined BACKEND_%%b (
        set "INCLUDE_DIRS=%INCLUDE_DIRS% /I"%sdl3_DIR%\include""
        set "SOURCES=%SOURCES% %IMGUI_BACKENDS_DIR%\imgui_impl_%%b.cpp"
    )
)

rem Backends that only need source files
for %%b in (dx11 dx12 opengl3 win32) do (
    if defined BACKEND_%%b (
        set "SOURCES=%SOURCES% %IMGUI_BACKENDS_DIR%\imgui_impl_%%b.cpp"
    )
)

rem Special backends with unique configurations
if defined BACKEND_glfw (
    set "INCLUDE_DIRS=%INCLUDE_DIRS% /I"%glfw_DIR%\include""
    set "SOURCES=%SOURCES% %IMGUI_BACKENDS_DIR%\imgui_impl_glfw.cpp"
)

if defined BACKEND_vulkan (
    set "INCLUDE_DIRS=%INCLUDE_DIRS% /I"%vulkan_DIR%\include""
    set "SOURCES=%SOURCES% %IMGUI_BACKENDS_DIR%\imgui_impl_vulkan.cpp"
    set "DEFINES=%DEFINES% /D"VK_NO_PROTOTYPES""
)

if defined BACKEND_wgpu (
    set "INCLUDE_DIRS=%INCLUDE_DIRS% /I"%DEPS_DIR%""
    set "SOURCES=%SOURCES% %IMGUI_BACKENDS_DIR%\imgui_impl_wgpu.cpp"
    set "DEFINES=%DEFINES% /D"IMGUI_IMPL_WEBGPU_BACKEND_WGPU""
)

exit /b 0

:fail
echo Build failed.
exit /b 1

:end
endLocal
