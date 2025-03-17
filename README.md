# Odin ImGui

[Odin Language][] bindings for **Dear ImGui v1.91.8-docking**.

## Table of Contents

- [Features](#features)
- [Building](#building)
  - [Prerequisites](#prerequisites)
  - [Windows](#windows)
  - [Unix (macOS/Linux)](#unix-macoslinux)
- [TODO](#todo)
- [Acknowledgements](#acknowledgements)
- [License](#license)

## Features

- Uses [dear_bindings][] to generate the C API.
- Generates bindings for the `docking` ImGui branch
- Generator is written in Odin
- Names are in Odin naming convention
- Contains bindings for most of the backends
  - All backends which exist in vendor have bindings
  - These include: `dx11`, `dx12`, `glfw`, `metal`, `opengl3`, `osx`, `sdl2`, `sdl3`,
    `sdlgpu3`, `sdlrenderer2`, `sdlrenderer3`, `vulkan`, `wgpu`, `win32`

## Building

Building ImGui requires utilizing a tool called **premake** found at
<https://premake.github.io>. Although the process involves several steps, they are relatively
straightforward.

### Prerequisites

- [Premake5](https://premake.github.io) - the build configuration
  - You can download the [Pre-Built Binaries](https://premake.github.io/download), simply need
    to be unpacked and placed somewhere on the system search path or any other convenient
    location.
  - For Unix, also requires **GNU libc 2.38**.
- [Git](http://git-scm.com/downloads) - required for clone backend dependencies
- [Python](https://www.python.org/downloads/) - version 3.3.x is required by [dear_bindings][]
  and `venv` (Python Virtual Environment)
- C++ compiler - `vs2022` on Windows or `g++/clang` on Unix

### Windows

1. Clone or [download](https://github.com/Capati/odin-imgui/archive/refs/heads/main.zip) this
   repository

2. Download and install **premake5.exe**.

    Either add to PATH or copy to project directory.

3. Open a command window, navigate to the project directory and generate Visual Studio 2022
   project files with desired backends:

    ```shell
    premake5 --backends=glfw,opengl3 vs2022
    ```

4. From the project folder, open the directory `build\make\windows`, them open the generated
   solution **ImGui.sln**.

5. In Visual Studio, confirm that the dropdown box at the top says “x64” (not “x86”); and then
   use **Build** > **Build Solution**.

    The generated library file `imgui_windows_x64.lib` will be located in the root of the
    project directory.

#### Compiling Without Visual Studio

If you do not have Visual Studio installed, you can use the **Build Tools for Visual Studio
2022**, which includes only the required tools to build.

1. Follow the steps above to use `premake5` for generating the project files.
2. [Download MSVC compiler/linker][] & Windows SDK without installing full Visual Studio.
3. Make sure you have the required folder in the PATH:

    - `<portable-msvc>\msvc\VC\Auxiliary\Build` - for `vcvars64.bat`
    - `<portable-msvc>\msvc\VC\Tools\MSVC\14.43.34808\bin\Hostx64\x64` - for `cl` and `lib`

4. Open a command window, navigate to the `build` directory, and locate the `build.bat` file.
   This batch file will use the generated project files to build ImGui.
5. Compile and link ImGui:

    ```bash
    build.bat
    ```

[Download MSVC compiler/linker]: https://gist.github.com/mmozeiko/7f3162ec2988e81e56d5c4e22cde9977

### Unix (macOS/Linux)

1. Clone or [download](https://github.com/Capati/odin-imgui/archive/refs/heads/main.zip) this
   repository

2. Download and install **premake5**

3. Open a terminal window, navigate to the project directory and generate the makefiles with
   desired backends:

    ```bash
    premake5 --backends=glfw,opengl3 gmake2
    # On macOS, you can also use Xcode:
    premake5 --backends=glfw,opengl3 xcode4
    ```

4. From the project folder, navigate to the generated build directory:

    ```bash
    cd build/make/linux
    # Or
    cd build/make/macosx
    ```

5. Compile the project using the `make` command:

    ```bash
    make config=release_x86_64
    # Or for debug build:
    # make config=debug_x86_64
    ```

    On macOS, the `make` command might need different configuration flags:

    ```bash
    make config=release_x86_64   # For Intel Macs
    # or
    make config=release_arm64    # For Apple Silicon (M1/M2/M3) Macs
    ```

    The generated library file will be located in the root of the project directory.

## TODO

- [ ] Internal
- [ ] Examples for reference

## Acknowledgements

- [odin-imgui](https://gitlab.com/L-4/odin-imgui/-/tree/main?ref_type=heads)
- [Odin Language](https://odin-lang.org/) - **Odin** Programming Language
- [Dear Bindings](https://github.com/dearimgui/dear_bindings) - Tool to generate the C API
- [Dear ImGui](https://github.com/ocornut/imgui) - The original ImGui library

## License

MIT License.

[dear_bindings]: https://github.com/dearimgui/dear_bindings
[Odin Language]: https://odin-lang.org
