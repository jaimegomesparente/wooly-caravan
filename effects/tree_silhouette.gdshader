shader_type canvas_item;
// Every tree of the forest (`Forest`): where it covers a body standing behind it (the body's feet
// higher up than the tree's foot, so the tree is drawn in front), one pixel out of two (a checker
// fixed on the world's pixels) takes the color of the body's silhouette, so a body hidden by a tree
// is still seen. The bodies come from the forest's mask view (`BodyMask`): at each pixel of the
// screen, the height of the feet of the front-most body there (R high byte, G low byte, in quarter
// pixels from FEET_ORIGIN) and its camp (B: 0 friend, 1 enemy).

uniform sampler2D body_mask : filter_nearest;
uniform vec4 friend_color : source_color = vec4(0.953, 0.91, 0.784, 1.0);
uniform vec4 enemy_color : source_color = vec4(0.753, 0.141, 0.173, 1.0);

// As in `BodyMask`.
const float FEET_ORIGIN = 1024.0;

varying float foot_y;
varying vec2 world;

void vertex() {
	// A tree stands at its foot.
	foot_y = MODEL_MATRIX[3].y;
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	if (COLOR.a > 0.5) {
		vec4 body = texture(body_mask, SCREEN_UV);
		if (body.a > 0.5) {
			float feet = (round(body.r * 255.0) * 256.0 + round(body.g * 255.0)) / 4.0 - FEET_ORIGIN;
			ivec2 pixel = ivec2(floor(world));
			if (feet < foot_y && (pixel.x + pixel.y) % 2 == 0) {
				COLOR.rgb = body.b > 0.5 ? enemy_color.rgb : friend_color.rgb;
			}
		}
	}
}
