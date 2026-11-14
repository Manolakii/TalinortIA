class_name GroundWithGrass
extends Node3D
## Piso de Talinorthland: genera la máscara de tierra, el piso con colisión y el pasto (MultiMesh).
## La cantidad de pasto depende del preset de calidad.

const GROUND_SHADER: Shader = preload("res://assets/shaders/ground_talinorthland.gdshader")
const GRASS_SHADER: Shader = preload("res://assets/shaders/grass_blade.gdshader")
const MASK_PIXELS_PER_METER := 4.0

## Tamaño total del piso, en metros (más grande que la sala para que nunca se vea el vacío).
@export var ground_size: Vector2 = Vector2(110.0, 80.0)
## Zona donde crece pasto, centrada en el nodo.
@export var grass_area: Vector2 = Vector2(64.0, 46.0)
## Briznas por metro cuadrado con el preset Alto.
@export var grass_per_square_meter: float = 30.0
@export var blade_height: float = 0.32
@export var blade_width: float = 0.05
## Qué tanto del piso es tierra (0 = nada, 1 = todo).
@export_range(0.0, 1.0) var dirt_amount: float = 0.3
## Semilla fija: la sala se ve igual cada vez (cuando haya salas al azar, sale de RunState).
@export var layout_seed: int = 1337

var _noise := FastNoiseLite.new()
var _grass: MultiMeshInstance3D


func _ready() -> void:
	add_to_group(&"ground")
	_noise.seed = layout_seed
	_noise.frequency = 0.06
	_noise.fractal_octaves = 3
	_build_ground()
	_build_grass()
	Events.quality_changed.connect(func(_preset: QualityPreset) -> void: _build_grass())


## 0 = pasto, 1 = tierra, en coordenadas locales del nodo.
func dirt_at(local_xz: Vector2) -> float:
	var n: float = _noise.get_noise_2d(local_xz.x, local_xz.y) * 0.5 + 0.5
	var threshold: float = 1.0 - dirt_amount
	return smoothstep(threshold - 0.06, threshold + 0.06, n)


func _build_ground() -> void:
	var width: int = int(ground_size.x * MASK_PIXELS_PER_METER)
	var height: int = int(ground_size.y * MASK_PIXELS_PER_METER)
	var image := Image.create(width, height, false, Image.FORMAT_L8)
	for py: int in height:
		for px: int in width:
			var world := Vector2(
					(float(px) / width - 0.5) * ground_size.x,
					(float(py) / height - 0.5) * ground_size.y)
			image.set_pixel(px, py, Color(dirt_at(world), 0.0, 0.0))

	var material := ShaderMaterial.new()
	material.shader = GROUND_SHADER
	material.set_shader_parameter("dirt_mask", ImageTexture.create_from_image(image))
	material.set_shader_parameter("mask_world_size", ground_size)

	var plane := PlaneMesh.new()
	plane.size = ground_size
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Floor"
	mesh_instance.mesh = plane
	mesh_instance.material_override = material
	add_child(mesh_instance)

	var body := StaticBody3D.new()
	body.name = "FloorBody"
	body.collision_layer = 1 << 1  # floor
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(ground_size.x, 0.2, ground_size.y)
	shape.shape = box
	shape.position.y = -0.1
	body.add_child(shape)
	add_child(body)


var _transforms: Array[Transform3D] = []


## Saca el pasto de una zona (x, z), por ejemplo el barranco. restore_grass() lo devuelve.
func hide_grass_in(area: Rect2) -> void:
	if _grass == null:
		return
	for i: int in _transforms.size():
		var origin: Vector3 = _transforms[i].origin
		if area.has_point(Vector2(origin.x, origin.z)):
			_grass.multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), origin))


func restore_grass() -> void:
	if _grass == null:
		return
	for i: int in _transforms.size():
		_grass.multimesh.set_instance_transform(i, _transforms[i])


func _build_grass() -> void:
	if _grass != null:
		_grass.queue_free()
	var density: float = GameSettings.current_preset.grass_density if GameSettings.current_preset else 1.0
	var target_count: int = int(grass_area.x * grass_area.y * grass_per_square_meter * density)

	var rng := RandomNumberGenerator.new()
	rng.seed = layout_seed
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var attempts: int = 0
	while transforms.size() < target_count and attempts < target_count * 3:
		attempts += 1
		var pos := Vector2(
				rng.randf_range(-0.5, 0.5) * grass_area.x,
				rng.randf_range(-0.5, 0.5) * grass_area.y)
		# En la tierra casi no crece pasto; en los bordes, de a poco.
		if rng.randf() < dirt_at(pos) * 1.1:
			continue
		var basis := Basis(Vector3.UP, rng.randf() * TAU)
		basis = basis.rotated(basis.x, rng.randf_range(-0.25, 0.25))
		var size: float = rng.randf_range(0.6, 1.35)
		basis = basis.scaled(Vector3(size, size * rng.randf_range(0.8, 1.2), size))
		transforms.append(Transform3D(basis, Vector3(pos.x, 0.0, pos.y)))
		var tint: float = rng.randf_range(0.8, 1.15)
		colors.append(Color(tint * rng.randf_range(0.95, 1.08), tint, tint * 0.9))

	_transforms = transforms
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = _make_blade_mesh()
	multimesh.instance_count = transforms.size()
	for i: int in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		multimesh.set_instance_color(i, colors[i])

	_grass = MultiMeshInstance3D.new()
	_grass.name = "Grass"
	_grass.multimesh = multimesh
	_grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = GRASS_SHADER
	_grass.material_override = material
	add_child(_grass)


## Brizna afinada hacia la punta: 5 vértices, 3 triángulos.
func _make_blade_mesh() -> ArrayMesh:
	var half: float = blade_width * 0.5
	var vertices := PackedVector3Array([
		Vector3(-half, 0.0, 0.0), Vector3(half, 0.0, 0.0),
		Vector3(-half * 0.6, blade_height * 0.55, 0.0), Vector3(half * 0.6, blade_height * 0.55, 0.0),
		Vector3(0.0, blade_height, 0.0),
	])
	var uvs := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(1.0, 0.0),
		Vector2(0.0, 0.55), Vector2(1.0, 0.55),
		Vector2(0.5, 1.0),
	])
	var normals := PackedVector3Array()
	normals.resize(5)
	normals.fill(Vector3.UP)
	var indices := PackedInt32Array([0, 2, 1, 1, 2, 3, 2, 4, 3])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
