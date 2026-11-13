// Aro del color del jugador bajo los pies (P1 azul, P2 rojo, P3 verde lima, P4 amarillo).
// Sin luz, para que se lea igual sobre pasto, tierra o sombra.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform vec4 ring_color : source_color = vec4(0.2, 0.48, 1.0, 1.0);
// Radios relativos al tamaño del plano (1 = borde).
uniform float inner_radius = 0.74;
uniform float outer_radius = 0.92;
uniform float softness = 0.05;
// Relleno muy suave adentro del aro.
uniform float fill_alpha = 0.12;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float ring = smoothstep(inner_radius - softness, inner_radius, r)
			* (1.0 - smoothstep(outer_radius, outer_radius + softness, r));
	float fill = (1.0 - smoothstep(inner_radius - softness, inner_radius, r)) * fill_alpha;
	ALBEDO = ring_color.rgb;
	ALPHA = max(ring, fill) * ring_color.a;
}
