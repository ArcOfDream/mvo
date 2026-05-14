package engine

import "core:math/linalg/glsl"

Camera2D :: struct {
	position: glsl.vec2,
	zoom:     f32,
	width:    f32,
	height:   f32,
}

camera_vp_matrix :: proc(cam: Camera2D) -> glsl.mat4 {
	half_w := cam.width / (2.0 * cam.zoom)
	half_h := cam.height / (2.0 * cam.zoom)

	return glsl.mat4Ortho3d(
		cam.position.x - half_w,
		cam.position.x + half_w,
		cam.position.y + half_h,
		cam.position.y - half_h,
		-1.0,
		1.0,
	)
}
