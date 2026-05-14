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
	pip:                 sg.Pipeline,
	bind:                sg.Bindings,
	pass_action:         sg.Pass_Action,
	camera:              Camera2D,

	// offscreen
	offscreen_pass:      sg.Pass,

	// viewport (display)
	viewport_pip:        sg.Pipeline,
	viewport_bind:       sg.Bindings,
	viewport_vertex_buf: sg.Buffer,
}

init :: proc(ctx: ^MvContext) {
	engine_init(ctx)
}

frame :: proc(ctx: ^MvContext) {
	update_viewport_quad(ctx)
	
	// drawing the game to offscreen
	vp := camera_vp_matrix(ctx.camera)
	model := glsl.identity(glsl.mat4)
	vs_params := r.Vs_Params {
		mvp = vp * model,
	}

	sg.begin_pass(ctx.offscreen_pass)
	sg.apply_pipeline(ctx.pip)
	sg.apply_bindings(ctx.bind)
	sg.apply_uniforms(r.UB_vs_params, {ptr = &vs_params, size = size_of(vs_params)})
	sg.draw(0, 6, 1)
	sg.end_pass()

	// drawing viewport on the screen
	sg.begin_pass({action = ctx.pass_action, swapchain = sglue.swapchain()})
	sg.apply_pipeline(ctx.viewport_pip)
	sg.apply_bindings(ctx.viewport_bind)
	sg.draw(0, 6, 1)
	sg.end_pass()

	sg.commit()
}

cleanup :: proc(ctx: ^MvContext) {
	sg.shutdown()
}

engine_init :: proc(ctx: ^MvContext) {
	context = runtime.default_context()

	// checkerboard texture for now
	TEX_W :: 8
	TEX_H :: 8
	pixels: [TEX_W * TEX_H]u32
	for y in 0 ..< TEX_H {
		for x in 0 ..< TEX_W {
			idx := y * TEX_W + x
			// checkerboard: white on even cells, color on odd
			if (x + y) % 2 == 0 {
				pixels[idx] = r.rgba(255, 255, 255, 255) // white
			} else {
				pixels[idx] = r.rgba(255, 136, 68, 255) // orange-ish
			}
		}
	}

	sg.setup({environment = sglue.environment(), logger = {func = slog.func}})

	backend := sg.query_backend()
	assert(backend != .DUMMY, "Failed to initialize sokol_gfx backend")
	fmt.println("sokol_gfx initialized with backend:", backend)

	// Vertex buffer for the quad
	QUAD_SIZE :: 128
	left := f32(VIRTUAL_W / 2 - QUAD_SIZE / 2) // 256
	right := f32(VIRTUAL_W / 2 + QUAD_SIZE / 2) // 384
	top := f32(VIRTUAL_H / 2 - QUAD_SIZE / 2) // 116
	bottom := f32(VIRTUAL_H / 2 + QUAD_SIZE / 2) // 244
	vertices := [?]r.Vertex {
		{left, top, 0.5, 1.0, 0xffffffff, 0.0, 0.0},
		{right, top, 0.5, 1.0, 0xffffffff, 1.0, 0.0},
		{right, bottom, 0.5, 1.0, 0xffffffff, 1.0, 1.0},
		{left, bottom, 0.5, 1.0, 0xffffffff, 0.0, 1.0},
	}
	ctx.bind.vertex_buffers[0] = sg.make_buffer(
		{data = {ptr = &vertices, size = size_of(vertices)}, label = "quad-vertices"},
	)

	// And now the index buffer
	indices := [?]u16{0, 1, 2, 0, 2, 3}
	ctx.bind.index_buffer = sg.make_buffer(
		{
			usage = {index_buffer = true},
			data = {ptr = &indices, size = size_of(indices)},
			label = "quad-indices",
		},
	)

	// And now to make a GPU texture (image) and a view into it
	ctx.bind.views[r.VIEW_tex] = sg.make_view(
		{
			texture = {
				image = sg.make_image(
					{
						width = TEX_W,
						height = TEX_H,
						pixel_format = .RGBA8,
						data = {mip_levels = {0 = {ptr = &pixels, size = size_of(pixels)}}},
					},
				),
			},
		},
	)

	// ...and a sampler to tell how a texture is read
	ctx.bind.samplers[r.SMP_smp] = sg.make_sampler(
		{
			min_filter = .NEAREST, // crunchy pixels - good for a checkerboard demo
			mag_filter = .NEAREST,
			wrap_u     = .CLAMP_TO_EDGE,
			wrap_v     = .CLAMP_TO_EDGE,
			label      = "checkerboard-sampler",
		},
	)

	// Pipeline time: shader and vertex layout
	ctx.pip = sg.make_pipeline(
		{
			shader = sg.make_shader(r.default_shader_desc(backend)),
			index_type = .UINT16,
			layout = {
				attrs = {
					r.ATTR_default_position = {format = .FLOAT4},
					r.ATTR_default_color0 = {format = .UBYTE4N},
					r.ATTR_default_texcoord0 = {format = .FLOAT2},
				},
			},
			label = "quad-pipeline",
		},
	)

	// ...and the Pass Action to tell what to do every frame
	ctx.pass_action = {
		colors = {0 = {load_action = .CLEAR, clear_value = {r = 0.1, g = 0.1, b = 0.15, a = 1.0}}},
	}

	// Camera setup
	ctx.camera = Camera2D {
		position = {VIRTUAL_W / 2, VIRTUAL_H / 2},
		zoom     = 1.0,
		width    = VIRTUAL_W,
		height   = VIRTUAL_H,
	}

	// offscreen color image
	offscreen_img := sg.make_image(
		{
			usage = {color_attachment = true},
			width = VIRTUAL_W,
			height = VIRTUAL_H,
			pixel_format = .RGBA8,
		},
	)

	// offscreen pass
	ctx.offscreen_pass = {
		action = {
			colors = {
				0 = {load_action = .CLEAR, clear_value = {r = 0.0, g = 0.0, b = 0.0, a = 1.0}},
			},
		},
		attachments = {colors = {0 = sg.make_view({color_attachment = {image = offscreen_img}})}},
	}

	viewport_vertices := [4]r.VertexViewport {
		{-1, 1, 0, 0},
		{1, 1, 1, 0},
		{1, -1, 1, 1},
		{-1, -1, 0, 1},
	}
	viewport_indices := [6]u16{0, 1, 2, 0, 2, 3}

	ctx.viewport_bind.vertex_buffers[0] = sg.make_buffer(
		{data = {ptr = &viewport_vertices, size = size_of(viewport_vertices)}},
	)
	ctx.viewport_bind.index_buffer = sg.make_buffer(
		{
			usage = {index_buffer = true},
			data = {ptr = &viewport_indices, size = size_of(viewport_indices)},
		},
	)
	ctx.viewport_bind.views[r.VIEW_tex] = sg.make_view({texture = {image = offscreen_img}})
	ctx.viewport_bind.samplers[r.SMP_smp] = sg.make_sampler(
		{min_filter = .NEAREST, mag_filter = .NEAREST},
	)
	ctx.viewport_pip = sg.make_pipeline(
		{
			shader = sg.make_shader(r.viewport_shader_desc(backend)),
			index_type = .UINT16,
			layout = {
				attrs = {
					r.ATTR_viewport_position = {format = .FLOAT2},
					r.ATTR_viewport_texcoord0 = {format = .FLOAT2},
				},
			},
		},
	)

	ctx.viewport_vertex_buf = sg.make_buffer(
		{
			data = {ptr = &viewport_vertices, size = size_of(viewport_vertices)},
			usage = {dynamic_update = true},
		},
	)
	ctx.viewport_bind.vertex_buffers[0] = ctx.viewport_vertex_buf
}

update_viewport_quad :: proc(ctx: ^MvContext) {
	win_w := sapp.widthf()
	win_h := sapp.heightf()
	virt_aspect := cast(f32)(VIRTUAL_W / VIRTUAL_H)
	win_aspect := win_w / win_h

	ndc_w, ndc_h: f32
	if virt_aspect > win_aspect {
		// virtual is wider than window → fill width, bars top/bottom
		ndc_w = 2.0
		ndc_h = 2.0 * win_aspect / virt_aspect
	} else {
		// virtual is taller or equal → fill height, bars left/right
		ndc_h = 2.0
		ndc_w = 2.0 * virt_aspect / win_aspect
	}

	hw := ndc_w / 2.0
	hh := ndc_h / 2.0

	vertices := [?]r.VertexViewport {
		{-hw, hh, 0, 0},
		{hw, hh, 1, 0},
		{hw, -hh, 1, 1},
		{-hw, -hh, 0, 1},
	}
	sg.update_buffer(ctx.viewport_vertex_buf, {ptr = &vertices, size = size_of(vertices)})
}
