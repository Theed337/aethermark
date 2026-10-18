shader_type canvas_item;
// Lebens-/Ressourcenkugel im Stil klassischer Action-Rollenspiele: Flüssigkeit mit Welle, Glasreflex, Randabdunklung.
uniform float level : hint_range(0.0, 1.0) = 1.0;
uniform vec4 col_low : source_color = vec4(0.45, 0.02, 0.03, 1.0);
uniform vec4 col_high : source_color = vec4(0.95, 0.15, 0.1, 1.0);
uniform float pulse : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float edge = smoothstep(1.0, 0.965, r);
	float surf = 1.0 - 2.0 * level;
	float wave = (sin(p.x * 5.0 + TIME * 2.2) * 0.022 + sin(p.x * 9.0 - TIME * 1.4) * 0.012) * step(level, 0.995);
	float liq = smoothstep(surf + wave - 0.012, surf + wave + 0.012, p.y);
	float grad = smoothstep(-1.0, 1.0, p.y);
	vec3 liquid = mix(col_high.rgb, col_low.rgb, grad);
	float sw = sin(p.x * 6.0 + p.y * 4.0 + TIME * 0.9) * 0.5 + 0.5;
	float sw2 = sin(p.x * -9.0 + p.y * 7.0 - TIME * 0.6) * 0.5 + 0.5;
	liquid *= 0.88 + 0.14 * sw + 0.08 * sw2;
	liquid += col_high.rgb * pulse * 0.35;
	vec3 empty = vec3(0.045, 0.03, 0.035) * (1.1 - r * 0.5);
	vec3 c = mix(empty, liquid, liq);
	float line = smoothstep(0.045, 0.0, abs(p.y - (surf + wave))) * liq * step(level, 0.995);
	c += col_high.rgb * line * 0.8;
	c *= mix(1.0, 0.45, smoothstep(0.62, 1.0, r));
	vec2 h = (p - vec2(-0.34, -0.5)) / vec2(0.55, 0.26);
	c += vec3(1.0) * smoothstep(1.0, 0.1, length(h)) * 0.28;
	vec2 h2 = (p - vec2(0.3, 0.72)) / vec2(0.5, 0.12);
	c += vec3(1.0) * smoothstep(1.0, 0.2, length(h2)) * 0.07;
	COLOR = vec4(c, edge);
}
