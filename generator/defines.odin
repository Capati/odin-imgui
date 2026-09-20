package imgui_gen

// Core
import "core:encoding/json"
import "core:mem"
import "core:os"
import "core:slice"
import "core:strings"

// Writes the defines from the given JSON data to the specified handle.
write_defines :: proc(gen: ^Generator, handle: ^os.File, json_data: ^json.Value) {
	root := json_data.(json.Object)

	defines, defines_ok := root["defines"]
	assert(defines_ok, "Missing 'defines' root object!")

	// Some definitions to ignore
	defines_to_ignore := []string{
		"IMGUI_IMPL_API",
		"IM_ARRAYSIZE",
	}
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
			content_str := content_value.(json.String)
			if translated, ok := translate_c_cast(content_str, allocator); ok {
				content_str = translated
			}
			write_constant(gen, handle, name, attached_comments, content_str)
		}
	}

	os.write_byte(handle, '\n')
}

translate_c_cast :: proc(content: string, allocator: mem.Allocator) -> (string, bool) {
	s := strings.trim_space(content)

	// Strip one redundant outer pair: "((T)v)" -> "(T)v"
	if len(s) > 2 && s[0] == '(' && s[len(s) - 1] == ')' {
		depth := 0
		wraps_all := true
		for i in 0 ..< len(s) {
			switch s[i] {
			case '(': depth += 1
			case ')':
				depth -= 1
				if depth == 0 && i < len(s) - 1 {
					wraps_all = false
				}
			}
		}
		if wraps_all {
			s = s[1:len(s) - 1]
		}
	}

	if len(s) == 0 || s[0] != '(' {
		return "", false
	}
	close := strings.index_byte(s, ')')
	if close < 0 {
		return "", false
	}
	type_name := s[1:close]
	value := strings.trim_space(s[close + 1:])
	if len(value) == 0 {
		return "", false
	}

	ty := remove_imgui(type_name, allocator)
	return strings.concatenate({ty, "(", value, ")"}, allocator), true
}
