shader_type spatial;
render_mode diffuse_toon, specular_disabled, cull_back;
// Stilisierter Cel-Look mit Rim-Licht, Treffer-Blitz und optionaler Vertex-Farbe (Gelände, Laub).
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 0.9, 1.0);
uniform float rim : hint_range(0.0, 1.5) = 0.35;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy : hint_range(0.0, 8.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec3 base = albedo.rgb * COLOR.rgb;
	ALBEDO = mix(base, vec3(1.0), flash);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = emission_color.rgb * emission_energy + rim_color.rgb * fres * rim + vec3(1.0, 0.9, 0.8) * flash * 0.9;
	ROUGHNESS = 1.0;
	ALPHA = alpha * albedo.a;
}
