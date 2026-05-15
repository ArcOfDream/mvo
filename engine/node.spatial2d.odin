package engine

import c "../core"
import m "core:math/linalg/glsl"

Spatial2D :: struct {
	using base: Node,
}

_spatial2d_vtable := NodeVTable {
	init      = spatial2d_init,
	ready     = spatial2d_ready,
	update    = spatial2d_update,
	draw      = spatial2d_draw,
	exit_tree = spatial2d_exit_tree,
}

spatial2d_new :: proc(name: string) -> ^Spatial2D {
	s := new(Spatial2D)
	s.vtable = &_spatial2d_vtable
	s.name = name
	s.transform = c.transform_default()
	s.global_transform = c.transform_default()
	s.visible = true
	s.process_flags = {.update, .draw}
	return s
}

spatial2d_vtable :: proc() -> ^NodeVTable {
	vt := node_vtable()
	vt.init = spatial2d_init
	vt.ready = spatial2d_ready
	vt.update = spatial2d_update
	vt.draw = spatial2d_draw
	vt.exit_tree = spatial2d_exit_tree
	return vt
}

// overridable callbacks

spatial2d_init :: proc(self: rawptr) {}
spatial2d_ready :: proc(self: rawptr) {}
spatial2d_update :: proc(self: rawptr, dt: f32) {}
spatial2d_draw :: proc(self: rawptr, cmd_buf: rawptr) {}
spatial2d_exit_tree :: proc(self: rawptr) {}

// public "internal" draw that subtypes can call

spatial2d_draw_internal :: proc(s: ^Spatial2D, ctx: ^SpriteDrawContext) {
	// base spatial doesn't draw anything
}

// position

set_pos :: proc(s: ^Spatial2D, pos: m.vec2) {
	c.transform_set_position(&s.transform, pos)
}

get_pos :: proc(s: ^Spatial2D) -> m.vec2 {
	return s.transform.position
}

get_global_pos :: proc(s: ^Spatial2D) -> m.vec2 {
	return s.global_transform.position
}

// rotation

set_rot :: proc(s: ^Spatial2D, radians: f32) {
	c.transform_set_rotation(&s.transform, radians)
}

get_rot :: proc(s: ^Spatial2D) -> f32 {
	return s.transform.rotation
}

set_rot_deg :: proc(s: ^Spatial2D, deg: f32) {
	c.transform_set_rotation_deg(&s.transform, deg)
}

get_rot_deg :: proc(s: ^Spatial2D) -> f32 {
	return c.transform_get_rotation_deg(&s.transform)
}

rotate :: proc(s: ^Spatial2D, radians: f32) {
	c.transform_set_rotation(&s.transform, s.transform.rotation + radians)
}

// scale

set_scale :: proc(s: ^Spatial2D, scale: m.vec2) {
	c.transform_set_scale(&s.transform, scale)
}

get_scale :: proc(s: ^Spatial2D) -> m.vec2 {
	return s.transform.scale
}

set_scale_uniform :: proc(s: ^Spatial2D, scl: f32) {
	c.transform_set_scale(&s.transform, {scl, scl})
}

apply_scale :: proc(s: ^Spatial2D, ratio: m.vec2) {
	c.transform_set_scale(&s.transform, s.transform.scale * ratio)
}

// movement

translate :: proc(s: ^Spatial2D, offset: m.vec2) {
	s.transform.position += offset
	s.transform._dirty = true
}

global_translate :: proc(s: ^Spatial2D, offset: m.vec2) {
	s.global_transform.position += offset
	s.global_transform._dirty = true
	// decompose back to local
	if s.parent != nil {
		inv_parent := m.inverse(c.transform_matrix(&s.parent.global_transform))
		local_pos :=
			inv_parent * m.vec4{s.global_transform.position.x, s.global_transform.position.y, 0, 1}
		s.transform.position = local_pos.xy
	} else {
		s.transform.position = s.global_transform.position
	}
	s.transform._dirty = true
}

move_x :: proc(s: ^Spatial2D, delta: f32, scaled := false) {
	rot := s.global_transform.rotation
	dir := m.vec2{m.cos(rot), m.sin(rot)}
	if !scaled {
		s.transform.position += dir * delta
	} else {
		s.transform.position.x += delta
	}
	s.transform._dirty = true
}

move_y :: proc(s: ^Spatial2D, delta: f32, scaled := false) {
	rot := s.global_transform.rotation
	dir := m.vec2{-m.sin(rot), m.cos(rot)}
	if !scaled {
		s.transform.position += dir * delta
	} else {
		s.transform.position.y += delta
	}
	s.transform._dirty = true
}

// direction

look_at :: proc(s: ^Spatial2D, target: m.vec2) {
	direction := target - s.transform.position
	s.transform.rotation = m.atan2(direction.y, direction.x)
	s.transform._dirty = true
}

angle_to :: proc(s: ^Spatial2D, point: m.vec2) -> f32 {
	direction := point - s.global_transform.position
	return m.atan2(direction.y, direction.x)
}

// coordinate conversion

// converts a point from this node's local space to global (world) space
to_global :: proc(s: ^Spatial2D, local_point: m.vec2) -> m.vec2 {
	mat := c.transform_matrix(&s.global_transform)
	world_pos := mat * m.vec4{local_point.x, local_point.y, 0, 1}
	return world_pos.xy
}

// converts a point from global (world) space to this node's local space
to_local :: proc(s: ^Spatial2D, global_point: m.vec2) -> m.vec2 {
	mat := m.inverse(c.transform_matrix(&s.global_transform))
	local_pos := mat * m.vec4{global_point.x, global_point.y, 0, 1}
	return local_pos.xy
}

// matrix

get_global_matrix :: proc(s: ^Spatial2D) -> m.mat4 {
	return s.global_transform._matrix
}
