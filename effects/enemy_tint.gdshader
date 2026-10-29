shader_type canvas_item;
// Enemy tints done in code: a flash toward white when hit, grey once beaten (out of health).

uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float grey : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 color = COLOR;
	float luminance = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	color.rgb = mix(color.rgb, vec3(luminance), grey);
	color.rgb = mix(color.rgb, vec3(1.0), flash);
	COLOR = color;
}
