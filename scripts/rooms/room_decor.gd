class_name RoomDecor
extends Node3D
## Decoración de las salas por escenario (pedido del grupo, 2026-11-16: escenarios más vivos).
## Usa modelos CC0 de KayKit (Medieval Hexagon Pack) y formas de piedra nuestras.
##   1-1 Llanuras Gronk: rocas, arbustos y algunos árboles.
##   1-2 Ruinas de Ciudad Derrumbe: columnas rotas, cajas, barriles y tablones.
##   1-3 Bosque Tuerto: muchos árboles, troncos cortados y arbustos.
## Los árboles grandes van afuera de las paredes y en los bordes (chocan, como las rocas). Adentro
## solo hay detalles chicos que no traban (no chocan): la pelea no cambia.

const NATURE := "res://assets/models/kaykit/nature/%s.gltf"
const PROPS := "res://assets/models/kaykit/props/%s.gltf"
const STONE: Material = preload("res://assets/materials/rock_material.tres")
## Bordes de la sala (las paredes están un poco más afuera).
const HALF_X := 23.6
const HALF_Z := 15.6
## Lugares que tienen que quedar libres: la entrada (sur) y las puertas (norte).
const KEEP_CLEAR: Array[Rect2] = [Rect2(-4, 8, 8, 9), Rect2(-11, -16, 22, 6)]
## Escala de los modelos de KayKit (vienen chiquitos, a escala de hexágono).
const TREE_SCALE := 4.2
const SMALL_SCALE := 4.5

const THEMES: Array[Dictionary] = [
	# 1-1 Llanuras Gronk
	{"outer": ["tree_single_A", "tree_single_B", "trees_A_small"], "outer_count": 16,
	 "edge": ["trees_A_small", "tree_single_B"], "edge_count": 4,
	 "inner": ["rock_single_A", "rock_single_B", "rock_single_D", "waterplant_A", "waterplant_B"], "inner_count": 22},
	# 1-2 Ruinas de Ciudad Derrumbe
	{"outer": ["tree_single_A_cut", "rock_single_E", "tree_single_A"], "outer_count": 12,
	 "edge": ["@column", "@column", "crate_A_big", "barrel", "resource_lumber", "wheelbarrow", "weaponrack"], "edge_count": 12,
	 "inner": ["rock_single_C", "rock_single_A", "sack", "crate_B_small", "waterplant_A"], "inner_count": 16},
	# 1-3 Bosque Tuerto
	{"outer": ["trees_A_medium", "trees_B_medium", "trees_A_small", "trees_B_small", "tree_single_B"], "outer_count": 26,
	 "edge": ["tree_single_A", "tree_single_B", "trees_B_small", "tree_single_A_cut"], "edge_count": 9,
	 "inner": ["waterplant_A", "waterplant_B", "rock_single_B", "tree_single_A_cut"], "inner_count": 20},
]

## Tintes para que los modelos de KayKit (muy saturados) combinen con el estilo semirrealista.
const TINTS: Dictionary = {"tree": Color(0.55, 0.66, 0.46), "rock": Color(0.6, 0.57, 0.52),
		"waterplant": Color(0.62, 0.75, 0.5), "prop": Color(0.78, 0.72, 0.66)}

static var _cache: Dictionary = {}


## Decora la sala del escenario `scenario` (0, 1 o 2). `avoid`: lugares que no hay que tapar.
## `outer_only`: solo afuera de las paredes (en el boss la arena queda como está).
func decorate(scenario: int, rng: RandomNumberGenerator, avoid: Array[Vector3] = [],
		outer_only: bool = false) -> void:
	var theme: Dictionary = THEMES[clampi(scenario, 0, THEMES.size() - 1)]
	var density: float = GameSettings.current_preset.decor_density if GameSettings.current_preset != null else 1.0
	# Afuera de las paredes: se ve el borde del mundo con vida.
	for i: int in roundi(theme["outer_count"] * density):
		var spot: Vector3 = _outer_spot(rng)
		_place(theme["outer"].pick_random(), spot, rng, TREE_SCALE * rng.randf_range(0.85, 1.25), true)
	if outer_only:
		return
	# En los bordes, adentro: algunos chocan (como las rocas).
	for i: int in roundi(theme["edge_count"] * density):
		var spot: Vector3 = _edge_spot(rng)
		if _blocked(spot, avoid, 3.0):
			continue
		_place(theme["edge"].pick_random(), spot, rng, TREE_SCALE * rng.randf_range(0.8, 1.1), true)
	# Adentro: detalles chicos que no traban.
	for i: int in roundi(theme["inner_count"] * density):
		var spot := Vector3(rng.randf_range(-HALF_X + 1.0, HALF_X - 1.0), 0.0, rng.randf_range(-HALF_Z + 1.0, HALF_Z - 1.0))
		if _blocked(spot, avoid, 1.6):
			continue
		_place(theme["inner"].pick_random(), spot, rng, SMALL_SCALE * rng.randf_range(0.6, 1.0), false)


func _outer_spot(rng: RandomNumberGenerator) -> Vector3:
	match rng.randi_range(0, 3):
		0:
			return Vector3(rng.randf_range(-HALF_X - 4.0, HALF_X + 4.0), 0.0, rng.randf_range(HALF_Z + 1.6, HALF_Z + 5.0))
		1:
			return Vector3(rng.randf_range(-HALF_X - 4.0, HALF_X + 4.0), 0.0, rng.randf_range(-HALF_Z - 6.0, -HALF_Z - 1.2))
		2:
			return Vector3(rng.randf_range(-HALF_X - 6.0, -HALF_X - 1.2), 0.0, rng.randf_range(-HALF_Z, HALF_Z))
		_:
			return Vector3(rng.randf_range(HALF_X + 1.2, HALF_X + 6.0), 0.0, rng.randf_range(-HALF_Z, HALF_Z))


func _edge_spot(rng: RandomNumberGenerator) -> Vector3:
	if rng.randf() < 0.5:
		var x: float = (HALF_X - rng.randf_range(0.8, 2.2)) * (1.0 if rng.randf() < 0.5 else -1.0)
		return Vector3(x, 0.0, rng.randf_range(-HALF_Z + 1.0, HALF_Z - 1.0))
	var z: float = (HALF_Z - rng.randf_range(0.8, 2.0)) * (1.0 if rng.randf() < 0.5 else -1.0)
	return Vector3(rng.randf_range(-HALF_X + 1.0, HALF_X - 1.0), 0.0, z)


func _blocked(spot: Vector3, avoid: Array[Vector3], margin: float) -> bool:
	for rect: Rect2 in KEEP_CLEAR:
		if rect.has_point(Vector2(spot.x, spot.z)):
			return true
	for other: Vector3 in avoid:
		if Vector2(spot.x - other.x, spot.z - other.z).length() < margin:
			return true
	return false


func _place(id: String, spot: Vector3, rng: RandomNumberGenerator, size: float, solid: bool) -> void:
	var node: Node3D
	if id == "@column":
		node = _broken_column(rng)
	else:
		var scene: PackedScene = _load(id)
		if scene == null:
			return
		node = scene.instantiate()
		node.scale = Vector3.ONE * size
		_tint(node, id)
	add_child(node)
	node.position = spot
	node.rotation.y = rng.randf() * TAU
	if solid:
		_add_collision(node, 0.6 if id.begins_with("tree") or id.begins_with("trees") else 0.5)


func _tint(node: Node3D, id: String) -> void:
	var key: String = "prop"
	for name: String in ["tree", "rock", "waterplant"]:
		if id.begins_with(name):
			key = name
	var tint: Color = TINTS[key]
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		for i: int in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(i) as StandardMaterial3D
			if original == null:
				continue
			var copy: StandardMaterial3D = _tinted(original, tint)
			mesh.set_surface_override_material(i, copy)


## Los materiales teñidos se comparten (no uno por árbol).
static var _tinted_cache: Dictionary = {}


static func _tinted(original: StandardMaterial3D, tint: Color) -> StandardMaterial3D:
	var key: String = "%d:%s" % [original.get_instance_id(), tint]
	if not _tinted_cache.has(key):
		var copy: StandardMaterial3D = original.duplicate()
		copy.albedo_color = copy.albedo_color * tint
		copy.roughness = 0.9
		_tinted_cache[key] = copy
	return _tinted_cache[key]


func _load(id: String) -> PackedScene:
	if _cache.has(id):
		return _cache[id]
	var path: String = NATURE % id
	if not ResourceLoader.exists(path):
		path = PROPS % id
	var scene: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
	_cache[id] = scene
	return scene


## Columna de piedra rota (Ciudad Derrumbe se cayó por mala planificación).
func _broken_column(rng: RandomNumberGenerator) -> Node3D:
	var holder := Node3D.new()
	var height: float = rng.randf_range(1.2, 3.2)
	var column := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.55
	cylinder.bottom_radius = 0.65
	cylinder.height = height
	cylinder.material = STONE
	column.mesh = cylinder
	column.position.y = height * 0.5
	column.rotation.z = rng.randf_range(-0.12, 0.12)
	holder.add_child(column)
	# Pedazo caído al lado.
	var chunk := MeshInstance3D.new()
	var piece := CylinderMesh.new()
	piece.top_radius = 0.5
	piece.bottom_radius = 0.55
	piece.height = rng.randf_range(0.8, 1.4)
	piece.material = STONE
	chunk.mesh = piece
	chunk.rotation.z = PI * 0.5
	chunk.position = Vector3(1.3, 0.5, rng.randf_range(-0.5, 0.5))
	holder.add_child(chunk)
	return holder


## Los de los bordes chocan como las rocas (capa de obstáculos).
func _add_collision(node: Node3D, radius: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 512
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = 3.0
	shape.shape = cylinder
	shape.position.y = 1.5
	body.add_child(shape)
	add_child(body)
	body.position = node.position
