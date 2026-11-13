// Piso de Talinorthland: pasto con variación y parches de tierra.
// La máscara de tierra la genera GroundWithGrass, que también la usa para no poner pasto encima.
shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D dirt_mask : filter_linear, repeat_disable;
// Tamaño en metros que cubre la máscara, centrada en el origen del nodo.
uniform vec2 mask_world_size = vec2(60.0, 40.0);

uniform vec3 grass_dark : source_color = vec3(0.11, 0.2, 0.05);
uniform vec3 grass_light : source_color = vec3(0.28, 0.4, 0.11);
uniform vec3 dirt_dark : source_color = vec3(0.22, 0.15, 0.09);
uniform vec3 dirt_light : source_color = vec3(0.44, 0.33, 0.21);
uniform float relief_strength = 0.35;

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float value = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 4; i++) {
		value += amplitude * value_noise(p);
		p *= 2.07;
		amplitude *= 0.5;
	}
	return value;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float dirt = texture(dirt_mask, p / mask_world_size + 0.5).r;
	float broad = fbm(p * 0.35);
	float fine = fbm(p * 3.5);

	vec3 grass = mix(grass_dark, grass_light, broad * 0.65 + fine * 0.35);
	vec3 soil = mix(dirt_dark, dirt_light, fine * 0.8 + broad * 0.2);
	ALBEDO = mix(grass, soil, dirt);
	ROUGHNESS = mix(0.88, 0.97, dirt);

	// Relieve fino a partir del ruido, más marcado en la tierra.
	float e = 0.05;
	float h0 = fbm(p * 3.5);
	float hx = fbm((p + vec2(e, 0.0)) * 3.5);
	float hz = fbm((p + vec2(0.0, e)) * 3.5);
	vec2 slope = vec2(hx - h0, hz - h0) / e * relief_strength * mix(0.35, 1.0, dirt) * 0.1;
	NORMAL_MAP = normalize(vec3(-slope.x, -slope.y, 1.0)) * 0.5 + 0.5;
}
