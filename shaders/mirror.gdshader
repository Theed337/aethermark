shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D refl : source_color, filter_linear;
uniform vec4 tint : source_color = vec4(0.82, 0.95, 1.0, 1.0);
void fragment() {
	vec2 uv = vec2(1.0 - UV.x, UV.y);
	vec3 c = texture(refl, uv).rgb * tint.rgb;
	float edge = smoothstep(0.0, 0.06, min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y)));
	ALBEDO = mix(vec3(0.55, 0.8, 0.85), c, edge * 0.97 + 0.03);
}
