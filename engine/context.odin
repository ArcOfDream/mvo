package engine

import c "../core"
import sg "../lib/sokol/gfx"
import r "../render"
import "base:runtime"
import "core:fmt"
import "core:math/linalg/glsl"

MvContext :: struct {
	allocator:  runtime.Allocator,
	is_running: bool,
	camera:     c.Camera2D,
	renderer:   r.Renderer,
}

init :: proc(ctx: ^MvContext) {
	engine_init(ctx)
}

frame :: proc(ctx: ^MvContext) {
	r.renderer_update_viewport(&ctx.renderer)
	r.renderer_begin(&ctx.renderer, ctx.camera)

	// draw the checkerboard using the sprite API
	transform := c.transform_make({VIRTUAL_W / 2 - 64, VIRTUAL_H / 2 - 64}, {128, 128}, 0)
	r.renderer_draw_sprite(
		&ctx.renderer,
		ctx.renderer.checkerboard_texture,
		&transform,
		0xFFFFFFFF,
	)

	r.renderer_end(&ctx.renderer)
}

cleanup :: proc(ctx: ^MvContext) {
	sg.shutdown()
}

engine_init :: proc(ctx: ^MvContext) {
	r.renderer_init(&ctx.renderer, VIRTUAL_W, VIRTUAL_H)

	backend := sg.query_backend()
	assert(backend != .DUMMY, "Failed to initialize sokol_gfx backend")
	fmt.println("sokol_gfx initialized with backend:", backend)

	// Camera setup
	ctx.camera = c.Camera2D {
		position = {VIRTUAL_W / 2, VIRTUAL_H / 2},
		zoom     = 1.0,
		viewport = c.rect_make(0, 0, VIRTUAL_W, VIRTUAL_H),
	}

}
