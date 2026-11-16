class_name ItemEffects
extends Node
## Objetos genéricos CON EFECTO (pedido del grupo, 2026-11-16, inspirados en Risk of Rain 2):
## sirven para cualquier personaje y cada copia los potencia. Los números están en
## data/items/generic_items.tres (`chance`, `amount`, `extra` de cada objeto).
## Algunos efectos viven en otros lados: Osito de peluche y Energético de Fadied →
## PlayerCharacter; Mira de Pipo y Anteojos de cerca → Enemy (damage_bonus_against).
##
##   bleed        Cuchillo oxidado: chance de sangrado (3 golpecitos de `amount` del golpe).
##   sling        Honda del abuelo: chance de tirarle una piedra al más cercano (`amount` del golpe).
##   chain        Ukelele de cantina: chance de rayo que salta a `extra` enemigos (+1 por copia).
##   on_kill_blast Petardo de Birig Bamba: al matar, explosión de `amount` (radio `extra`).
##   on_kill_shield Huevo de Gronk: al matar, escudo de `amount` (hasta 50% de la vida).
##   first_hit    Mira de Pipo: +`amount` a enemigos con más del 90% de vida.
##   close_range  Anteojos de cerca: +`amount` a enemigos a menos de `extra` m.
##   block        Osito de peluche: chance de bloquear un golpe.
##   extra_dodge  Pluma de pájaro: +1 carga de esquiva.
##   medkit       Botiquín de Champaka: `extra` s después de recibir daño, cura `amount`.
##   still_heal   Hongo quietito: quieto 1 s, cura `amount` de la vida por segundo.
##   calm_speed   Energético de Fadied: +`amount` de velocidad sin pelea.

const PROC_COLOR := Color(1.0, 0.92, 0.6)
const BLEED_COLOR := Color(0.75, 0.15, 0.15)

var player: PlayerCharacter
var _still_time: float = 0.0
var _last_position: Vector3
var _heal_tick: float = 0.0


func setup(owner_player: PlayerCharacter) -> void:
	player = owner_player
	Events.hit_landed.connect(_on_hit_landed)
	player.hit_taken.connect(_on_hit_taken)


## Número de un objeto con efecto (`field`: chance, amount o extra).
static func value(effect: StringName, field: StringName) -> float:
	for item: GenericItem in Balance.generic_items.items:
		if item.effect == effect:
			return item.get(field)
	return 0.0


func stacks(effect: StringName) -> int:
	return player.item_stacks(effect) if player != null else 0


func _physics_process(delta: float) -> void:
	if player == null or player.health.is_dead:
		return
	# Hongo quietito: si no se mueve, se cura de a poco.
	var moved: float = Vector2(player.global_position.x - _last_position.x,
			player.global_position.z - _last_position.z).length()
	_last_position = player.global_position
	_still_time = 0.0 if moved > 0.02 else _still_time + delta
	var fungus: int = stacks(&"still_heal")
	if fungus > 0 and _still_time >= 1.0 and player.health.current < player.health.max_health:
		_heal_tick -= delta
		if _heal_tick <= 0.0:
			_heal_tick = 0.5
			player.health.heal(player.health.max_health * value(&"still_heal", &"amount") * fungus * 0.5)


## Daño extra contra este enemigo (lo pide Enemy al recibir un golpe del jugador).
func damage_bonus_against(enemy: Combatant) -> float:
	var bonus: float = 1.0
	var sight: int = stacks(&"first_hit")
	if sight > 0 and enemy.health.ratio() > 0.9:
		bonus += value(&"first_hit", &"amount") * sight
	var glasses: int = stacks(&"close_range")
	if glasses > 0 and Vector2(enemy.global_position.x - player.global_position.x,
			enemy.global_position.z - player.global_position.z).length() <= value(&"close_range", &"extra"):
		bonus += value(&"close_range", &"amount") * glasses
	return bonus


func _on_hit_landed(info: DamageInfo, target: Node3D) -> void:
	if player == null or info.attacker != player or not is_instance_valid(target) or target == player:
		return
	var victim := target as Combatant
	if victim == null or victim.team == DamageInfo.Team.PLAYERS:
		return
	if info.has_tag(&"proc") or info.has_tag(&"tick") or info.has_tag(&"echo"):
		return
	if victim.health.is_dead:
		_on_kill(victim)
		return
	var base: float = maxf(info.final_amount, info.amount)
	var knife: int = stacks(&"bleed")
	if knife > 0 and Combat.roll(minf(value(&"bleed", &"chance") * knife, 1.0)):
		_bleed(victim, base * value(&"bleed", &"amount"))
	var sling: int = stacks(&"sling")
	if sling > 0 and Combat.roll(value(&"sling", &"chance")):
		_sling(victim, base * value(&"sling", &"amount") * sling)
	var uke: int = stacks(&"chain")
	if uke > 0 and Combat.roll(value(&"chain", &"chance")):
		_chain(victim, base * value(&"chain", &"amount"), int(value(&"chain", &"extra")) + uke - 1)


func _proc_hit(amount: float, origin: Vector3) -> DamageInfo:
	var info: DamageInfo = player.kit.make_hit(amount)
	info.is_crit = false
	info.is_melee = false
	info.hitstop = 0.0
	info.knockback = 0.0
	info.origin = origin
	info.tags.append(&"proc")
	return info


## Cuchillo oxidado: tres golpecitos de sangrado, uno por segundo.
func _bleed(victim: Combatant, per_tick: float) -> void:
	for i: int in 3:
		var timer: SceneTreeTimer = player.get_tree().create_timer(0.5 + i * 1.0, false)
		timer.timeout.connect(func() -> void:
			if not is_instance_valid(victim) or not victim.is_targetable() or not is_instance_valid(player):
				return
			var tick: DamageInfo = _proc_hit(per_tick, victim.global_position)
			tick.tags.append(&"tick")
			victim.receive_hit(tick)
			Fx.ring_burst(victim.get_parent(), victim.global_position, 0.6, BLEED_COLOR, 0.15))


## Honda del abuelo: una piedra que sale de vos hacia el enemigo más cercano.
func _sling(victim: Combatant, amount: float) -> void:
	var target: Hurtbox = CombatQuery.nearest(player.get_tree(), DamageInfo.Team.ENEMIES,
			player.global_position, 14.0)
	if target == null:
		return
	var from: Vector3 = player.global_position + Vector3.UP * 1.4
	var to: Vector3 = target.global_position + Vector3.UP * 1.0
	Fx.beam(player.get_parent(), from, (to - from).normalized(), from.distance_to(to), 0.08,
			Color(0.6, 0.55, 0.48), 0.12)
	target.take_hit(_proc_hit(amount, from))
	if victim == target.receiver:
		Events.floating_text_requested.emit(to + Vector3.UP, "¡Hondazo!", PROC_COLOR)


## Ukelele de cantina: un rayo que salta de enemigo en enemigo.
func _chain(first: Combatant, amount: float, jumps: int) -> void:
	var hit: Array[Node] = [first]
	var from: Vector3 = first.global_position + Vector3.UP
	for i: int in jumps:
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
		var to: Vector3 = next.global_position + Vector3.UP
		Fx.beam(player.get_parent(), from, (to - from).normalized(), from.distance_to(to), 0.07,
				Color(0.75, 0.9, 1.0), 0.15)
		next.take_hit(_proc_hit(amount, from))
		from = to


func _on_kill(victim: Combatant) -> void:
	var at := Vector3(victim.global_position.x, 0.0, victim.global_position.z)
	# Petardo de Birig Bamba: explota el que matás.
	var firecracker: int = stacks(&"on_kill_blast")
	if firecracker > 0:
		var radius: float = value(&"on_kill_blast", &"extra") + 0.5 * (firecracker - 1)
		var blast: DamageInfo = _proc_hit(value(&"on_kill_blast", &"amount") * firecracker, at)
		blast.knockback = 4.0
		Combat.deliver(blast, CombatQuery.in_circle(player.get_tree(), DamageInfo.Team.ENEMIES, at, radius))
		Fx.ring_burst(victim.get_parent(), at, radius, Color(1.0, 0.75, 0.35), 0.25)
	# Huevo de Gronk: escudo que se va sumando (hasta la mitad de la vida).
	var egg: int = stacks(&"on_kill_shield")
	if egg > 0 and not player.health.is_dead:
		var cap: float = player.health.max_health * 0.5
		player.health.add_shield(minf(player.health.shield + value(&"on_kill_shield", &"amount") * egg, cap))


## Botiquín de Champaka: un rato después de recibir daño, cura un poco.
func _on_hit_taken(info: DamageInfo) -> void:
	_still_time = 0.0
	var kits: int = stacks(&"medkit")
	if kits <= 0 or info.final_amount <= 0.0:
		return
	var timer: SceneTreeTimer = player.get_tree().create_timer(value(&"medkit", &"extra"), false)
	timer.timeout.connect(func() -> void:
		if is_instance_valid(player) and not player.health.is_dead:
			player.health.heal(value(&"medkit", &"amount") * kits))
