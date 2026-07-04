package check_version

import "core:fmt"
import im "../.."

main :: proc() {
	result := im.DebugCheckVersionAndDataLayout(
		im.VERSION,
		size_of(im.IO),
		size_of(im.Style),
		size_of(im.Vec2),
		size_of(im.Vec4),
		size_of(im.DrawVert),
		size_of(im.DrawIdx),
	)
	if !result {
		fmt.printfln("CHECKVERSION FAILED!")
		fmt.printfln("  VERSION:           %s", im.VERSION)
		fmt.printfln("  size_of(IO):       %d", size_of(im.IO))
		fmt.printfln("  size_of(Style):    %d", size_of(im.Style))
		fmt.printfln("  size_of(Vec2):     %d", size_of(im.Vec2))
		fmt.printfln("  size_of(Vec4):     %d", size_of(im.Vec4))
		fmt.printfln("  size_of(DrawVert): %d", size_of(im.DrawVert))
		fmt.printfln("  size_of(DrawIdx):  %d", size_of(im.DrawIdx))
	}
	ensure(result)
}
