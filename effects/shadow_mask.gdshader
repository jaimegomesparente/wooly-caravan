shader_type canvas_item;
// Shadow shaped by a mask sprite (its color is ignored), cast over whatever is drawn below it: the
// ground, the characters, the trees. Shown smaller with the node's scale, it samples the mask once
// per game pixel of its drawn size, so a reduced shadow is still made of whole game pixels (no
// mixels), at any window scale.

// Size (px) of one frame of the mask sheet (frames side by side, in one row).
uniform vec2 frame_size = vec2(32.0, 48.0);
// Drawn size (px) of a frame: frame_size times the node's scale, set by the script per instance.
instance uniform vec2 size = vec2(32.0, 48.0);
// Color the shadow pulls toward, by its alpha (same as shadow.gdshader).
uniform vec4 shadow_color : source_color = vec4(0.04, 0.12, 0.05, 0.35);

void fragment() {
	vec2 sheet = vec2(textureSize(TEXTURE, 0));
	vec2 texel = UV * sheet;
	vec2 frame_origin = floor(texel / frame_size) * frame_size;
	vec2 local = (texel - frame_origin) / frame_size;
	// Center of the game pixel this fragment belongs to, back in the sheet.
	vec2 snapped = (floor(local * size) + 0.5) / size;
	if (texture(TEXTURE, (frame_origin + snapped * frame_size) / sheet).a < 0.5) {
		discard;
	}
	COLOR = shadow_color;
}
