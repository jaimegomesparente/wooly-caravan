shader_type canvas_item;
render_mode blend_mul, unshaded;
// The night, laid over the world (`Night`): multiplies every color under it by what the night
// leaves of it (`night`), plus the lantern's light. The lantern is full in its core, then fades out
// to its edge in `levels` levels, dithered between them; the fade follows the exact (sub-pixel)
// center of the lantern, while the dithering pattern stays put on the world's pixels, so the light
// slides smoothly through a fixed pattern.

// Ordered dithering thresholds (4x4 Bayer matrix, 0-15), by (y % 4) * 4 + x % 4.
const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

// What the night leaves of each color.
uniform vec3 night = vec3(0.015, 0.015, 0.05);
uniform vec3 lantern = vec3(1.0, 0.82, 0.55);
uniform float energy = 1.0;
// The lantern's exact center, in world pixels.
uniform vec2 center = vec2(0.0);
uniform float radius = 112.0;
uniform float core = 0.2;
uniform float falloff = 1.5;
uniform float levels = 3.0;
uniform float band = 1.0;

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec2 pixel = floor(world);
	float distance_to_center = length(pixel + 0.5 - center) / radius;
	float fade = clamp((distance_to_center - core) / max(1.0 - core, 0.001), 0.0, 1.0);
	float level = pow(1.0 - smoothstep(0.0, 1.0, fade), falloff) * levels;
	float base = floor(level);
	float share = clamp((level - base - 0.5) / band + 0.5, 0.0, 1.0);
	ivec2 cell = ivec2(mod(pixel, 4.0));
	float threshold = (BAYER[cell.y * 4 + cell.x] + 0.5) / 16.0;
	float value = clamp((base + (share > threshold ? 1.0 : 0.0)) / levels, 0.0, 1.0);
	COLOR = vec4(min(night + lantern * energy * value, vec3(1.0)), 1.0);
}
