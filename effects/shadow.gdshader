shader_type canvas_item;
// Ground shadow: a solid pixel ellipse filling the rect drawn by Shadow. It darkens the screen as it
// was before the first shadow was drawn (Godot copies the screen once, at the first reader), so
// overlapping shadows never darken each other.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
// Size (px) of the rect, set by Shadow for each instance.
instance uniform vec2 size = vec2(10.0, 3.0);
// Color the ground is pulled toward, by its alpha.
uniform vec4 shadow_color : source_color = vec4(0.04, 0.12, 0.05, 0.35);

void fragment() {
	// Test the center of the game pixel, so the edge is a clean pixel staircase at any window scale.
	vec2 p = (floor(UV * size) + 0.5) / size * 2.0 - 1.0;
	if (dot(p, p) > 1.0) {
		discard;
	}
	vec3 ground = texture(screen_texture, SCREEN_UV).rgb;
	COLOR = vec4(mix(ground, shadow_color.rgb, shadow_color.a), 1.0);
}
