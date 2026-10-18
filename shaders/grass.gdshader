shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
// Grasbüschel: Farbverlauf Wurzel -> Spitze, Windwiegen, Licht wie der Boden (Normale nach oben).
uniform float wind_strength = 1.0;
varying float h;

void vertex() {
	h = UV.y;
	vec3 wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float s = sin(TIME * 1.7 + wpos.x * 0.45 + wpos.z * 0.37) * 0.6 + sin(TIME * 2.9 + wpos.x * 0.9) * 0.25;
	VERTEX.x += s * h * h * 0.14 * wind_strength;
	VERTEX.z += s * h * h * 0.08 * wind_strength;
}

void fragment() {
	vec3 c = COLOR.rgb;
	ALBEDO = mix(c * 0.5, c * 1.2, h);
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ROUGHNESS = 1.0;
	// Spitzen leicht durchscheinend/abgerundet
	EMISSION = c * 0.12 * h;
}
