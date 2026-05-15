package resource

import c "../core"
import sg "../lib/sokol/gfx"

// a single entry in the texture pool
TextureEntry :: struct {
	handle: c.TextureHandle,
	image:  sg.Image,
	width:  i32,
	height: i32,
	path:   string, // file path, for reloading or debug display
}

// a pool of textures with handle-based access
TexturePool :: struct {
	entries:     [dynamic]TextureEntry,
	free_slots:  [dynamic]u32,
	generations: [dynamic]u32,
	name_map:    map[string]c.TextureHandle,
}

// initializes an empty texture pool
texture_pool_init :: proc(pool: ^TexturePool, allocator := context.allocator) {
	pool.entries = make([dynamic]TextureEntry, allocator)
	pool.free_slots = make([dynamic]u32, allocator)
	pool.generations = make([dynamic]u32, allocator)
	pool.name_map = make(map[string]c.TextureHandle, allocator)
}

// destroys all GPU images and releases memory
texture_pool_destroy :: proc(pool: ^TexturePool) {
	for entry in pool.entries {
		sg.destroy_image(entry.image)
		delete(entry.path)
	}
	delete(pool.entries)
	delete(pool.free_slots)
	delete(pool.generations)
	delete(pool.name_map)
}

// inserts a texture and returns a handle
texture_pool_insert :: proc(
	pool: ^TexturePool,
	image: sg.Image,
	width, height: i32,
	path: string,
	name: string = "",
) -> c.TextureHandle {
	entry := TextureEntry {
		image  = image,
		width  = width,
		height = height,
		path   = path,
	}

	index: u32
	if len(pool.free_slots) > 0 {
		index = pop(&pool.free_slots)
		pool.generations[index] += 1
		entry.handle = c.make_texture_handle(index, pool.generations[index])
		pool.entries[index] = entry
	} else {
		index = u32(len(pool.entries))
		entry.handle = c.make_texture_handle(index, 0)
		append(&pool.entries, entry)
		append(&pool.generations, 0)
	}

	if name != "" {
		pool.name_map[name] = entry.handle
	}

	return entry.handle
}

// returns a pointer to the entry, or nil if the handle is invalid
texture_pool_get :: proc(pool: ^TexturePool, handle: c.TextureHandle) -> ^TextureEntry {
	index := c.handle_index(handle)
	gen := c.handle_generation(handle)

	if index >= u32(len(pool.entries)) {
		return nil
	}
	if pool.generations[index] != gen {
		return nil
	}

	return &pool.entries[index]
}

// finds a texture by its string name
texture_pool_find_by_name :: proc(pool: ^TexturePool, name: string) -> ^TextureEntry {
	handle, found := pool.name_map[name]
	if !found {
		return nil
	}
	return texture_pool_get(pool, handle)
}

// updates the pixel data of an existing texture
// returns false if the handle is invalid or sizes don't match
texture_pool_update_pixels :: proc(
	pool: ^TexturePool,
	handle: c.TextureHandle,
	pixels: []u32,
	width, height: i32,
) -> bool {
	entry := texture_pool_get(pool, handle)
	if entry == nil {
		return false
	}
	if entry.width != width || entry.height != height {
		return false
	}

	sg.update_image(
		entry.image,
		{mip_levels = {0 = {ptr = raw_data(pixels), size = len(pixels) * size_of(u32)}}},
	)

	return true
}

// replaces the GPU image for a texture with new data
// returns false if the handle is invalid
texture_pool_replace_image :: proc(
	pool: ^TexturePool,
	handle: c.TextureHandle,
	pixels: []u32,
	width, height: i32,
) -> bool {
	entry := texture_pool_get(pool, handle)
	if entry == nil {
		return false
	}

	sg.destroy_image(entry.image)

	entry.image = sg.make_image(
		{
			width = width,
			height = height,
			pixel_format = .RGBA8,
			data = {
				mip_levels = {0 = {ptr = raw_data(pixels), size = len(pixels) * size_of(u32)}},
			},
		},
	)

	entry.width = width
	entry.height = height

	return true
}

// frees a single texture immediately
texture_pool_free :: proc(pool: ^TexturePool, handle: c.TextureHandle) -> bool {
	entry := texture_pool_get(pool, handle)
	if entry == nil {
		return false
	}

	sg.destroy_image(entry.image)
	delete(entry.path)

	index := c.handle_index(handle)
	append(&pool.free_slots, index)

	for name, h in pool.name_map {
		if h == handle {
			delete_key(&pool.name_map, name)
			break
		}
	}

	return true
}
