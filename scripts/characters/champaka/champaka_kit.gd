class_name ChampakaKit
extends CharacterKit
## Capitán Champaka, el Coloso del Hongo (KITS_MVP). Tanque y sanador.
##   Esporas Protectoras: recibe 15% menos siempre; cada 100 de daño recibido brota un hongo
##     que cura 5. Los aliados a su lado reciben 10% menos (eso está en PlayerCharacter).
##   Aplauso de Papá: un golpe solo, fuerte y lento (pedido del grupo), con onda en el piso.
##   Abrazo de Oso: agarra, inmoviliza y aplasta (80). Sobre Tali en Furia: la calma y la cura.
##   Panzazo: se tira de panza. Sin invulnerabilidad: recibe 40% menos y empuja todo.
##   Floración del Hongo: zona que cura, revive caídos y confunde a los enemigos.

const SPORE_COLOR := Color(0.35, 0.95, 0.85)  # verde agua = curación

var kd: ChampakaKitData
var hug_cooldown: AbilityCooldown
var spores: float = 0.0
var sliding: bool = false
var _attack_timer: float = 0.0
var _consecutive_hits: int = 0
var _slide_hit: Array[Node] = []
var _slide_direction: Vector3 = Vector3.FORWARD
var _slide_time: float = 0.0


func _setup() -> void:
	kd = data.kit_data as ChampakaKitData
	dodge_cooldown = AbilityCooldown.new(kd.belly_recharge, 1)
	hug_cooldown = AbilityCooldown.new(kd.hug_cooldown)


func _tick(delta: float) -> void:
	hug_cooldown.tick(cd_delta(delta))
	_attack_timer -= delta
	if sliding:
		_slide_tick(delta)


func _handle_input() -> void:
	var input: PlayerInput = player.slot.input
	if player.has_buffered(PlayerInput.Action.ABILITY) and hug_cooldown.is_ready() and can_start_skill():
		if _hug():
			player.consume_buffered(PlayerInput.Action.ABILITY)
	elif input.is_held(PlayerInput.Action.ATTACK) and _attack_timer <= 0.0 and player.can_act():
		_swipe()


# --- Aplauso de Papá ---

func _swipe() -> void:
	_attack_timer = kd.clap_interval / attack_speed()
	player.face_aim_now()
	player.start_action(0.4 / attack_speed(), 0.3)
	basic_recovery = true
	var direction: Vector3 = player.aim_direction
	var info: DamageInfo = make_hit(kd.clap_damage)
	info.knockback = kd.swipe_knockback
	info.hitstop = Balance.combat.hitstop_heavy
	info.shake = Balance.combat.shake_heavy * 0.4
	Fx.slash(_world(), player.global_position, direction, swipe_range(), kd.swipe_angle_deg, player.slot.color)
	Sound.play("hit_heavy", -8.0)
	var targets: Array[Hurtbox] = CombatQuery.in_sector(player.get_tree(), DamageInfo.Team.ENEMIES,
			player.global_position, direction, swipe_range(), kd.swipe_angle_deg)
	var landed: bool = Combat.deliver(info, targets) > 0
	_ground_wave(player.global_position + direction * 1.2)
	if landed:
		player.freeze(info.hitstop)
		_consecutive_hits += 1
		# Mejora: el tercer aplauso seguido que conecta da un escudito.
		if _consecutive_hits >= 3 and has_upgrade(&"champaka_escudo"):
			_consecutive_hits = 0
			player.health.add_shield(15.0)
			say("Escudo", SPORE_COLOR, 0.8)
	else:
		_consecutive_hits = 0


func swipe_range() -> float:
	return kd.swipe_range * (1.25 if has_upgrade(&"champaka_manos_oso") else 1.0)


func _ground_wave(center: Vector3) -> void:
	if has_upgrade(&"champaka_onda_fuerte"):
		var info: DamageInfo = make_hit(15.0)
		info.origin = center
		Combat.deliver(info, CombatQuery.in_circle(player.get_tree(), DamageInfo.Team.ENEMIES, center, kd.wave_radius))
	for hurtbox: Hurtbox in CombatQuery.in_circle(player.get_tree(), DamageInfo.Team.ENEMIES, center, kd.wave_radius):
		var enemy := hurtbox.receiver as Combatant
		if enemy == null:
			continue
		var away := Vector3(enemy.global_position.x - center.x, 0.0, enemy.global_position.z - center.z)
		if away.length_squared() < 0.01:
			away = player.aim_direction
		enemy.knockback_velocity = away.normalized() * kd.wave_knockback
	Fx.ring_burst(_world(), center, kd.wave_radius, player.slot.color, 0.3)


# --- Pasiva: menos daño y esporas ---

func modify_incoming(info: DamageInfo) -> void:
	info.amount *= 1.0 - kd.damage_reduction
	if sliding:
		info.amount *= 1.0 - kd.belly_damage_reduction
		info.knockback = 0.0  # nada lo frena


func _on_damage_taken(info: DamageInfo) -> void:
	spores += info.final_amount
	while spores >= spores_per_mushroom():
		spores -= spores_per_mushroom()
		var angle: float = randf() * TAU
		spawn_mushroom(player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * 1.6)


func spores_per_mushroom() -> float:
	return 70.0 if has_upgrade(&"champaka_esporulacion") else kd.spores_per_mushroom


func spawn_mushroom(at: Vector3) -> void:
	var mushroom := HealMushroom.new()
	mushroom.heal_amount = mushroom_heal()
	_world().add_child(mushroom)
	mushroom.global_position = Vector3(at.x, 0.0, at.z)


func mushroom_heal() -> float:
	var base: float = kd.mushroom_heal * (2.0 if has_upgrade(&"champaka_hongos_gorditos") else 1.0)
	return base * (1.0 + 0.1 * hero(&"champaka_hongos"))


## Papá del grupo (lo usa PlayerCharacter para los aliados cerca).
func dad_radius() -> float:
	return 5.0 if has_upgrade(&"champaka_papa_presente") else kd.dad_radius


func dad_reduction() -> float:
	return 0.15 if has_upgrade(&"champaka_papa_presente") else kd.dad_reduction


func bloom_radius() -> float:
	return kd.bloom_radius * (1.4 if has_upgrade(&"champaka_micelio") else 1.0)


func apply_upgrade_stats(_mods: StatModifiers) -> void:
	dodge_cooldown.max_charges = 1 + (1 if has_upgrade(&"champaka_panzazo_doble") else 0)
	hug_cooldown.recharge_time = kd.hug_cooldown * (0.75 if has_upgrade(&"champaka_abrazador_serial") else 1.0)


# --- Abrazo de Oso ---

## Devuelve false si no había a quién abrazar (no gasta el cooldown).
func _hug() -> bool:
	var tali: PlayerCharacter = _furious_tali_near()
	if tali != null:
		hug_cooldown.use()
		player.end_action()
		player.start_action(0.4, 0.0)
		(tali.kit as TaliKit).calm_fury()
		tali.health.heal(tali.health.max_health * kd.hug_tali_heal)
		Fx.ring_burst(_world(), tali.global_position, 1.6, SPORE_COLOR, 0.4)
		say("Ya está, ya pasó...", SPORE_COLOR, 1.1)
		_hug_heal_allies()
		return true
	var hurtbox: Hurtbox = CombatQuery.nearest(player.get_tree(), DamageInfo.Team.ENEMIES,
			player.global_position, kd.hug_range)
	var enemy: Enemy = hurtbox.receiver as Enemy if hurtbox != null else null
	if enemy == null:
		return false
	hug_cooldown.use()
	player.end_action()
	cancel_scheduled()
	var to_enemy: Vector3 = enemy.global_position - player.global_position
	to_enemy.y = 0.0
	if to_enemy.length_squared() > 0.01:
		player.aim_direction = to_enemy.normalized()
		player.face_aim_now()
	say("¡Abrazo de oso!", player.slot.color.lightened(0.3), 1.1)
	_hug_heal_allies()
	if enemy is GronkGigante:
		# Al boss no lo puede levantar: solo el apretón.
		player.start_action(0.4, 0.0)
		_crush(enemy)
		return true
	var hold: float = (kd.hug_hold_elite if enemy.is_elite else kd.hug_hold) + 0.5 * hero(&"champaka_abrazo")
	player.start_action(hold + 0.2, 0.0)
	enemy.set_controlled(true)
	var held_at: Vector3 = player.global_position + player.aim_direction * 1.1 + Vector3.UP * 0.6
	var tween: Tween = player.create_tween()
	tween.tween_property(enemy, "global_position", held_at, 0.15)
	tween.tween_interval(hold)
	tween.tween_property(enemy, "global_position:y", 0.0, 0.12).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		if is_instance_valid(enemy):
			enemy.set_controlled(false)
			_crush(enemy))
	return true


func _crush(enemy: Enemy) -> void:
	if not is_instance_valid(player) or not enemy.is_targetable():
		return
	var info: DamageInfo = make_hit(kd.hug_damage)
	info.hitstop = Balance.combat.hitstop_heavy
	info.shake = Balance.combat.shake_heavy * 0.6
	info.knockback = 2.0
	enemy.hurtbox.take_hit(info)
	Fx.ring_burst(_world(), enemy.global_position, 1.8, player.slot.color, 0.35)
	Sound.play("hit_heavy", -2.0)


func _furious_tali_near() -> PlayerCharacter:
	for node: Node in player.get_tree().get_nodes_in_group(&"players"):
		var ally := node as PlayerCharacter
		if ally == null or ally == player or ally.health.is_dead or not (ally.kit is TaliKit):
			continue
		if (ally.kit as TaliKit).in_fury and ally.global_position.distance_to(player.global_position) <= kd.hug_range:
			return ally
	return null


## Mejora: el Abrazo también cura 10 a los aliados cerca.
func _hug_heal_allies() -> void:
	if not has_upgrade(&"champaka_abrazo_cura"):
		return
	for ally: PlayerCharacter in _allies_in(player.global_position, 4.0):
		ally.health.heal(10.0)


# --- Panzazo ---

## Sin invulnerabilidad (GDD): se mueve con una acción, no con la esquiva común.
func do_dodge() -> void:
	dodge_cooldown.use()
	cancel_scheduled()
	player.end_action()
	_slide_direction = dodge_direction()
	_slide_time = kd.belly_duration
	_slide_hit.clear()
	sliding = true
	player.start_action(kd.belly_duration, 0.0)
	player.action_velocity = _slide_direction * kd.belly_distance / kd.belly_duration
	Sound.play("dodge", -6.0)
	say("¡Panzazo!", player.slot.color.lightened(0.3), 0.8)


func can_dodge() -> bool:
	return dodge_cooldown.is_ready() and not sliding


func _slide_tick(delta: float) -> void:
	_slide_time -= delta
	for hurtbox: Hurtbox in CombatQuery.in_circle(player.get_tree(), DamageInfo.Team.ENEMIES,
			player.global_position + _slide_direction * 0.5, 1.2):
		if hurtbox.receiver in _slide_hit:
			continue
		_slide_hit.append(hurtbox.receiver)
		var info: DamageInfo = make_hit(kd.belly_damage)
		info.knockback = kd.belly_knockback
		hurtbox.take_hit(info)
	if _slide_time <= 0.0 or not player.is_in_action():
		_land()


func _land() -> void:
	sliding = false
	var here: Vector3 = player.global_position
	for ally: PlayerCharacter in _allies_in(here, kd.belly_heal_radius):
		ally.health.heal(kd.belly_heal)
	Fx.ring_burst(_world(), here, kd.belly_heal_radius, SPORE_COLOR, 0.35)
	# Pedido del grupo: con la sala o el evento ya terminados no suelta hongos.
	if has_upgrade(&"champaka_panzazo_hongo") and in_combat():
		spawn_mushroom(here - _slide_direction * 0.8)


# --- Floración del Hongo ---

func _use_ultimate() -> bool:
	var zone := FloracionZone.new()
	_world().add_child(zone)
	zone.global_position = Vector3(player.global_position.x, 0.0, player.global_position.z)
	zone.setup(self, kd.bloom_duration + 1.0 * hero(&"champaka_floracion"))
	say("¡Floración!", SPORE_COLOR, 1.4)
	Events.camera_shake_requested.emit(Balance.combat.shake_light)
	return true


# --- Ayudas ---

## ¿Hay pelea? (enemigos en la sala; los que se van corriendo ya no cuentan).
func in_combat() -> bool:
	return not player.get_tree().get_nodes_in_group(&"enemies").is_empty()


## Jugadores vivos (incluido él) cerca de un punto.
func _allies_in(center: Vector3, radius: float) -> Array[PlayerCharacter]:
	var result: Array[PlayerCharacter] = []
	for node: Node in player.get_tree().get_nodes_in_group(&"players"):
		var ally := node as PlayerCharacter
		if ally != null and not ally.health.is_dead and not ally.is_downed() \
				and ally.global_position.distance_to(center) <= radius:
			result.append(ally)
	return result


func _world() -> Node:
	return player.get_parent()


# --- HUD ---

func hud_bar() -> Dictionary:
	return {"label": "Esporas %d/%d" % [roundi(spores), roundi(spores_per_mushroom())],
			"value": spores / spores_per_mushroom(), "color": SPORE_COLOR, "pulse": false}


func hud_abilities() -> Array[Dictionary]:
	return [cooldown_slot("Abrazo", hug_cooldown), cooldown_slot("Panzazo", dodge_cooldown),
			ult_slot("Floración")]


func ability_cooldowns() -> Array[AbilityCooldown]:
	return [hug_cooldown]


func debug_lines() -> Array[String]:
	return ["Esporas %d" % roundi(spores), "Aplausos seguidos %d" % _consecutive_hits]
