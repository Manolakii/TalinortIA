// Brizna de pasto para MultiMesh. UV.y = 0 en la raíz y 1 en la punta.
// COLOR (por instancia) varía el tono de cada brizna.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, shadows_disabled;

uniform vec3 root_color : source_color = vec3(0.07, 0.14, 0.03);
uniform vec3 tip_color : source_color = vec3(0.42, 0.55, 0.17);
uniform float wind_strength = 0.07;
uniform float wind_speed = 1.3;
uniform float wind_scale = 0.3;

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = UV.y;
	float gust = sin(TIME * wind_speed + world.x * wind_scale + world.z * wind_scale * 0.7);
	gust += 0.4 * sin(TIME * wind_speed * 2.3 + world.z * wind_scale * 2.0);
	// El viento sopla siempre en la misma dirección del mundo, aunque la brizna esté rotada.
	vec3 wind_world = vec3(1.0, 0.0, 0.4) * gust * wind_strength * h * h;
	VERTEX += (inverse(MODEL_MATRIX) * vec4(wind_world, 0.0)).xyz;
	// Normales hacia arriba: con la cámara desde arriba, el pasto se ilumina como el piso.
	NORMAL = (inverse(MODEL_MATRIX) * vec4(0.0, 1.0, 0.0, 0.0)).xyz;
}

void fragment() {
	float h = UV.y;
	ALBEDO = mix(root_color, tip_color, h) * COLOR.rgb;
	ROUGHNESS = 0.85;
	BACKLIGHT = vec3(0.3) * h;
}
