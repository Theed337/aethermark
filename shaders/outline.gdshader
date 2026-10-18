shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
// Inverted-Hull-Outline für Charaktere und Gegner.
uniform vec4 outline_color : source_color = vec4(0.05, 0.04, 0.06, 1.0);
uniform float thickness = 0.025;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;

void vertex() {
	VERTEX += NORMAL * thickness;
}
void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = alpha;
}
