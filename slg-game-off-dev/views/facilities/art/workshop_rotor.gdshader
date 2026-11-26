shader_type canvas_item;
render_mode unshaded;

uniform float phase = 0.0;
varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	// The rotor face is a disk viewed obliquely, behind the fixed shaft and casing.
	const vec2 axle = vec2(133.0, 42.5);
	const mat2 projection = mat2(vec2(14.0, 4.5), vec2(-4.5, 22.0));
	vec2 face = inverse(projection) * (local_position - axle);
	float radius = length(face);
	float angle = atan(face.y, face.x);
	float blade = pow(max(0.0, cos(8.0 * (angle - phase + radius * 0.27))), 2.0);
	float rim = smoothstep(0.76, 0.84, radius) * (1.0 - smoothstep(0.91, 1.0, radius));
	float shine = 0.47 + 0.34 * dot(normalize(face + vec2(0.0001)), vec2(-0.6, -0.8));
	vec3 bronze = mix(vec3(0.23, 0.134, 0.077), vec3(0.82, 0.59, 0.27), (blade + rim * 0.25) * shine);
	float opacity = 0.87 * (1.0 - smoothstep(0.89, 1.0, radius));
	COLOR = vec4(bronze, opacity);
}
