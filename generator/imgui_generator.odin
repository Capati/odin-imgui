package imgui_gen

// Core
import "core:encoding/json"
import "core:log"
import "core:mem"
import "core:mem/virtual"
import "core:os"

Generator :: struct {
	// Allocator
	allocator:           mem.Allocator,
	tmp_arena:           mem.Arena,

	// Containers
	flags:               [dynamic]Enum_Definition,
	types_to_ignore:     []string,
	functions_to_ignore: []string,
	pointers_to_ignore:  []string,

	// Maps
	type_map:            map[string]string,
	identifier_map:      map[string]bool,
	replace_map:         map[string]string,
}

FLAG_TYPE :: "i32"
TAB_SPACE :: "    "
GENERATED_DIR :: "./generated/"
GENERATED_BACKENDS_DIR :: "./generated/backends/"

// odinfmt: disable
FOREIGN_IMPORT :: `
when ODIN_OS == .Linux || ODIN_OS == .Darwin {
	@(require) foreign import stdcpp "system:c++"
}

when ODIN_OS == .Windows {
	when ODIN_ARCH == .amd64 {
		foreign import lib "imgui_windows_x64.lib"
	} else {
		foreign import lib "imgui_windows_arm64.lib"
	}
} else when ODIN_OS == .Linux {
	when ODIN_ARCH == .amd64 {
		foreign import lib "libimgui_linux_x64.a"
	} else {
		foreign import lib "libimgui_linux_arm64.a"
	}
} else when ODIN_OS == .Darwin {
	when ODIN_ARCH == .amd64 {
		foreign import lib "libimgui_macosx_x64.a"
	} else {
		foreign import lib "libimgui_macosx_arm64.a"
	}
}

CHECKVERSION :: proc() {
	ensure(
		debug_check_version_and_data_layout(
			VERSION,
			size_of(IO),
			size_of(Style),
			size_of(Vec2),
			size_of(Vec4),
			size_of(Draw_Vert),
			size_of(Draw_Idx),
		),
	)
}

`
// odinfmt: enable

main :: proc() {
	context.logger = log.create_console_logger(opt = {.Terminal_Color, .Level})
	defer log.destroy_console_logger(context.logger)

	arena: virtual.Arena
	ensure(virtual.arena_init_growing(&arena) == nil, "Failed to initialize 'virtual.Arena'")
	defer virtual.arena_destroy(&arena)

	allocator := virtual.arena_allocator(&arena)

	gen := new(Generator, allocator)
	ensure(gen != nil, "Failed to allocate new 'Generator'")

	gen.allocator = allocator
	gen.flags.allocator = allocator
	gen.type_map.allocator = allocator
	gen.identifier_map.allocator = allocator
	gen.replace_map.allocator = allocator

	fill_type_map(gen)

	// Enough memory for the dcimgui.json
	tmp_ally_buf := make([]byte, 24 * mem.Megabyte, allocator)
	ensure(tmp_ally_buf != nil)
	mem.arena_init(&gen.tmp_arena, tmp_ally_buf[:])

	if !write_imgui(gen) {
		return
	}
}

IMGUI_JSON :: GENERATED_DIR + "dcimgui.json"

write_imgui :: proc(gen: ^Generator) -> (ok: bool) {
	file_allocator := mem.arena_allocator(&gen.tmp_arena)
	defer free_all(file_allocator)

	filename := "./../imgui.odin"
	if os.exists(filename) {
		os.remove(filename)
	}

	im := create_file_handle(filename, IMGUI_JSON, file_allocator)
	defer os.close(im.handle)

	write_package_name(im.handle, nl = false)

	os.write_string(im.handle, FOREIGN_IMPORT)

	gen.functions_to_ignore = {"ImStr_FromCharStr"}
	defer gen.functions_to_ignore = {}

	write_defines(gen, im.handle, &im.data)
	write_enums(gen, im.handle, &im.data)
	write_typedefs(gen, im.handle, &im.data)
	write_structs(gen, im.handle, &im.data)
	write_procedures(gen, im.handle, &im.data)

	return true
}

File_Handle :: struct {
	data:   json.Value,
	handle: os.Handle,
}

create_file_handle :: proc(
	filename: string,
	json_path: string,
	allocator := context.allocator,
) -> File_Handle {
	json_file, json_file_ok := os.read_entire_file_from_filename(json_path, allocator)
	if !json_file_ok {
		log.panicf("Failed to load '%s' file!", json_path)
	}

	json_data, json_err := json.parse(json_file, allocator = allocator)
	if json_err != nil {
		log.errorf("Failed to parse '%s' file!", json_path)
		log.panicf("Json Error: %s", json_err)
	}

	file_handle, handle_err := os.open(filename, os.O_WRONLY | os.O_CREATE)
	if handle_err != nil {
		log.errorf("Failed to create '%s' file.", filename)
		log.panicf("Handle Error: %s", handle_err)
	}

	return {json_data, file_handle}
}
