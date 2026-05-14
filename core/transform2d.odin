package core

import m "core:math/linalg/glsl"

Transform2D :: struct {
	position: m.vec2,
	scale:    m.vec2,
	rotation: f32,
	_dirty:   bool,
	_matrix:  m.mat4,
}

transform_default :: proc() -> Transform2D {
	return {scale = {1, 1}, _matrix = 1}
}

transform_make :: proc(pos: m.vec2, scale: m.vec2 = {1, 1}, rot: f32 = 0) -> Transform2D {
	return {position = pos, scale = scale, rotation = rot, _dirty = true}
}

// setters
transform_set_position :: proc(t: ^Transform2D, v: m.vec2) {
	t.position = v
	t._dirty = true
}

transform_set_scale :: proc(t: ^Transform2D, v: m.vec2) {
	t.scale = v
	t._dirty = true
}

transform_set_rotation :: proc(t: ^Transform2D, r: f32) {
	t.rotation = r
	t._dirty = true
}

// helpers for angle in degrees
transform_set_rotation_deg :: proc(t: ^Transform2D, deg: f32) {
	t.rotation = deg * (m.PI / 180.0)
	t._dirty = true
}

transform_get_rotation_deg :: proc(t: ^Transform2D) -> f32 {
	return t.rotation * (180.0 / m.PI)
}

// lazy matrix
transform_matrix :: proc(t: ^Transform2D) -> m.mat4 {
	if t._dirty {
		t._matrix =
			m.mat4Translate({t.position.x, t.position.y, 0}) *
			m.mat4Rotate({0, 0, 1}, t.rotation) *
			m.mat4Scale({t.scale.x, t.scale.y, 1})
		t._dirty = false
	}
	return t._matrix
}

// decompose
transform_decompose :: proc(mat: m.mat4) -> Transform2D {
	// translation is column 3, rows 0..1
	pos := mat[3].xy

	// scale = length of column vectors before rotation
	sx := m.length(mat[0].xyz)
	sy := m.length(mat[1].xyz)

	// rotation from normalized first column
	rot: f32
	if sx > 0 {
		rot = m.atan2(mat[0].y / sx, mat[0].x / sx)
	}

	return Transform2D{position = pos, scale = {sx, sy}, rotation = rot, _matrix = mat}
}

// compose

transform_compose :: proc(parent, child: ^Transform2D) -> Transform2D {
	mat := transform_matrix(parent) * transform_matrix(child)
	return transform_decompose(mat)
}
