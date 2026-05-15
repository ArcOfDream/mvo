package engine

import c "../core"
import sg "../lib/sokol/gfx"
import r "../render"
import res "../resource"
import "base:runtime"
import "core:fmt"
import "core:math/linalg/glsl"

MvContext :: struct {
	allocator:  runtime.Allocator,
	is_running: bool,
	camera:     c.Camera2D,
	renderer:   r.Renderer,
	resources:  res.ResourceManager,
	scene_root: ^Node,
	delta_time: f32,
}

init :: proc(ctx: ^MvContext) {
	engine_init(ctx)
}

frame :: proc(ctx: ^MvContext) {
	r.renderer_update_viewport(&ctx.renderer)

	scene_traverse_update(ctx.scene_root, ctx.delta_time)

	draw_ctx := SpriteDrawContext {
		renderer  = &ctx.renderer,
		resources = &ctx.resources,
	}
	r.renderer_begin(&ctx.renderer, ctx.camera)
	scene_traverse_draw(ctx.scene_root, &draw_ctx)
	r.renderer_end(&ctx.renderer)
}

cleanup :: proc(ctx: ^MvContext) {
	sg.shutdown()
}

engine_init :: proc(ctx: ^MvContext) {
	context = runtime.default_context()

	r.renderer_init(&ctx.renderer, VIRTUAL_W, VIRTUAL_H)
	res.manager_init(&ctx.resources, ctx.allocator)

	ctx.scene_root = node_new("root")

	ctx.camera = c.Camera2D {
		position = {VIRTUAL_W / 2, VIRTUAL_H / 2},
		zoom     = 1.0,
		viewport = c.rect_make(0, 0, VIRTUAL_W, VIRTUAL_H),
	}
}

// update traversal
scene_traverse_update :: proc(root: ^Node, dt: f32) {
	node_traverse_update(root, dt)
}

// draw traversal
scene_traverse_draw :: proc(root: ^Node, ctx: ^SpriteDrawContext) {
	node_traverse_draw(root, ctx)
}
