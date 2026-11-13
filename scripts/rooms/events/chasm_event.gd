class_name ChasmEvent
extends Node3D
## Evento "El barranco" (pedido del grupo: una sala de plataformas). Un barranco cruza la sala
## de lado a lado y se pasa por piedras que se derrumban al rato de pisarlas (y vuelven). Algunos
## huecos se saltan con la esquiva (mientras esquivás, estás en el aire). Si caés: daño y volvés
## al último lugar seguro. El cofre está del otro lado; si nadie se cayó, el evento sale perfecto.

signal resolved(perfect: bool)

const BAND_MIN_Z := -6.5
const BAND_MAX_Z := 3.5
const ROW_Z: Array[float] = [2.0, -1.0, -4.0]
const TILE_SIZE := Vector2(2.6, 3.0)
const COLUMN_STEP := 3.0
const MIN_X := -21.0
const MAX_X := 21.0
## Tiempo sin piso antes de caer (para que no se caiga por pasar rozando un borde).
const COYOTE := 0.15

var _config: StageRoomsConfig
var _tiles: Array[ChasmTile] = []
var _off_ground: Dictionary = {}  # Node3D -> segundos sin piso
var _safe_spot: Dictionary = {}  # Node3D -> último lugar seguro
var _falls: int = 0
var _finished: bool = false


func setup(config: StageRoomsConfig, template: Node3D, rng: RandomNumberGenerator) -> void:
	_config = config
	var holder: Node = template.get_parent()
	for node: Node in holder.find_children("*", "", true, false):
		if not (node is RockProp or node is Vase or node is CrackedRock):
			continue
		var z: float = (node as Node3D).global_position.z
		if z > BAND_MIN_Z - 2.5 and z < BAND_MAX_Z + 2.5:
			node.queue_free()
	_build_abyss()
	_build_tiles(rng)
	var ground: Node = get_tree().get_first_node_in_group(&"ground")
	if ground != null:
		ground.hide_grass_in(Rect2(-30.0, BAND_MIN_Z, 60.0, BAND_MAX_Z - BAND_MIN_Z))
	var chest := Chest.new()
	chest.gold_table = Balance.economy.event_chest_gold
	chest.position = Vector3(0, 0, -9.0)
	add_child(chest)
	chest.opened.connect(_on_chest_opened)


func _exit_tree() -> void:
	var ground: Node = get_tree().get_first_node_in_group(&"ground") if is_inside_tree() else null
	if ground != null:
		ground.restore_grass()


func _physics_process(delta: float) -> void:
	if _finished:
		return
	for node: Node in get_tree().get_nodes_in_group(&"enemy_targets"):
		var body := node as Node3D
		if body == null or not (body is PlayerCharacter or body is DuoCompanion):
			continue
		_check_body(body, delta)


func _check_body(body: Node3D, delta: float) -> void:
	var p: Vector3 = body.global_position
	var player := body as PlayerCharacter
	if player != null and (player.health.is_dead or player.is_dodging()):
		_off_ground[body] = 0.0
		return
	if p.z < BAND_MIN_Z or p.z > BAND_MAX_Z or _on_tile(p):
		_off_ground[body] = 0.0
		if p.z < BAND_MIN_Z or p.z > BAND_MAX_Z:
			_safe_spot[body] = p
		else:
			_safe_spot[body] = _tile_center_under(p)
		return
	_off_ground[body] = _off_ground.get(body, 0.0) + delta
	if _off_ground[body] >= COYOTE:
		_fall(body)


func _fall(body: Node3D) -> void:
	_off_ground[body] = 0.0
	var back: Vector3 = _safe_spot.get(body, Vector3(body.global_position.x, 0, BAND_MAX_Z + 1.5))
	var player := body as PlayerCharacter
	if player != null:
		_falls += 1
		var info := DamageInfo.new()
		info.amount = _config.chasm_fall_damage
		info.attacker_team = DamageInfo.Team.ENEMIES
		info.tags.append(&"tick")
		player.health.apply_damage(info)
		player.flash()
		Dialogue.say("barranco_caida", back + Vector3.UP * 2.6, Color(1.0, 0.85, 0.7))
		Events.camera_shake_requested.emit(0.3)
	body.global_position = Vector3(back.x, body.global_position.y, back.z)
	(body as Node3D).reset_physics_interpolation()
	if body is CharacterBody3D:
		(body as CharacterBody3D).velocity = Vector3.ZERO
	Fx.ring_burst(get_parent(), body.global_position, 1.0, Color(0.6, 0.55, 0.5), 0.25)


func _on_tile(point: Vector3) -> bool:
	return _tile_center_under(point) != Vector3.INF


func _tile_center_under(point: Vector3) -> Vector3:
	for tile: ChasmTile in _tiles:
		if tile.is_solid() and tile.contains(point):
			tile.step_on()
			return tile.global_position
	return Vector3.INF


func _on_chest_opened(_by: PlayerCharacter) -> void:
	if _finished:
		return
	_finished = true
	resolved.emit(_falls == 0)


func fall_count() -> int:
	return _falls


# --- Armado ---

func _build_abyss() -> void:
	var abyss := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(48.0, BAND_MAX_Z - BAND_MIN_Z)
	abyss.mesh = plane
	abyss.position = Vector3(0, 0.03, (BAND_MIN_Z + BAND_MAX_Z) * 0.5)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.03, 0.03, 0.05)
	dark.roughness = 1.0
	abyss.material_override = dark
	abyss.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(abyss)
	# Bordes de tierra, para que se lea dónde empieza el barranco.
	for z: float in [BAND_MIN_Z, BAND_MAX_Z]:
		var edge := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(48.0, 0.25, 0.35)
		edge.mesh = box
		edge.position = Vector3(0, 0.1, z)
		edge.material_override = Fx.flat_material(Color(0.36, 0.27, 0.18))
		add_child(edge)


## Un camino seguro que serpentea (siempre se puede cruzar) más piedras sueltas al azar.
func _build_tiles(rng: RandomNumberGenerator) -> void:
	var columns: int = int((MAX_X - MIN_X) / COLUMN_STEP) + 1
	var path_col: int = rng.randi_range(2, columns - 3)
	for row: int in ROW_Z.size():
		for col: int in columns:
			var on_path: bool = col == path_col
			if not on_path and rng.randf() > _config.chasm_extra_tiles:
				continue
			var tile := ChasmTile.new()
			tile.size = TILE_SIZE
			tile.crumble_delay = _config.chasm_crumble_delay
			tile.respawn_time = _config.chasm_respawn_time
			tile.position = Vector3(MIN_X + col * COLUMN_STEP, 0, ROW_Z[row])
			add_child(tile)
			_tiles.append(tile)
		# La fila siguiente del camino se corre uno para un lado (o queda).
		path_col = clampi(path_col + rng.randi_range(-1, 1), 1, columns - 2)
