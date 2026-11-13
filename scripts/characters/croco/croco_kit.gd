class_name CrocoKit
extends CharacterKit
## Mercenario Croco, el Llanero Solitario (KITS_MVP.md).
##   Arma Adaptativa: según la distancia al enemigo apuntado, escopeta, pistola o rifle.
##     El primer disparo después de cada cambio pega +30%.
##   Tiro por Contrato: se planta, carga hasta 1,5 s y atraviesa todo.
##   Ruta de Escape: voltereta con señuelo y rastro que acelera a los aliados.
##   Riel (definitiva): rayo de 4 s que gira lento; después, 3 s solo pistola.
## La Recompensa sobre los élites llega con los élites (Fase 3).

enum Mode { SHOTGUN, PISTOL, RIFLE }

const MODE_NAMES: Array[String] = ["Escopeta", "Pistola", "Rifle"]
const BULLET_COLOR := Color(0.92, 0.94, 1.0)
const BEAM_COLOR := Color(0.78, 0.9, 1.0, 0.85)
const STACK_KEY := &"contract_stacks"
const RINGS_SHADER: Shader = preload("res://assets/shaders/range_rings.gdshader")
const MARKER_SHADER: Shader = preload("res://assets/shaders/player_ring.gdshader")
## Margen exterior de los aros, más allá del límite del rifle.
const RINGS_OUTER_MARGIN := 2.0
## Que el cartel con el nombre del arma no aparezca más seguido que esto.
const MODE_TEXT_COOLDOWN := 0.6

var kd: CrocoKitData
var mode: Mode = Mode.PISTOL
var contract_cooldown: AbilityCooldown
## True si el próximo disparo lleva el bonus por cambio de modo.
var switch_bonus_ready: bool = false

var _attack_timer: float = 0.0
var _bullets: ProjectilePool
var _charging: bool = false
var _charge: float = 0.0
var _aim_line: MeshInstance3D
var _rail_time: float = 0.0
var _rail_direction: Vector3 = Vector3.FORWARD
var _rail_tick: float = 0.0
var _rail_beam: MeshInstance3D
var _overheat: float = 0.0
## Arma trabada mientras dispara (opción A).
var locked: bool = false
var _lock_target: Hurtbox
var _since_trigger: float = 99.0
var _mode_text_cooldown: float = 0.0
var _aimed: Hurtbox
var _rings: MeshInstance3D
var _rings_material: ShaderMaterial
var _rings_strength: float = 0.0
var _marker: MeshInstance3D
var _marker_material: ShaderMaterial


func _setup() -> void:
	kd = data.kit_data as CrocoKitData
	dodge_cooldown = AbilityCooldown.new(kd.dodge_recharge, kd.dodge_charges)
	contract_cooldown = AbilityCooldown.new(kd.contract_cooldown)
	_bullets = ProjectilePool.new()
	_bullets.name = "BulletPool"
	_bullets.top_level = true
	add_child(_bullets)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.09, 0.09, 0.4)
	_bullets.setup(mesh, Fx.flat_material(BULLET_COLOR, 1.5), 24)
	_aim_line = Fx.make_beam_mesh(Color(BEAM_COLOR, 0.25), 0.08)
	_aim_line.top_level = true
	_aim_line.visible = false
	add_child(_aim_line)
	_rail_beam = Fx.make_beam_mesh(BEAM_COLOR, kd.rail_width * 0.6)
	_rail_beam.top_level = true
	_rail_beam.visible = false
	add_child(_rail_beam)
	_build_range_visuals()


func _tick(delta: float) -> void:
	contract_cooldown.tick(cd_delta(delta))
	_attack_timer -= delta
	_overheat = maxf(_overheat - delta, 0.0)
	_mode_text_cooldown -= delta
	_update_lock(delta)
	_update_mode()
	_update_range_visuals(delta)
	if _charging:
		_update_charge(delta)
	if _rail_time > 0.0:
		_update_rail(delta)


func _handle_input() -> void:
	var input: PlayerInput = player.slot.input
	if _rail_time > 0.0 or _charging:
		return
	if player.has_buffered(PlayerInput.Action.ABILITY) and contract_cooldown.is_ready() \
			and can_start_skill():
		player.consume_buffered(PlayerInput.Action.ABILITY)
		cancel_scheduled()
		player.end_action()
		_start_charge()
	elif input.is_held(PlayerInput.Action.ATTACK) and _attack_timer <= 0.0 and player.can_act():
		_fire()


func move_speed_multiplier() -> float:
	return kd.rail_move_multiplier if _rail_time > 0.0 else 1.0


# --- Arma Adaptativa ---

## El enemigo apuntado: el más cercano a la mira dentro de un cono.
func aimed_enemy() -> Hurtbox:
	var best: Hurtbox = null
	var best_angle: float = deg_to_rad(kd.target_cone_deg)
	var here := Vector3(player.global_position.x, 0.0, player.global_position.z)
	for hurtbox: Hurtbox in CombatQuery.hurtboxes(player.get_tree(), DamageInfo.Team.ENEMIES):
		var to_enemy: Vector3 = hurtbox.flat_position() - here
		var distance: float = to_enemy.length()
		if distance < 0.01 or distance > kd.target_max_distance:
			continue
		var angle: float = player.aim_direction.angle_to(to_enemy)
		if angle < best_angle:
			best_angle = angle
			best = hurtbox
	return best


## Elige el modo según la distancia. Sin enemigo apuntado, se queda como está.
func mode_for_distance(distance: float) -> Mode:
	if distance <= kd.near_max_distance:
		return Mode.SHOTGUN
	if distance <= kd.mid_max_distance:
		return Mode.PISTOL
	return Mode.RIFLE


## Como mode_for_distance, pero con margen: para pasar a un modo más lejano hay que
## alejarse un poco más allá del límite, y para volver, acercarse un poco más acá.
func mode_with_hysteresis(distance: float) -> Mode:
	var farther: Mode = mode_for_distance(distance - kd.mode_hysteresis)
	if farther > mode:
		return farther
	var closer: Mode = mode_for_distance(distance + kd.mode_hysteresis)
	if closer < mode:
		return closer
	return mode


## Opción A: mientras dispara, el arma queda trabada. Se destraba si suelta el disparo un
## instante o si muere el enemigo con el que la trabó.
func _update_lock(delta: float) -> void:
	if player.slot.input.is_held(PlayerInput.Action.ATTACK):
		_since_trigger = 0.0
	else:
		_since_trigger += delta
	if not locked:
		return
	var target_gone: bool = _lock_target != null and (not is_instance_valid(_lock_target) \
			or not _lock_target.is_targetable())
	if _since_trigger > kd.lock_release_time or target_gone:
		locked = false
		_lock_target = null


func _update_mode() -> void:
	_aimed = aimed_enemy()
	if locked and _overheat <= 0.0:
		return
	var wanted: Mode = mode
	if _overheat > 0.0:
		wanted = Mode.PISTOL
	elif _aimed != null:
		wanted = mode_with_hysteresis(Vector3(player.global_position.x, 0.0,
				player.global_position.z).distance_to(_aimed.flat_position()))
	if wanted != mode:
		mode = wanted
		switch_bonus_ready = _overheat <= 0.0
		if _mode_text_cooldown <= 0.0:
			_mode_text_cooldown = MODE_TEXT_COOLDOWN
			say(MODE_NAMES[mode], Color(0.85, 0.9, 1.0), 0.75)


func _fire() -> void:
	if not locked:
		locked = true
		_lock_target = _aimed
	var bonus: float = 1.0 + (kd.mode_switch_bonus if switch_bonus_ready else 0.0)
	switch_bonus_ready = false
	player.face_aim_now()
	basic_recovery = true
	match mode:
		Mode.SHOTGUN:
			_attack_timer = kd.shotgun_interval / attack_speed()
			player.start_action(0.25, 0.6)
			for i: int in kd.shotgun_pellets:
				var t: float = float(i) / maxf(kd.shotgun_pellets - 1, 1) - 0.5
				var spread: float = deg_to_rad(t * kd.shotgun_spread_deg
						+ Combat.rng.randf_range(-3.0, 3.0))
				var info: DamageInfo = make_hit(kd.shotgun_damage * bonus)
				info.knockback = kd.shotgun_knockback
				_shoot(info, player.aim_direction.rotated(Vector3.UP, spread), kd.shotgun_speed,
						kd.shotgun_range)
			Events.camera_shake_requested.emit(Balance.combat.shake_light)
		Mode.PISTOL:
			_attack_timer = kd.pistol_interval / attack_speed()
			player.start_action(0.14, 0.8)
			var shot: DamageInfo = make_hit(kd.pistol_damage * bonus)
			shot.knockback = kd.pistol_knockback
			_shoot(shot, player.aim_direction, kd.pistol_speed, kd.pistol_range)
			Events.camera_shake_requested.emit(Balance.combat.shake_light * 0.6)
		Mode.RIFLE:
			_attack_timer = kd.rifle_interval / attack_speed()
			player.start_action(kd.rifle_burst_gap * kd.rifle_burst + 0.1, 0.7)
			for i: int in kd.rifle_burst:
				schedule(i * kd.rifle_burst_gap, _rifle_bullet.bind(bonus))


func _rifle_bullet(bonus: float) -> void:
	_shoot(make_hit(kd.rifle_damage * bonus), player.aim_direction, kd.rifle_speed, kd.rifle_range)


func _shoot(info: DamageInfo, direction: Vector3, speed: float, max_range: float) -> void:
	info.is_melee = false
	var from: Vector3 = player.global_position + Vector3.UP * 1.1 + direction * 0.5
	_bullets.fire(from, direction, speed, max_range, kd.bullet_radius, info,
			DamageInfo.Team.ENEMIES)


# --- Tiro por Contrato ---

func _start_charge() -> void:
	_charging = true
	_charge = 0.0
	_aim_line.visible = true


func _update_charge(delta: float) -> void:
	_charge += delta
	player.start_action(0.1, 0.0)  # plantado mientras carga
	player.face_aim_now()
	var from: Vector3 = player.global_position + Vector3.UP * 1.1
	Fx.place_beam(_aim_line, from, player.aim_direction, kd.contract_length)
	var ratio: float = clampf(_charge / kd.contract_full_charge, 0.0, 1.0)
	(_aim_line.material_override as StandardMaterial3D).albedo_color.a = 0.15 + 0.5 * ratio
	if not player.slot.input.is_held(PlayerInput.Action.ABILITY) or _charge >= kd.contract_max_hold:
		_fire_contract()


func _fire_contract() -> void:
	_charging = false
	_aim_line.visible = false
	contract_cooldown.use()
	var ratio: float = clampf(_charge / kd.contract_full_charge, 0.0, 1.0)
	var stacks: int = RunState.get_bonus(player.slot.index, STACK_KEY)
	var damage: float = lerpf(kd.contract_min_damage, kd.contract_max_damage, ratio) \
			* (1.0 + stacks * kd.contract_stack_bonus)
	var info: DamageInfo = make_hit(damage)
	info.is_melee = false
	info.knockback = 4.0
	info.hitstop = Balance.combat.hitstop_heavy
	info.shake = Balance.combat.shake_heavy * 0.5
	var from: Vector3 = player.global_position + Vector3.UP * 1.1
	var to: Vector3 = from + player.aim_direction * kd.contract_length
	var targets: Array[Hurtbox] = CombatQuery.in_line(player.get_tree(), DamageInfo.Team.ENEMIES,
			from, to, kd.contract_width)
	Combat.deliver(info, targets)
	Fx.beam(_world(), from, player.aim_direction, kd.contract_length, kd.contract_width * 0.5,
			BEAM_COLOR)
	player.start_action(0.2, 0.3)
	var killed: bool = false
	for hurtbox: Hurtbox in targets:
		var victim := hurtbox.receiver as Combatant
		if victim != null and victim.health.is_dead:
			killed = true
	if killed:
		contract_cooldown.reduce(kd.contract_cooldown * kd.contract_kill_refund)
		RunState.add_bonus(player.slot.index, STACK_KEY, 1)
		say("¡Contrato cumplido!", Color(0.85, 0.9, 1.0))


func _cancel_charge() -> void:
	if _charging:
		_charging = false
		_aim_line.visible = false


# --- Ruta de Escape ---

func do_dodge() -> void:
	_cancel_charge()
	dodge_cooldown.use()
	cancel_scheduled()
	var direction: Vector3 = dodge_direction()
	var start: Vector3 = player.global_position
	player.start_dodge(direction, kd.dodge_distance, kd.dodge_duration)
	var decoy := Decoy.new()
	_world().add_child(decoy)
	decoy.global_position = start
	decoy.setup(player.slot.color, data.placeholder_height, data.placeholder_radius,
			kd.decoy_duration, kd.decoy_priority)
	var trail := HasteTrail.new()
	_world().add_child(trail)
	trail.setup(player, start, start + direction * kd.dodge_distance, kd.trail_width,
			kd.trail_duration, kd.haste_duration, player.slot.color)


# --- Riel ---

func _use_ultimate() -> bool:
	_cancel_charge()
	_rail_time = kd.rail_duration
	_rail_direction = player.aim_direction
	_rail_tick = 0.0
	_rail_beam.visible = true
	say("¡Esto lo cobro doble!", Color.WHITE, 1.2)
	Events.camera_shake_requested.emit(Balance.combat.shake_heavy * 0.5)
	return true


func _update_rail(delta: float) -> void:
	_rail_time -= delta
	# Sigue a la mira, pero lento.
	var current: float = atan2(-_rail_direction.x, -_rail_direction.z)
	var target: float = atan2(-player.aim_direction.x, -player.aim_direction.z)
	var angle: float = rotate_toward(current, target, deg_to_rad(kd.rail_turn_speed_deg) * delta)
	_rail_direction = Vector3(-sin(angle), 0.0, -cos(angle))
	player.aim_direction = _rail_direction
	player.face_aim_now()
	var from: Vector3 = player.global_position + Vector3.UP * 1.1
	Fx.place_beam(_rail_beam, from, _rail_direction, kd.rail_length)
	_rail_tick -= delta
	if _rail_tick <= 0.0:
		_rail_tick += kd.rail_tick
		var info: DamageInfo = make_hit(kd.rail_dps * kd.rail_tick)
		info.is_melee = false
		info.hitstop = 0.0
		info.tags.append(&"tick")
		var targets: Array[Hurtbox] = CombatQuery.in_line(player.get_tree(),
				DamageInfo.Team.ENEMIES, from, from + _rail_direction * kd.rail_length, kd.rail_width)
		if Combat.deliver(info, targets) > 0:
			Events.camera_shake_requested.emit(Balance.combat.shake_light * 0.5)
	if _rail_time <= 0.0:
		_rail_beam.visible = false
		_overheat = kd.overheat_duration
		say("¡Recalentada!", Color(0.85, 0.85, 0.9))


func _world() -> Node:
	return player.get_parent()


# --- Aros de alcance y marca del enemigo apuntado ---

func _build_range_visuals() -> void:
	var outer: float = kd.mid_max_distance + RINGS_OUTER_MARGIN
	_rings = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * outer * 2.0
	_rings.mesh = plane
	_rings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rings.position.y = 0.05
	_rings_material = ShaderMaterial.new()
	_rings_material.shader = RINGS_SHADER
	_rings_material.set_shader_parameter("ring_color", player.slot.color.lightened(0.35))
	_rings_material.set_shader_parameter("near_m", kd.near_max_distance)
	_rings_material.set_shader_parameter("mid_m", kd.mid_max_distance)
	_rings_material.set_shader_parameter("outer_m", outer)
	_rings_material.set_shader_parameter("strength", 0.0)
	_rings.material_override = _rings_material
	player.add_child(_rings)

	_marker = MeshInstance3D.new()
	var marker_plane := PlaneMesh.new()
	marker_plane.size = Vector2.ONE * 1.8
	_marker.mesh = marker_plane
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.top_level = true
	_marker_material = ShaderMaterial.new()
	_marker_material.shader = MARKER_SHADER
	_marker_material.set_shader_parameter("inner_radius", 0.8)
	_marker_material.set_shader_parameter("fill_alpha", 0.0)
	_marker.material_override = _marker_material
	_marker.visible = false
	add_child(_marker)


func _update_range_visuals(delta: float) -> void:
	if _rings == null:
		return
	# Los aros se ven cuando hay a quién apuntar o mientras dispara; si no, se apagan.
	var wanted: float = 1.0 if kd.show_range_rings and _rail_time <= 0.0 \
			and (_aimed != null or locked) else 0.0
	_rings_strength = move_toward(_rings_strength, wanted, delta * 4.0)
	_rings_material.set_shader_parameter("strength", _rings_strength)
	_rings_material.set_shader_parameter("active_band", int(mode))
	_rings.visible = _rings_strength > 0.01
	var marked: Hurtbox = _lock_target if locked and is_instance_valid(_lock_target) else _aimed
	_marker.visible = marked != null and _rail_time <= 0.0
	if _marker.visible:
		_marker.global_position = marked.flat_position() + Vector3.UP * 0.06
		_marker.scale = Vector3.ONE * maxf(marked.radius * 1.6, 0.8)
		var alpha: float = 0.9 if locked else 0.45
		_marker_material.set_shader_parameter("ring_color", Color(1.0, 1.0, 1.0, alpha))


func debug_lines() -> Array[String]:
	var chips: Array[String] = []
	for i: int in MODE_NAMES.size():
		chips.append("[%s]" % MODE_NAMES[i] if i == mode else MODE_NAMES[i])
	var weapon: String = "Arma: " + " ".join(chips) + (" (trabada)" if locked else "")
	if switch_bonus_ready:
		weapon += "  +30%"
	var lines: Array[String] = [weapon]
	if _rail_time > 0.0:
		lines.append("RIEL %.1f s" % _rail_time)
	elif _overheat > 0.0:
		lines.append("Recalentada %.1f s" % _overheat)
	var contract: String = "Contrato " + ("listo" if contract_cooldown.is_ready()
			else "%.1f s" % contract_cooldown.time_until_ready())
	if _charging:
		contract = "Contrato cargando %d%%" % roundi(clampf(_charge / kd.contract_full_charge, 0.0, 1.0) * 100.0)
	lines.append(contract + " · bonus +%.1f%%" % (RunState.get_bonus(player.slot.index, STACK_KEY)
			* kd.contract_stack_bonus * 100.0))
	lines.append("Ruta de Escape %d/%d · Definitiva %d%%" % [dodge_cooldown.charges,
			dodge_cooldown.max_charges, roundi(ult_charge)])
	return lines


# --- HUD ---

func hud_chips() -> Array[String]:
	return MODE_NAMES


func hud_chip_active() -> int:
	return int(mode)


func hud_bar() -> Dictionary:
	if _rail_time > 0.0:
		return {"label": "RIEL %d s" % ceili(_rail_time), "value": _rail_time / kd.rail_duration,
				"color": Color(0.78, 0.9, 1.0), "pulse": true}
	if _charging:
		var ratio: float = clampf(_charge / kd.contract_full_charge, 0.0, 1.0)
		return {"label": "Contrato", "value": ratio, "color": Color(0.85, 0.9, 1.0), "pulse": ratio >= 1.0}
	return {}


func hud_abilities() -> Array[Dictionary]:
	return [cooldown_slot("Contrato", contract_cooldown), cooldown_slot("Ruta", dodge_cooldown),
			ult_slot("Riel")]
