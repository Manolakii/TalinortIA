// Aviso de ataque enemigo (GDD, colores reservados): naranja intenso, borde blanco
// y un relleno que avanza hasta el momento del golpe. Nunca rojo ni violeta.
// shape 0: abanico/círculo centrado en el nodo, mirando a -Z.
// shape 1: rectángulo que arranca en el nodo y se extiende hacia -Z.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform int shape = 0;
uniform float angle_deg = 360.0;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 base_color : source_color = vec4(1.0, 0.45, 0.02, 0.2);
uniform vec4 fill_color : source_color = vec4(1.0, 0.45, 0.02, 0.6);
uniform vec4 border_color : source_color = vec4(1.0, 1.0, 1.0, 0.95);
// Grosor del borde en metros, y tamaño del plano en metros (lo pone el script).
uniform float border_m = 0.07;
uniform vec2 size_m = vec2(4.0, 4.0);

void fragment() {
	// p.x a la derecha, p.y hacia adelante (-Z del nodo), de -1 a 1.
	vec2 p = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y * 2.0);
	float edge_m;
	float filled;
	if (shape == 0) {
		float r = length(p);
		float ang = atan(p.x, p.y);
		float half_a = radians(angle_deg) * 0.5;
		if (r > 1.0 || abs(ang) > half_a + 0.0001) {
			discard;
		}
		float radius_m = size_m.x * 0.5;
		edge_m = (1.0 - r) * radius_m;
		if (angle_deg < 359.0) {
			edge_m = min(edge_m, r * radius_m * sin(half_a - abs(ang)));
		}
		filled = step(r, progress);
	} else {
		float t = (p.y + 1.0) * 0.5;
		edge_m = min((1.0 - abs(p.x)) * size_m.x * 0.5, min(t, 1.0 - t) * size_m.y);
		filled = step(t, progress);
	}
	vec4 color = mix(base_color, fill_color, filled);
	if (edge_m < border_m) {
		color = border_color;
	}
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
