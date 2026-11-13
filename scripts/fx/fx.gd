class_name Fx
## Efectos visuales cortos y baratos (placeholders hasta tener partículas y animaciones).

const RING_SHADER: Shader = preload("res://assets/shaders/player_ring.gdshader")
const AREA_SHADER: Shader = preload("res://assets/shaders/telegraph.gdshader")


## Aro que se expande y se desvanece (impactos, aterrizajes, rugidos).
static func ring_burst(parent: Node, position: Vector3, radius: float, color: Color,
		duration: float = 0.35) -> void:
	var ring := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * 2.0
	ring.mesh = plane
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = RING_SHADER
	material.set_shader_parameter("ring_color", color)
	material.set_shader_parameter("inner_radius", 0.82)
	material.set_shader_parameter("fill_alpha", 0.18)
	ring.material_override = material
	parent.add_child(ring)
	ring.global_position = position + Vector3.UP * 0.25
	ring.scale = Vector3.ONE * radius * 0.3
	var tween: Tween = ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE * radius, duration) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(a: float) -> void:
		material.set_shader_parameter("ring_color", Color(color, a)), 1.0, 0.0, duration)
	tween.chain().tween_callback(ring.queue_free)


## Zona con forma de abanico del color del jugador, que dura un instante (zarpazos).
static func slash(parent: Node, position: Vector3, direction: Vector3, radius: float,
		angle_deg: float, color: Color, duration: float = 0.14) -> void:
	var mesh_instance := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * radius * 2.0
	mesh_instance.mesh = plane
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = AREA_SHADER
	material.set_shader_parameter("shape", 0)
	material.set_shader_parameter("angle_deg", angle_deg)
	material.set_shader_parameter("size_m", plane.size)
	material.set_shader_parameter("progress", 1.0)
	material.set_shader_parameter("border_m", 0.0)
	material.set_shader_parameter("fill_color", Color(color.lightened(0.35), 0.55))
	material.set_shader_parameter("border_color", Color(1, 1, 1, 0))
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	mesh_instance.global_position = position + Vector3.UP * 0.3
	mesh_instance.rotation.y = atan2(-direction.x, -direction.z)
	var tween: Tween = mesh_instance.create_tween()
	tween.tween_method(func(a: float) -> void:
		material.set_shader_parameter("fill_color", Color(color.lightened(0.35), a)),
		0.55, 0.0, duration)
	tween.tween_callback(mesh_instance.queue_free)


## Rayo recto que se desvanece (Tiro por Contrato).
static func beam(parent: Node, from: Vector3, direction: Vector3, length: float, width: float,
		color: Color, duration: float = 0.18) -> void:
	var node: MeshInstance3D = make_beam_mesh(color, width)
	parent.add_child(node)
	place_beam(node, from, direction, length)
	var material := node.material_override as StandardMaterial3D
	var tween: Tween = node.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, duration)
	tween.tween_callback(node.queue_free)


## Malla de rayo reutilizable: una caja estirada, sin luz y con brillo.
static func make_beam_mesh(color: Color, width: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, width * 0.4, 1.0)
	node.mesh = box
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## Ubica una malla de rayo entre `from` y `from + direction * length`.
static func place_beam(node: MeshInstance3D, from: Vector3, direction: Vector3, length: float) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z).normalized()
	node.global_position = from + flat * length * 0.5
	node.rotation = Vector3(0.0, atan2(-flat.x, -flat.z), 0.0)
	node.scale = Vector3(1.0, 1.0, length)


## Material simple sin luz, para efectos.
static func flat_material(color: Color, emission: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material


## Dibuja una vez cada efecto escondido bajo el piso, para que los shaders se compilen
## al entrar a la sala y no en plena pelea (evita tirones la primera vez).
static func prewarm(parent: Node3D) -> void:
	var hidden: Vector3 = parent.global_position + Vector3(0.0, -3.0, 0.0)
	ring_burst(parent, hidden, 1.0, Color.WHITE, 0.2)
	slash(parent, hidden, Vector3.FORWARD, 1.0, 90.0, Color.WHITE, 0.2)
	var telegraph := Telegraph.new()
	parent.add_child(telegraph)
	telegraph.show_circle(1.0, 0.2)
	telegraph.position.y = -3.0
	parent.get_tree().create_timer(0.3).timeout.connect(telegraph.queue_free)
	var aura := MeshInstance3D.new()
	aura.mesh = SphereMesh.new()
	var aura_material := ShaderMaterial.new()
	aura_material.shader = preload("res://assets/shaders/fury_aura.gdshader")
	aura.material_override = aura_material
	parent.add_child(aura)
	aura.global_position = hidden
	parent.get_tree().create_timer(0.3).timeout.connect(aura.queue_free)
