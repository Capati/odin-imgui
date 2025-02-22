# Odin ImGui

[Odin Language][] bindings for **Dear ImGui v1.91.8-docking**.

## Table of Contents

- [Features](#features)
- [Building](#building)
  - [Prerequisites](#prerequisites)
  - [Windows](#windows)
  - [Unix](#unix)
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

Building is entirely automated using `build.bat` on Windows and `build.sh` on Unix systems
(Linux/Mac).

### Prerequisites

- [Git](http://git-scm.com/downloads) - must be in the path
- [Python](https://www.python.org/downloads/) - version 3.3.x is required by [dear_bindings][]
  and `venv` (Python Virtual Environment)
- C++ compiler - `MSVC` on Windows or `g++/clang` on Unix

### Windows

1. Open a Command Prompt and navigate to the project directory

2. Run the `.\build.bat` script with **wanted backends** in arguments:

    ```batch
    build.bat glfw vulkan
    ```

3. To create a debug build, provide a `debug` argument:

    ```batch
    build.bat glfw vulkan debug
    ```

### Unix

1. Open a Terminal and navigate to the project directory

2. Make the script `build.sh` executable (if needed):

    ```shell
    chmod +x ./build.sh
    ```

3. Run the `./build.sh` script with **wanted backends** in arguments:

    ```shell
    ./build.sh glfw vulkan
    ```

4. To create a debug build, provide a `debug` argument:

    ```shell
    build.sh glfw vulkan debug
    ```

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
