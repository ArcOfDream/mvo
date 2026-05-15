package resource

import c "../core"
import sg "../lib/sokol/gfx"
import "core:image"
import "core:os"

ResourceManager :: struct {
	textures: TexturePool,
}

manager_init :: proc(rm: ^ResourceManager, allocator := context.allocator) {
	texture_pool_init(&rm.textures, allocator)
}

manager_destroy :: proc(rm: ^ResourceManager) {
	texture_pool_destroy(&rm.textures)
}

// texture wrappers

manager_texture_insert :: proc(
	rm: ^ResourceManager,
	image: sg.Image,
	width, height: i32,
	path: string,
	name: string = "",
) -> c.TextureHandle {
	return texture_pool_insert(&rm.textures, image, width, height, path, name)
}

manager_get_texture :: proc(rm: ^ResourceManager, handle: c.TextureHandle) -> ^TextureEntry {
	return texture_pool_get(&rm.textures, handle)
}

manager_find_texture :: proc(rm: ^ResourceManager, name: string) -> ^TextureEntry {
	return texture_pool_find_by_name(&rm.textures, name)
}

manager_texture_free :: proc(rm: ^ResourceManager, handle: c.TextureHandle) -> bool {
	return texture_pool_free(&rm.textures, handle)
}

// loads a texture from a file on disk
manager_load_texture_from_file :: proc(
	rm: ^ResourceManager,
	path: string,
	name: string = "",
) -> (
	c.TextureHandle,
	bool,
) {
	data, err := os.read_entire_file_from_path(path, context.allocator)
	if err != nil {
		return c.INVALID_TEXTURE, false
	}
	defer delete(data)
	return manager_load_texture_from_memory(rm, data, path, name)
}

// loads a texture from raw bytes (PNG, JPG, etc.)
manager_load_texture_from_memory :: proc(
	rm: ^ResourceManager,
	data: []u8,
	debug_path: string = "memory",
	name: string = "",
) -> (
	c.TextureHandle,
	bool,
) {
	img, err := image.load_from_bytes(data)
	if err != nil {
		return c.INVALID_TEXTURE, false
	}
	defer image.destroy(img)

	// ensure RGBA
	if img.channels == 3 {
		image.alpha_add_if_missing(img)
	}

	// pack into u32 RGBA (0xRRGGBBAA)
	pixels := make([]u32, img.width * img.height)
	defer delete(pixels)

	pixel_data := img.pixels.buf[:]
	channels := img.channels
	for i in 0 ..< img.width * img.height {
		offset := i * channels
		r := pixel_data[offset + 0]
		g := pixel_data[offset + 1]
		b := pixel_data[offset + 2]
		a: u8 = 255
		if channels >= 4 {
			a = pixel_data[offset + 3]
		}
		pixels[i] = u32(r) | (u32(g) << 8) | (u32(b) << 16) | (u32(a) << 24)
	}

	// upload to GPU
	gpu_image := sg.make_image(
		{
			width = i32(img.width),
			height = i32(img.height),
			pixel_format = .RGBA8,
			data = {
				mip_levels = {0 = {ptr = raw_data(pixels[:]), size = len(pixels) * size_of(u32)}},
			},
		},
	)

	// insert into pool
	handle := texture_pool_insert(
		&rm.textures,
		gpu_image,
		i32(img.width),
		i32(img.height),
		debug_path,
		name,
	)

	return handle, true
}

// thin wrappers for update/replace operations

manager_texture_update_pixels :: proc(
	rm: ^ResourceManager,
	handle: c.TextureHandle,
	pixels: []u32,
	width, height: i32,
) -> bool {
	return texture_pool_update_pixels(&rm.textures, handle, pixels, width, height)
}

manager_texture_replace_image :: proc(
	rm: ^ResourceManager,
	handle: c.TextureHandle,
	pixels: []u32,
	width, height: i32,
) -> bool {
	return texture_pool_replace_image(&rm.textures, handle, pixels, width, height)
}
