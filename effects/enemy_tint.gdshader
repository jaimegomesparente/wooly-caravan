shader_type canvas_item;
// Enemy tints done in code: a flash toward white when hit, grey once beaten (out of health), and a
// muddy brown while slowed by mud.

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float grey : hint_range(0.0, 1.0) = 0.0;
uniform float mud : hint_range(0.0, 1.0) = 0.0;
uniform vec4 mud_color : source_color = vec4(0.357, 0.184, 0.102, 1.0);
// How much of the mud color covers the sprite at mud = 1.
uniform float mud_strength : hint_range(0.0, 1.0) = 0.45;

void fragment() {
	vec4 color = COLOR;
	float luminance = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	color.rgb = mix(color.rgb, vec3(luminance), grey);
	color.rgb = mix(color.rgb, mud_color.rgb, mud * mud_strength);
	color.rgb = mix(color.rgb, vec3(1.0), flash);
	COLOR = color;
}
