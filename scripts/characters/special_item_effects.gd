class_name SpecialItemEffects
extends Node
## Efectos de los objetos especiales de Yole Sajor (GDD, "Objetos especiales") para UN jugador.
## Algunos efectos viven en otros lados porque necesitan saber algo de ahí:
##   Vasija sin fondo → Vase; Espora errante → Enemy; Corona del Líder Supremo → PlayerCharacter;
##   Trébol de cuatro Gronks → PlayerCharacter; Diente del Gronk Gigante → Enemy.

const STATIK_PER_METER := 4.0
const STATIK_CHAIN_DAMAGE := 30.0
const ECHO_COLOR := Color(0.55, 0.35, 0.75)
const STATIK_COLOR := Color(0.75, 0.9, 1.0)

var player: PlayerCharacter
## Barra de Statik (0 a 100).
var statik: float = 0.0

var _last_attack_input: float = -10.0
var _last_skill_input: float = -10.0
var _was_dodging: bool = false
var _last_position: Vector3
var _ability_charges: Dictionary = {}  # AbilityCooldown -> cargas del frame anterior
var _abilities_used: int = 0
## Capa de Yole: en qué sala se usó por última vez (una vez por sala).
var _cape_room: int = -1
## Venenoso: cargas por enemigo {id: {"node", "stacks", "until", "tick"}}.
var _poison: Dictionary = {}
const POISON_PER_STACK := 3.0  # por cada medio segundo
const SWORD_KILLS := 50


func setup(owner_player: PlayerCharacter) -> void:
	player = owner_player
	_last_position = player.global_position if player.is_inside_tree() else Vector3.ZERO
	Events.hit_landed.connect(_on_hit_landed)
	Events.ultimate_used.connect(_on_ultimate_used)
	player.hit_taken.connect(_on_hit_taken)
	Events.room_finished.connect(_on_room_finished)


func has(item_id: StringName) -> bool:
	return player != null and RunState.has_special(player.slot.index, item_id)


func _physics_process(delta: float) -> void:
	if player == null or player.slot == null:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	var input: PlayerInput = player.slot.input
	if input.is_held(PlayerInput.Action.ATTACK):
		_last_attack_input = now
	for action: PlayerInput.Action in [PlayerInput.Action.ABILITY, PlayerInput.Action.ULTIMATE,
			PlayerInput.Action.DODGE]:
		if input.is_held(action):
			_last_skill_input = now
	# Statik: se carga caminando.
	if has(&"statik") and statik < 100.0:
		var moved: float = Vector2(player.global_position.x - _last_position.x,
				player.global_position.z - _last_position.z).length()
		statik = minf(statik + moved * STATIK_PER_METER, 100.0)
	_last_position = player.global_position
	# Kunai de repuesto: al empezar una esquiva.
	var dodging: bool = player.is_dodging()
	if dodging and not _was_dodging and has(&"kunai_repuesto"):
		_drop_kunai(player.global_position)
	# Botas de Cartero: después de esquivar, más rápido un rato.
	if dodging and not _was_dodging and has(&"botas_cartero"):
		player.status.apply(StatusEffects.MAILMAN, 2.0)
	# Barro en las botas: al esquivar deja un barro que frena a los enemigos.
	if dodging and not _was_dodging and has(&"barro_botas"):
		var mud := MudPatch.new()
		player.get_parent().add_child(mud)
		mud.global_position = Vector3(player.global_position.x, 0.0, player.global_position.z)
	_was_dodging = dodging
	# Núcleo Uwey: cuenta las habilidades usadas (una carga que se gastó).
	if has(&"nucleo_uwey"):
		_watch_abilities()
	if not _poison.is_empty():
		_tick_poison(delta)


## ¿Este golpe es del golpe común? (atacando hace poco y sin habilidades recientes)
func is_basic_hit() -> bool:
	var now: float = Time.get_ticks_msec() / 1000.0
	return now - _last_attack_input < 0.6 and now - _last_skill_input > 0.8


func _on_hit_landed(info: DamageInfo, target: Node3D) -> void:
	if player == null or info.attacker != player or not is_instance_valid(target) or target == player:
		return
	var victim := target as Combatant
	if victim == null or victim.team == DamageInfo.Team.PLAYERS:
		return
	var basic: bool = is_basic_hit() and not info.has_tag(&"tick") and not info.has_tag(&"echo") \
			and not info.has_tag(&"proc")
	if victim.health.is_dead:
		_on_kill(victim)
		return
	# Ejecutor: por debajo del 15% (bosses 3%), muere al pegarle.
	if has(&"ejecutor") and not info.has_tag(&"execute"):
		var threshold: float = 0.03 if victim.is_in_group(&"boss") else 0.15
		if victim.health.ratio() < threshold:
			_execute(victim)
			return
	# Venenoso: el golpe común suma cargas de veneno.
	if basic and has(&"venenoso"):
		_add_poison(victim)
	if basic and has(&"piedra_suerte") and randf() < 0.08:
		victim.status.apply(StatusEffects.STUN, 0.5)
		Events.floating_text_requested.emit(victim.global_position + Vector3.UP * 2.4, "¡Piedrazo de suerte!",
				Color(0.75, 0.9, 1.0))
	if basic and has(&"statik") and statik >= 100.0:
		statik = 0.0
		_chain_lightning(victim)
	if info.is_crit and has(&"fragmento_crepusculo") and not info.has_tag(&"echo"):
		_shadow_echo(victim, info.final_amount * 0.5)


func _on_kill(_victim: Combatant) -> void:
	# Aplausos del público: matar con la definitiva cura.
	if has(&"aplausos_publico") and player.kit.ult_active() and not player.health.is_dead:
		player.health.heal(5.0)
	# Espada sedienta: a los 50 enemigos se sacia y pega más.
	if has(&"espada_sedienta"):
		RunState.add_bonus(player.slot.index, &"espada_kills", 1)
		if RunState.get_bonus(player.slot.index, &"espada_kills") == SWORD_KILLS:
			Events.floating_text_requested.emit(player.global_position + Vector3.UP * 3.0,
					"¡Espada sedienta saciada! Las habilidades pegan +30", Color(1.0, 0.82, 0.3))
			Sound.play("chest", -4.0, 0.0)


## Espada sedienta: daño extra (plano) de las habilidades. Lo pide Enemy al recibir el golpe.
func ability_flat_bonus() -> float:
	if not has(&"espada_sedienta") or is_basic_hit():
		return 0.0
	return 30.0 if RunState.get_bonus(player.slot.index, &"espada_kills") >= SWORD_KILLS else 10.0


func _execute(victim: Combatant) -> void:
	var info := DamageInfo.new()
	info.amount = victim.health.current + victim.health.shield + 1.0
	info.attacker = player
	info.attacker_team = DamageInfo.Team.PLAYERS
	info.origin = victim.global_position
	info.tags.append(&"execute")
	info.tags.append(&"proc")
	info.hitstop = 0.0
	victim.receive_hit(info)
	Events.floating_text_requested.emit(victim.global_position + Vector3.UP * 2.6, "¡Ejecutado!",
			Color(1.0, 0.82, 0.3))


func _add_poison(victim: Combatant) -> void:
	var key: int = victim.get_instance_id()
	var now: float = Time.get_ticks_msec() / 1000.0
	var entry: Dictionary = _poison.get(key, {"node": victim, "stacks": 0, "tick": 0.5})
	entry["stacks"] = mini(int(entry["stacks"]) + 1, 3)
	entry["until"] = now + 3.0
	_poison[key] = entry


func _tick_poison(delta: float) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	for key: Variant in _poison.keys():
		var entry: Dictionary = _poison[key]
		var victim := entry["node"] as Combatant
		if not is_instance_valid(victim) or victim.health.is_dead or now > float(entry["until"]):
			_poison.erase(key)
			continue
		entry["tick"] = float(entry["tick"]) - delta
		if float(entry["tick"]) > 0.0:
			continue
		entry["tick"] = 0.5
		var info := DamageInfo.new()
		info.amount = POISON_PER_STACK * int(entry["stacks"])
		info.attacker = player
		info.attacker_team = DamageInfo.Team.PLAYERS
		info.origin = victim.global_position
		info.hitstop = 0.0
		info.tags.append(&"tick")
		info.tags.append(&"proc")
		victim.receive_hit(info)


func poison_stacks(victim: Node) -> int:
	return int(_poison.get(victim.get_instance_id(), {}).get("stacks", 0))


## Bombito: al usar la definitiva, los aliados cercanos van 15% más rápido por 4 s.
func _on_ultimate_used(user: Node3D) -> void:
	if user != player or not has(&"bombito"):
		return
	for node: Node in player.get_tree().get_nodes_in_group(&"players"):
		var ally := node as PlayerCharacter
		if ally != null and not ally.health.is_dead \
				and ally.global_position.distance_to(player.global_position) <= 7.0:
			ally.status.apply(StatusEffects.BOMBITO, 4.0)
	Fx.ring_burst(player.get_parent(), player.global_position, 7.0, Color(1.0, 0.82, 0.3), 0.4)


## Mate de Birig Bamba: al terminar cada sala, te curás 15% de la vida.
func _on_room_finished() -> void:
	if player == null or not is_instance_valid(player) or not has(&"mate_birig") or player.health.is_dead:
		return
	player.health.heal(player.health.max_health * 0.15)
	Events.floating_text_requested.emit(player.global_position + Vector3.UP * 2.6, "¡Un matecito!",
			Color(0.35, 0.95, 0.85))


## Capa de Yole: si bajás del 30%, escudo de 30% de tu vida (una vez por sala).
func _check_cape() -> void:
	if not has(&"capa_yole") or player.health.is_dead or player.health.ratio() >= 0.3 			or _cape_room == RunState.rooms_played:
		return
	_cape_room = RunState.rooms_played
	player.health.add_shield(player.health.max_health * 0.3)
	Events.floating_text_requested.emit(player.global_position + Vector3.UP * 2.6, "¡La Capa de Yole!",
			Color(0.72, 0.88, 1.0))


## Escama de Gronk: un golpe cuerpo a cuerpo le devuelve 20 al que pegó.
func _on_hit_taken(info: DamageInfo) -> void:
	_check_cape()
	if not has(&"escama_gronk") or not info.is_melee or info.has_tag(&"reflect"):
		return
	var attacker := info.attacker as Combatant
	if attacker == null or not is_instance_valid(attacker) or not attacker.is_targetable():
		return
	var reflected: DamageInfo = player.kit.make_hit(20.0)
	reflected.is_crit = false
	reflected.tags.append(&"reflect")
	reflected.hitstop = 0.0
	attacker.receive_hit(reflected)


func _chain_lightning(first: Node3D) -> void:
	var hit: Array[Node3D] = []
	var from: Vector3 = first.global_position + Vector3.UP
	for i: int in 3:
		var next: Hurtbox = null
		var best: float = 8.0
		for hurtbox: Hurtbox in CombatQuery.targets(player.get_tree(), DamageInfo.Team.ENEMIES):
			if hit.has(hurtbox.receiver):
				continue
			var d: float = hurtbox.global_position.distance_to(from)
			if d < best:
				best = d
				next = hurtbox
		if next == null:
			break
		hit.append(next.receiver)
		var info: DamageInfo = player.kit.make_hit(STATIK_CHAIN_DAMAGE)
		info.is_melee = false
		info.tags.append(&"tick")
		next.take_hit(info)
		var to: Vector3 = next.global_position + Vector3.UP
		Fx.beam(player.get_parent(), from, (to - from).normalized(), from.distance_to(to), 0.1, STATIK_COLOR, 0.15)
		from = to
	Events.floating_text_requested.emit(first.global_position + Vector3.UP * 2.6, "¡Statik!", STATIK_COLOR)


## Fragmento del Crepúsculo: el crítico deja un eco de sombra que repite el golpe al 50%.
func _shadow_echo(victim: Combatant, amount: float) -> void:
	var timer: SceneTreeTimer = player.get_tree().create_timer(0.25, false)
	timer.timeout.connect(func() -> void:
		if not is_instance_valid(victim) or not victim.is_targetable() or not is_instance_valid(player):
			return
		var echo := DamageInfo.new()
		echo.amount = amount
		echo.attacker = player
		echo.attacker_team = DamageInfo.Team.PLAYERS
		echo.origin = victim.global_position
		echo.hitstop = 0.0
		echo.tags.append(&"echo")
		victim.receive_hit(echo)
		Fx.ring_burst(victim.get_parent(), victim.global_position, 1.0, ECHO_COLOR, 0.2))


## Kunai de repuesto: queda donde arrancó la esquiva y explota a los 0,5 s.
func _drop_kunai(at: Vector3) -> void:
	var world: Node = player.get_parent()
	var spot := Vector3(at.x, 0.0, at.z)
	var mark := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.12, 0.12, 0.5)
	mark.mesh = mesh
	mark.material_override = Fx.flat_material(Color(0.7, 0.72, 0.76), 0.5)
	world.add_child(mark)
	mark.global_position = spot + Vector3.UP * 0.2
	var timer: SceneTreeTimer = player.get_tree().create_timer(0.5, false)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(mark):
			mark.queue_free()
		if not is_instance_valid(player):
			return
		var info: DamageInfo = player.kit.make_hit(35.0)
		info.origin = spot
		info.is_melee = false
		info.knockback = 5.0
		Combat.deliver(info, CombatQuery.in_circle(player.get_tree(), DamageInfo.Team.ENEMIES, spot, 2.5))
		Fx.ring_burst(world, spot, 2.5, Color(1.0, 0.9, 0.7), 0.3))


## Núcleo Uwey: cada tercera habilidad recupera la carga al toque.
func _watch_abilities() -> void:
	for cooldown: AbilityCooldown in player.kit.ability_cooldowns():
		var before: int = _ability_charges.get(cooldown, cooldown.charges)
		if cooldown.charges < before:
			_abilities_used += 1
			if _abilities_used % 3 == 0:
				cooldown.refill()
				Events.floating_text_requested.emit(player.global_position + Vector3.UP * 2.6,
						"¡Núcleo Uwey!", Color(0.8, 0.9, 1.0))
		_ability_charges[cooldown] = cooldown.charges
