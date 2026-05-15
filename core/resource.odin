package core

// a texture handle packs a slot index (lower 32 bits) and a generation
// counter (upper 32 bits) into a u64
TextureHandle :: distinct u64

INVALID_TEXTURE :: TextureHandle(0)

// construction from parts
make_texture_handle :: proc(index, generation: u32) -> TextureHandle {
    return TextureHandle((u64(generation) << 32) | u64(index))
}

// extracts the slot index from a handle
handle_index :: proc(h: TextureHandle) -> u32 {
    return u32(h & 0xFFFFFFFF)
}

// extracts the generation counter from a handle
handle_generation :: proc(h: TextureHandle) -> u32 {
    return u32(h >> 32)
}