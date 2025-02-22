package imgui_gen

// Core
import "base:runtime"
import "core:encoding/json"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"

write_typedefs :: proc(gen: ^Generator, handle: os.Handle, json_data: ^json.Value) {
	ta := context.temp_allocator
	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

	ignore_type_map: map[string]string;ignore_type_map.allocator = ta
	ignore_type_map["ImS64"] = "i64"
	ignore_type_map["ImU64"] = "u64"
	ignore_type_map["ImS8"] = "i8"
	ignore_type_map["ImU8"] = "u8"
	ignore_type_map["ImS16"] = "i16"
	ignore_type_map["ImU16"] = "u16"
	ignore_type_map["ImS32"] = "i32"
	ignore_type_map["ImU32"] = "u32"

	root := json_data.(json.Object)

	typedefs, defines_ok := root["typedefs"]
	if !defines_ok {
		log.warn("Missing 'typedefs' root object! Ignoring...")
		return
	}

	allocator := mem.arena_allocator(&gen.tmp_arena)

	loop: for &t in typedefs.(json.Array) {
		// Avoid obsolete constants
		if test_ifndef_condition(&t.(json.Object), "IMGUI_USE_WCHAR32") {
			continue
		}

		tmp_ally := mem.begin_arena_temp_memory(&gen.tmp_arena)
		defer mem.end_arena_temp_memory(tmp_ally)

		typedef_name_raw, typedef_name_raw_ok := json_get_string(&t, "name")
		assert(typedef_name_raw_ok, "Typedef name is missing!")

		// Ignore integral types
		if typedef_name_raw in ignore_type_map {
			continue
		}

		typedef_name: string

		if elem, ok := gen.type_map[typedef_name_raw]; ok {
			typedef_name = elem
		} else {
			typedef_name = remove_imgui(typedef_name_raw, allocator)
		}

		typedef_name = pascal_to_ada_case(typedef_name, allocator)

		// Only use typedef that is not in the identifiers map
		if _, typedef_exists := gen.identifier_map[typedef_name]; typedef_exists {
			continue
		}

		typedef_type, typedef_type_ok := t.(json.Object)["type"]
		assert(typedef_type_ok, "Typedef type is missing!")

		// Check for function pointer
		typedef_details, typedef_details_ok := typedef_type.(json.Object)["type_details"]
		if typedef_details_ok {
			description, description_ok := typedef_type.(json.Object)["description"]
			assert(description_ok, "Typedef description is missing!")
			proc_def := get_proc_definition(
				gen = gen,
				type = &description.(json.Object),
				details = &typedef_details.(json.Object),
				allocator = ta,
			)
			os.write_string(handle, proc_def.name)
			os.write_string(handle, " :: #type ")
			os.write_string(handle, proc_def.definition)
			os.write_string(handle, "\n")
		} else {
			typedef_type_declaration, typedef_type_declaration_ok := json_get_string(
				&typedef_type,
				"declaration",
			)
			assert(typedef_type_declaration_ok, "Typedef declaration is missing!")
			typedef_type_value: string
			if elem, ok := gen.type_map[typedef_type_declaration]; ok {
				typedef_type_value = elem
			} else {
				typedef_type_value = typedef_type_declaration
			}

			typedef_to_write := fmt.tprintf("%s :: %s\n", typedef_name, typedef_type_value)

			os.write_string(handle, typedef_to_write)
		}
	}
	os.write_string(handle, "\n")
}
