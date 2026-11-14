class_name StampedeEvent
extends Node3D
## Evento "La estampida" (reemplaza al barranco, pedido del grupo). Durante un rato pasan manadas
## de Gronks por carriles que cruzan la sala, cada una con su aviso naranja antes. Cada vez más
## seguidas, y desde la mitad también de arriba a abajo y de a dos. Se gana aguantando sin que
## caiga nadie (LORE: la invasión de los Pipos se ganó con una estampida pedida por error).

signal resolved(won: bool)

const HALF_X := 24.0
const HALF_Z := 15.0
const GRONK_COLOR := Color(0.42, 0.33, 0.24)

var _config: StageRoomsConfig
var _rng: RandomNumberGenerator
var _time: float = 0.0
var _next_herd: float = 2.0
var _finished: bool = false
var _herds: Array[Dictionary] = []
var _label: Label


func setup(config: StageRoomsConfig, rng: RandomNumberGenerator) -> void:
	_config = config
	_rng = rng
	var layer := CanvasLayer.new()
	layer.layer = 31
	add_child(layer)
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.offset_top = 92.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 34)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 10)
	layer.add_child(_label)
	Events.player_downed.connect(_on_player_downed)


func _physics_process(delta: float) -> void:
	_move_herds(delta)
	if _finished:
		return
	_time += delta
	var left: float = _config.stampede_duration - _time
	_label.text = "¡Aguanten la estampida! %d s" % ceili(maxf(left, 0.0))
	if left <= 0.0:
		_win()
		return
	_next_herd -= delta
	if _next_herd <= 0.0:
		var progress: float = _time / _config.stampede_duration
		_next_herd = lerpf(_config.stampede_interval_start, _config.stampede_interval_end, progress)
		_launch_herd(progress >= 0.5)
		if progress >= 0.5 and _rng.randf() < 0.4:
			_launch_herd(true)


## Un carril al azar: de costado (de un lado de la sala al otro) o, desde la mitad, de arriba a abajo.
func _launch_herd(any_direction: bool) -> void:
	var vertical: bool = any_direction and _rng.randf() < 0.5
	var reverse: bool = _rng.randf() < 0.5
	var from: Vector3
	var to: Vector3
	if vertical:
		var x: float = _rng.randf_range(-HALF_X + 3.0, HALF_X - 3.0)
		from = Vector3(x, 0, -HALF_Z)
		to = Vector3(x, 0, HALF_Z)
	else:
		var z: float = _rng.randf_range(-HALF_Z + 3.0, HALF_Z - 3.0)
		from = Vector3(-HALF_X, 0, z)
		to = Vector3(HALF_X, 0, z)
	if reverse:
		var temp: Vector3 = from
		from = to
		to = temp
	var direction: Vector3 = (to - from).normalized()
	var warning := Telegraph.new()
	add_child(warning)
	warning.global_position = from + Vector3.UP * 0.05
	warning.rotation.y = atan2(-direction.x, -direction.z)
	var windup: float = _config.stampede_warning * Scaling.current_windup()
	warning.show_rect(from.distance_to(to), _config.stampede_width, windup)
	_herds.append({"from": from, "to": to, "dir": direction, "wait": windup, "warning": warning,
			"bodies": [], "pos": from - direction * 4.0, "hit": []})


func _move_herds(delta: float) -> void:
	for i: int in range(_herds.size() - 1, -1, -1):
		var herd: Dictionary = _herds[i]
		if herd["wait"] > 0.0:
			herd["wait"] -= delta
			if herd["wait"] <= 0.0:
				(herd["warning"] as Telegraph).hide_telegraph()
				herd["bodies"] = _build_gronks(herd["dir"])
				Events.camera_shake_requested.emit(0.2)
			continue
		var before: Vector3 = herd["pos"]
		herd["pos"] = before + herd["dir"] * _config.stampede_speed * delta
		var bodies: Array = herd["bodies"]
		for j: int in bodies.size():
			(bodies[j] as Node3D).global_position = herd["pos"] - herd["dir"] * (j * 2.2)
		_trample(herd, before - herd["dir"] * (bodies.size() * 2.2), herd["pos"])
		if (herd["pos"] - herd["from"]).length() > (herd["to"] - herd["from"]).length() + 10.0:
			for body: Node3D in bodies:
				body.queue_free()
			(herd["warning"] as Node).queue_free()
			_herds.remove_at(i)


## Pisa a los jugadores del carril (una vez por manada) y los tira para el costado.
func _trample(herd: Dictionary, from: Vector3, to: Vector3) -> void:
	for hurtbox: Hurtbox in CombatQuery.in_line(get_tree(), DamageInfo.Team.PLAYERS, from, to,
			_config.stampede_width):
		if herd["hit"].has(hurtbox.receiver):
			continue
		herd["hit"].append(hurtbox.receiver)
		var info := DamageInfo.new()
		info.amount = _config.stampede_damage * Scaling.current_damage_multiplier()
		info.attacker_team = DamageInfo.Team.ENEMIES
		var closest: Vector3 = Geometry3D.get_closest_point_to_segment(hurtbox.global_position, from, to)
		info.origin = closest - (hurtbox.global_position - closest).normalized() * 0.1
		info.knockback = 10.0
		info.hitstop = Balance.combat.hitstop_heavy
		info.shake = Balance.combat.shake_heavy * 0.4
		hurtbox.take_hit(info)


func _build_gronks(direction: Vector3) -> Array:
	var bodies: Array = []
	for i: int in 3:
		var gronk := Node3D.new()
		add_child(gronk)
		gronk.rotation.y = atan2(-direction.x, -direction.z)
		var body := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.75
		capsule.height = 2.4
		body.mesh = capsule
		body.rotation.x = PI * 0.5
		body.position.y = 0.8
		body.material_override = Fx.flat_material(GRONK_COLOR)
		gronk.add_child(body)
		for side: float in [-1.0, 1.0]:
			var horn := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.16
			cone.height = 0.7
			horn.mesh = cone
			horn.position = Vector3(side * 0.45, 1.3, -1.0)
			horn.rotation.x = -0.9
			horn.material_override = Fx.flat_material(Color(0.92, 0.88, 0.8))
			gronk.add_child(horn)
		bodies.append(gronk)
	return bodies


func _on_player_downed(_player: Node3D) -> void:
	if _finished:
		return
	_finished = true
	_label.text = "¡Pisaron a uno! Perdieron la estampida"
	_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.3))
	_fade_label()
	resolved.emit(false)


func _win() -> void:
	_finished = true
	_label.text = "¡Aguantaron la estampida!"
	_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))
	_fade_label()
	resolved.emit(true)


func _fade_label() -> void:
	var tween: Tween = create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(_label, "modulate:a", 0.0, 0.5)
