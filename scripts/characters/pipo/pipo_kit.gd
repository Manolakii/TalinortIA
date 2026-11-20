class_name PipoKit
extends CharacterKit
## General Pipo, el Tuerto del Bosque (KITS_MVP).
##   Racha de Cuartel (pasiva, pedido del grupo en vez de la Marca Táctica): cada tiro seguido
##     que acierta le suma +5% de daño al Bláster, hasta +50%. Si un tiro falla, vuelve a 0.
##   Un Ojo Basta: en el cono angosto de su mira, 20% de crítico; desde su izquierda (punto
##     ciego) le pegan +15%.
##   Bláster Reglamentario: tiro preciso y lento.
##   Despliegue de Chatarra: torreta que le tira a lo que viene acertando Pipo (máximo 2).
##   Repliegue Ordenado: salto hacia atrás que deja una mina.
##   Fuego de la Nave Insignia: marca una zona y la bombardea con 6 impactos (uno cae al azar).

const BOLT_COLOR := Color(0.85, 1.0, 0.75)
const RETREAT_LINES: Array[String] = ["No es huir, es reposicionarse.", "Repliegue táctico.",
		"¡Retirada estratégica! Que no es lo mismo."]

var kd: PipoKitData
var turret_cooldown: AbilityCooldown
var turrets: Array[PipoTurret] = []
var _shots: int = 0
## Tiros seguidos que acertaron (la racha).
var streak: int = 0
## Último enemigo que acertó (las torretas le tiran a ese).
var last_target: Node3D
var _attack_timer: float = 0.0
var _bolts: ProjectilePool


func _setup() -> void:
	kd = data.kit_data as PipoKitData
	dodge_cooldown = AbilityCooldown.new(kd.retreat_cooldown, 1)
	turret_cooldown = AbilityCooldown.new(kd.turret_cooldown)
	_bolts = ProjectilePool.new()
	_bolts.name = "BlasterPool"
	_bolts.top_level = true
	add_child(_bolts)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.1, 0.1, 0.55)
	_bolts.setup(mesh, Fx.flat_material(BOLT_COLOR, 2.0), 16)


func _tick(delta: float) -> void:
	turret_cooldown.tick(cd_delta(delta))
	_attack_timer -= delta
	# Saca las torretas que ya se desarmaron (sin filter(): devuelve un Array sin tipo).
	for i: int in range(turrets.size() - 1, -1, -1):
		if not is_instance_valid(turrets[i]) or turrets[i].is_queued_for_deletion():
			turrets.remove_at(i)


func _handle_input() -> void:
	var input: PlayerInput = player.slot.input
	if player.has_buffered(PlayerInput.Action.ABILITY) and turret_cooldown.is_ready() and can_start_skill():
		player.consume_buffered(PlayerInput.Action.ABILITY)
		player.end_action()
		_deploy_turret()
	elif input.is_held(PlayerInput.Action.ATTACK) and _attack_timer <= 0.0 and player.can_act():
		_fire()


# --- Bláster y Racha de Cuartel ---

func _fire() -> void:
	_attack_timer = kd.blaster_interval / attack_speed()
	player.face_aim_now()
	player.start_action(0.16, 0.7)
	basic_recovery = true
	_shots += 1
	var base: float = kd.blaster_damage * (1.2 if has_upgrade(&"pipo_blaster_reglamentado") else 1.0)
	var info: DamageInfo = make_hit(base * (1.0 + streak_bonus()))
	# Precisión: en el cono angosto de la mira, más chance de crítico.
	if not info.is_crit and _enemy_in_cone() and Combat.roll(cone_crit_chance() - player.crit_chance()):
		info.is_crit = true
		info.amount *= player.crit_multiplier()
	info.is_melee = false
	info.knockback = 2.0
	var from: Vector3 = player.global_position + Vector3.UP * 1.1 + player.aim_direction * 0.5
	_bolts.fire(from, player.aim_direction, kd.blaster_speed, kd.blaster_range, 0.25, info,
			DamageInfo.Team.ENEMIES, _on_bolt_hit, _on_bolt_missed)


## Acertó: la racha sube (las vasijas no cuentan, ni para sumar ni para cortar).
func _on_bolt_hit(target: Node3D, _info: DamageInfo) -> void:
	if not (target is Enemy):
		return
	last_target = target
	var was_full: bool = streak_bonus() >= streak_cap()
	streak += 1
	if not was_full and streak_bonus() >= streak_cap():
		say("¡Racha completa!", BOLT_COLOR, 0.9)
		Fx.ring_burst(_world(), player.global_position, 1.4, player.slot.color, 0.25)


## Falló (el tiro llegó al final sin pegarle a nada): la racha vuelve a 0.
func _on_bolt_missed(_at: Vector3) -> void:
	if streak > 0 and streak_bonus() >= streak_cap() * 0.5:
		say("Se cortó la racha", Color(0.8, 0.8, 0.85), 0.7)
	if has_upgrade(&"pipo_racha_firme"):
		streak = streak / 2
	else:
		streak = 0


## Bonus de daño del Bláster por la racha (0,05 por tiro seguido, con tope).
func streak_bonus() -> float:
	return minf(streak * kd.streak_per_hit, streak_cap())


func streak_cap() -> float:
	return kd.streak_cap + (0.25 if has_upgrade(&"pipo_racha_alta") else 0.0) + 0.05 * hero(&"pipo_racha")


func _enemy_in_cone() -> bool:
	var here := Vector3(player.global_position.x, 0.0, player.global_position.z)
	for hurtbox: Hurtbox in CombatQuery.targets(player.get_tree(), DamageInfo.Team.ENEMIES):
		var to_enemy: Vector3 = hurtbox.flat_position() - here
		if to_enemy.length() <= kd.blaster_range \
				and player.aim_direction.angle_to(to_enemy) <= deg_to_rad(kd.cone_half_deg):
			return true
	return false


func cone_crit_chance() -> float:
	return kd.cone_crit_chance + player.modifiers.crit_chance_bonus()




## Punto ciego: los que le pegan desde su izquierda hacen +15%.
func modify_incoming(info: DamageInfo) -> void:
	if has_upgrade(&"pipo_cubrime"):
		return
	var to_attacker := Vector3(info.origin.x - player.global_position.x, 0.0,
			info.origin.z - player.global_position.z)
	if to_attacker.length_squared() < 0.01:
		return
	var facing: Vector3 = player.aim_direction
	var left := Vector3(facing.z, 0.0, -facing.x)  # izquierda en pantalla, mirando hacia `facing`
	if left.angle_to(to_attacker) <= deg_to_rad(60.0):
		info.amount *= 1.0 + kd.blind_spot_damage


# --- Despliegue de Chatarra ---

func _deploy_turret() -> void:
	turret_cooldown.use()
	if turrets.size() >= max_turrets():
		var oldest: PipoTurret = turrets.pop_front()
		if is_instance_valid(oldest):
			oldest.dismantle()
	var turret := PipoTurret.new()
	turret.position = player.global_position + player.aim_direction * 1.8
	turret.position.y = 0.0
	_world().add_child(turret)
	turret.setup(self)
	turrets.append(turret)
	player.start_action(0.3, 0.3)
	say("¡Despliegue!", Color(0.85, 1.0, 0.75))


func apply_upgrade_stats(_mods: StatModifiers) -> void:
	dodge_cooldown.max_charges = 1 + (1 if has_upgrade(&"pipo_repliegue_doble") else 0)


func turret_health() -> float:
	return kd.turret_health * (1.5 if has_upgrade(&"pipo_torreta_blindada") else 1.0)


func turret_fire_rate() -> float:
	return kd.turret_shots_per_second * (1.3 if has_upgrade(&"pipo_torreta_aceitada") else 1.0)


func max_turrets() -> int:
	return kd.turret_max + (1 if has_upgrade(&"pipo_torreta_extra") else 0)


func turret_duration() -> float:
	return kd.turret_duration + 2.0 * hero(&"pipo_torretas")


# --- Repliegue Ordenado ---

func do_dodge() -> void:
	dodge_cooldown.use()
	cancel_scheduled()
	var start: Vector3 = player.global_position
	var away: Vector3 = -player.aim_direction
	var move: Vector2 = player.get_move_input()
	if move.length() > 0.3:
		away = Vector3(move.x, 0.0, move.y).normalized()
	player.start_dodge(away, kd.retreat_distance, kd.retreat_duration)
	var mine := PipoMine.new()
	_world().add_child(mine)
	mine.global_position = Vector3(start.x, 0.0, start.z)
	mine.setup(self)
	if randf() < 0.3:
		say(RETREAT_LINES.pick_random(), Color(0.85, 1.0, 0.75), 0.8)


func mine_damage() -> float:
	return kd.mine_damage * (1.0 + 0.15 * hero(&"pipo_mina"))


# --- Fuego de la Nave Insignia ---

var _bomb_until: int = 0


func ult_active() -> bool:
	return Time.get_ticks_msec() < _bomb_until


func _use_ultimate() -> bool:
	_bomb_until = Time.get_ticks_msec() + int((kd.bomb_delay + 0.8) * 1000.0)
	var to_point: Vector3 = player.aim_point - player.global_position
	to_point.y = 0.0
	if to_point.length() > kd.bomb_range:
		to_point = to_point.normalized() * kd.bomb_range
	var center: Vector3 = player.global_position + to_point
	center.y = 0.0
	var marker := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = kd.bomb_radius
	disc.bottom_radius = kd.bomb_radius
	disc.height = 0.04
	marker.mesh = disc
	var material := Fx.flat_material(Color(player.slot.color, 0.35), 0.8)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker.material_override = material
	_world().add_child(marker)
	marker.global_position = center + Vector3.UP * 0.05
	say("¡Fuego de la nave insignia!", Color(0.85, 1.0, 0.75), 1.3)
	# Con un timer (no con schedule): la esquiva no cancela el bombardeo.
	var timer: SceneTreeTimer = player.get_tree().create_timer(kd.bomb_delay, false)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(marker):
			marker.queue_free()
		_bombard(center))
	return true


func _bombard(center: Vector3) -> void:
	if not is_instance_valid(player):
		return
	var spots: Array[Vector3] = []
	var impacts: int = kd.bomb_impacts + (2 if has_upgrade(&"pipo_bombardeo_mas") else 0)
	for i: int in impacts - 1:
		var angle: float = randf() * TAU
		var radius: float = sqrt(randf()) * kd.bomb_radius * 0.85
		spots.append(center + Vector3(cos(angle) * radius, 0, sin(angle) * radius))
	# La nave sigue medio rota: uno cae en cualquier lado.
	spots.append(Vector3(randf_range(-20, 20), 0, randf_range(-13, 13)))
	for i: int in spots.size():
		var timer: SceneTreeTimer = player.get_tree().create_timer(i * 0.12, false)
		timer.timeout.connect(_impact.bind(spots[i]))


func _impact(at: Vector3) -> void:
	if not is_instance_valid(player):
		return
	var info: DamageInfo = make_hit(kd.bomb_damage)
	info.origin = at
	info.knockback = 6.0
	info.is_melee = false
	info.hitstop = Balance.combat.hitstop_light
	Combat.deliver(info, CombatQuery.in_circle(player.get_tree(), DamageInfo.Team.ENEMIES, at, kd.bomb_impact_radius))
	Fx.beam(_world(), at + Vector3.UP * 14.0, Vector3.DOWN, 14.0, 0.5, Color(1.0, 0.9, 0.7), 0.25)
	Fx.ring_burst(_world(), at, kd.bomb_impact_radius, Color(1.0, 0.8, 0.5), 0.3)
	Events.camera_shake_requested.emit(Balance.combat.shake_heavy * 0.35)
	Sound.play("hit_heavy", -2.0)


func _world() -> Node:
	return player.get_parent()


# --- HUD y otros ---

func hud_bar() -> Dictionary:
	var bonus: float = streak_bonus()
	return {"label": "Racha +%d%%" % roundi(bonus * 100.0), "value": bonus / streak_cap(),
			"color": Color(0.85, 1.0, 0.75), "pulse": bonus >= streak_cap()}


func hud_abilities() -> Array[Dictionary]:
	return [cooldown_slot("Torreta", turret_cooldown), cooldown_slot("Repliegue", dodge_cooldown),
			ult_slot("Nave")]


func ability_cooldowns() -> Array[AbilityCooldown]:
	return [turret_cooldown]


func debug_lines() -> Array[String]:
	return ["Torretas: %d/%d" % [turrets.size(), max_turrets()], "Racha: %d tiros" % streak]
