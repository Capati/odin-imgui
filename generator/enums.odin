package imgui_gen

// Core
import "base:runtime"
import "core:encoding/json"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:strings"
import "core:unicode"

write_enums :: proc(gen: ^Generator, handle: os.Handle, json_data: ^json.Value) {
	root := json_data.(json.Object)

	enums, defines_ok := root["enums"]
	if !defines_ok {
		log.warn("Missing 'enums' root object! Ignoring...")
		return
	}

	allocator := mem.arena_allocator(&gen.tmp_arena)

	loop: for &e in enums.(json.Array) {
		// Avoid obsolete constants
		if test_ifndef_condition(&e.(json.Object), "IMGUI_DISABLE_OBSOLETE_KEYIO") {
			continue
		}

		tmp_ally := mem.begin_arena_temp_memory(&gen.tmp_arena)
		defer mem.end_arena_temp_memory(tmp_ally)

		enum_name_raw, enum_name_raw_ok := json_get_string(&e, "name")
		assert(enum_name_raw_ok, "Enum name is missing!")

		enum_name_raw_no_suffix := enum_name_raw
		// Remove underscore suffix from names (eg: ImGuiWindowFlags_ -> ImGuiWindowFlags)
		if strings.ends_with(enum_name_raw_no_suffix, "_") {
			enum_name_raw_no_suffix = enum_name_raw[:len(enum_name_raw) - 1]
		}

		enum_name := remove_imgui(enum_name_raw_no_suffix, allocator)
		enum_name = pascal_to_ada_case(enum_name, gen.allocator)

		// Add this name to the map of identifiers found, will be used later
		// to generate remain definitions
		gen.identifier_map[enum_name] = true

		elements_value := e.(json.Object)["elements"]

		is_flags := strings.ends_with(enum_name, "Flags")

		entry := create_enum_entry(
			enum_entry = &e.(json.Object),
			enum_name_raw = enum_name_raw_no_suffix,
			enum_name = enum_name,
			elements = &elements_value.(json.Array),
			is_flags = is_flags,
			allocator = gen.allocator if is_flags else allocator,
		)

		if is_flags {
			append(&gen.flags, entry)
		}

		write_enum_entry(entry, handle)
	}
}

Enum_Kind :: enum {
	None,
	Basic,
	Bitset,
}

Enum_Constant :: struct {
	allocator: mem.Allocator,
	comment:   string,
	name:      string,
	value:     int,
}

Alias_Constant :: struct {
	name:  string,
	value: int,
}

Grouped_Aliases :: struct {
	name:    string,
	aliases: [dynamic]string,
}

Enum_Definition :: struct {
	allocator:    mem.Allocator,
	kind:         Enum_Kind,
	name:         string,
	comment:      string,
	constants:    [dynamic]Enum_Constant,
	alias_values: [dynamic]Alias_Constant,
	flags:        [dynamic]string,
	flag_groups:  [dynamic]Grouped_Aliases,
}

create_enum_entry :: proc(
	enum_entry: ^json.Object,
	enum_name_raw: string,
	enum_name: string,
	elements: ^json.Array,
	is_flags: bool,
	allocator: runtime.Allocator,
) -> (
	entry: Enum_Definition,
) {
	entry.allocator = allocator

	entry.constants.allocator = allocator
	entry.alias_values.allocator = allocator
	entry.flags.allocator = allocator
	entry.flag_groups.allocator = allocator

	entry.name = strings.clone(enum_name, allocator)

	ta := context.temp_allocator
	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

	// Get preceding comments (if any)
	if preceding_comments, preceding_comments_ok := get_preceding_comments(
		obj = enum_entry,
		allocator = allocator,
	); preceding_comments_ok {
		entry.comment = preceding_comments
	}

	if is_flags {
		entry.kind = .Bitset
	} else {
		entry.kind = .Basic
	}

	for &e in elements {
		if test_ifndef_condition(&e.(json.Object), "IMGUI_DISABLE_OBSOLETE_FUNCTIONS") {
			continue
		}

		if test_ifndef_condition(&e.(json.Object), "IMGUI_DISABLE_OBSOLETE_KEYIO") {
			continue
		}

		is_internal_value := e.(json.Object)["is_internal"]
		is_internal := is_internal_value.(json.Boolean)
		if is_flags && is_internal {
			continue
		}

		element_name_raw, element_name_ok := json_get_string(&e, "name")
		assert(element_name_ok, "Enum entry name is missing!")

		entry_name, _ := strings.remove(element_name_raw, enum_name_raw, -1, ta)
		if strings.starts_with(entry_name, "_") {
			entry_name = entry_name[1:]
		}
		if strings.ends_with(entry_name, "_") {
			entry_name = entry_name[:len(entry_name) - 1]
		}

		element_obj := e.(json.Object)

		json_value, json_value_ok := element_obj["value"].(json.Float)
		assert(json_value_ok, "Failed to parse enum value!")
		value := int(json_value) // Convert float to int first

		if strings.starts_with(entry_name, "ImGui") {
			append(&entry.alias_values, Alias_Constant{entry_name, value})
			continue
		}

		if is_flags {
			// Skip 'None' entry
			if value == 0 && entry_name == "None" {
				continue
			}

			append(&entry.flags, strings.clone(entry_name, allocator))

			if expr, expr_ok := json_get_string(&e, "value_expression"); expr_ok {
				if strings.contains(expr, "|") {
					flags := strings.fields(expr, ta)
					flag_groups: Grouped_Aliases;flag_groups.aliases.allocator = allocator
					flag_groups.name = strings.clone(entry_name, allocator)
					for f in flags {
						if f == "|" {
							continue
						}
						flag_entry_name := f[strings.index(f, "_") + 1:]
						append(&flag_groups.aliases, strings.clone(flag_entry_name, allocator))
					}
					append(&entry.flag_groups, flag_groups)
					continue
				}

				// Check if it's a bit shift expression (e.g., "1<<5")
				if strings.contains(expr, "<<") {
					// Searching for the bit position...
					for i := 0; i < 32; i += 1 {
						mask := u32(1) << u32(i)
						if u32(value) & mask != 0 {
							value = i // Found bit position
							break
						}
					}
				}
			}
		}

		append(
			&entry.constants,
			Enum_Constant {
				allocator = allocator,
				comment = get_attached_comments(&element_obj, allocator),
				name = pascal_to_ada_case(entry_name, allocator),
				value = value,
			},
		)
	}

	return
}

write_enum_entry :: proc(entry: Enum_Definition, handle: os.Handle) {
	ta := context.temp_allocator
	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()

	b := strings.builder_make(ta)

	if entry.comment != "" {
		strings.write_string(&b, entry.comment)
	}

	if entry.kind == .Bitset {
		bit_set_str := fmt.tprintf(
			"%s :: bit_set[%s; %s]",
			entry.name,
			entry.name[:len(entry.name) - 1],
			FLAG_TYPE,
		)
		strings.write_string(&b, bit_set_str)
		strings.write_rune(&b, '\n')
	}

	strings.write_string(
		&b,
		entry.name if entry.kind == .Basic else entry.name[:len(entry.name) - 1],
	)
	strings.write_string(&b, " :: enum ")
	strings.write_string(&b, FLAG_TYPE)
	strings.write_string(&b, " {")
	strings.write_rune(&b, '\n')

	can_be_constant := [?]string{"Named_Key_"}
	check_can_be_constant :: proc(arr: []string, name: string) -> bool {
		for v in arr {
			if strings.starts_with(name, v) {
				return true
			}
		}
		return false
	}

	constants: [dynamic]Enum_Constant;constants.allocator = ta
	found_count: bool

	create_enum_constant :: proc(
		entry: Enum_Definition,
		curr: Enum_Constant,
		allocator: runtime.Allocator,
	) -> Enum_Constant {
		name := strings.concatenate({entry.name, "_", curr.name}, allocator = allocator)
		name = to_constant_case(name, allocator)
		value := curr.value
		return {allocator, curr.comment, name, value}
	}

	for &v in entry.constants {
		if check_can_be_constant(can_be_constant[:], v.name) {
			append(&constants, create_enum_constant(entry, v, ta))
			continue
		} else if found_count || v.name == "COUNT" {
			found_count = true
			append(&constants, create_enum_constant(entry, v, ta))
			continue
		}
		strings.write_string(&b, TAB_SPACE)
		if unicode.is_digit(rune(v.name[0])) {
			strings.write_byte(&b, '_')
		}
		strings.write_string(&b, v.name)
		strings.write_string(&b, " = ")
		strings.write_int(&b, v.value)
		strings.write_byte(&b, ',')
		if v.comment != "" {
			strings.write_byte(&b, ' ')
			strings.write_string(&b, v.comment)
		}
		strings.write_byte(&b, '\n')
	}
	strings.write_string(&b, "}\n")

	if len(constants) > 0 {
		strings.write_byte(&b, '\n')
		for &v in constants {
			strings.write_string(&b, v.name)
			strings.write_string(&b, " :: ")
			strings.write_int(&b, v.value)
			strings.write_byte(&b, '\n')
		}
	}

	if entry.kind == .Basic && len(entry.alias_values) > 0 {
		if len(constants) == 0 {
			strings.write_byte(&b, '\n')
		}

		for &v in entry.alias_values {
			b_entry_name := strings.builder_make(ta)
			strings.write_string(&b_entry_name, entry.name)
			strings.write_string(&b_entry_name, "_")
			strings.write_string(&b_entry_name, v.name)
			strings.write_string(&b_entry_name, " :: ")
			strings.write_int(&b_entry_name, v.value)
			entry_name := strings.to_string(b_entry_name)
			entry_name, _ = strings.remove(entry_name, "ImGui", -1, ta)
			entry_name = to_constant_case(entry_name, ta)
			strings.write_string(&b, entry_name)
			strings.write_byte(&b, '\n')
		}
	}

	// Pre defined flags
	if entry.kind == .Bitset && len(entry.flag_groups) > 0 {
		strings.write_byte(&b, '\n')

		flag_map := make(map[string][]string, ta)

		for &v in entry.flag_groups {
			flag_map[v.name] = v.aliases[:]
		}

		for &v in entry.flag_groups {
			b_flags_name := strings.builder_make(ta)
			strings.write_string(&b_flags_name, entry.name)
			strings.write_byte(&b_flags_name, '_')
			strings.write_string(&b_flags_name, v.name)
			b_flags := strings.builder_make(ta)
			flags_name_constant := to_constant_case(strings.to_string(b_flags_name), ta)
			if strings.ends_with(flags_name_constant, "_") {
				flags_name_constant = flags_name_constant[:len(flags_name_constant) - 1]
			}
			strings.write_string(&b_flags, flags_name_constant)
			strings.write_string(&b_flags, " :: ")
			strings.write_string(&b_flags, entry.name)
			strings.write_byte(&b_flags, '{')
			for flag, flag_idx in v.aliases {
				// Check if we need to "append" the flags from a current set
				if curr, curr_ok := flag_map[flag]; curr_ok {
					for f, _ in curr {
						flag_entry_name := f[strings.index(f, "_") + 1:]
						strings.write_byte(&b_flags, '.')
						flag_entry_name = pascal_to_ada_case(flag_entry_name, ta)
						strings.write_string(&b_flags, flag_entry_name)
						strings.write_string(&b_flags, ", ")
					}
					continue
				}
				flag_entry_name := flag[strings.index(flag, "_") + 1:]
				flag_entry_name = pascal_to_ada_case(flag_entry_name, ta)
				strings.write_byte(&b_flags, '.')
				strings.write_string(&b_flags, flag_entry_name)
				if flag_idx < len(v.aliases) - 1 {
					strings.write_string(&b_flags, ", ")
				}
			}
			strings.write_string(&b_flags, "}\n")
			strings.write_string(&b, strings.to_string(b_flags))
		}
	}

	strings.write_byte(&b, '\n')

	os.write_string(handle, strings.to_string(b))
}

to_constant_case :: proc(str: string, ally: mem.Allocator) -> string {
	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(ignore = ally == context.temp_allocator)
	b := strings.builder_make(context.temp_allocator)

	was_prev_upper := false
	for c, i in str {
		if unicode.is_upper(c) {
			// Only add underscore if:
			// 1. Not at the start of string
			// 2. Previous character wasn't underscore
			// 3. Previous character wasn't uppercase (to prevent splitting consecutive caps)
			if i > 0 && str[i - 1] != '_' && !was_prev_upper {
				strings.write_byte(&b, '_')
			}
			was_prev_upper = true
		} else {
			was_prev_upper = false
		}
		strings.write_byte(&b, u8(unicode.to_upper(c)))
	}

	return strings.clone(strings.to_string(b), ally)
}
