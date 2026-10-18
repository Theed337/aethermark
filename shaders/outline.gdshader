shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;
// Inverted-Hull-Outline für Charaktere und Gegner.
uniform vec4 outline_color : source_color = vec4(0.05, 0.04, 0.06, 1.0);
uniform float thickness = 0.025;

void vertex() {
	// Mit der Entfernung etwas dicker, damit die Kontur nie unter Pixelgröße fällt (Flimmern)
	float depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
	VERTEX += NORMAL * thickness * clamp(depth * 0.14, 1.0, 3.0);
}
void fragment() {
	ALBEDO = outline_color.rgb;
}
