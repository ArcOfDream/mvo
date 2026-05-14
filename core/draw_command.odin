package core

DrawCommandType :: enum {
	Sprite,
	Rect,
	Clear,
}

DrawCommand :: struct {
	type:      DrawCommandType,
	// texture: TextureHandle
	transform: Transform2D,
	color:     u32,
	z_index:   f32,
}
