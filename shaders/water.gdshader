shader_type spatial;
render_mode specular_disabled;
uniform vec4 shallow : source_color = vec4(0.2, 0.75, 0.8, 0.75);
uniform vec4 deep : source_color = vec4(0.05, 0.3, 0.45, 0.9);
void fragment() {
	float w = sin(UV.x * 40.0 + TIME * 1.6) * 0.5 + sin(UV.y * 33.0 - TIME * 1.1) * 0.5;
	vec4 c = mix(deep, shallow, 0.5 + 0.5 * w);
	ALBEDO = c.rgb;
	ALPHA = c.a;
	EMISSION = c.rgb * 0.25 + vec3(0.6, 0.9, 1.0) * pow(max(w, 0.0), 6.0) * 0.4;
	ROUGHNESS = 0.2;
}
