shader_type canvas_item;
// Recorta la imagen en un círculo con el borde suave (retratos del HUD).

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float d = distance(UV, vec2(0.5));
	c.a *= smoothstep(0.5, 0.47, d);
	COLOR = c;
}
