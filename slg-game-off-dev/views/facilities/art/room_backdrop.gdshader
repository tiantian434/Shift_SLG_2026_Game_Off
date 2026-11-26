shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec2 offset = (UV - vec2(0.5, 0.51)) * vec2(1.35, 0.94);
	float light = 1.0 - smoothstep(0.04, 0.82, length(offset));
	COLOR.rgb = mix(COLOR.rgb * 0.55, COLOR.rgb * 1.43, light);
}
