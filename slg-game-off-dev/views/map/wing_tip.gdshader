shader_type canvas_item;
render_mode unshaded;

uniform float flap;
uniform bool tip_on_left;

void fragment() {
	float span = tip_on_left ? 1.0 - UV.x : UV.x;
	float weight = smoothstep(0.29, 0.98, span);
	vec2 wing_point = UV + vec2(0.0, flap * weight);
	vec4 wing_color = texture(TEXTURE, wing_point);
	float inside = step(0.0, wing_point.y) * step(wing_point.y, 1.0);
	COLOR = vec4(wing_color.rgb, wing_color.a * inside);
}
