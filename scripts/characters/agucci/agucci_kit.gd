class_name AgucciKit
extends CharacterKit
## Agucci, el Asesino de las Sombras (KITS_MVP.md).
##   Hambre (0-100): Lucidez (0-30) = crítico garantizado por la espalda;
##     Hambre (31-99) = +1% de daño por punto; 100 = Posesión (6 s).
##   Katana y Plomo: 3 cortes, patada y UZI en abanico. Los golpes comunes bajan el Hambre.
##   Paso de Sombra: kunai; al reactivar viaja hasta él cortando todo en el camino.
##   Disolverse: se hunde en su sombra y reaparece adelante, intangible.
##   Noche del Valle sin Luz (definitiva): 8 s en que la sombra repite cada golpe.
## Posesión: camina solo al enemigo más cercano y ataca solo; la habilidad y la esquiva
## pasan a ser Mordida de Sombra y Abrazo del Valle sin Luz (cuestan vida, curan si conectan).

## Capas de física: paredes de la sala (1) y obstáculos como rocas (512).
const WORLD_LAYER := 1
const OBSTACLE_LAYER := 512

## Violeta = sombra (GDD, colores reservados).
const SHADOW_COLOR := Color(0.45, 0.2, 0.72)
const AURA_SHADER: Shader = preload("res://assets/shaders/fury_aura.gdshader")
const RING_SHADER: Shader = preload("res://assets/shaders/player_ring.gdshader")

var kd: AgucciKitData
## Barra de Hambre, de 0 a 100.
var hunger: float = 0.0
var possessed: bool = false
var step_cooldown: AbilityCooldown
var bite_cooldown: AbilityCooldown
var embrace_cooldown: AbilityCooldown

var _combo_index: int = 0
var _combo_idle: float = 0.0
var _possession_time: float = 0.0
var _auto_timer: float = 0.0
var _embrace_time: float = 0.0
var _embrace_tick: float = 0.0
var _night_time: float = 0.0
var _since_attack: float = 99.0
var _kunai_active: bool = false
var _kunai_time: float = 0.0
var _kunai_position: Vector3 = Vector3.ZERO
var _kunai_target: Node3D
var _kunai_marker: MeshInstance3D
var _saved_collision_mask: int = 515
var _in_shadow: bool = false
var _dissolve_direction: Vector3 = Vector3.FORWARD
var _projectiles: ProjectilePool
var _shadow_material: ShaderMaterial
var _shadow_disc: MeshInstance3D
var _aura_material: ShaderMaterial
var _body_material: StandardMaterial3D
var _base_body_color: Color


func _setup() -> void:
	kd = data.kit_data as AgucciKitData
	dodge_cooldown = AbilityCooldown.new(kd.dissolve_recharge, kd.dissolve_charges)
	step_cooldown = AbilityCooldown.new(kd.step_cooldown)
	bite_cooldown = AbilityCooldown.new(kd.bite_cooldown)
	embrace_cooldown = AbilityCooldown.new(kd.embrace_cooldown)
	_build_visuals()


func _tick(delta: float) -> void:
	step_cooldown.tick(cd_delta(delta))
	bite_cooldown.tick(cd_delta(delta))
	embrace_cooldown.tick(cd_delta(delta))
	_since_attack += delta
	if not player.is_in_action():
		_combo_idle += delta
		if _combo_idle > kd.combo_reset:
			_combo_index = 0
	if _kunai_active:
		_kunai_time -= delta
		if is_instance_valid(_kunai_target) and _kunai_target is Combatant \
				and (_kunai_target as Combatant).is_targetable():
			_kunai_position = _kunai_target.global_position
		_kunai_marker.global_position = _kunai_position + Vector3.UP * 0.3
		if _kunai_time <= 0.0:
			_clear_kunai()
	if _night_time > 0.0:
		_night_time -= delta
		player.hidden_from_enemies = _since_attack > kd.night_hide_after
		if _night_time <= 0.0:
			player.hidden_from_enemies = false
	if possessed:
		_update_possession(delta)
	elif _tali_nearby():
		hunger = maxf(hunger - kd.tali_synergy_decay * delta, 0.0)
	_update_visuals()


func _handle_input() -> void:
	if possessed:
		if player.has_buffered(PlayerInput.Action.ABILITY) and bite_cooldown.is_ready() \
				and can_start_skill():
			player.consume_buffered(PlayerInput.Action.ABILITY)
			_start_skill()
			_shadow_bite()
		return
	if player.has_buffered(PlayerInput.Action.ABILITY) and can_start_skill():
		if _kunai_active:
			player.consume_buffered(PlayerInput.Action.ABILITY)
			_start_skill()
			_shadow_dash()
		elif step_cooldown.is_ready():
			player.consume_buffered(PlayerInput.Action.ABILITY)
			_start_skill()
			_throw_kunai()
	elif player.slot.input.is_held(PlayerInput.Action.ATTACK) and player.can_act():
		_combo_step()


func _start_skill() -> void:
	cancel_scheduled()
	player.end_action()
	basic_recovery = false
	_since_attack = 0.0


# --- Hambre ---

func add_hunger(points: float) -> void:
	if possessed:
		return
	hunger = clampf(hunger + points, 0.0, 100.0)
	if hunger >= 100.0:
		_enter_possession()


func is_lucid() -> bool:
	return not possessed and hunger <= _lucidity_max()


func outgoing_multiplier() -> float:
	if possessed:
		return kd.possession_damage_multiplier
	if hunger > _lucidity_max():
		return 1.0 + hunger * kd.hunger_damage_per_point
	return 1.0


func move_speed_multiplier() -> float:
	return kd.possession_speed_multiplier if possessed else 1.0


func _tali_nearby() -> bool:
	for node: Node in player.get_tree().get_nodes_in_group(&"players"):
		var other := node as PlayerCharacter
		if other == null or other == player or not (other.kit is TaliKit):
			continue
		if other.global_position.distance_to(player.global_position) <= kd.tali_synergy_radius:
			return true
	return false


## Golpe a cada objetivo por separado: en Lucidez, por la espalda es crítico seguro.
## `from` es desde dónde viene el golpe (por defecto, donde está Agucci).
func _hit_each(targets: Array[Hurtbox], base: float, setup: Callable = Callable(),
		is_basic: bool = true, from: Variant = null) -> int:
	var origin: Vector3 = from as Vector3 if from != null else player.global_position
	var landed: int = 0
	for hurtbox: Hurtbox in targets:
		var info: DamageInfo = make_hit(base)
		info.origin = origin
		var from_behind: bool = _is_behind(hurtbox, origin)
		if from_behind and has_upgrade(&"agucci_espalda_letal"):
			info.amount *= 1.3
		if is_lucid() and from_behind and not info.is_crit:
			info.is_crit = true
			info.amount *= player.crit_multiplier()
			info.hitstop += Balance.combat.hitstop_crit_bonus
		if setup.is_valid():
			setup.call(info)
		if hurtbox.take_hit(info):
			landed += 1
	if is_basic and landed > 0:
		hunger = maxf(hunger - kd.hunger_drop_per_basic_hit * landed, 0.0)
	return landed


func _is_behind(hurtbox: Hurtbox, origin: Vector3) -> bool:
	var enemy := hurtbox.receiver as Enemy
	if enemy == null:
		return false
	var to_agucci: Vector3 = origin - enemy.global_position
	to_agucci.y = 0.0
	return to_agucci.length_squared() > 0.01 and enemy.facing.dot(to_agucci.normalized()) < -0.3


# --- Katana y Plomo ---

func _combo_step() -> void:
	var index: int = _combo_index
	_combo_index = (index + 1) % kd.step_durations.size()
	_combo_idle = 0.0
	_since_attack = 0.0
	basic_recovery = false
	player.face_aim_now()
	player.start_action(kd.step_durations[index] / attack_speed(), 0.55)
	if index < 3:
		schedule(0.06, _cut.bind(index))
	elif index == 3:
		schedule(0.1, _kick)
	else:
		for i: int in _uzi_bullets():
			schedule(0.05 + i * kd.uzi_gap, _uzi_bullet.bind(i))


func _cut(index: int) -> void:
	basic_recovery = true
	var direction: Vector3 = player.aim_direction
	Fx.slash(_world(), player.global_position, direction, kd.cut_range, kd.cut_angle_deg,
			player.slot.color, 0.1)
	var targets: Array[Hurtbox] = CombatQuery.in_sector(player.get_tree(), DamageInfo.Team.ENEMIES,
			player.global_position, direction, kd.cut_range, kd.cut_angle_deg)
	if _hit_each(targets, kd.cut_damage[index], _setup_cut) > 0:
		player.freeze(Balance.combat.hitstop_light)


func _setup_cut(info: DamageInfo) -> void:
	info.knockback = 1.5


func _kick() -> void:
	basic_recovery = true
	var targets: Array[Hurtbox] = CombatQuery.in_sector(player.get_tree(), DamageInfo.Team.ENEMIES,
			player.global_position, player.aim_direction, kd.kick_range, kd.kick_angle_deg)
	if _hit_each(targets, kd.kick_damage, _setup_kick) > 0:
		player.freeze(Balance.combat.hitstop_light)


func _setup_kick(info: DamageInfo) -> void:
	info.knockback = kd.kick_knockback


func _uzi_bullet(i: int) -> void:
	basic_recovery = true
	var t: float = float(i) / maxf(_uzi_bullets() - 1, 1) - 0.5
	var direction: Vector3 = player.aim_direction.rotated(Vector3.UP, deg_to_rad(t * kd.uzi_spread_deg))
	var info: DamageInfo = make_hit(kd.uzi_damage)
	info.is_melee = false
	_projectiles.fire(player.global_position + Vector3.UP * 1.1 + direction * 0.5, direction,
			kd.uzi_speed, kd.uzi_range, 0.2, info, DamageInfo.Team.ENEMIES, _on_uzi_hit)


func _on_uzi_hit(_target: Node3D, _info: DamageInfo) -> void:
	hunger = maxf(hunger - kd.hunger_drop_per_basic_hit, 0.0)


# --- Paso de Sombra ---

func _throw_kunai() -> void:
	step_cooldown.use()
	add_hunger(kd.step_hunger)
	if possessed:
		return
	player.face_aim_now()
	player.start_action(0.15, 0.7)
	var info: DamageInfo = make_hit(kd.kunai_damage)
	info.is_melee = false
	var from: Vector3 = player.global_position + Vector3.UP * 1.1 + player.aim_direction * 0.5
	_projectiles.fire(from, player.aim_direction, kd.kunai_speed,
			_range_until_obstacle(from, player.aim_direction, kd.kunai_range), 0.25, info,
			DamageInfo.Team.ENEMIES, _on_kunai_hit, _on_kunai_expire)


## Hasta dónde llega antes de chocar con una pared o roca (el kunai se clava ahí).
func _range_until_obstacle(from: Vector3, direction: Vector3, max_range: float) -> float:
	# Se mide a ras del piso: la pared sur es bajita y a la altura de la mano el kunai
	# le pasaba por arriba y quedaba clavado afuera de la sala.
	var low := Vector3(from.x, 0.3, from.z)
	var query := PhysicsRayQueryParameters3D.create(low, low + direction * max_range, 1 | 512)
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return max_range
	return maxf(low.distance_to(hit["position"]) - 0.6, 0.5)


## Hasta dónde se puede llegar de `from` a `to` sin cruzar una pared de la sala.
func _clamp_to_walls(from: Vector3, to: Vector3) -> Vector3:
	var low_from := Vector3(from.x, 0.3, from.z)
	var low_to := Vector3(to.x, 0.3, to.z)
	var query := PhysicsRayQueryParameters3D.create(low_from, low_to, WORLD_LAYER)
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Vector3(to.x, 0.0, to.z)
	var stop: Vector3 = (hit["position"] as Vector3) - (low_to - low_from).normalized() * 0.7
	return Vector3(stop.x, 0.0, stop.z)


func _on_kunai_hit(target: Node3D, _info: DamageInfo) -> void:
	if has_upgrade(&"agucci_kunai_veneno"):
		for i: int in 3:
			schedule(1.0 + i, _poison_tick.bind(target))
	var victim := target as Combatant
	if victim != null and victim.health.is_dead:
		# Si mata con el kunai, no suma Hambre.
		hunger = maxf(hunger - kd.step_hunger, 0.0)
		_stick_kunai(target.global_position, null)
	else:
		_stick_kunai(target.global_position, target)


func _on_kunai_expire(at: Vector3) -> void:
	_stick_kunai(at, null)


func _stick_kunai(at: Vector3, target: Node3D) -> void:
	_kunai_active = true
	_kunai_time = kd.kunai_window
	_kunai_position = Vector3(at.x, 0.0, at.z)
	_kunai_target = target
	_kunai_marker.visible = true


func _clear_kunai() -> void:
	_kunai_active = false
	_kunai_target = null
	_kunai_marker.visible = false


## Viaja por la sombra hasta el kunai y corta a todo lo que haya en el camino.
func _shadow_dash() -> void:
	var from := Vector3(player.global_position.x, 0.0, player.global_position.z)
	var to: Vector3 = _clamp_to_walls(from, _kunai_position)
	_clear_kunai()
	var offset: Vector3 = to - from
	Fx.ring_burst(_world(), from, 1.4, SHADOW_COLOR)
	player.health.make_invulnerable(kd.dash_time + 0.05)
	player.start_action(kd.dash_time, 0.0)
	player.action_velocity = offset / kd.dash_time
	player.visual.visible = false
	# Viaja por la sombra: atraviesa obstáculos y siempre llega al kunai (antes una roca lo
	# frenaba y el corte pegaba igual, sin moverse).
	_enter_shadow()
	schedule(kd.dash_time, _shadow_dash_end.bind(from, to))


func _shadow_dash_end(from: Vector3, to: Vector3) -> void:
	player.global_position = Vector3(to.x, player.global_position.y, to.z)
	_exit_shadow(to - from)
	player.visual.visible = true
	Fx.ring_burst(_world(), to, 1.4, SHADOW_COLOR)
	var targets: Array[Hurtbox] = CombatQuery.in_line(player.get_tree(), DamageInfo.Team.ENEMIES,
			from, to, kd.dash_width)
	_hit_each(targets, kd.dash_damage, _setup_dash, false, from)
	if _any_dead(targets):
		step_cooldown.reduce(kd.step_cooldown * kd.dash_kill_refund)
	if not targets.is_empty():
		player.freeze(Balance.combat.hitstop_heavy)


func _setup_dash(info: DamageInfo) -> void:
	info.hitstop = Balance.combat.hitstop_heavy
	info.shake = Balance.combat.shake_light


func _any_dead(targets: Array[Hurtbox]) -> bool:
	for hurtbox: Hurtbox in targets:
		var victim := hurtbox.receiver as Combatant
		if victim != null and victim.health.is_dead:
			return true
	return false


# --- Moverse por la sombra: atraviesa rocas, no las paredes de la sala ---

func _enter_shadow() -> void:
	if not _in_shadow:
		_saved_collision_mask = player.collision_mask
	_in_shadow = true
	player.collision_mask = WORLD_LAYER


## Vuelve a chocar con todo. Si quedó adentro de una roca, sale al lugar libre más cercano
## (primero hacia adelante, en la dirección en que venía).
func _exit_shadow(travel: Vector3) -> void:
	if not _in_shadow:
		return
	_in_shadow = false
	player.collision_mask = _saved_collision_mask
	var forward := Vector3(travel.x, 0.0, travel.z)
	forward = forward.normalized() if forward.length_squared() > 0.001 else player.aim_direction
	var here: Vector3 = player.global_position
	if not _blocked_at(here):
		return
	for step: int in range(1, 13):
		for sign_dir: float in [1.0, -1.0]:
			var candidate: Vector3 = here + forward * sign_dir * step * 0.3
			if not _blocked_at(candidate):
				player.global_position = candidate
				player.reset_physics_interpolation()
				return


func _blocked_at(point: Vector3) -> bool:
	var shape := SphereShape3D.new()
	shape.radius = data.placeholder_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(), Vector3(point.x, data.placeholder_height * 0.5, point.z))
	query.collision_mask = OBSTACLE_LAYER
	return not player.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


# --- Disolverse (o Abrazo del Valle sin Luz en Posesión) ---

func can_dodge() -> bool:
	if possessed:
		return embrace_cooldown.is_ready() and _embrace_time <= 0.0
	return super.can_dodge()


func do_dodge() -> void:
	if possessed:
		_embrace()
		return
	dodge_cooldown.use()
	cancel_scheduled()
	if _in_shadow:
		_exit_shadow(Vector3.ZERO)
	player.visual.visible = true
	var start: Vector3 = player.global_position
	var direction: Vector3 = dodge_direction()
	_dissolve_direction = direction
	_enter_shadow()
	player.start_dodge(direction, kd.dissolve_distance, kd.dissolve_duration)
	player.health.make_invulnerable(kd.dissolve_duration)
	player.visual.visible = false
	Fx.ring_burst(_world(), start, 1.2, SHADOW_COLOR, 0.25)
	schedule(kd.dissolve_duration, _reappear)
	add_hunger(kd.dissolve_hunger)


func _reappear() -> void:
	_exit_shadow(_dissolve_direction)
	player.visual.visible = true
	Fx.ring_burst(_world(), player.global_position, 1.2, SHADOW_COLOR, 0.25)


# --- Noche del Valle sin Luz ---

func _use_ultimate() -> bool:
	_night_time = _night_duration()
	_since_attack = 0.0
	say("Noche del Valle sin Luz", SHADOW_COLOR.lightened(0.45), 1.2)
	Events.room_tint_requested.emit(SHADOW_COLOR, _night_duration())
	add_hunger(kd.night_hunger)
	return true


## En la Noche, la sombra repite cada golpe.
func _on_damage_dealt(info: DamageInfo, target: Node3D) -> void:
	if info.attacker == player:
		_since_attack = 0.0
	if _night_time <= 0.0 or info.has_tag(&"echo") or info.amount <= 0.0:
		return
	var echo: DamageInfo = info.clone()
	echo.tags.append(&"echo")
	echo.knockback = 0.0
	echo.hitstop = 0.0
	echo.shake = 0.0
	schedule(kd.night_echo_delay, _echo_hit.bind(target, echo))


func _echo_hit(target: Node3D, echo: DamageInfo) -> void:
	var victim := target as Combatant
	if is_instance_valid(victim) and victim.is_targetable():
		Fx.ring_burst(_world(), victim.global_position, 0.8, SHADOW_COLOR, 0.2)
		victim.receive_hit(echo)


# --- Posesión ---

func _enter_possession() -> void:
	possessed = true
	hunger = 100.0
	_possession_time = kd.possession_duration
	if _tali_nearby():
		_possession_time *= kd.possession_tali_multiplier
	_auto_timer = 0.0
	cancel_scheduled()
	player.end_action()
	say("¡Posesión!", SHADOW_COLOR.lightened(0.45), 1.5)
	Fx.ring_burst(_world(), player.global_position, 3.0, SHADOW_COLOR, 0.4)
	Events.camera_shake_requested.emit(Balance.combat.shake_heavy * 0.5)


func _exit_possession() -> void:
	possessed = false
	hunger = 0.0
	player.move_override = null
	say("La sombra se calma...", Color(0.8, 0.75, 0.9))


func _update_possession(delta: float) -> void:
	_possession_time -= delta
	var target: Hurtbox = CombatQuery.nearest(player.get_tree(), DamageInfo.Team.ENEMIES,
			player.global_position)
	if _embrace_time > 0.0:
		_update_embrace(delta)
	if target == null:
		player.move_override = Vector2.ZERO
		var drain := DamageInfo.new()
		drain.amount = player.health.max_health * kd.possession_self_drain * delta
		drain.attacker_team = DamageInfo.Team.ENEMIES
		player.health.apply_damage(drain)
	else:
		var to_target: Vector3 = target.flat_position() - Vector3(player.global_position.x, 0.0,
				player.global_position.z)
		player.move_override = Vector2(to_target.x, to_target.z).normalized() \
				if to_target.length() > 1.4 else Vector2.ZERO
		_auto_timer -= delta
		if _auto_timer <= 0.0:
			_auto_timer = kd.possession_auto_interval
			_auto_attack()
	if _possession_time <= 0.0:
		_exit_possession()


func _auto_attack() -> void:
	var targets: Array[Hurtbox] = CombatQuery.in_circle(player.get_tree(), DamageInfo.Team.ENEMIES,
			player.global_position, kd.possession_auto_radius)
	if targets.is_empty():
		return
	Fx.ring_burst(_world(), player.global_position, kd.possession_auto_radius, SHADOW_COLOR, 0.2)
	var dealt: float = _deal_and_sum(targets, kd.possession_auto_damage)
	player.health.heal(dealt * kd.possession_lifesteal)


## Paga la vida que cuestan las habilidades de la Posesión.
func _pay_possession_cost() -> void:
	var cost := DamageInfo.new()
	cost.amount = maxf(player.health.current * kd.possession_skill_cost, 1.0)
	cost.attacker_team = DamageInfo.Team.ENEMIES
	if player.health.current - cost.amount >= 1.0:
		player.health.apply_damage(cost)


## Mordida de Sombra: dash que atraviesa y corta dos veces. Si mata, se reinicia.
func _shadow_bite() -> void:
	_pay_possession_cost()
	var from := Vector3(player.global_position.x, 0.0, player.global_position.z)
	var to: Vector3 = from + player.aim_direction * kd.bite_distance
	player.start_action(kd.bite_time, 0.0)
	player.action_velocity = (to - from) / kd.bite_time
	player.health.make_invulnerable(kd.bite_time)
	schedule(kd.bite_time, _bite_land.bind(from, to))


func _bite_land(from: Vector3, to: Vector3) -> void:
	var targets: Array[Hurtbox] = CombatQuery.in_line(player.get_tree(), DamageInfo.Team.ENEMIES,
			from, to, kd.bite_width)
	var dealt: float = 0.0
	for i: int in kd.bite_hits:
		dealt += _deal_and_sum(targets, kd.bite_damage)
	player.health.heal(dealt * kd.possession_skill_heal)
	if _any_dead(targets):
		bite_cooldown.refill()
	else:
		bite_cooldown.use()
	Fx.ring_burst(_world(), to, 1.2, SHADOW_COLOR, 0.25)


## Abrazo del Valle sin Luz: atrae a los cercanos y les drena vida durante 1 s.
func _embrace() -> void:
	_pay_possession_cost()
	embrace_cooldown.use()
	_embrace_time = kd.embrace_duration
	_embrace_tick = 0.0
	player.start_action(kd.embrace_duration, 0.3)
	Fx.ring_burst(_world(), player.global_position, kd.embrace_radius, SHADOW_COLOR, 0.5)


func _update_embrace(delta: float) -> void:
	_embrace_time -= delta
	var center: Vector3 = player.global_position
	var targets: Array[Hurtbox] = CombatQuery.in_circle(player.get_tree(), DamageInfo.Team.ENEMIES,
			center, kd.embrace_radius)
	for hurtbox: Hurtbox in targets:
		var enemy := hurtbox.receiver as Combatant
		if enemy != null:
			var pull: Vector3 = center - enemy.global_position
			pull.y = 0.0
			if pull.length() > 1.2:
				enemy.knockback_velocity = pull.normalized() * kd.embrace_pull_speed
	_embrace_tick -= delta
	if _embrace_tick <= 0.0:
		_embrace_tick += kd.embrace_duration / 4.0
		var dealt: float = _deal_and_sum(targets, kd.embrace_damage / 4.0, &"tick")
		player.health.heal(dealt * kd.possession_skill_heal)


func _deal_and_sum(targets: Array[Hurtbox], base: float, tag: StringName = &"") -> float:
	var total: float = 0.0
	for hurtbox: Hurtbox in targets:
		var info: DamageInfo = make_hit(base)
		info.hitstop = 0.03
		if tag != &"":
			info.tags.append(tag)
		if hurtbox.take_hit(info):
			total += info.final_amount
	return total


# --- Visual ---

func _build_visuals() -> void:
	_projectiles = ProjectilePool.new()
	_projectiles.name = "Projectiles"
	_projectiles.top_level = true
	add_child(_projectiles)
	var bullet := BoxMesh.new()
	bullet.size = Vector3(0.08, 0.08, 0.35)
	_projectiles.setup(bullet, Fx.flat_material(Color(0.92, 0.94, 1.0), 1.5), 12)

	_kunai_marker = MeshInstance3D.new()
	var kunai := CylinderMesh.new()
	kunai.top_radius = 0.0
	kunai.bottom_radius = 0.12
	kunai.height = 0.5
	_kunai_marker.mesh = kunai
	_kunai_marker.material_override = Fx.flat_material(SHADOW_COLOR.lightened(0.3), 2.0)
	_kunai_marker.top_level = true
	_kunai_marker.visible = false
	add_child(_kunai_marker)

	# La sombra en el piso se agranda con el Hambre.
	_shadow_disc = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * data.placeholder_radius * 3.0
	_shadow_disc.mesh = plane
	_shadow_disc.position.y = 0.025
	_shadow_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow_material = ShaderMaterial.new()
	_shadow_material.shader = RING_SHADER
	_shadow_material.set_shader_parameter("ring_color", Color(SHADOW_COLOR.darkened(0.5), 0.8))
	_shadow_material.set_shader_parameter("inner_radius", 0.9)
	_shadow_material.set_shader_parameter("fill_alpha", 0.55)
	_shadow_disc.material_override = _shadow_material
	player.add_child(_shadow_disc)

	var aura := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = data.placeholder_radius * 2.0
	sphere.height = data.placeholder_height * 1.3
	aura.mesh = sphere
	aura.position.y = data.placeholder_height * 0.5
	aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_aura_material = ShaderMaterial.new()
	_aura_material.shader = AURA_SHADER
	_aura_material.set_shader_parameter("aura_color", SHADOW_COLOR)
	aura.material_override = _aura_material
	player.visual.add_child(aura)

	var body := player.get_node("Visual/Body") as MeshInstance3D
	_body_material = body.material_override as StandardMaterial3D
	_base_body_color = _body_material.albedo_color


func _update_visuals() -> void:
	_shadow_disc.scale = Vector3.ONE * (1.0 + hunger / 100.0 * 1.6)
	var intensity: float = 1.0 if possessed else (0.6 if _night_time > 0.0 else 0.0)
	_aura_material.set_shader_parameter("intensity", intensity)
	_body_material.albedo_color = _base_body_color.lerp(SHADOW_COLOR.darkened(0.3),
			0.6 if possessed else 0.0)


func _world() -> Node:
	return player.get_parent()


func debug_lines() -> Array[String]:
	var zone: String = "Lucidez" if is_lucid() else ("POSESIÓN %.1f s" % _possession_time
			if possessed else "Hambre +%d%% daño" % roundi(hunger))
	var lines: Array[String] = ["Hambre %d  (%s)" % [roundi(hunger), zone]]
	if possessed:
		lines.append("Mordida %s · Abrazo %s" % [_cd(bite_cooldown), _cd(embrace_cooldown)])
	else:
		var step_text: String = "¡reactivá!" if _kunai_active else _cd(step_cooldown)
		lines.append("Paso de Sombra %s · Disolverse %d/%d" % [step_text, dodge_cooldown.charges,
				dodge_cooldown.max_charges])
	var ult_line: String = "Definitiva %d%%" % roundi(ult_charge)
	if _night_time > 0.0:
		ult_line = "NOCHE %.1f s%s" % [_night_time, " (oculto)" if player.hidden_from_enemies else ""]
	lines.append(ult_line)
	return lines


func _cd(cd: AbilityCooldown) -> String:
	return "listo" if cd.is_ready() else "%.1f s" % cd.time_until_ready()


# --- HUD ---

## Hambre en tres zonas (GDD, Interfaz): Lucidez (0-30), Hambre (31-99), Posesión (100).
func hud_bar() -> Dictionary:
	if possessed:
		return {"label": "POSESIÓN %d s" % ceili(_possession_time), "value": 1.0,
				"color": SHADOW_COLOR.lightened(0.25), "pulse": true}
	var lucid: bool = hunger <= _lucidity_max()
	return {"label": "Lucidez" if lucid else "Hambre +%d%%" % roundi(hunger * kd.hunger_damage_per_point * 100.0),
			"value": hunger / 100.0, "color": Color(0.55, 0.62, 0.75) if lucid else SHADOW_COLOR,
			"pulse": hunger >= 85.0, "marks": [_lucidity_max() / 100.0]}


func hud_abilities() -> Array[Dictionary]:
	if possessed:
		return [cooldown_slot("Mordida", bite_cooldown), cooldown_slot("Abrazo", embrace_cooldown),
				ult_slot("Noche")]
	var step_slot: Dictionary = cooldown_slot("Paso", step_cooldown)
	if _kunai_active:
		step_slot = {"name": "Paso", "ratio": 0.0, "text": "¡Ya!"}
	return [step_slot, cooldown_slot("Disolverse", dodge_cooldown), ult_slot("Noche")]


# --- Mejoras ---

func _lucidity_max() -> float:
	return 40.0 if has_upgrade(&"agucci_lucidez_amplia") else kd.lucidity_max


func _night_duration() -> float:
	return kd.night_duration + (3.0 if has_upgrade(&"agucci_noche_larga") else 0.0)


func _uzi_bullets() -> int:
	return kd.uzi_bullets + (2 if has_upgrade(&"agucci_uzi_cargador") else 0)


func apply_upgrade_stats(_mods: StatModifiers) -> void:
	dodge_cooldown.max_charges = kd.dissolve_charges + (1 if has_upgrade(&"agucci_disolverse_extra") else 0)


## Kunai envenenado: 10 de daño por segundo durante 3 s.
func _poison_tick(target: Node3D) -> void:
	var victim := target as Combatant
	if not is_instance_valid(victim) or not victim.is_targetable():
		return
	var info: DamageInfo = make_hit(10.0)
	info.hitstop = 0.0
	info.is_melee = false
	info.tags.append(&"tick")
	victim.receive_hit(info)
