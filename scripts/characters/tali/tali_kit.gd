class_name TaliKit
extends CharacterKit
## Tali, el Especial Superviviente (KITS_MVP.md). Dos estados:
##   Normal: débil y con suerte. Piedrazo, Llamado Salvaje, Tropezón.
##   Furia (10 s): una bestia. Zarpazos, Aplastón, Embestida. Recibe 30% menos de daño.
## La barra de Furia se llena al recibir daño (rápido) y al pegar (más lento); al 100%
## entra en Furia sola. Al terminar, Resaca: lento y sin esquiva, y la barra bloqueada.

## Rojo-ocre: el naranja está reservado para los avisos enemigos.
const FURY_COLOR := Color(0.6, 0.14, 0.06)
const LUCK_TEXTS: Array[String] = ["¡Se resbaló!", "¡Le erró!", "¡Ni lo rozó!"]
const CALL_TEXTS: Array[String] = ["¡Pájaros!", "¡Bichos!", "¡UN GRONK!"]
const AURA_SHADER: Shader = preload("res://assets/shaders/fury_aura.gdshader")

var kd: TaliKitData
var in_fury: bool = false
## Barra de Furia, de 0 a 100.
var fury: float = 0.0
var call_cooldown: AbilityCooldown
var slam_cooldown: AbilityCooldown

var _fury_time: float = 0.0
var _lockout: float = 0.0
var _attack_timer: float = 0.0
var _combo_index: int = 0
var _combo_idle: float = 0.0
var _stumbling: bool = false
var _lucky_this_dodge: bool = false
var _charging: bool = false
var _charge_hit: Array[Node] = []
var _charge_previous: Vector3 = Vector3.ZERO
var _slam_tween: Tween
var _scale_tween: Tween
var _rocks: ProjectilePool
var _aura_material: ShaderMaterial


func _setup() -> void:
	kd = data.kit_data as TaliKitData
	dodge_cooldown = AbilityCooldown.new(kd.dodge_recharge, kd.dodge_charges)
	call_cooldown = AbilityCooldown.new(kd.call_cooldown)
	slam_cooldown = AbilityCooldown.new(kd.slam_cooldown)
	_build_rock_pool()
	_build_aura()


func _tick(delta: float) -> void:
	call_cooldown.tick(delta)
	slam_cooldown.tick(delta)
	_attack_timer -= delta
	_lockout = maxf(_lockout - delta, 0.0)
	if in_fury:
		_fury_time -= delta
		if _fury_time <= 0.0:
			_exit_fury()
	if not player.is_in_action():
		_combo_idle += delta
		if _combo_idle > kd.claw_combo_reset:
			_combo_index = 0
	if _charging:
		_update_charge()
	if not player.is_dodging():
		_stumbling = false
		_charging = false
	_update_aura()


func _handle_input() -> void:
	var input: PlayerInput = player.slot.input
	if in_fury:
		if player.has_buffered(PlayerInput.Action.ABILITY) and slam_cooldown.is_ready() \
				and can_start_skill():
			player.consume_buffered(PlayerInput.Action.ABILITY)
			_start_skill()
			_slam()
		elif input.is_held(PlayerInput.Action.ATTACK) and player.can_act():
			_claw()
	else:
		if player.has_buffered(PlayerInput.Action.ABILITY) and call_cooldown.is_ready() \
				and can_start_skill():
			player.consume_buffered(PlayerInput.Action.ABILITY)
			_start_skill()
			_wild_call()
		elif input.is_held(PlayerInput.Action.ATTACK) and _attack_timer <= 0.0 and player.can_act():
			_throw_rock()


## Corta la recuperación del golpe común para arrancar una habilidad.
func _start_skill() -> void:
	cancel_scheduled()
	player.end_action()
	basic_recovery = false


# --- Esquiva: Tropezón (Normal) o Embestida (Furia) ---

func can_dodge() -> bool:
	return super.can_dodge() and not is_exhausted()


func do_dodge() -> void:
	dodge_cooldown.use()
	cancel_scheduled()
	_cancel_slam()
	if in_fury:
		_charging = true
		_charge_hit.clear()
		_charge_previous = player.global_position
		player.start_dodge(dodge_direction(), kd.charge_distance, kd.charge_duration)
	else:
		_stumbling = true
		_lucky_this_dodge = false
		player.start_dodge(dodge_direction(), kd.stumble_distance, kd.stumble_duration)


## Tropezón: si un ataque lo iba a impactar, lo esquiva de casualidad.
func on_blocked_by_invulnerability(info: DamageInfo) -> void:
	if not _stumbling or _lucky_this_dodge or info.attacker_team != DamageInfo.Team.ENEMIES:
		return
	_lucky_this_dodge = true
	add_fury(kd.lucky_dodge_fury)
	var attacker: Combatant = info.attacker as Combatant if is_instance_valid(info.attacker) else null
	if attacker != null and attacker.is_targetable():
		attacker.status.apply(StatusEffects.STUN, kd.lucky_dodge_unbalance)
	_say("¡De casualidad!", Color(0.75, 0.9, 1.0))


## Embestida: tira al piso a todo lo que atraviesa.
func _update_charge() -> void:
	var now: Vector3 = player.global_position
	var targets: Array[Hurtbox] = CombatQuery.in_line(player.get_tree(), DamageInfo.Team.ENEMIES,
			_charge_previous, now + player.aim_direction * 0.4, kd.charge_width)
	for hurtbox: Hurtbox in targets:
		if _charge_hit.has(hurtbox.receiver):
			continue
		_charge_hit.append(hurtbox.receiver)
		var info: DamageInfo = Combat.make_hit(player, DamageInfo.Team.PLAYERS, 0.0, 0.0, 1.0)
		info.stun = kd.charge_knockdown
		info.knockback = 6.0
		info.hitstop = Balance.combat.hitstop_light
		info.shake = Balance.combat.shake_light
		# Empuja hacia el costado de la carga.
		var closest: Vector3 = Geometry3D.get_closest_point_to_segment(
				hurtbox.global_position, _charge_previous, now)
		info.origin = closest - (hurtbox.global_position - closest).normalized() * 0.1
		hurtbox.take_hit(info)
	_charge_previous = now


# --- Suerte y Furia ---

## Suerte: en Normal, 20% de que un ataque enemigo falle solo.
func try_avoid(info: DamageInfo) -> String:
	if in_fury or info.attacker_team != DamageInfo.Team.ENEMIES:
		return ""
	if Combat.roll(kd.luck_miss_chance):
		return LUCK_TEXTS[Combat.rng.randi() % LUCK_TEXTS.size()]
	return ""


func _on_damage_taken(info: DamageInfo) -> void:
	if in_fury:
		return
	var multiplier: float = 1.0
	if _is_back_hit(info) or _is_surrounded():
		multiplier = kd.fury_bonus_multiplier
	add_fury(info.final_amount * kd.fury_per_damage_taken * multiplier)


func _on_damage_dealt(info: DamageInfo, _target: Node3D) -> void:
	if not in_fury:
		add_fury(info.final_amount * kd.fury_per_damage_dealt)


func add_fury(points: float) -> void:
	if in_fury or _lockout > 0.0 or points <= 0.0:
		return
	fury = minf(fury + points, 100.0)
	if fury >= 100.0:
		_enter_fury()


func is_exhausted() -> bool:
	return player.status.has(StatusEffects.EXHAUSTED)


func move_speed_multiplier() -> float:
	return kd.exhausted_speed_multiplier if is_exhausted() else 1.0


func _enter_fury() -> void:
	in_fury = true
	fury = 100.0
	_lockout = 0.0
	_fury_time = kd.fury_duration
	_combo_index = 0
	_attack_timer = 0.0
	cancel_scheduled()
	player.end_action()
	player.status.clear(StatusEffects.EXHAUSTED)
	player.health.damage_taken_multiplier = kd.fury_damage_taken_multiplier
	_tween_scale(kd.fury_body_scale)
	_say("¡FURIA!", FURY_COLOR.lightened(0.3), 1.6)
	Fx.ring_burst(_world(), player.global_position, 4.0, FURY_COLOR, 0.45)
	Events.camera_shake_requested.emit(Balance.combat.shake_heavy * 0.7)


func _exit_fury() -> void:
	in_fury = false
	fury = 0.0
	_charging = false
	cancel_scheduled()
	_cancel_slam()
	player.end_action()
	player.health.damage_taken_multiplier = 1.0
	player.status.apply(StatusEffects.EXHAUSTED, kd.exhausted_duration)
	_lockout = kd.fury_lockout
	_tween_scale(1.0)
	_say("Resaca...", Color(0.75, 0.75, 0.8))


func _is_back_hit(info: DamageInfo) -> bool:
	var to_attacker := Vector3(info.origin.x - player.global_position.x, 0.0,
			info.origin.z - player.global_position.z)
	if to_attacker.length_squared() < 0.0001:
		return false
	return player.aim_direction.dot(to_attacker.normalized()) < -0.25


func _is_surrounded() -> bool:
	var count: int = 0
	for hurtbox: Hurtbox in CombatQuery.in_circle(player.get_tree(), DamageInfo.Team.ENEMIES,
			player.global_position, kd.surrounded_radius):
		count += 1
	return count >= kd.surrounded_count


# --- Normal: Piedrazo ---

func _throw_rock() -> void:
	_attack_timer = kd.rock_interval
	player.start_action(0.18, 0.75)
	basic_recovery = true
	var spread: float = deg_to_rad(Combat.rng.randf_range(-kd.rock_spread_deg, kd.rock_spread_deg))
	var direction: Vector3 = player.aim_direction.rotated(Vector3.UP, spread)
	var lucky: bool = Combat.roll(kd.lucky_shot_chance)
	var info: DamageInfo = Combat.make_hit(player, DamageInfo.Team.PLAYERS, kd.rock_damage,
			1.0 if lucky else data.crit_chance, data.crit_multiplier)
	info.is_melee = false
	info.knockback = 1.5
	info.hitstop = Balance.combat.hitstop_light
	if info.is_crit:
		info.hitstop += Balance.combat.hitstop_crit_bonus
	if lucky:
		info.stun = kd.lucky_shot_stun
		info.shake = Balance.combat.shake_light
		info.tags.append(&"lucky_shot")
	var from: Vector3 = player.global_position + Vector3.UP * 1.1 + direction * 0.5
	_rocks.fire(from, direction, kd.rock_speed, kd.rock_range, kd.rock_radius, info,
			DamageInfo.Team.ENEMIES, _on_rock_hit)


func _on_rock_hit(target: Node3D, info: DamageInfo) -> void:
	if info.has_tag(&"lucky_shot"):
		Events.floating_text_requested.emit(target.global_position + Vector3.UP * 2.6,
				"¡Tiro de Suerte!", Color(0.75, 0.9, 1.0))


# --- Normal: Llamado Salvaje ---

func _wild_call() -> void:
	call_cooldown.use()
	player.face_aim_now()
	player.start_action(0.3, 0.2)
	var kind: int = Combat.weighted_pick([kd.call_weight_birds, kd.call_weight_bugs,
			kd.call_weight_gronk])
	_say(CALL_TEXTS[kind], Color.WHITE, 1.2 if kind == WildCallEffect.Kind.GRONK else 1.0)
	schedule(0.2, _spawn_call.bind(kind, player.aim_direction))


func _spawn_call(kind: int, direction: Vector3) -> void:
	var effect := WildCallEffect.new()
	_world().add_child(effect)
	effect.launch(self, kd, kind as WildCallEffect.Kind, direction)


# --- Furia: Zarpazos ---

func _claw() -> void:
	var index: int = _combo_index
	player.face_aim_now()
	player.start_action(kd.claw_combo_time / 3.0, kd.claw_move_multiplier)
	_combo_index = (index + 1) % 3
	_combo_idle = 0.0
	basic_recovery = false
	schedule(0.1, _claw_hit.bind(index))


func _claw_hit(index: int) -> void:
	basic_recovery = true
	var heavy: bool = index == 2
	var direction: Vector3 = player.aim_direction
	var info: DamageInfo = Combat.make_hit(player, DamageInfo.Team.PLAYERS,
			kd.claw_damage[index], data.crit_chance, data.crit_multiplier)
	var combat: CombatConfig = Balance.combat
	info.knockback = 6.0 if heavy else 2.5
	info.hitstop = combat.hitstop_heavy if heavy else combat.hitstop_light
	if info.is_crit:
		info.hitstop += combat.hitstop_crit_bonus
	info.shake = combat.shake_heavy * 0.5 if heavy else combat.shake_light
	if heavy:
		info.stun = kd.claw_third_stun
		info.tags.append(&"launch")
	Fx.slash(_world(), player.global_position, direction, kd.claw_range, kd.claw_angle_deg,
			player.slot.color)
	if heavy:
		Fx.ring_burst(_world(), player.global_position + direction * 1.3, 1.6, player.slot.color)
	var targets: Array[Hurtbox] = CombatQuery.in_sector(player.get_tree(),
			DamageInfo.Team.ENEMIES, player.global_position, direction, kd.claw_range,
			kd.claw_angle_deg)
	if Combat.deliver(info, targets) > 0:
		player.freeze(info.hitstop)


# --- Furia: Aplastón ---

func _slam() -> void:
	slam_cooldown.use()
	var from: Vector3 = player.global_position
	var target := Vector3(player.aim_point.x, 0.0, player.aim_point.z)
	var offset: Vector3 = (target - Vector3(from.x, 0.0, from.z)).limit_length(kd.slam_max_distance)
	player.face_aim_now()
	player.start_action(kd.slam_air_time, 0.0)
	player.action_velocity = offset / kd.slam_air_time
	_slam_tween = player.create_tween()
	_slam_tween.tween_property(player.visual, "position:y", 1.8, kd.slam_air_time * 0.5) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_slam_tween.tween_property(player.visual, "position:y", 0.0, kd.slam_air_time * 0.5) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	schedule(kd.slam_air_time, _slam_land)


func _slam_land() -> void:
	var center: Vector3 = player.global_position
	var info: DamageInfo = Combat.make_hit(player, DamageInfo.Team.PLAYERS, kd.slam_damage,
			data.crit_chance, data.crit_multiplier)
	info.stun = kd.slam_stun
	info.knockback = 7.0
	info.hitstop = Balance.combat.hitstop_heavy
	info.shake = 0.0
	var targets: Array[Hurtbox] = CombatQuery.in_circle(player.get_tree(), DamageInfo.Team.ENEMIES,
			center, kd.slam_radius)
	if Combat.deliver(info, targets) > 0:
		player.freeze(Balance.combat.hitstop_heavy)
	Events.camera_shake_requested.emit(Balance.combat.shake_heavy)
	Fx.ring_burst(_world(), center, kd.slam_radius, player.slot.color, 0.4)


func _cancel_slam() -> void:
	if _slam_tween != null and _slam_tween.is_valid():
		_slam_tween.kill()
	player.visual.position.y = 0.0


# --- Definitiva: La Bestia de Talinorthland ---

func _use_ultimate() -> bool:
	if in_fury:
		return _toss()
	_roar()
	_enter_fury()
	return true


## En Normal: rugido que empuja y asusta a los cercanos durante 2 s.
func _roar() -> void:
	var center: Vector3 = player.global_position
	for hurtbox: Hurtbox in CombatQuery.in_circle(player.get_tree(), DamageInfo.Team.ENEMIES,
			center, kd.roar_radius):
		var enemy := hurtbox.receiver as Enemy
		if enemy == null:
			continue
		var away := Vector3(enemy.global_position.x - center.x, 0.0, enemy.global_position.z - center.z)
		enemy.knockback_velocity = away.normalized() * kd.roar_knockback
		enemy.fear_origin = center
		enemy.status.apply(StatusEffects.FEAR, kd.roar_fear)
	Fx.ring_burst(_world(), center, kd.roar_radius, FURY_COLOR, 0.5)


## En Furia: Revoleo. Agarra al enemigo más grande, lo tira contra los demás y alarga la Furia.
func _toss() -> bool:
	var victim: Enemy = _biggest_enemy_near()
	if victim == null:
		_say("¡No hay a quién revolear!", Color(0.8, 0.8, 0.85))
		return false
	victim.set_controlled(true)
	cancel_scheduled()
	player.start_action(0.6, 0.0)
	var to_victim: Vector3 = victim.global_position - player.global_position
	to_victim.y = 0.0
	if to_victim.length_squared() > 0.01:
		player.aim_direction = to_victim.normalized()
		player.face_aim_now()
	_fury_time += kd.toss_fury_extension
	_say("¡Revoleo!", FURY_COLOR.lightened(0.3), 1.3)

	var above_head: Vector3 = player.global_position + Vector3.UP * 2.3
	var landing: Vector3 = _toss_landing()
	var tween: Tween = player.create_tween()
	tween.tween_property(victim, "global_position", above_head, 0.18)
	tween.tween_property(victim, "global_position", landing, 0.38) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_toss_land.bind(victim, landing))
	return true


func _biggest_enemy_near() -> Enemy:
	var best: Enemy = null
	for hurtbox: Hurtbox in CombatQuery.in_circle(player.get_tree(), DamageInfo.Team.ENEMIES,
			player.global_position, kd.toss_grab_range):
		var enemy := hurtbox.receiver as Enemy
		if enemy == null:
			continue
		if best == null or enemy.data.size_rank > best.data.size_rank \
				or (enemy.data.size_rank == best.data.size_rank \
				and enemy.health.max_health > best.health.max_health):
			best = enemy
	return best


## Hacia donde apunta, sin atravesar paredes.
func _toss_landing() -> Vector3:
	var from: Vector3 = player.global_position + Vector3.UP
	var to: Vector3 = from + player.aim_direction * kd.toss_distance
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 512)
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	var landing: Vector3 = (hit["position"] as Vector3) - player.aim_direction * 0.8 \
			if not hit.is_empty() else to
	return Vector3(landing.x, 0.0, landing.z)


func _toss_land(victim: Enemy, landing: Vector3) -> void:
	var combat: CombatConfig = Balance.combat
	if is_instance_valid(victim):
		victim.global_position = landing
		victim.set_controlled(false)
		var thrown: DamageInfo = Combat.make_hit(player, DamageInfo.Team.PLAYERS,
				kd.toss_thrown_damage, data.crit_chance, data.crit_multiplier)
		thrown.stun = kd.toss_knockdown
		thrown.hitstop = combat.hitstop_heavy
		thrown.tags.append(&"thrown")
		victim.receive_hit(thrown)
	var splash: DamageInfo = Combat.make_hit(player, DamageInfo.Team.PLAYERS,
			kd.toss_splash_damage, data.crit_chance, data.crit_multiplier)
	splash.origin = landing
	splash.stun = kd.toss_knockdown
	splash.knockback = 7.0
	splash.hitstop = combat.hitstop_heavy
	var targets: Array[Hurtbox] = []
	for hurtbox: Hurtbox in CombatQuery.in_circle(player.get_tree(), DamageInfo.Team.ENEMIES,
			landing, kd.toss_splash_radius):
		if hurtbox.receiver != victim:
			targets.append(hurtbox)
	Combat.deliver(splash, targets)
	Events.camera_shake_requested.emit(combat.shake_heavy)
	Fx.ring_burst(_world(), landing, kd.toss_splash_radius, player.slot.color, 0.4)


# --- Visual ---

func _build_rock_pool() -> void:
	_rocks = ProjectilePool.new()
	_rocks.name = "RockPool"
	_rocks.top_level = true
	add_child(_rocks)
	var mesh := SphereMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.26
	mesh.radial_segments = 8
	mesh.rings = 4
	_rocks.setup(mesh, Fx.flat_material(Color(0.5, 0.47, 0.42)), 6)


func _build_aura() -> void:
	var aura := MeshInstance3D.new()
	aura.name = "FuryAura"
	var sphere := SphereMesh.new()
	sphere.radius = data.placeholder_radius * 2.0
	sphere.height = data.placeholder_height * 1.3
	aura.mesh = sphere
	aura.position.y = data.placeholder_height * 0.5
	aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_aura_material = ShaderMaterial.new()
	_aura_material.shader = AURA_SHADER
	_aura_material.set_shader_parameter("aura_color", FURY_COLOR)
	aura.material_override = _aura_material
	player.visual.add_child(aura)


func _update_aura() -> void:
	var intensity: float = 1.0 if in_fury else fury / 100.0 * 0.55
	_aura_material.set_shader_parameter("intensity", intensity)


func _tween_scale(target: float) -> void:
	if _scale_tween != null and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = player.create_tween()
	_scale_tween.tween_property(player.visual, "scale", Vector3.ONE * target, 0.25) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _say(text: String, color: Color, size: float = 1.0) -> void:
	var damage_numbers: Node = player.get_tree().get_first_node_in_group(&"damage_numbers")
	if damage_numbers != null:
		damage_numbers.show_text(player.global_position + Vector3.UP * 3.4, text, color, size)


func _world() -> Node:
	return player.get_parent()


func debug_lines() -> Array[String]:
	var form: String = "Normal"
	if in_fury:
		form = "FURIA (%.1f s)" % _fury_time
	elif is_exhausted():
		form = "Resaca"
	var fury_line: String = "Furia %d%%" % roundi(fury)
	if _lockout > 0.0 and not in_fury:
		fury_line += "  (bloqueada %.0f s)" % ceilf(_lockout)
	var lines: Array[String] = ["Forma: " + form, fury_line,
			"Definitiva %d%%" % roundi(ult_charge)]
	if in_fury:
		lines.append("Embestida %d/%d · Aplastón %s" % [dodge_cooldown.charges,
				dodge_cooldown.max_charges, _cd_text(slam_cooldown)])
	else:
		lines.append("Tropezón %d/%d · Llamado %s" % [dodge_cooldown.charges,
				dodge_cooldown.max_charges, _cd_text(call_cooldown)])
	return lines


func _cd_text(cd: AbilityCooldown) -> String:
	return "listo" if cd.is_ready() else "%.1f s" % cd.time_until_ready()
