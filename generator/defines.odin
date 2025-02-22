package imgui_gen

// Core
import "core:encoding/json"
import "core:mem"
import "core:os"
import "core:slice"

// Writes the defines from the given JSON data to the specified handle.
write_defines :: proc(gen: ^Generator, handle: os.Handle, json_data: ^json.Value) {
	root := json_data.(json.Object)

	defines, defines_ok := root["defines"]
	assert(defines_ok, "Missing 'defines' root object!")

	// Some definitions to ignore
	defines_to_ignore := []string{"IMGUI_IMPL_API"}
	is_ignored_define :: #force_inline proc(defines: []string, name: string) -> bool {
		return slice.contains(defines, name)
	}

	allocator := mem.arena_allocator(&gen.tmp_arena)

	loop: for &d in defines.(json.Array) {
		tmp_ally := mem.begin_arena_temp_memory(&gen.tmp_arena)
		defer mem.end_arena_temp_memory(tmp_ally)

		define_obj := d.(json.Object)

		// Only use default definitions (assuming not defined)
		if conditionals_value, conditionals_ok := define_obj["conditionals"]; conditionals_ok {
			conditionals := conditionals_value.(json.Array)
			for &c in conditionals {
				if condition, condition_ok := c.(json.Object)["condition"]; condition_ok {
					if condition.(json.String) != "ifndef" {
						continue loop
					}
					continue
				}
			}
		}

		name_raw, name_raw_ok := define_obj["name"].(json.String)
		assert(name_raw_ok, "Missing name definition!")

		if is_ignored_define(defines_to_ignore, name_raw) {
			continue
		}

		if content_value, content_ok := define_obj["content"]; content_ok {
			attached_comments := get_attached_comments(&define_obj, allocator)
			name := remove_imgui(name_raw, allocator)
			write_constant(gen, handle, name, attached_comments, content_value.(json.String))
		}
	}

	os.write_byte(handle, '\n')
}
