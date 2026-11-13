class_name TalinorteanoCegado
extends Enemy
## Talinorteano cegado (GDD, Stage 1): corre directo en grupo y pega con un palo
## después de 0,6 s de aviso. Lento y torpe.

enum Mode { CHASE, WINDUP, RECOVER }

## Color de la venda: violeta = sombra (la sombra de los Aguccis los ciega).
const BLINDFOLD_COLOR := Color(0.42, 0.2, 0.62)

var mode: Mode = Mode.CHASE
var _mode_time: float = 0.0
## Variación de velocidad para que el grupo no se mueva como un bloque.
var _speed_jitter: float = 1.0
var _wander_direction: Vector3 = Vector3.FORWARD
var _wander_time: float = 0.0
## Combo: después de este golpe viene otro rápido.
var _chain: bool = false
var _follow_up: bool = false


func _ready() -> void:
	if enemy_id == &"":
		enemy_id = &"talinorteano_cegado"
	super._ready()
	_speed_jitter = randf_range(0.85, 1.12)


func _think(delta: float) -> void:
	if status.has(StatusEffects.STUN):
		stop(delta)
		return
	if status.has(StatusEffects.FEAR):
		steer(flat_direction_to(fear_origin) * -1.0, data.move_speed * 1.3, delta)
		return
	if status.has(StatusEffects.BLIND):
		_wander(delta)
		return

	_mode_time += delta
	match mode:
		Mode.CHASE:
			_chase(delta)
		Mode.WINDUP:
			stop(delta)
			if _mode_time >= _current_windup():
				_strike()
		Mode.RECOVER:
			stop(delta)
			if _mode_time >= recovery_time() * (0.35 if _chain else 1.0):
				if _chain:
					# Segundo golpe del combo: se da vuelta hacia el objetivo y vuelve a pegar.
					_chain = false
					_follow_up = true
					var target: Node3D = nearest_target()
					if target != null:
						facing = flat_direction_to(target.global_position)
					_start_windup()
				else:
					_follow_up = false
					choose_reposition()
					_set_mode(Mode.CHASE)


func _chase(delta: float) -> void:
	var target: Node3D = nearest_target()
	if target == null:
		stop(delta)
		return
	if run_tactic(target, delta):
		return
	var direction: Vector3 = flat_direction_to(target.global_position)
	var distance: float = flat_distance_to(target.global_position)
	if distance <= data.attack_range:
		if not take_attack_slot(target):
			start_tactic(&"wait", randf_range(0.4, 0.8))
			return
		turn_towards(direction, delta)
		if facing.angle_to(direction) < deg_to_rad(35.0):
			_start_windup()
		else:
			stop(delta)
		return
	steer(approach_direction(target), data.move_speed * _speed_jitter * speed_multiplier(), delta)


func _start_windup() -> void:
	_set_mode(Mode.WINDUP)
	# El aviso queda fijo hacia donde miraba al empezar: se puede salir esquivando o caminando.
	telegraph.rotation.y = atan2(-facing.x, -facing.z)
	telegraph.show_sector(data.attack_radius, data.attack_angle_deg, _current_windup())


func _strike() -> void:
	telegraph.hide_telegraph()
	var info: DamageInfo = make_attack()
	var targets: Array[Hurtbox] = CombatQuery.in_sector(get_tree(), DamageInfo.Team.PLAYERS,
			global_position, facing, data.attack_radius, data.attack_angle_deg)
	if Combat.deliver(info, targets) > 0:
		freeze(Balance.combat.hitstop_light)
	_swing_stick()
	_chain = not _follow_up and randf() < data.combo_chance
	_set_mode(Mode.RECOVER)


func _wander(delta: float) -> void:
	_wander_time -= delta
	if _wander_time <= 0.0:
		_wander_time = randf_range(0.6, 1.4)
		var angle: float = randf() * TAU
		_wander_direction = Vector3(cos(angle), 0.0, sin(angle))
	steer(_wander_direction, data.move_speed * 0.5, delta)


func _set_mode(new_mode: Mode) -> void:
	mode = new_mode
	_mode_time = 0.0


func _on_interrupted() -> void:
	_chain = false
	if mode == Mode.WINDUP:
		_set_mode(Mode.RECOVER)


## El segundo golpe del combo avisa más corto (pero avisa).
func _current_windup() -> float:
	return windup_time() * (0.65 if _follow_up else 1.0)


# --- Placeholder ---

var _stick: MeshInstance3D


func _build_extras() -> void:
	var blindfold := MeshInstance3D.new()
	var band := CylinderMesh.new()
	band.top_radius = data.body_radius * 1.04
	band.bottom_radius = data.body_radius * 1.04
	band.height = 0.12
	blindfold.mesh = band
	blindfold.position.y = data.body_height * 0.8
	var band_material := _make_material(BLINDFOLD_COLOR, false)
	band_material.emission_enabled = true
	band_material.emission = BLINDFOLD_COLOR
	band_material.emission_energy_multiplier = 0.4
	blindfold.material_override = band_material
	visual.add_child(blindfold)

	_stick = MeshInstance3D.new()
	var stick_mesh := BoxMesh.new()
	stick_mesh.size = Vector3(0.09, 0.09, 1.0)
	_stick.mesh = stick_mesh
	_stick.position = Vector3(data.body_radius + 0.08, data.body_height * 0.55, -0.35)
	_stick.material_override = _make_material(Color(0.35, 0.24, 0.14))
	visual.add_child(_stick)


func _swing_stick() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_stick, "rotation:y", 1.1, 0.08)
	tween.tween_property(_stick, "rotation:y", 0.0, 0.3)
