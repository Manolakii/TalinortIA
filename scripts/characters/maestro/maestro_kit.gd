class_name MaestroKit
extends CharacterKit
## Maestro Uwey y Stewie, el Dúo de los Valles (KITS_MVP.md). Un jugador, dos cuerpos:
## el que controlás es el PlayerCharacter; el otro es un DuoCompanion que maneja la IA.
##   Maestro: Bastón de Caminante (18/18/34 + onda), Bastonazo (carga), Garrocha.
##   Stewie: Cabezazo, Refugio (2 s en el caparazón), Rodar.
##   Vínculo: a menos de 8 m, +10% de daño y de resistencia, con una línea que los une.
##   Caída: si cae uno, pasás al otro; el caído se levanta a los 15 s.
##   Cambio (botón de definitiva, CD 6 s): pasás a manejar al otro.
##   Relevo Total (Y+RB / R, con la barra llena): Cambio + 8 s de efecto según quién entra.
## Sendas: estructura lista (todo en Base). Sus efectos llegan con las mejoras (Fase 5).

enum Body { MAESTRO, STEWIE }
enum StewiePath { BASE, SHELL, CHARGE, SPIRIT }
enum MaestroPath { BASE, GUIDE, COMBAT, MIST }
enum Slot { BASIC, ABILITY, DODGE }

const BODY_NAMES: Array[String] = ["Maestro", "Stewie"]
const FORM_NAMES: Array[String] = ["Cría", "Joven", "Sabia"]
const SHELL_COLOR := Color(0.42, 0.32, 0.2)
const STAFF_COLOR := Color(0.45, 0.32, 0.18)
const COMPANION_SCRIPT := preload("res://scripts/characters/maestro/duo_companion.gd")

var kd: MaestroKitData
var controlled: Body = Body.MAESTRO
var companion: DuoCompanion
## Sendas por cuerpo y hueco: {Body: {Slot: [senda, nivel]}}. Todo Base por ahora.
var paths: Dictionary = {}
## Mejoras que recibió Stewie (cambia de forma con 3 y 6).
var stewie_upgrades: int = 0
var switch_cooldown: AbilityCooldown

var _hp: Dictionary[int, float] = {}
var _ability_cd: Dictionary[int, AbilityCooldown] = {}
var _dodge_cd: Dictionary[int, AbilityCooldown] = {}
var _combo_index: int = 0
var _combo_idle: float = 0.0
var _attack_timer: float = 0.0
var _charging: bool = false
var _charge: float = 0.0
var _relay_time: float = 0.0
var _relay_effect: StringName = &""
var _player_target: Node3D
var _bond_line: MeshInstance3D
var _extras: Node3D
var _bonded: bool = false


func _setup() -> void:
	kd = data.kit_data as MaestroKitData
	# Copia propia: la velocidad cambia según el cuerpo y no hay que pisar los datos compartidos.
	data = data.duplicate()
	player.data = data
	switch_cooldown = AbilityCooldown.new(kd.switch_cooldown)
	_ability_cd[Body.MAESTRO] = AbilityCooldown.new(kd.bastonazo_cooldown)
	_ability_cd[Body.STEWIE] = AbilityCooldown.new(kd.refuge_cooldown)
	_dodge_cd[Body.MAESTRO] = AbilityCooldown.new(kd.pole_recharge, kd.pole_charges)
	_dodge_cd[Body.STEWIE] = AbilityCooldown.new(kd.roll_recharge, kd.roll_charges)
	dodge_cooldown = _dodge_cd[Body.MAESTRO]
	_hp[Body.MAESTRO] = kd.maestro_max_health
	_hp[Body.STEWIE] = stewie_max_health()
	for body: int in [Body.MAESTRO, Body.STEWIE]:
		paths[body] = {Slot.BASIC: [0, 0], Slot.ABILITY: [0, 0], Slot.DODGE: [0, 0]}
	_bond_line = Fx.make_beam_mesh(Color(player.slot.color.lightened(0.5), 0.35), 0.06)
	_bond_line.top_level = true
	add_child(_bond_line)
	_apply_controlled_body()
	_spawn_companion.call_deferred()


func _spawn_companion() -> void:
	companion = COMPANION_SCRIPT.new() as DuoCompanion
	companion.name = "Companion_%s" % BODY_NAMES[_other(controlled)]
	companion.kit = self
	player.get_parent().add_child(companion)
	companion.global_position = player.global_position + Vector3(1.6, 0.0, 0.8)
	_dress_companion()


func stewie_form() -> int:
	return clampi(stewie_upgrades / kd.stewie_upgrades_per_form, 0, kd.stewie_health_by_form.size() - 1)


func stewie_max_health() -> float:
	return kd.stewie_health_by_form[stewie_form()]


func _max_health_of(body: int) -> float:
	return kd.maestro_max_health if body == Body.MAESTRO else stewie_max_health()


func _other(body: int) -> Body:
	return Body.STEWIE if body == Body.MAESTRO else Body.MAESTRO


# --- Cada frame ---

func _tick(delta: float) -> void:
	switch_cooldown.tick(delta)
	for body: int in _ability_cd:
		_ability_cd[body].tick(delta)
		_dodge_cd[body].tick(delta)
	_attack_timer -= delta
	if not player.is_in_action():
		_combo_idle += delta
		if _combo_idle > 0.6:
			_combo_index = 0
	if _charging:
		_update_charge(delta)
	if _relay_time > 0.0:
		_relay_time -= delta
		if _relay_time <= 0.0:
			_end_relay()
	_update_bond()


func _handle_input() -> void:
	var input: PlayerInput = player.slot.input
	if _charging:
		return
	var ability_cd: AbilityCooldown = _ability_cd[controlled]
	if player.has_buffered(PlayerInput.Action.ABILITY) and ability_cd.is_ready() and can_start_skill():
		player.consume_buffered(PlayerInput.Action.ABILITY)
		cancel_scheduled()
		player.end_action()
		basic_recovery = false
		if controlled == Body.MAESTRO:
			_charging = true
			_charge = 0.0
		else:
			_refuge()
		_mirror(Slot.ABILITY)
	elif input.is_held(PlayerInput.Action.ATTACK) and player.can_act():
		_controlled_basic()


## Botón de definitiva: siempre Cambio. Relevo Total con la combinación propia.
func _handle_ultimate() -> void:
	if player.has_buffered(PlayerInput.Action.RELAY) and ult_charge >= 100.0 \
			and can_start_skill() and _companion_ready():
		player.consume_buffered(PlayerInput.Action.RELAY)
		player.consume_buffered(PlayerInput.Action.ULTIMATE)
		ult_charge = 0.0
		_switch(true)
		return
	if player.has_buffered(PlayerInput.Action.ULTIMATE) and switch_cooldown.is_ready() \
			and can_start_skill() and _companion_ready() \
			and not player.slot.input.is_held(PlayerInput.Action.RELAY):
		player.consume_buffered(PlayerInput.Action.ULTIMATE)
		switch_cooldown.use()
		_switch(false)


func _companion_ready() -> bool:
	return companion != null and not companion.downed and companion.is_targetable()


# --- Vínculo ---

func is_bonded() -> bool:
	return companion != null and not companion.downed \
			and player.global_position.distance_to(companion.global_position) <= kd.bond_distance


func outgoing_multiplier() -> float:
	return 1.0 + (kd.bond_bonus if is_bonded() else 0.0)


func _update_bond() -> void:
	if companion == null:
		return
	var bonded: bool = is_bonded()
	if bonded != _bonded:
		_bonded = bonded
		var resist: float = 1.0 - (kd.bond_bonus if bonded else 0.0)
		player.health.damage_taken_multiplier = resist
		companion.health.damage_taken_multiplier = resist
	_bond_line.visible = bonded
	if bonded:
		var from: Vector3 = player.global_position + Vector3.UP * 0.6
		var to: Vector3 = companion.global_position + Vector3.UP * 0.6
		var offset: Vector3 = to - from
		if offset.length() > 0.1:
			Fx.place_beam(_bond_line, from, offset, Vector3(offset.x, 0.0, offset.z).length())


# --- Golpes compartidos por los dos cuerpos ---

func _hit(source: Node3D, base: float) -> DamageInfo:
	var info: DamageInfo = make_hit(base * _source_bonus(source), source)
	return info


## Forma Ancestral: Stewie gigante pega más.
func _source_bonus(source: Node3D) -> float:
	var stewie_is_source: bool = (source == player and controlled == Body.STEWIE) \
			or (source == companion and companion.identity == Body.STEWIE)
	if _relay_effect == &"ancestral" and stewie_is_source:
		return 1.0 + kd.ancestral_damage_bonus
	return 1.0


func _strike(source: Node3D, direction: Vector3, reach: float, angle: float, damage: float,
		knockback: float, extra_line: float = 0.0) -> void:
	var tree: SceneTree = player.get_tree()
	var targets: Array[Hurtbox] = CombatQuery.in_sector(tree, DamageInfo.Team.ENEMIES,
			source.global_position, direction, reach, angle)
	if extra_line > 0.0:
		for hurtbox: Hurtbox in CombatQuery.in_line(tree, DamageInfo.Team.ENEMIES,
				source.global_position, source.global_position + direction * extra_line,
				kd.staff_wave_width):
			if not targets.has(hurtbox):
				targets.append(hurtbox)
	var info: DamageInfo = _hit(source, damage)
	info.knockback = knockback
	Fx.slash(_world(), source.global_position, direction, reach, angle, player.slot.color, 0.1)
	if Combat.deliver(info, targets) > 0 and source is Combatant:
		(source as Combatant).freeze(info.hitstop)


func _maestro_staff(source: Node3D, direction: Vector3, index: int) -> void:
	var heavy: bool = index == 2
	_strike(source, direction, kd.staff_range, kd.staff_angle_deg, kd.staff_damage[index],
			4.0 if heavy else 1.5, kd.staff_wave_length if heavy else 0.0)
	if heavy:
		Fx.ring_burst(_world(), source.global_position + direction * 1.5, 1.4, player.slot.color)


func _stewie_headbutt(source: Node3D, direction: Vector3) -> void:
	_strike(source, direction, kd.headbutt_range, kd.headbutt_angle_deg, kd.headbutt_damage,
			kd.headbutt_knockback)


# --- Cuerpo controlado ---

func _controlled_basic() -> void:
	player.face_aim_now()
	_combo_idle = 0.0
	basic_recovery = false
	if controlled == Body.MAESTRO:
		var index: int = _combo_index
		_combo_index = (index + 1) % 3
		player.start_action(kd.staff_step_durations[index], 0.5)
		schedule(0.12, _controlled_staff_hit.bind(index))
	else:
		player.start_action(kd.headbutt_interval, 0.6)
		schedule(0.12, _controlled_headbutt_hit)
	_mirror(Slot.BASIC)


func _controlled_staff_hit(index: int) -> void:
	basic_recovery = true
	_maestro_staff(player, player.aim_direction, index)


func _controlled_headbutt_hit() -> void:
	basic_recovery = true
	_stewie_headbutt(player, player.aim_direction)


func _update_charge(delta: float) -> void:
	_charge += delta
	player.start_action(0.1, 0.0)
	player.face_aim_now()
	if not player.slot.input.is_held(PlayerInput.Action.ABILITY) or _charge >= kd.bastonazo_max_hold:
		_charging = false
		_ability_cd[Body.MAESTRO].use()
		var ratio: float = clampf(_charge / kd.bastonazo_full_charge, 0.0, 1.0)
		var from: Vector3 = player.global_position
		var info: DamageInfo = _hit(player, lerpf(kd.bastonazo_min_damage, kd.bastonazo_max_damage, ratio))
		info.knockback = 6.0
		info.hitstop = Balance.combat.hitstop_heavy
		info.shake = Balance.combat.shake_heavy * 0.4
		var targets: Array[Hurtbox] = CombatQuery.in_line(player.get_tree(), DamageInfo.Team.ENEMIES,
				from, from + player.aim_direction * kd.bastonazo_length, kd.bastonazo_width)
		Combat.deliver(info, targets)
		Fx.beam(_world(), from + Vector3.UP * 0.3, player.aim_direction, kd.bastonazo_length,
				kd.bastonazo_width * 0.6, Color(player.slot.color.lightened(0.5), 0.6), 0.25)
		player.start_action(0.25, 0.3)


func _refuge() -> void:
	_ability_cd[Body.STEWIE].use()
	player.start_action(kd.refuge_duration, 0.0)
	player.health.make_invulnerable(kd.refuge_duration)
	say("¡Refugio!", Color(0.8, 0.95, 0.8))
	var tween: Tween = player.create_tween()
	tween.tween_property(player.visual, "scale", Vector3(1.2, 0.6, 1.2), 0.1)
	tween.tween_interval(kd.refuge_duration - 0.2)
	tween.tween_property(player.visual, "scale", Vector3.ONE * _controlled_scale(), 0.1)


func do_dodge() -> void:
	_charging = false
	dodge_cooldown.use()
	cancel_scheduled()
	var direction: Vector3 = dodge_direction()
	if controlled == Body.MAESTRO:
		# Garrocha: salta apoyado en el bastón, por encima de los enemigos.
		player.start_dodge(direction, kd.pole_distance, kd.pole_duration)
		player.health.make_invulnerable(kd.pole_duration)
		var tween: Tween = player.create_tween()
		tween.tween_property(player.visual, "position:y", 1.2, kd.pole_duration * 0.5)
		tween.tween_property(player.visual, "position:y", 0.0, kd.pole_duration * 0.5)
	else:
		player.start_dodge(direction, kd.roll_distance, kd.roll_duration)
	_mirror(Slot.DODGE, direction)


# --- IA del compañero ---

func companion_think(body: DuoCompanion, delta: float) -> void:
	var to_player: Vector3 = player.global_position - body.global_position
	to_player.y = 0.0
	var distance: float = to_player.length()
	if distance > kd.teleport_distance:
		body.global_position = player.global_position + Vector3(1.5, 0.0, 1.0)
		body.reset_physics_interpolation()
		return
	var speed: float = body.move_speed
	if distance > kd.leash_distance:
		body.steer(to_player.normalized(), speed, delta)
		return
	if body.busy > 0.0:
		body.stop(delta)
		return
	var target: Node3D = _companion_target()
	if target != null:
		var to_target: Vector3 = target.global_position - body.global_position
		to_target.y = 0.0
		var reach: float = (kd.staff_range if body.identity == Body.MAESTRO else kd.headbutt_range) * 0.85
		if to_target.length() > reach:
			body.steer(to_target.normalized(), speed, delta)
		else:
			body.stop(delta)
			body.facing = to_target.normalized()
			if body.attack_timer <= 0.0:
				_companion_basic(body)
		return
	if distance > kd.follow_distance:
		body.steer(to_player.normalized(), speed * clampf(distance / 4.0, 0.4, 1.0), delta)
	else:
		body.stop(delta)


## Ataca a lo mismo que el jugador: lo último que golpeó, si sigue vivo y cerca.
func _companion_target() -> Node3D:
	var target := _player_target as Combatant
	if target == null or not is_instance_valid(target) or not target.is_targetable():
		return null
	if target.global_position.distance_to(player.global_position) > kd.companion_target_range:
		return null
	return target


func _companion_basic(body: DuoCompanion, direction: Vector3 = Vector3.ZERO) -> void:
	var facing: Vector3 = direction if direction != Vector3.ZERO else body.facing
	if body.identity == Body.MAESTRO:
		var total: float = 0.0
		for d: float in kd.staff_step_durations:
			total += d
		body.attack_timer = total
		body.busy = total
		for i: int in 3:
			schedule(0.12 + i * kd.staff_step_durations[0], _companion_staff_hit.bind(body, facing, i))
	else:
		body.attack_timer = kd.headbutt_interval
		body.busy = 0.3
		schedule(0.12, _companion_headbutt_hit.bind(body, facing))


func _companion_staff_hit(body: DuoCompanion, facing: Vector3, index: int) -> void:
	if is_instance_valid(body) and not body.downed:
		_maestro_staff(body, body.facing if facing == Vector3.ZERO else facing, index)


func _companion_headbutt_hit(body: DuoCompanion, facing: Vector3) -> void:
	if is_instance_valid(body) and not body.downed:
		_stewie_headbutt(body, facing)


## Lección del Maestro: Stewie copia cada técnica que hace el Maestro.
func _mirror(slot_kind: Slot, direction: Vector3 = Vector3.ZERO) -> void:
	if _relay_effect != &"lesson" or not _companion_ready():
		return
	var aim: Vector3 = direction if direction != Vector3.ZERO else player.aim_direction
	match slot_kind:
		Slot.BASIC:
			companion.attack_timer = 0.0
			_companion_basic(companion, aim)
		Slot.ABILITY:
			companion.invulnerable_shell = true
			companion.busy = kd.refuge_duration
			schedule(kd.refuge_duration, func() -> void: companion.invulnerable_shell = false)
		Slot.DODGE:
			companion.knockback_velocity = aim * (kd.roll_distance / kd.roll_duration)


# --- Cambio y Relevo Total ---

## Pasás a manejar al otro: se intercambian identidades y lugares.
func _switch(total: bool) -> void:
	cancel_scheduled()
	_charging = false
	player.end_action()
	_end_relay()
	var old_controlled: Body = controlled
	var player_pos: Vector3 = player.global_position
	var companion_pos: Vector3 = companion.global_position
	_hp[old_controlled] = player.health.current
	_hp[_other(old_controlled)] = companion.health.current
	controlled = _other(old_controlled)
	_apply_controlled_body()
	_dress_companion()
	player.global_position = companion_pos
	companion.global_position = player_pos
	player.reset_physics_interpolation()
	companion.reset_physics_interpolation()
	_entrance()
	if total:
		_start_relay()


func _entrance() -> void:
	if controlled == Body.MAESTRO:
		# Cae con la garrocha.
		player.visual.position.y = 2.0
		var tween: Tween = player.create_tween()
		tween.tween_property(player.visual, "position:y", 0.0, 0.25).set_ease(Tween.EASE_IN)
	else:
		# Cae rodando.
		var tween: Tween = player.create_tween()
		tween.tween_property(player.visual, "rotation:x", TAU, 0.3)
		tween.tween_callback(func() -> void: player.visual.rotation.x = 0.0)
	Fx.ring_burst(_world(), player.global_position, 1.8, player.slot.color)
	say("¡Te toca, %s!" % BODY_NAMES[controlled], Color.WHITE)


func _start_relay() -> void:
	_relay_time = kd.relay_duration
	if controlled == Body.STEWIE:
		_relay_effect = &"ancestral"
		var bonus_max: float = stewie_max_health() * (1.0 + kd.ancestral_health_bonus)
		var ratio: float = player.health.ratio()
		player.health.max_health = bonus_max
		player.health.current = bonus_max * ratio
		var tween: Tween = player.create_tween()
		tween.tween_property(player.visual, "scale", Vector3.ONE * kd.ancestral_scale, 0.3) \
				.set_trans(Tween.TRANS_BACK)
		say("¡Forma Ancestral!", Color(0.8, 0.95, 0.8), 1.4)
	else:
		_relay_effect = &"lesson"
		say("¡Lección del Maestro!", Color(0.95, 0.9, 0.8), 1.4)
	Events.camera_shake_requested.emit(Balance.combat.shake_heavy * 0.5)


func _end_relay() -> void:
	if _relay_effect == &"ancestral":
		var ratio: float = player.health.ratio()
		player.health.max_health = stewie_max_health()
		player.health.current = maxf(player.health.max_health * ratio, 1.0)
		var tween: Tween = player.create_tween()
		tween.tween_property(player.visual, "scale", Vector3.ONE, 0.25)
	_relay_effect = &""
	_relay_time = 0.0


func _controlled_scale() -> float:
	return kd.ancestral_scale if _relay_effect == &"ancestral" else 1.0


# --- Caída ---

## Si cae el que controlás y el otro está en pie, pasás al otro.
func handle_owner_death(_info: DamageInfo) -> bool:
	if not _companion_ready():
		return false  # cayeron los dos: cae el jugador
	var fallen: Body = controlled
	_switch(false)
	_hp[fallen] = 0.0
	companion.health.current = 1.0
	companion.set_downed(true, kd.fallen_revive_time)
	say("¡%s cayó! Se levanta en %d s" % [BODY_NAMES[fallen], roundi(kd.fallen_revive_time)],
			Color(1.0, 0.7, 0.7))
	return true


func _on_companion_died(_info: DamageInfo) -> void:
	companion.set_downed(true, kd.fallen_revive_time)
	say("¡%s cayó! Se levanta en %d s" % [BODY_NAMES[companion.identity],
			roundi(kd.fallen_revive_time)], Color(1.0, 0.7, 0.7))


func revive_companion() -> void:
	companion.set_downed(false)
	companion.health.restore_full()
	companion.health.current = companion.health.max_health * kd.fallen_revive_health
	Fx.ring_burst(_world(), companion.global_position, 1.5, player.slot.color)


# --- Puntos de daño para la barra y el objetivo de la IA ---

func _on_damage_dealt(_info: DamageInfo, target: Node3D) -> void:
	_player_target = target


## El compañero también carga la barra de Relevo Total.
func on_companion_damage(info: DamageInfo) -> void:
	add_ult(info.final_amount * data.ult_per_damage_dealt)


# --- Cuerpos ---

func _apply_controlled_body() -> void:
	var is_maestro: bool = controlled == Body.MAESTRO
	var height: float = kd.maestro_height if is_maestro else kd.stewie_height
	var radius: float = kd.maestro_radius if is_maestro else kd.stewie_radius
	player.rebuild_body(height, radius)
	player.visual.scale = Vector3.ONE
	player.health.max_health = _max_health_of(controlled)
	player.health.is_dead = false
	player.health.current = clampf(_hp.get(controlled, player.health.max_health), 1.0,
			player.health.max_health)
	player.health.changed.emit(player.health.current, player.health.max_health)
	data.move_speed = kd.maestro_move_speed if is_maestro else kd.stewie_move_speed
	player.data = data
	dodge_cooldown = _dodge_cd[controlled]
	if _extras != null:
		_extras.queue_free()
	_extras = Node3D.new()
	player.visual.add_child(_extras)
	_add_body_extras(_extras, controlled, height, radius)
	_bonded = false


func _dress_companion() -> void:
	if companion == null:
		return
	var body: Body = _other(controlled)
	var is_maestro: bool = body == Body.MAESTRO
	var height: float = kd.maestro_height if is_maestro else kd.stewie_height
	var radius: float = kd.maestro_radius if is_maestro else kd.stewie_radius
	var speed: float = kd.maestro_move_speed if is_maestro else kd.stewie_move_speed
	companion.become(body, height, radius, player.slot.color, speed, _max_health_of(body),
			_hp.get(body, _max_health_of(body)))
	companion.name = "Companion_%s" % BODY_NAMES[body]
	if not companion.died.is_connected(_on_companion_died):
		companion.died.connect(_on_companion_died)
		Events.hit_landed.connect(_on_any_hit)
	_add_body_extras(companion.extras(), body, height, radius)
	_bonded = false


func _on_any_hit(info: DamageInfo, target: Node3D) -> void:
	if companion != null and info.attacker == companion and target != companion:
		on_companion_damage(info)


## Caparazón para Stewie, bastón para el Maestro.
func _add_body_extras(parent: Node3D, body: int, height: float, radius: float) -> void:
	if body == Body.STEWIE:
		var shell := MeshInstance3D.new()
		var dome := SphereMesh.new()
		dome.radius = radius * 1.15
		dome.height = height * 0.9
		dome.is_hemisphere = true
		shell.mesh = dome
		shell.position.y = height * 0.45
		shell.material_override = Fx.flat_material(SHELL_COLOR)
		parent.add_child(shell)
	else:
		var staff := MeshInstance3D.new()
		var stick := CylinderMesh.new()
		stick.top_radius = 0.04
		stick.bottom_radius = 0.05
		stick.height = height * 1.05
		staff.mesh = stick
		staff.position = Vector3(radius + 0.12, height * 0.5, -0.15)
		staff.material_override = Fx.flat_material(STAFF_COLOR)
		parent.add_child(staff)


func _world() -> Node:
	return player.get_parent()


func debug_lines() -> Array[String]:
	var other: Body = _other(controlled)
	var companion_state: String = "?"
	if companion != null:
		companion_state = "caído %.0f s" % companion.downed_time if companion.downed \
				else "%d/%d" % [roundi(companion.health.current), roundi(companion.health.max_health)]
	var lines: Array[String] = [
		"Controlás: %s · %s (IA): %s" % [BODY_NAMES[controlled], BODY_NAMES[other], companion_state],
		"Stewie %s · Vínculo %s" % [FORM_NAMES[stewie_form()], "sí (+10%)" if is_bonded() else "no"],
	]
	var ability_name: String = "Bastonazo" if controlled == Body.MAESTRO else "Refugio"
	var dodge_name: String = "Garrocha" if controlled == Body.MAESTRO else "Rodar"
	var ability_cd: AbilityCooldown = _ability_cd[controlled]
	lines.append("%s %s · %s %d/%d" % [ability_name, "listo" if ability_cd.is_ready()
			else "%.1f s" % ability_cd.time_until_ready(), dodge_name, dodge_cooldown.charges,
			dodge_cooldown.max_charges])
	var relay: String = "Relevo Total %d%%" % roundi(ult_charge)
	if _relay_time > 0.0:
		relay = "%s %.1f s" % ["FORMA ANCESTRAL" if _relay_effect == &"ancestral" else "LECCIÓN",
				_relay_time]
	lines.append("Cambio %s · %s" % ["listo" if switch_cooldown.is_ready()
			else "%.1f s" % switch_cooldown.time_until_ready(), relay])
	return lines
