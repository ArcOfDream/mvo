package render

Vertex :: struct {
	x, y, z, w: f32,
	color:      u32, // packed rgba as 0xRRGGBBAA
	u, v:       f32, // tex coords
}

VertexViewport :: struct {
	x, y: f32,
	u, v: f32,
}

// Returns a u32 with bytes laid out as [R, G, B, A] in memory
rgba :: proc(r, g, b, a: u8) -> u32 {
	return u32(r) | (u32(g) << 8) | (u32(b) << 16) | (u32(a) << 24)
}
