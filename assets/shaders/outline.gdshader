// Contorno finito por casco invertido. Va como next_pass del material del personaje.
// Solo para personajes y enemigos (legibilidad en co-op, GDD > Estilo visual).
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

uniform vec4 outline_color : source_color = vec4(0.04, 0.04, 0.06, 1.0);
// Grosor en metros. A la distancia de juego, 0,03 m son unos 2 px.
uniform float outline_width = 0.03;

void vertex() {
	VERTEX += NORMAL * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
}
