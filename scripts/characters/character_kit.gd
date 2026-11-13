class_name CharacterKit
extends Node
## Base de los kits de personaje. Decide qué hace cada botón; el PlayerCharacter
## se encarga del movimiento, la esquiva y los estados.
##
## Este kit base solo esquiva (lo usan los personajes que todavía no tienen kit).

var player: PlayerCharacter
var data: CharacterData
var dodge_cooldown: AbilityCooldown
## Barra de definitiva, de 0 a 100.
var ult_charge: float = 0.0
## True cuando el golpe común ya conectó y solo queda su recuperación:
## ahí una habilidad o la definitiva lo pueden cortar (feel).
var basic_recovery: bool = false

var _scheduled: Array[Dictionary] = []


func setup(owner_player: PlayerCharacter) -> void:
	player = owner_player
	data = owner_player.data
	dodge_cooldown = AbilityCooldown.new(data.dodge_recharge, data.dodge_charges)
	_setup()


## Cooldowns, barras y acciones programadas. Lo llama el jugador si no está congelado.
func tick(delta: float) -> void:
	dodge_cooldown.tick(delta)
	_tick_scheduled(delta)
	_tick(delta)


## Lee los botones (con buffer) y dispara acciones.
func handle_input() -> void:
	if player.has_buffered(PlayerInput.Action.DODGE) and can_dodge():
		player.consume_buffered(PlayerInput.Action.DODGE)
		do_dodge()
	_handle_ultimate()
	_handle_input()


## Definitiva con la barra llena. El dúo Maestro y Stewie lo sobreescribe (Cambio y Relevo).
func _handle_ultimate() -> void:
	var wants_ult: bool = player.has_buffered(PlayerInput.Action.ULTIMATE)
	if wants_ult and ult_charge >= 100.0 and can_start_skill():
		player.consume_buffered(PlayerInput.Action.ULTIMATE)
		player.end_action()
		if _use_ultimate():
			ult_charge = 0.0


## Puede empezar una habilidad: está libre o en la recuperación de un golpe común.
func can_start_skill() -> bool:
	if player.can_act():
		return true
	return player.is_in_action() and basic_recovery and not player.is_dodging()


func can_dodge() -> bool:
	return dodge_cooldown.is_ready() and not player.is_dodging()


## Esquiva genérica: cancela lo que esté haciendo.
func do_dodge() -> void:
	dodge_cooldown.use()
	cancel_scheduled()
	player.start_dodge(dodge_direction(), data.dodge_distance, data.dodge_duration)


## Hacia donde camina; si está quieto, hacia donde apunta.
func dodge_direction() -> Vector3:
	var move: Vector2 = player.get_move_input()
	if move != Vector2.ZERO:
		return Vector3(move.x, 0.0, move.y).normalized()
	return player.aim_direction


func add_ult(points: float) -> void:
	ult_charge = clampf(ult_charge + points * player.modifiers.ult_charge_multiplier(), 0.0, 100.0)


## Delta para los cooldowns de habilidades (el Reloj Uwey los acorta).
func cd_delta(delta: float) -> float:
	return delta / (1.0 - player.modifiers.cooldown_reduction())


## Velocidad de ataque (Guantes de Gronk): los tiempos del golpe común se dividen por esto.
func attack_speed() -> float:
	return player.modifiers.attack_speed_multiplier()


## Vida base del cuerpo actual (el dúo la cambia según el cuerpo).
func base_max_health() -> float:
	return data.max_health


## Las mejoras de personaje que suman estadísticas las agregan acá (cada kit las define).
func apply_upgrade_stats(_mods: StatModifiers) -> void:
	pass


func has_upgrade(upgrade_id: StringName) -> bool:
	return RunState.has_upgrade(player.slot.index, upgrade_id)


## Llamado cuando un golpe de este jugador conectó.
func on_damage_dealt(info: DamageInfo, _target: Node3D) -> void:
	add_ult(info.final_amount * data.ult_per_damage_dealt)
	_on_damage_dealt(info, _target)


## Llamado cuando este jugador recibió un golpe.
func on_damage_taken(info: DamageInfo) -> void:
	add_ult(info.final_amount * data.ult_per_damage_taken)
	_on_damage_taken(info)


# --- Programar acciones (respetan el hitstop y se cancelan con la esquiva) ---

func schedule(delay: float, callback: Callable) -> void:
	_scheduled.append({"time": delay, "callback": callback})


func cancel_scheduled() -> void:
	_scheduled.clear()


func _tick_scheduled(delta: float) -> void:
	if _scheduled.is_empty():
		return
	var due: Array[Callable] = []
	for i: int in range(_scheduled.size() - 1, -1, -1):
		_scheduled[i]["time"] -= delta
		if _scheduled[i]["time"] <= 0.0:
			due.append(_scheduled[i]["callback"])
			_scheduled.remove_at(i)
	due.reverse()
	for callback: Callable in due:
		if callback.is_valid():
			callback.call()


# --- Para sobreescribir en cada kit ---

func _setup() -> void:
	pass


func _tick(_delta: float) -> void:
	pass


func _handle_input() -> void:
	pass


## Devuelve true si la definitiva se usó (y hay que vaciar la barra).
func _use_ultimate() -> bool:
	return false


func _on_damage_dealt(_info: DamageInfo, _target: Node3D) -> void:
	pass


func _on_damage_taken(_info: DamageInfo) -> void:
	pass


## Si el jugador cae, el kit puede evitarlo (el dúo pasa el control al otro cuerpo).
## Devuelve true si lo resolvió.
func handle_owner_death(_info: DamageInfo) -> bool:
	return false


## Texto si el golpe se esquiva por algo propio del kit; "" si no.
func try_avoid(_info: DamageInfo) -> String:
	return ""


func on_blocked_by_invulnerability(_info: DamageInfo) -> void:
	pass


## Multiplicador para que los enemigos lo elijan (menos de 1 = atrae más).
func target_priority() -> float:
	return 1.0


func move_speed_multiplier() -> float:
	return 1.0


## Multiplicador de daño propio del kit (Hambre de Agucci, Vínculo del dúo...).
func outgoing_multiplier() -> float:
	return 1.0


## Arma un golpe de este jugador: crítico de sus datos, multiplicador del kit y hitstop liviano.
## `source` es quien pega (por defecto el jugador; el compañero del dúo pega con su cuerpo).
func make_hit(base_damage: float, source: Node3D = null) -> DamageInfo:
	var info: DamageInfo = Combat.make_hit(source if source != null else player,
			DamageInfo.Team.PLAYERS, base_damage * outgoing_multiplier(), player.crit_chance(),
			player.crit_multiplier())
	info.hitstop = Balance.combat.hitstop_light
	if info.is_crit:
		info.hitstop += Balance.combat.hitstop_crit_bonus
	return info


## Texto flotante sobre el personaje.
func say(text: String, color: Color = Color.WHITE, size: float = 1.0) -> void:
	var damage_numbers: Node = player.get_tree().get_first_node_in_group(&"damage_numbers")
	if damage_numbers != null:
		damage_numbers.show_text(player.global_position + Vector3.UP * 3.4, text, color, size)


# --- HUD ---

## Barra propia del personaje (segundo renglón del panel). Vacío = no tiene.
## Claves: "label" (String), "value" (0 a 1), "color" (Color), "pulse" (bool).
func hud_bar() -> Dictionary:
	return {}


## Chips (por ejemplo, los modos del arma del Croco) y cuál está activo.
func hud_chips() -> Array[String]:
	return []


func hud_chip_active() -> int:
	return -1


## Habilidades para el panel: [{"name", "ratio" (0 = lista, 1 = recién usada), "text"}].
func hud_abilities() -> Array[Dictionary]:
	return [cooldown_slot("Esquiva", dodge_cooldown), ult_slot("Definitiva")]


## Ayudas para armar los huecos del panel.
static func cooldown_slot(slot_name: String, cd: AbilityCooldown) -> Dictionary:
	var ratio: float = 0.0
	var text: String = ""
	if cd.charges <= 0:
		ratio = clampf(cd.time_until_ready() / maxf(cd.recharge_time, 0.01), 0.0, 1.0)
		text = "%d" % ceili(cd.time_until_ready())
	elif cd.max_charges > 1:
		text = "%d" % cd.charges
	return {"name": slot_name, "ratio": ratio, "text": text}


func ult_slot(slot_name: String) -> Dictionary:
	return {"name": slot_name, "ratio": 1.0 - ult_charge / 100.0,
			"text": "¡Lista!" if ult_charge >= 100.0 else "%d%%" % roundi(ult_charge)}


## Líneas para el HUD de prueba.
func debug_lines() -> Array[String]:
	return ["Definitiva %d%%" % roundi(ult_charge), "Esquiva %d/%d" % [dodge_cooldown.charges, dodge_cooldown.max_charges]]
