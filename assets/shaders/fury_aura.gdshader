// Aura de Furia de Tali: rojo-ocre (DECISIONES 2026-11-12), nunca naranja (reservado
// para avisos enemigos). Brilla en los bordes y crece con la barra de Furia.
shader_type spatial;
render_mode unshaded, blend_mix, cull_back, depth_draw_never, shadows_disabled;

uniform vec4 aura_color : source_color = vec4(0.72, 0.22, 0.08, 1.0);
// 0 = invisible, 1 = Furia plena.
uniform float intensity = 0.0;
uniform float pulse_speed = 6.0;

void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	float pulse = 0.8 + 0.2 * sin(TIME * pulse_speed);
	ALBEDO = aura_color.rgb;
	ALPHA = clamp(rim * intensity * pulse * 1.3, 0.0, 0.9);
}
