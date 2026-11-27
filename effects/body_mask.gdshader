shader_type canvas_item;
render_mode unshaded, blend_disabled;
// A body's mask (`BodyMask`), drawn only in the forest's mask view: where its sprite is opaque, writes
// as is the code its color carries (the height of its feet and its camp), for the trees
// (`tree_silhouette.gdshader`) to read.

varying vec4 code;

void vertex() {
	code = COLOR;
}

void fragment() {
	if (texture(TEXTURE, UV).a < 0.5) {
		discard;
	}
	COLOR = vec4(code.rgb, 1.0);
}
