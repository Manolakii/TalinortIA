// Aros de alcance del Croco en el piso: dónde cambia cada arma (escopeta / pistola / rifle).
// La zona del arma actual se ilumina apenas. Color del jugador, muy tenue.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform vec4 ring_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
// Radios en metros y radio total del plano (el plano mide 2 × outer_m).
uniform float near_m = 4.5;
uniform float mid_m = 11.0;
uniform float outer_m = 13.0;
// 0 escopeta, 1 pistola, 2 rifle.
uniform int active_band = 1;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float ring_alpha = 0.12;
uniform float fill_alpha = 0.025;
uniform float ring_width_m = 0.045;

void fragment() {
	float r = length(UV * 2.0 - 1.0) * outer_m;
	float a = 0.0;
	if (abs(r - near_m) < ring_width_m || abs(r - mid_m) < ring_width_m) {
		a = ring_alpha;
	}
	bool in_band = (active_band == 0 && r < near_m)
			|| (active_band == 1 && r > near_m && r < mid_m)
			|| (active_band == 2 && r > mid_m && r < outer_m);
	if (in_band) {
		// En el rifle, el relleno se desvanece hacia afuera.
		float fade = active_band == 2 ? 1.0 - smoothstep(mid_m, outer_m, r) : 1.0;
		a = max(a, fill_alpha * fade);
	}
	if (a <= 0.0) {
		discard;
	}
	ALBEDO = ring_color.rgb;
	ALPHA = a * strength;
}
