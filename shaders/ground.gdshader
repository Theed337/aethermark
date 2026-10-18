shader_type spatial;
render_mode diffuse_burley, specular_disabled;
// Gelände: alle Zonen (Flecken, Weg, Lichtung, Bossarena, Teichufer) werden hier berechnet, nicht aus
// übereinanderliegenden Scheiben gebaut -> kein Z-Fighting, beliebig scharf, kein Speicher für Texturen.
uniform vec3 c_ground : source_color = vec3(0.29, 0.6, 0.3);
uniform vec3 c_p1 : source_color = vec3(0.25, 0.56, 0.29);
uniform vec3 c_p2 : source_color = vec3(0.36, 0.7, 0.35);
uniform vec3 c_path : source_color = vec3(0.79, 0.67, 0.45);
uniform vec3 c_clear : source_color = vec3(0.85, 0.76, 0.53);
uniform vec3 c_arena : source_color = vec3(0.6, 0.6, 0.5);
uniform vec3 c_inner : source_color = vec3(0.48, 0.6, 0.38);
uniform vec2 spawn = vec2(0.0, 18.0);
uniform vec2 boss = vec2(0.0, -36.0);
uniform vec2 pond = vec2(24.0, 8.0);
uniform float pond_r = 8.0;
uniform float arena_r = 15.0;
uniform float clear_r = 7.0;
uniform vec2 path_pts[14];
uniform sampler2D t_grass : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D t_grass_h : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D t_dirt : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D t_dirt_h : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D t_rock : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D t_rock_h : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform vec3 n_grass = vec3(1.0);
uniform vec3 n_dirt = vec3(1.0);
uniform vec3 n_rock = vec3(1.0);
uniform float tex_on = 1.0;

varying vec3 wp;

float h2(vec2 p) {
	p = fract(p * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.x);
}
float n2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h2(i), h2(i + vec2(1, 0)), f.x), mix(h2(i + vec2(0, 1)), h2(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	return n2(p) * 0.5 + n2(p * 2.03) * 0.25 + n2(p * 4.1) * 0.125 + n2(p * 8.3) * 0.0625;
}
float seg_dist(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float t = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * t);
}

float hmix(vec2 p, float pm, float am, float joint) {
	float hg = texture(t_grass_h, p * 0.45).r * 0.6 + texture(t_grass_h, p * 0.113 + 0.37).r * 0.4;
	float hd = texture(t_dirt_h, p * 0.5).r;
	float hr = texture(t_rock_h, p * 0.35).r * (1.0 - joint);
	return mix(mix(hg, hd, pm), hr, am);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wp.xz;
	float big = fbm(p * 0.07);
	float mid = fbm(p * 0.28 + 11.0);
	vec3 col = mix(c_ground, mix(c_p1, c_p2, mid), smoothstep(0.38, 0.62, big));
	// feine Grasstruktur (echte Textur, zwei Maßstäbe gegen sichtbare Wiederholung)
	float fine = n2(p * 5.0) * 0.6 + n2(p * 17.0) * 0.4;
	col *= 0.9 + fine * 0.2;
	vec3 gt = texture(t_grass, p * 0.45).rgb * n_grass * 0.6 + texture(t_grass, p * 0.113 + 0.37).rgb * n_grass * 0.4;
	col *= mix(vec3(1.0), gt, tex_on);

	// Weg
	float d = 1e5;
	for (int i = 0; i < 13; i++) {
		d = min(d, seg_dist(p, path_pts[i], path_pts[i + 1]));
	}
	float wob = (fbm(p * 0.9) - 0.5) * 0.9;
	float pm = 1.0 - smoothstep(1.7, 2.3, d + wob);
	vec3 pc = c_path * (0.88 + n2(p * 7.0) * 0.24);
	pc *= mix(vec3(1.0), texture(t_dirt, p * 0.5).rgb * n_dirt, tex_on);
	col = mix(col, pc, pm);
	// Wegrand: dunkler Saum
	col *= 1.0 - 0.12 * smoothstep(1.4, 2.0, d + wob) * (1.0 - smoothstep(2.0, 2.7, d + wob));
	// Startlichtung
	float dc = length(p - spawn) + wob * 0.6;
	float cm = 1.0 - smoothstep(clear_r - 0.7, clear_r + 0.2, dc);
	col = mix(col, c_clear * (0.9 + n2(p * 6.0) * 0.2), cm);
	// Teichufer: feuchter, dunkler Rand
	float dp = length(p - pond);
	float mud = (1.0 - smoothstep(pond_r - 0.5, pond_r + 1.6, dp + wob)) * 0.55;
	col = mix(col, col * vec3(0.55, 0.5, 0.42), mud);
	// Bossarena: Steinplatten mit Fugen
	float db = length(p - boss);
	float am = 1.0 - smoothstep(arena_r - 0.25, arena_r + 0.1, db);
	vec2 tg = abs(fract(p * 0.42) - 0.5);
	float joint = smoothstep(0.455, 0.485, max(tg.x, tg.y));
	vec3 stone = c_arena * (0.86 + n2(floor(p * 0.42) * 3.7) * 0.28) * (0.94 + n2(p * 9.0) * 0.12);
	stone *= mix(vec3(1.0), texture(t_rock, p * 0.35).rgb * n_rock, tex_on * 0.8);
	stone *= 1.0 - joint * 0.35;
	float inner = 1.0 - smoothstep(arena_r - 2.6, arena_r - 2.3, db);
	stone = mix(stone, c_inner * (0.86 + n2(floor(p * 0.42) * 5.1) * 0.28) * (1.0 - joint * 0.3), inner);
	float ring = smoothstep(0.12, 0.0, abs(db - (arena_r - 2.45)));
	stone *= 1.0 - ring * 0.4;
	col = mix(col, stone, am);
	ALBEDO = col;
	// Relief aus der Höhenkarte (Differenzen durch Mehrfach-Abtastung: kein Blockmuster wie bei dFdx)
	float e = 0.35;
	float hx = hmix(p + vec2(e, 0.0), pm, am, joint);
	float hz = hmix(p + vec2(0.0, e), pm, am, joint);
	float h0 = hmix(p, pm, am, joint);
	vec3 nw = normalize(vec3(-(hx - h0) / e * 0.55, 1.0, -(hz - h0) / e * 0.55));
	NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(nw, 0.0)).xyz, tex_on));
	ROUGHNESS = 1.0;
}
