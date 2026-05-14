package main

import "base:runtime"
import "core:fmt"
import sapp "../lib/sokol/app"
import "../engine"

main :: proc() {
	ctx := engine.MvContext{
		allocator = context.temp_allocator,
	}

	sapp.run(sapp.Desc{
		init_cb = init_tester,
		frame_cb = frame_tester,
		cleanup_cb = cleanup_tester,
		window_title = "mv engine - tester",
		width = 640,
		height = 480,
		user_data = &ctx,
	})
}

init_tester :: proc "c" () {
	context = runtime.default_context()
	
    ctx := cast(^engine.MvContext) sapp.userdata()
    engine.init(ctx)
}

frame_tester :: proc "c" () {
	context = runtime.default_context()
	
    ctx := cast(^engine.MvContext) sapp.userdata()
    engine.frame(ctx)
}

cleanup_tester :: proc "c" () {
	context = runtime.default_context()
	
    ctx := cast(^engine.MvContext) sapp.userdata()
    engine.cleanup(ctx)
}