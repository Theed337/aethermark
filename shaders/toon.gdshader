shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_back;
// OPAK (schreibt Tiefe, kein ALPHA!). Für Transparenz gibt es toon_alpha.gdshader.
// Stilisiert-realistischer Look: weiche Licht-Umwicklung, feine Oberflächenvariation (Rauschen im Objektraum),
// Bodenverschattung, Rim-Licht, Treffer-Blitz, optionaler Wind für Laub und Vertex-Farbe.
uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 1.0, 0.9, 1.0);
uniform float rim : hint_range(0.0, 1.5) = 0.35;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy : hint_range(0.0, 8.0) = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float detail : hint_range(0.0, 0.6) = 0.16;
uniform float roughness : hint_range(0.0, 1.0) = 0.78;
uniform float wind : hint_range(0.0, 1.0) = 0.0;
uniform float wrap : hint_range(0.0, 1.0) = 0.3;

varying vec3 lpos;
varying float wy;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i + vec3(0, 0, 0)), hash3(i + vec3(1, 0, 0)), f.x),
				   mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x),
				   mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	lpos = VERTEX;
	vec3 wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wy = wpos.y;
	if (wind > 0.0) {
		float h = max(wy - MODEL_MATRIX[3].y, 0.0);
		float sway = sin(TIME * 1.3 + wpos.x * 0.35 + wpos.z * 0.27) * 0.5 + sin(TIME * 2.1 + wpos.z * 0.6) * 0.25;
		VERTEX.x += sway * wind * 0.045 * h;
		VERTEX.z += sway * wind * 0.03 * h;
	}
}

void fragment() {
	float n = vnoise(lpos * 3.2) * 0.65 + vnoise(lpos * 9.0) * 0.35;
	vec3 base = albedo.rgb * COLOR.rgb;
	base *= 1.0 + (n - 0.5) * 2.0 * detail;
	base *= mix(0.78, 1.0, smoothstep(0.0, 0.9, wy));
	ALBEDO = mix(base, vec3(1.0), flash);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = emission_color.rgb * emission_energy + rim_color.rgb * fres * rim + vec3(1.0, 0.9, 0.8) * flash * 0.9;
	ROUGHNESS = roughness;
	SPECULAR = 0.35;
}

void light() {
	float nl = dot(NORMAL, LIGHT);
	float d = clamp((nl + wrap) / (1.0 + wrap), 0.0, 1.0);
	d = d * d * (3.0 - 2.0 * d);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * d / PI;
	vec3 h = normalize(LIGHT + VIEW);
	float s = pow(max(dot(NORMAL, h), 0.0), mix(8.0, 64.0, 1.0 - ROUGHNESS)) * (1.0 - ROUGHNESS) * 0.6;
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * s * step(0.0, nl) / PI;
}
