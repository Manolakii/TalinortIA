extends "res://scripts/rooms/test_room.gd"
## Birig Bamba (GDD, LORE): el asteroide-estación con luces de neón y el Salón Beláustegui en el
## medio. Acá no se pelea (Pacto del Bombo). Está Yole Sajor con su mercado (negro), la fuente
## que cura una vez por visita, NPCs para charlar y la nave a Talinorthland.
## Por ahora todo es placeholder (formas simples), con la luz de neón ya puesta.

const STAGE_SCENE := "res://scenes/run/stage_run.tscn"
const NEON_PINK := Color(1.0, 0.25, 0.7)
const NEON_CYAN := Color(0.25, 0.9, 1.0)
const NEON_BLUE := Color(0.4, 0.45, 1.0)
const WOOD := Color(0.36, 0.24, 0.15)
const ENTRY_SPOTS: Array[Vector3] = [Vector3(-1.5, 0, 9.5), Vector3(1.5, 0, 9.5),
		Vector3(-1.5, 0, 11.5), Vector3(1.5, 0, 11.5)]
const BEAT := 0.6

var _result_screen: CanvasLayer
var _beat_nodes: Array[Node3D] = []
var _beat_timer: float = 0.0
var _ship: HubInteractable


func _ready() -> void:
	add_to_group(&"room_title")
	add_to_group(&"hub")
	Events.quality_changed.connect(_on_quality_changed)
	Events.player_out.connect(_on_player_out)
	if PlayerManager.player_count() == 0:
		_auto_join_for_testing()
	GameSettings.auto_revive_players = true
	for leftover: String in ["Rocks", "EnemySpawner"]:
		var node: Node = get_node_or_null(leftover)
		if node != null:
			remove_child(node)
			node.queue_free()
	_set_night()
	_spawn_players()
	for player: PlayerCharacter in players:
		player.peaceful = true
		player.global_position = ENTRY_SPOTS[player.slot.index % ENTRY_SPOTS.size()]
		player.reset_physics_interpolation()
		# Los que quedaron afuera vuelven con 40% y sin fuente (GDD).
		if RunState.party.get(player.slot.index, {}).get("out", false):
			if not RunState.fountain_used.has(player.slot.index):
				RunState.fountain_used.append(player.slot.index)
	_camera.snap_to_targets()
	_result_screen = RESULT_SCENE.instantiate()
	add_child(_result_screen)
	_build_floor()
	_build_salon()
	_build_market()
	_build_fountain()
	_build_drum()
	_build_ship()
	Sound.music("birig_bamba")
	Fx.prewarm(_camera_focus_node())


func room_title() -> String:
	return "Birig Bamba · Salón Beláustegui · visita %d" % (RunState.visit + 1)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	# El asteroide late como un tambor (LORE): todo se mueve al ritmo.
	_beat_timer -= delta
	if _beat_timer <= 0.0:
		_beat_timer = BEAT
		for node: Node3D in _beat_nodes:
			if is_instance_valid(node):
				var base: Vector3 = node.get_meta(&"base_scale", Vector3.ONE)
				var tween: Tween = node.create_tween()
				tween.tween_property(node, "scale", base * 1.08, 0.08)
				tween.tween_property(node, "scale", base, 0.3)


# --- Interacciones ---

func _open_shop(by: PlayerCharacter) -> void:
	var shop := ShopPanel.new()
	add_child(shop)
	shop.open(by, players.find(by), players.size())


func _talk(by: PlayerCharacter, npc_id: String, spot: HubInteractable) -> void:
	var talk: Dictionary = DialogueBox.lines_for(npc_id, String(by.data.id), RunState.visit)
	if talk.is_empty():
		return
	spot.busy = true
	var box := DialogueBox.new()
	add_child(box)
	box.start(by, talk)
	box.finished.connect(func() -> void:
		spot.busy = false
		if npc_id == "yole":
			_open_shop(by))


func _use_fountain(by: PlayerCharacter) -> void:
	var index: int = by.slot.index
	if RunState.fountain_used.has(index):
		var out: bool = RunState.party.get(index, {}).get("out", false)
		Events.floating_text_requested.emit(by.global_position + Vector3.UP * 2.6,
				"Volviste de afuera: la fuente no te cura" if out else "Ya te curaste en esta visita",
				Color(0.8, 0.8, 0.85))
		return
	RunState.fountain_used.append(index)
	by.health.restore_full()
	Fx.ring_burst(self, by.global_position, 1.8, HealMushroom.CAP_COLOR, 0.5)
	Events.floating_text_requested.emit(by.global_position + Vector3.UP * 2.6, "¡Como nuevo!",
			HealMushroom.CAP_COLOR)


func _use_ship(_by: PlayerCharacter) -> void:
	if RunState.visit == 0:
		RunState.save_party(players)
		get_tree().change_scene_to_file(STAGE_SCENE)
		return
	# El MVP llega hasta acá: Birig Bamba → Stage 1 → vuelta a Birig Bamba.
	_result_screen.show_result(true, "¡Volvieron vivos a Birig Bamba!",
			"El Stage 2 (Planeta Uwey) llega después del MVP. ¡Talinorthland, donde la supervivencia es un éxito!")


# --- Armado (placeholder con neón) ---

func _set_night() -> void:
	var env: Environment = _environment.environment.duplicate()
	_environment.environment = env
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.02, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.5, 0.75)
	env.ambient_light_energy = 1.1
	env.fog_light_color = Color(0.25, 0.15, 0.4)
	env.glow_intensity = 1.0
	GameSettings.apply_to_environment(env)
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		sun.light_color = Color(0.7, 0.7, 1.0)
		sun.light_energy = 0.9
	var ground: Node = get_node_or_null("Ground")
	if ground != null:
		for child: Node in ground.get_children():
			if child is GeometryInstance3D:
				(child as GeometryInstance3D).visible = false


func _build_floor() -> void:
	_box(Vector3(50, 0.1, 34), Vector3(0, -0.04, 0), Fx.flat_material(Color(0.27, 0.25, 0.31)))
	# Tiras de neón en el piso.
	for z: float in [-14.0, 14.0]:
		_box(Vector3(46, 0.05, 0.12), Vector3(0, 0.03, z), Fx.flat_material(NEON_CYAN, 3.0))
	for x: float in [-22.5, 22.5]:
		_box(Vector3(0.12, 0.05, 28), Vector3(x, 0.03, 0), Fx.flat_material(NEON_PINK, 3.0))
	for spot: Vector3 in [Vector3(-18, 3, 12), Vector3(18, 3, 12), Vector3(-18, 3, -12), Vector3(18, 3, -12)]:
		_light(spot, NEON_BLUE, 2.5, 12.0)


func _build_salon() -> void:
	var wood := Fx.flat_material(WOOD)
	_box(Vector3(20, 0.06, 9), Vector3(0, 0.0, -7.5), Fx.flat_material(Color(0.3, 0.2, 0.13)))
	_wall(Vector3(20, 3.0, 0.5), Vector3(0, 1.5, -12))
	_wall(Vector3(0.5, 3.0, 9), Vector3(-10, 1.5, -7.5))
	_wall(Vector3(0.5, 3.0, 9), Vector3(10, 1.5, -7.5))
	# Barra y barman.
	var bar := _box(Vector3(12, 1.1, 1.0), Vector3(0, 0.55, -9.8), wood)
	_solid(bar, Vector3(12, 1.1, 1.0))
	_npc(Vector3(0, 0, -10.9), Color(0.75, 0.55, 0.35), "barman", "Hablar con Pocho (E / X)")
	# Mesas con Birigbambenses que se mueven al ritmo.
	var colors: Array[Color] = [Color(0.5, 0.75, 0.45), Color(0.7, 0.45, 0.65), Color(0.45, 0.6, 0.8),
			Color(0.8, 0.7, 0.4), Color(0.6, 0.5, 0.45)]
	var i: int = 0
	for table: Vector3 in [Vector3(-6, 0, -6), Vector3(-2, 0, -7.2), Vector3(3, 0, -6), Vector3(7, 0, -7)]:
		var top := _box(Vector3(1.6, 0.1, 1.6), table + Vector3(0, 0.8, 0), wood)
		_solid(top, Vector3(1.6, 0.9, 1.6))
		for side: float in [-1.0, 1.0]:
			var guest := _capsule(table + Vector3(side * 1.1, 0, 0.3), colors[i % colors.size()], 0.35, 1.3)
			_beat_nodes.append(guest)
			i += 1
	_npc(Vector3(-8, 0, -4.5), Color(0.45, 0.55, 0.85), "consejo", "Hablar con el Consejo (E / X)")
	# Cartel de neón y el de la entrada (LORE).
	var sign := _label("Salón Beláustegui", 90, NEON_PINK)
	sign.position = Vector3(0, 4.2, -11.7)
	add_child(sign)
	var rule := _label("Se prohíben los chistes sobre familiares", 40, Color(1.0, 0.9, 0.7))
	rule.position = Vector3(-6.5, 3.2, -3.2)
	add_child(rule)
	_light(Vector3(0, 3.5, -9), NEON_PINK, 3.0, 12.0)


func _build_market() -> void:
	var center := Vector3(-16, 0, -4)
	var cloth := Fx.flat_material(Color(0.35, 0.15, 0.4))
	# Lona atrás del puesto (un techo taparía a Yole desde la cámara de arriba).
	_box(Vector3(5.5, 2.6, 0.08), center + Vector3(0, 1.6, -1.7), cloth)
	for x: float in [-2.6, 2.6]:
		_box(Vector3(0.15, 2.6, 0.15), center + Vector3(x, 1.3, -1.6), Fx.flat_material(WOOD))
	for offset: Vector3 in [Vector3(-1.8, 0, -1), Vector3(1.6, 0, -1.2), Vector3(-1.2, 0, 1.2), Vector3(2.0, 0, 0.9)]:
		var crate := _box(Vector3(1.0, 0.8, 1.0), center + offset + Vector3(0, 0.4, 0), Fx.flat_material(WOOD.lightened(0.15)))
		_solid(crate, Vector3(1.0, 0.8, 1.0))
	var sign := _label("Mercado (negro)", 64, NEON_CYAN)
	sign.position = center + Vector3(0, 3.4, 0)
	add_child(sign)
	_light(center + Vector3(0, 2.2, 1.5), NEON_CYAN, 2.5, 8.0)
	# Yole Sajor: mapache (placeholder) con antifaz y cola rayada.
	var yole := Node3D.new()
	yole.position = center + Vector3(0, 0, -0.3)
	add_child(yole)
	var body := _capsule_at(yole, Vector3.ZERO, Color(0.55, 0.55, 0.6), 0.42, 1.4)
	_beat_nodes.append(body)
	var mask := MeshInstance3D.new()
	var band := CylinderMesh.new()
	band.top_radius = 0.44
	band.bottom_radius = 0.44
	band.height = 0.16
	mask.mesh = band
	mask.position.y = 1.15
	mask.material_override = Fx.flat_material(Color(0.08, 0.08, 0.1))
	yole.add_child(mask)
	for k: int in 4:
		var ring := MeshInstance3D.new()
		var tail := CylinderMesh.new()
		tail.top_radius = 0.14
		tail.bottom_radius = 0.16
		tail.height = 0.22
		ring.mesh = tail
		ring.rotation.x = 1.1
		ring.position = Vector3(0, 0.35 + k * 0.08, 0.45 + k * 0.18)
		ring.material_override = Fx.flat_material(Color(0.12, 0.12, 0.14) if k % 2 == 0 else Color(0.62, 0.62, 0.66))
		yole.add_child(ring)
	var spot := HubInteractable.new()
	spot.position = center + Vector3(0, 0, 1.0)
	add_child(spot)
	spot.setup("Hablar con Yole Sajor (E / X)", 2.6, 2.8)
	spot.used.connect(func(by: PlayerCharacter) -> void:
		# La primera vez de la visita charla; después va directo a la tienda.
		if RunState.shop_state.has(by.slot.index) and RunState.shop_state[by.slot.index].get("visit", -1) == RunState.visit:
			_open_shop(by)
		else:
			_talk(by, "yole", spot))


func _build_fountain() -> void:
	var center := Vector3(15, 0, -4)
	var stone: Material = preload("res://assets/materials/rock_material.tres")
	var basin := MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = 2.0
	ring.bottom_radius = 2.2
	ring.height = 0.7
	ring.material = stone
	basin.mesh = ring
	basin.position = center + Vector3(0, 0.35, 0)
	add_child(basin)
	_solid(basin, Vector3(4.2, 0.7, 4.2))
	var water := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.8
	disc.bottom_radius = 1.8
	disc.height = 0.05
	water.mesh = disc
	water.position = center + Vector3(0, 0.72, 0)
	water.material_override = Fx.flat_material(HealMushroom.CAP_COLOR, 1.8)
	add_child(water)
	_beat_nodes.append(water)
	_box(Vector3(0.4, 1.8, 0.4), center + Vector3(0, 0.9, 0), stone)
	_light(center + Vector3(0, 2.0, 0), HealMushroom.CAP_COLOR, 2.0, 7.0)
	var spot := HubInteractable.new()
	spot.position = center + Vector3(0, 0, 2.2)
	add_child(spot)
	spot.setup("Curarse en la fuente (E / X)", 2.4, 2.4)
	spot.used.connect(_use_fountain)


func _build_drum() -> void:
	var center := Vector3(13, 0, 7)
	var drum := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.6
	cylinder.bottom_radius = 1.6
	cylinder.height = 1.6
	drum.mesh = cylinder
	drum.position = center + Vector3(0, 0.8, 0)
	drum.material_override = Fx.flat_material(Color(0.6, 0.2, 0.25))
	add_child(drum)
	_solid(drum, Vector3(3.2, 1.6, 3.2))
	drum.set_meta(&"base_scale", Vector3.ONE)
	_beat_nodes.append(drum)
	var label := _label("El Bombo", 54, NEON_PINK)
	label.position = center + Vector3(0, 2.6, 0)
	add_child(label)


func _build_ship() -> void:
	var center := Vector3(-16, 0, 9)
	var hull := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 1.1
	capsule.height = 5.0
	hull.mesh = capsule
	hull.rotation.z = PI * 0.5
	hull.position = center + Vector3(0, 1.3, 0)
	hull.material_override = Fx.flat_material(Color(0.6, 0.62, 0.7))
	add_child(hull)
	_solid(hull, Vector3(5.0, 2.2, 2.2))
	for side: float in [-1.0, 1.0]:
		_box(Vector3(1.6, 0.12, 1.2), center + Vector3(-1.2, 1.3, side * 1.3), Fx.flat_material(Color(0.45, 0.47, 0.55)))
	_light(center + Vector3(2.6, 1.3, 0), NEON_CYAN, 2.0, 5.0)
	var label := _label("Nave a Talinorthland", 54, Color.WHITE)
	label.position = center + Vector3(0, 3.6, 0)
	add_child(label)
	_ship = HubInteractable.new()
	_ship.position = center + Vector3(0, 0, 2.4)
	add_child(_ship)
	_ship.setup("Subir a la nave: Stage 1 (E / X)" if RunState.visit == 0 else "Stage 2: próximamente (E / X)",
			3.0, 2.6)
	_ship.used.connect(_use_ship)


func _npc(at: Vector3, color: Color, npc_id: String, prompt_text: String) -> void:
	var body := _capsule(at, color, 0.4, 1.6)
	_beat_nodes.append(body)
	var spot := HubInteractable.new()
	spot.position = at + Vector3(0, 0, 1.4)
	add_child(spot)
	spot.setup(prompt_text, 2.4, 2.6)
	spot.used.connect(func(by: PlayerCharacter) -> void: _talk(by, npc_id, spot))


# --- Ayudas para armar formas ---

func _box(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = material
	add_child(node)
	return node


func _wall(size: Vector3, at: Vector3) -> void:
	var wall := _box(size, at, preload("res://assets/materials/rock_material.tres"))
	_solid(wall, size)


## Le pone colisión (capa de obstáculos) a una forma, centrada en ella.
func _solid(node: Node3D, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 512
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	node.add_child(body)


func _capsule(at: Vector3, color: Color, radius: float, height: float) -> MeshInstance3D:
	return _capsule_at(self, at, color, radius, height)


func _capsule_at(parent: Node3D, at: Vector3, color: Color, radius: float, height: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = radius
	capsule.height = height
	node.mesh = capsule
	node.position = at + Vector3(0, height * 0.5, 0)
	node.material_override = Fx.flat_material(color)
	node.set_meta(&"base_scale", Vector3.ONE)
	parent.add_child(node)
	return node


func _light(at: Vector3, color: Color, energy: float, light_range: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	add_child(light)


func _label(text: String, size: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.01
	label.outline_size = 14
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	return label
