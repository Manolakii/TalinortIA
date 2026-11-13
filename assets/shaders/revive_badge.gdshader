// Insignia sobre el jugador caído: círculo con su cara (iniciales encima, en el color del
// jugador) y un aro que se llena mientras lo levantan. Un aro fino interior marca el tiempo
// que le queda.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_test_disabled, depth_draw_never;

uniform vec4 player_color : source_color = vec4(0.2, 0.48, 1.0, 1.0);
// 0 a 1: cuánto lo levantaron.
uniform float progress = 0.0;
// 0 a 1: cuánto tiempo le queda.
uniform float time_left = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	// Ángulo desde arriba, en sentido horario, de 0 a 1.
	float a = fract(atan(p.x, p.y) / 6.2831853 + 1.0);
	vec4 color = vec4(0.0);
	if (r < 0.66) {
		// Cara: disco del color del jugador, más oscuro.
		color = vec4(player_color.rgb * 0.45, 0.92);
	} else if (r < 0.72) {
		// Tiempo que le queda (aro fino).
		color = a < time_left ? vec4(1.0, 0.75, 0.75, 0.9) : vec4(0.1, 0.1, 0.12, 0.6);
	} else if (r > 0.78) {
		// Progreso del revivir (aro grueso).
		color = a < progress ? vec4(player_color.rgb * 1.3, 1.0) : vec4(0.08, 0.08, 0.1, 0.75);
	}
	if (color.a <= 0.0) {
		discard;
	}
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
