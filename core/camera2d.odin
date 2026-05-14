package core

import m "core:math/linalg/glsl"

Camera2D :: struct {
	viewport: Rect2,
	position: m.vec2,
	rotation: f32,
	zoom: f32,
}

camera_projection :: proc(c: Camera2D) -> m.mat4 {
    // half the viewport, scaled by zoom
    hw := (c.viewport.w / 2) / c.zoom
    hh := (c.viewport.h / 2) / c.zoom

    // pixel space centered on camera position
    left   := c.position.x - hw
    right  := c.position.x + hw
    bottom := c.position.y + hh    // Y-down screen space
    top    := c.position.y - hh

    return m.mat4Ortho3d(left, right, bottom, top, -1, 1)
}

camera_view_matrix :: proc(c: Camera2D) -> m.mat4 {
    return m.mat4Scale({c.zoom, c.zoom, 1}) *
           m.mat4Rotate({0, 0, 1}, -c.rotation) *
           m.mat4Translate({-c.position.x, -c.position.y, 0})
}