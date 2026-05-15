package engine

import c "../core"
import r "../render"
import res "../resource"
import m "core:math/linalg/glsl"

SpriteDrawContext :: struct {
	renderer:  ^r.Renderer,
	resources: ^res.ResourceManager,
}

Sprite :: struct {
	using spatial: Spatial2D,
	texture:       c.TextureHandle, // Was sg.Image
	size:          m.vec2,
	color:         u32,
}

_sprite_vtable := NodeVTable {
	init      = spatial2d_init,
	ready     = spatial2d_ready,
	update    = spatial2d_update,
	draw      = sprite_draw,
	exit_tree = spatial2d_exit_tree,
}

sprite_new :: proc(name: string, texture: c.TextureHandle, size: m.vec2) -> ^Sprite {
	s := new(Sprite)
	s.vtable = &_sprite_vtable
	s.name = name
	s.transform = c.transform_make({0, 0}, size, 0)
	s.global_transform = c.transform_default()
	s.texture = texture
	s.size = size
	s.color = 0xFFFFFFFF
	s.visible = true
	s.process_flags = {.update, .draw}
	return s
}

sprite_vtable :: proc() -> ^NodeVTable {
	vt := spatial2d_vtable()
	vt.draw = sprite_draw
	return vt
}

// overridable callbacks

sprite_draw :: proc(self: rawptr, cmd_buf: rawptr) {
	sprite := cast(^Sprite)self
	// cmd_buf now carries a ^SpriteDrawContext instead of ^r.Renderer
	ctx := cast(^SpriteDrawContext)cmd_buf
	sprite_draw_internal(sprite, ctx)
}

// public "internal" draw that subtypes can call

sprite_draw_internal :: proc(s: ^Sprite, ctx: ^SpriteDrawContext) {
	entry := res.manager_get_texture(ctx.resources, s.texture)
	if entry == nil {
		return // Texture not loaded or freed, skip drawing
	}
	r.renderer_draw_sprite(ctx.renderer, entry.image, &s.global_transform, s.color)
}

// texture

set_tex :: proc(s: ^Sprite, texture: c.TextureHandle) {
	s.texture = texture
}

get_tex :: proc(s: ^Sprite) -> c.TextureHandle {
	return s.texture
}

// size

get_size :: proc(s: ^Sprite) -> m.vec2 {
	return s.size
}

set_size :: proc(s: ^Sprite, size: m.vec2) {
	s.size = size
	set_scale(s, size)
}

get_width :: proc(s: ^Sprite) -> f32 {
	return s.size.x
}

get_height :: proc(s: ^Sprite) -> f32 {
	return s.size.y
}

// color

set_color :: proc(s: ^Sprite, color: u32) {
	s.color = color
}

get_color :: proc(s: ^Sprite) -> u32 {
	return s.color
}

set_alpha :: proc(s: ^Sprite, alpha: u8) {
	s.color = (s.color & 0x00FFFFFF) | (u32(alpha) << 24)
}

get_alpha :: proc(s: ^Sprite) -> u8 {
	return u8(s.color >> 24)
}
