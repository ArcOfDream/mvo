package engine

import sapp "../lib/sokol/app"
import sg "../lib/sokol/gfx"
import sglue "../lib/sokol/glue"
import slog "../lib/sokol/log"
import r "../render"
import "base:runtime"
import "core:fmt"
import "core:image"
import "core:math/linalg/glsl"

MvContext :: struct {
	allocator:           runtime.Allocator,
	is_running:          bool,
	camera:              Camera2D,
	renderer: r.Renderer,
}

init :: proc(ctx: ^MvContext) {
	engine_init(ctx)
}

frame :: proc(ctx: ^MvContext) {
	r.renderer_update_viewport(&ctx.renderer)

	r.renderer_begin(&ctx.renderer)
	
	// drawing the game to offscreen
	vp := camera_vp_matrix(ctx.camera)
	model := glsl.identity(glsl.mat4)
	vs_params := r.Vs_Params {
		mvp = vp * model,
	}

	sg.apply_uniforms(r.UB_vs_params, {ptr = &vs_params, size = size_of(vs_params)})
	sg.draw(0, 6, 1)

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
	ctx.camera = Camera2D {
		position = {VIRTUAL_W / 2, VIRTUAL_H / 2},
		zoom     = 1.0,
		width    = VIRTUAL_W,
		height   = VIRTUAL_H,
	}

}

