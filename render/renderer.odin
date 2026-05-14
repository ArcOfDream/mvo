package render

import c "../core"
import sapp "../lib/sokol/app"
import sg "../lib/sokol/gfx"
import sglue "../lib/sokol/glue"
import slog "../lib/sokol/log"
import "core:fmt"
import "core:image"

// the core struct holding all GPU state.
Renderer :: struct {
	// default draw pipeline (for sprites, shapes)
	pip:                           sg.Pipeline,
	bind:                          sg.Bindings,
	pass_action:                   sg.Pass_Action,

	// offscreen render target
	offscreen_pass:                sg.Pass,
	offscreen_img:                 sg.Image,

	// viewport display
	viewport_pip:                  sg.Pipeline,
	viewport_bind:                 sg.Bindings,
	viewport_vertex_buf:           sg.Buffer,

	// settings
	virtual_width, virtual_height: i32,
}

renderer_init :: proc(r: ^Renderer, virtual_w, virtual_h: i32) {
    r.virtual_width = virtual_w
    r.virtual_height = virtual_h

    sg.setup({
        environment = sglue.environment(),
        logger = {func = slog.func},
    })

    backend := sg.query_backend()
    assert(backend != .DUMMY, "Failed to initialize sokol_gfx backend")
    fmt.println("sokol_gfx initialized with backend:", backend)

    // create the default shader and pipeline
    r.pip = sg.make_pipeline({
        shader = sg.make_shader(default_shader_desc(backend)),
        index_type = .UINT16,
        layout = {
            attrs = {
                ATTR_default_position  = {format = .FLOAT4},
                ATTR_default_color0    = {format = .UBYTE4N},
                ATTR_default_texcoord0 = {format = .FLOAT2},
            },
        },
        label = "default-pipeline",
    })

    // create a test texture (checkerboard) and its sampler
    TEX_W :: 8
    TEX_H :: 8
    pixels: [TEX_W * TEX_H]u32
    for y in 0 ..< TEX_H {
        for x in 0 ..< TEX_W {
            idx := y * TEX_W + x
            if (x + y) % 2 == 0 {
                pixels[idx] = rgba(255, 255, 255, 255)
            } else {
                pixels[idx] = rgba(255, 136, 68, 255)
            }
        }
    }

    r.bind.views[VIEW_tex] = sg.make_view({
        texture = {
            image = sg.make_image({
                width = TEX_W,
                height = TEX_H,
                pixel_format = .RGBA8,
                data = {mip_levels = {0 = {ptr = &pixels, size = size_of(pixels)}}},
            }),
        },
    })

    r.bind.samplers[SMP_smp] = sg.make_sampler({
        min_filter = .NEAREST,
        mag_filter = .NEAREST,
        wrap_u     = .CLAMP_TO_EDGE,
        wrap_v     = .CLAMP_TO_EDGE,
        label      = "default-sampler",
    })

    // create the offscreen render target
    r.offscreen_img = sg.make_image({
        usage = {color_attachment = true},
        width = virtual_w,
        height = virtual_h,
        pixel_format = .RGBA8,
    })

    r.offscreen_pass = {
        action = {
            colors = {
                0 = {load_action = .CLEAR, clear_value = {r = 0.0, g = 0.0, b = 0.0, a = 1.0}},
            },
        },
        attachments = {colors = {0 = sg.make_view({color_attachment = {image = r.offscreen_img}})}},
    }

    // create the viewport display pipeline
    viewport_vertices := [4]VertexViewport{
        {-1, 1, 0, 0},
        {1, 1, 1, 0},
        {1, -1, 1, 1},
        {-1, -1, 0, 1},
    }
    viewport_indices := [6]u16{0, 1, 2, 0, 2, 3}

    r.viewport_vertex_buf = sg.make_buffer({
        data = {ptr = &viewport_vertices, size = size_of(viewport_vertices)},
        usage = {dynamic_update = true},
    })

    r.viewport_bind.vertex_buffers[0] = r.viewport_vertex_buf
    r.viewport_bind.index_buffer = sg.make_buffer({
        usage = {index_buffer = true},
        data = {ptr = &viewport_indices, size = size_of(viewport_indices)},
    })
    r.viewport_bind.views[VIEW_tex] = sg.make_view({texture = {image = r.offscreen_img}})
    r.viewport_bind.samplers[SMP_smp] = sg.make_sampler({
        min_filter = .NEAREST,
        mag_filter = .NEAREST,
    })

    r.viewport_pip = sg.make_pipeline({
        shader = sg.make_shader(viewport_shader_desc(backend)),
        index_type = .UINT16,
        layout = {
            attrs = {
                ATTR_viewport_position  = {format = .FLOAT2},
                ATTR_viewport_texcoord0 = {format = .FLOAT2},
            },
        },
    })

    // default pass action for the final display
    r.pass_action = {
        colors = {0 = {load_action = .CLEAR, clear_value = {r = 0.1, g = 0.1, b = 0.15, a = 1.0}}},
    }
}

// updates the viewport quad to maintain aspect ratio
renderer_update_viewport :: proc(r: ^Renderer) {
    win_w := sapp.widthf()
    win_h := sapp.heightf()
    virt_aspect := f32(r.virtual_width) / f32(r.virtual_height)
    win_aspect := win_w / win_h

    ndc_w, ndc_h: f32
    if virt_aspect > win_aspect {
        ndc_w = 2.0
        ndc_h = 2.0 * win_aspect / virt_aspect
    } else {
        ndc_h = 2.0
        ndc_w = 2.0 * virt_aspect / win_aspect
    }

    hw := ndc_w / 2.0
    hh := ndc_h / 2.0

    vertices := [?]VertexViewport{
        {-hw, hh, 0, 0},
        {hw, hh, 1, 0},
        {hw, -hh, 1, 1},
        {-hw, -hh, 0, 1},
    }
    sg.update_buffer(r.viewport_vertex_buf, {ptr = &vertices, size = size_of(vertices)})
}

// called at the start of each frame, sets up the offscreen pass
renderer_begin :: proc(r: ^Renderer) {
    sg.begin_pass(r.offscreen_pass)
    sg.apply_pipeline(r.pip)
    sg.apply_bindings(r.bind)
}

// called at the end of each frame, flushes the offscreen pass and composites to the window
renderer_end :: proc(r: ^Renderer) {
    sg.end_pass()

    // composite the offscreen texture to the screen
    sg.begin_pass({action = r.pass_action, swapchain = sglue.swapchain()})
    sg.apply_pipeline(r.viewport_pip)
    sg.apply_bindings(r.viewport_bind)
    sg.draw(0, 6, 1)
    sg.end_pass()

    sg.commit()
}

renderer_shutdown :: proc(r: ^Renderer) {
    sg.shutdown()
}