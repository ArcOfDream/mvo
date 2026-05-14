package core

import m "core:math/linalg/glsl"

Rect2 :: struct {
	x, y, w, h: f32,
}

// constructors
rect_make :: proc(x, y, w, h: f32) -> Rect2 {
	return {x, y, w, h}
}

rect_from_vec2 :: proc(min, max: m.vec2) -> Rect2 {
	return {min.x, min.y, max.x - min.x, max.y - min.y}
}

// derived edges
rect_right :: proc(r: Rect2) -> f32 {return r.x + r.w}
rect_bottom :: proc(r: Rect2) -> f32 {return r.y + r.h}
rect_center :: proc(r: Rect2) -> m.vec2 {return {r.x + r.w * 0.5, r.y + r.h * 0.5}}

// queries
rect_contains_point :: proc(r: Rect2, p: m.vec2) -> bool {
	return p.x >= r.x && p.x < r.x + r.w && p.y >= r.y && p.y < r.y + r.h
}
rect_contains_rect :: proc(r, other: Rect2) -> bool {
	return(
		other.x >= r.x &&
		rect_right(other) <= rect_right(r) &&
		other.y >= r.y &&
		rect_bottom(other) <= rect_bottom(r) \
	)
}
rect_overlaps :: proc(r, other: Rect2) -> bool {
	return(
		r.x < rect_right(other) &&
		rect_right(r) > other.x &&
		r.y < rect_bottom(other) &&
		rect_bottom(r) > other.y \
	)
}

// mutations
rect_union :: proc(r, other: Rect2) -> Rect2 {
	x := min(r.x, other.x)
	y := min(r.y, other.y)
	return Rect2 {
		x = x,
		y = y,
		w = max(rect_right(r), rect_right(other)) - x,
		h = max(rect_bottom(r), rect_bottom(other)) - y,
	}
}

rect_intersection :: proc(r, other: Rect2) -> (Rect2, bool) {
	x := max(r.x, other.x)
	y := max(r.y, other.y)
	w := min(rect_right(r), rect_right(other)) - x
	h := min(rect_bottom(r), rect_bottom(other)) - y
	if w > 0 && h > 0 {
		return Rect2{x, y, w, h}, true
	}
	return Rect2{}, false
}

rect_grow :: proc(r: Rect2, amount: f32) -> Rect2 {
	return Rect2{x = r.x - amount, y = r.y - amount, w = r.w + amount * 2, h = r.h + amount * 2}
}
