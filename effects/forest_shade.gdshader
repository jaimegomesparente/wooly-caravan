shader_type canvas_item;
render_mode blend_mul, unshaded;
// The forest's shade (`Forest`), laid over the forest and what stands in it: multiplies every color
// under it, darker the deeper the pixel is behind the front line. A pixel's depth is the deepest over
// the four sides (the front line recedes along each side by `recess`: one row per side, top, bottom,
// left, right, one texel per px along it). From `start` to `end` it goes through `levels` levels,
// from white (no change) to `darkest`, dithered from one to the next on the world's pixels.

#include "res://effects/dither.gdshaderinc"

uniform float start = -4.0;
uniform float end = 40.0;
uniform int levels = 5;
uniform vec3 darkest = vec3(0.3, 0.33, 0.42);
// How far (px) the front line stands inside the band where it does not recede.
uniform float overflow = 16.0;
uniform sampler2D recess : filter_nearest;
// Along (px) of the first texel of the top and bottom rows (the left and right rows start at 0).
uniform float along_origin = 0.0;
// Size (px) of the walkable band.
uniform vec2 band = vec2(1200.0, 300.0);

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

// Depth behind the front line of a pixel `out_px` px out from a side's wall, at texel `along` of
// its row of length `size` (past its ends, the recess at the end).
float side_depth(int row, float along, float size, float out_px) {
	int i = int(clamp(along, 0.0, size - 1.0));
	return out_px + overflow - texelFetch(recess, ivec2(i, row), 0).r;
}

void fragment() {
	vec2 pixel = floor(world);
	float across = float(textureSize(recess, 0).x);
	// Deepest behind the top or bottom line, and behind the left or right one.
	float vertical = max(side_depth(0, pixel.x - along_origin, across, -(pixel.y + 1.0)),
			side_depth(1, pixel.x - along_origin, across, pixel.y - band.y));
	float horizontal = max(side_depth(2, pixel.y, band.y, -(pixel.x + 1.0)),
			side_depth(3, pixel.y, band.y, pixel.x - band.x));
	// Behind both (a corner): as far as from a rounded corner, so the two sides meet without a crease.
	vec2 both = vec2(vertical, horizontal);
	float depth = length(max(both, vec2(0.0))) + min(max(both.x, both.y), 0.0);
	float steps = float(max(levels - 1, 1));
	float level = clamp((depth - start) / max(end - start, 0.001), 0.0, 1.0) * steps;
	float base = floor(level);
	float shown = min(base + (level - base > bayer_threshold(pixel) ? 1.0 : 0.0), steps);
	COLOR = vec4(mix(vec3(1.0), darkest, shown / steps), 1.0);
}
