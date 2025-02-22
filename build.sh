#!/bin/bash

set -e  # Exit on error

# Function to check prerequisites
check_prerequisites() {
    # Check if git is available
    if ! command -v git > /dev/null 2>&1
    then
        echo "Error: git is not installed. Please install git and try again."
        exit 1
    fi

    # Check for C++ compiler
    if ! command -v c++ > /dev/null 2>&1
    then
        echo "Error: C++ compiler not found. Please install a C++ compiler and try again."
        exit 1
    fi
}

# Function to setup directories
setup_directories() {
    BUILD_DIR="./build"
    DEPS_DIR="${BUILD_DIR}/deps"
    GENERATED_DIR="${BUILD_DIR}/generated"

    mkdir -p "${BUILD_DIR}"
    mkdir -p "${DEPS_DIR}"
    rm -rf "${GENERATED_DIR}"
    mkdir -p "${GENERATED_DIR}"
}

# Function to define backends and versions
define_backends() {
    # Backend list
    BACKENDS_LIST="glfw opengl3 sdl2 sdl3 sdlgpu3 sdlrenderer2 sdlrenderer3 vulkan wgpu osx metal"

    # Initialize versions
    imgui_VERSION="v1.91.8-docking"
    dear_bindings_VERSION="f6e8ea7"
    glfw_VERSION="3.4"
    vulkan_VERSION="v1.4.307"
    wgpu_VERSION="aef5e42"
    sdl2_VERSION="release-2.28.3"
    sdl3_VERSION="release-3.2.4"

    # Initialize backend flags
    for backend in ${BACKENDS_LIST}; do
        eval "BACKEND_${backend}="
    done

    # Define repository information
    set_repo_info "GLFW" "glfw" "https://github.com/glfw/glfw.git" "${glfw_VERSION}"
    set_repo_info "VULKAN" "vulkan_headers" "https://github.com/KhronosGroup/Vulkan-Headers.git" "${vulkan_VERSION}"
    set_repo_info "SDL2" "sdl2" "https://github.com/libsdl-org/SDL.git" "${sdl2_VERSION}"
    set_repo_info "SDL3" "sdl3" "https://github.com/libsdl-org/SDL.git" "${sdl3_VERSION}"
    set_repo_info "WGPU" "webgpu" "https://github.com/webgpu-native/webgpu-headers.git" "${wgpu_VERSION}"

    # Set aliases for SDL-based backends
    sdlrenderer2_VERSION="${sdl2_VERSION}"
    sdlrenderer3_VERSION="${sdl3_VERSION}"
    sdlgpu3_VERSION="${sdl3_VERSION}"
}

# Function to set repository information
set_repo_info() {
    local name=$1
    local dir=$2
    local url=$3
    local version=$4

    eval "${name}_DIR='${DEPS_DIR}/${dir}'"
    eval "${name}_URL='${url}'"
    eval "${name}_VERSION='${version}'"
    eval "${name}_NAME='${name}'"
}

# Function to parse command line arguments
parse_arguments() {
    DEBUG_BUILD=""
    INTERNAL=""

    for arg in "$@"
    do
        # Convert argument to lowercase for comparison
        arg_lower=$(echo "$arg" | tr '[:upper:]' '[:lower:]')

        case "$arg_lower" in
            "debug")
                DEBUG_BUILD=1
                ;;
            "internal")
                INTERNAL=1
                ;;
            *)
                # Check if arg matches any backend
                backend_found=0
                for backend in $BACKENDS_LIST
                do
                    if [ "$arg_lower" = "$backend" ]
                    then
                        eval "BACKEND_$backend=1"
                        backend_found=1
                        break
                    fi
                done
                if [ $backend_found -eq 0 ]
                then
                    echo "Warning: Unknown argument '$arg'"
                fi
                ;;
        esac
    done

    # Print enabled backends
    echo "Enabled backends:"
    for backend in $BACKENDS_LIST
    do
        if [ -n "$(eval echo \$BACKEND_$backend)" ]
        then
            echo "  - $backend"
        fi
    done
}

# Function to clone a repository
clone_repo() {
    local repo_name=$1
    local repo_dir=$2
    local repo_url=$3
    local repo_version=$4

    if [ ! -d "${repo_dir}" ]
    then
        echo "Cloning repository ${repo_name} ${repo_version}..."
        if git clone "${repo_url}" "${repo_dir}"
        then
            if ! (cd "${repo_dir}" && git checkout "${repo_version}" > /dev/null 2>&1)
            then
                echo "Failed to checkout version ${repo_version}."
                return 1
            fi
        else
            echo "Failed to clone repository."
            return 1
        fi
    fi
}

# Function to clone core repositories
clone_core_repositories() {
    # Clone ImGui and Dear_Bindings
    imgui_DIR="${DEPS_DIR}/imgui"
    DEAR_BINDINGS_DIR="${DEPS_DIR}/dear_bindings"

    clone_repo "ImGui" "${imgui_DIR}" "https://github.com/ocornut/imgui.git" "${imgui_VERSION}" || return 1
    clone_repo "Dear_Bindings" "${DEAR_BINDINGS_DIR}" "https://github.com/dearimgui/dear_bindings.git" "${dear_bindings_VERSION}" || return 1

    # Clone enabled backend repositories
    for backend in ${BACKENDS_LIST}; do
        # Check if the backend is enabled
        if [ -n "$(eval echo \$BACKEND_${backend})" ]; then
            # Convert backend name to uppercase for variable access
            backend_upper=$(echo "${backend}" | tr '[:lower:]' '[:upper:]')

            # Access repository information
            backend_url="$(eval echo \$${backend_upper}_URL)"
            backend_dir="$(eval echo \$${backend_upper}_DIR)"
            backend_version="$(eval echo \$${backend_upper}_VERSION)"

            # Clone the repository
            clone_repo "${backend_upper}" "${backend_dir}" "${backend_url}" "${backend_version}" || return 1
        fi
    done
}

# Function to setup Python environment
setup_python_environment() {
    VENV_DIR="${BUILD_DIR}/venv"
    PYTHON="${VENV_DIR}/bin/python"
    PIP="${VENV_DIR}/bin/pip"

    if [ ! -f "${VENV_DIR}/bin/activate" ]; then
        echo "Setting up Python virtual environment..."
        python3 -m venv "${VENV_DIR}" || {
            echo "Failed to create virtual environment."
            return 1
        }
    fi

    source "${VENV_DIR}/bin/activate" || {
        echo "Failed to activate virtual environment."
        return 1
    }

    ${PIP} install -r "${DEAR_BINDINGS_DIR}/requirements.txt" || {
        echo "Failed to install Python dependencies."
        return 1
    }
}

# Function to process ImGui headers
process_imgui_headers() {
    DEAR_BINDINGS_CMD="${DEAR_BINDINGS_DIR}/dear_bindings.py"
    DEAR_BINDINGS_COMMON_OPTIONS="--nogeneratedefaultargfunctions"

    echo "Processing imgui.h"
    ${PYTHON} ${DEAR_BINDINGS_CMD} \
        ${DEAR_BINDINGS_COMMON_OPTIONS} \
        -o ${GENERATED_DIR}/dcimgui ${imgui_DIR}/imgui.h || return 1

    if [ -n "${INTERNAL}" ]
    then
        echo "Processing imgui_internal.h"
        ${PYTHON} ${DEAR_BINDINGS_CMD} \
            ${DEAR_BINDINGS_COMMON_OPTIONS} \
            -o ${GENERATED_DIR}/dcimgui_internal \
            --include ${imgui_DIR}/imgui.h ${imgui_DIR}/imgui_internal.h || return 1
    fi
}

# Function to add backend-specific configurations
add_backend_configs() {
    # SDL2 related backends
    for backend in sdl2 sdlrenderer2; do
        if [ -n "$(eval echo \$BACKEND_${backend})" ]; then
            INCLUDE_DIRS+=(-I"${sdl2_DIR}/include")
            SOURCES+=("${IMGUI_BACKENDS_DIR}/imgui_impl_${backend}.cpp")
        fi
    done

    # SDL3 related backends
    for backend in sdl3 sdlgpu3 sdlrenderer3; do
        if [ -n "$(eval echo \$BACKEND_${backend})" ]; then
            INCLUDE_DIRS+=(-I"${sdl3_DIR}/include")
            SOURCES+=("${IMGUI_BACKENDS_DIR}/imgui_impl_${backend}.cpp")
        fi
    done

    # Simple backends that only need source files
    for backend in opengl3 osx metal; do
        if [ -n "$(eval echo \$BACKEND_${backend})" ]; then
            SOURCES+=("${IMGUI_BACKENDS_DIR}/imgui_impl_${backend}.cpp")
        fi
    done

    # Special backends with unique configurations
    if [ -n "${BACKEND_glfw}" ]; then
        INCLUDE_DIRS+=(-I"${glfw_DIR}/include")
        SOURCES+=("${IMGUI_BACKENDS_DIR}/imgui_impl_glfw.cpp")
    fi

    if [ -n "${BACKEND_vulkan}" ]; then
        INCLUDE_DIRS+=(-I"${vulkan_DIR}/include")
        SOURCES+=("${IMGUI_BACKENDS_DIR}/imgui_impl_vulkan.cpp")
        DEFINES+=(-DVK_NO_PROTOTYPES)
    fi

    if [ -n "${BACKEND_wgpu}" ]; then
        INCLUDE_DIRS+=(-I"${DEPS_DIR}")
        SOURCES+=("${IMGUI_BACKENDS_DIR}/imgui_impl_wgpu.cpp")
        DEFINES+=(-DIMGUI_IMPL_WEBGPU_BACKEND_WGPU)
    fi
}

# Function to build ImGui
build_imgui() {
    echo "Building ImGui..."

    # Determine OS and architecture
    OS_NAME=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH_NAME=$(uname -m)
    case ${ARCH_NAME} in
        x86_64) ARCH_NAME="x64" ;;
        aarch64) ARCH_NAME="arm64" ;;
    esac
    LIB_EXTENSION="a"

    IMGUI_BACKENDS_DIR="${imgui_DIR}/backends"

    # Setup include directories
    INCLUDE_DIRS=(
        -I"${imgui_DIR}"
        -I"${GENERATED_DIR}"
        -I"${IMGUI_BACKENDS_DIR}"
    )

    # Setup defines
    DEFINES=(
        -DIMGUI_DISABLE_OBSOLETE_FUNCTIONS
        -DIMGUI_DISABLE_OBSOLETE_KEYIO
        -D'IMGUI_IMPL_API=extern "C"'
    )

    # Add main source files
    SOURCES=()
    for file in "${imgui_DIR}"/*.cpp "${GENERATED_DIR}"/*.cpp; do
        SOURCES+=("${file}")
    done

    # Add backend-specific configurations
    add_backend_configs

    FILE_NAME="imgui_${OS_NAME}_${ARCH_NAME}.${LIB_EXTENSION}"

    # Set compiler flags based on build type
    if [ -n "${DEBUG_BUILD}" ]; then
        echo "Building in debug mode..."
        CXXFLAGS="-c -g -O0"
    else
        echo "Building in release mode..."
        CXXFLAGS="-c -O2"
    fi

    # Clean up before compile
    rm -f *.o

    # Compile sources
    MAX_JOBS=4
    for source in "${SOURCES[@]}"; do
        # Extract the base name of the source file (without path)
        BASENAME=$(basename "${source}" .cpp)
        # Set the output object file to the current directory
        OBJECT_FILE="${BASENAME}.o"
        echo "Compiling $source -> $OBJECT_FILE"
        g++ ${CXXFLAGS} "${INCLUDE_DIRS[@]}" "${DEFINES[@]}" "${source}" -o "${OBJECT_FILE}" || return 1 &

        # Limit the number of parallel jobs
        if [[ $(jobs -r -p | wc -l) -ge $MAX_JOBS ]]; then
            wait -n || return 1
        fi
    done

    # Wait for all remaining jobs to finish
    wait || return 1

    # Create library
    ar rcs "${FILE_NAME}" *.o

    # Clean up
    rm -f *.o
}

# Main execution
main() {
    check_prerequisites || exit 1
    setup_directories || exit 1
    define_backends || exit 1
    parse_arguments "$@" || exit 1
    clone_core_repositories || exit 1
    setup_python_environment || exit 1
    process_imgui_headers || exit 1
    build_imgui || exit 1
    echo "All operations completed successfully."
}

main "$@"
