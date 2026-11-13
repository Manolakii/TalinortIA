extends "res://scripts/rooms/test_room.gd"
## Recorrido de un stage (GDD, Estructura de la partida): escenarios X-1 a X-3 con 3 salas
## cada uno. Cada sala sale de una plantilla al azar (con la semilla de la partida).
## Al terminarla se cobra el premio que mostraba la puerta (mejora, oro o curación); al cerrar
## el escenario, oro y objeto 1 de 3. Después salen dos puertas con su premio, y lo que hay
## adentro es sorpresa (combate, élite o evento). El Tesoro y la Cabaña de Pipo son escondidos.
##
## Los jugadores, la cámara y el HUD quedan; lo de la sala vive en `_room_root` y se cambia
## entero al cruzar una puerta.

const DOOR_Z := -12.5
const DOOR_X := 7.0
## Qué hay que hacer en cada tipo de sala (cartel en pantalla al entrar).
const HINTS: Dictionary = {
	RoomKind.Type.TREASURE: "¡Encontraron un tesoro escondido! Abrí el cofre con E / X.",
	RoomKind.Type.MIMICS: "Uno de estos cofres muerde. Se puede abrir uno solo: mirá bien antes.",
	RoomKind.Type.PRISONERS: "¡Liberá a los presos antes de que se los lleven! Mantené E / X al lado de cada jaula.",
	RoomKind.Type.PIPO_CABIN: "Shhh... alguien vive acá. Acercate a la cabaña.",
}
const ENTRY_SPOTS: Array[Vector3] = [Vector3(-1.5, 0, 10.5), Vector3(1.5, 0, 10.5),
		Vector3(-1.5, 0, 12.5), Vector3(1.5, 0, 12.5)]

var config: StageRoomsConfig
var room_type: int = RoomKind.Type.COMBAT
var template: RoomTemplate
var _room_root: Node3D
var _event: Node
var _chest: Chest
var _result_screen: CanvasLayer
var _fade: ColorRect
var _banner: Label
var _banner_tween: Tween
var _done: bool = false
var _failed: bool = false
var _transitioning: bool = false
var _doors_shown: bool = false
var _riddle_solved: bool = false
var _secret_found: bool = false
var _cracked_rock: CrackedRock


func _ready() -> void:
	add_to_group(&"stage_run")
	config = Balance.stage_rooms(RunState.stage)
	GameSettings.apply_to_environment(_environment.environment)
	Events.quality_changed.connect(_on_quality_changed)
	Events.room_tint_requested.connect(_on_room_tint)
	Events.player_out.connect(_on_player_out)
	if PlayerManager.player_count() == 0:
		_auto_join_for_testing()
	GameSettings.auto_revive_players = false
	# La sala base trae rocas y enemigos infinitos de la sala de prueba: acá no van.
	for leftover: String in ["Rocks", "EnemySpawner"]:
		var node: Node = get_node_or_null(leftover)
		if node != null:
			remove_child(node)
			node.queue_free()
	_spawn_players()
	_result_screen = RESULT_SCENE.instantiate()
	add_child(_result_screen)
	_build_fade()
	if RunState.riddle_room < 0:
		var rng: RandomNumberGenerator = RunState.room_rng(&"riddle")
		RunState.riddle_room = config.riddle_scenario * config.rooms_per_scenario \
				+ rng.randi_range(0, config.rooms_per_scenario - 2)
	build_room(RunState.room_type)
	Fx.prewarm(_camera_focus_node())


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not _failed and not _transitioning and _all_players_down():
		_failed = true
		_result_screen.show_result(false)


## Título para el HUD: "1-2 · Ruinas de Ciudad Derrumbe · Sala 2 de 3 · Élite".
func room_title() -> String:
	var scenario_name: String = config.scenario_names[mini(RunState.scenario, config.scenario_names.size() - 1)]
	if RoomKind.is_bonus(room_type):
		return "%s · %s" % [scenario_name, RoomKind.display_name(room_type)]
	var text: String = "%s · Sala %d de %d · %s" % [scenario_name, RunState.room_index + 1,
			config.rooms_per_scenario, RoomKind.display_name(room_type)]
	if RunState.room_reward != RoomKind.Reward.NONE:
		text += " · Premio: %s" % RoomKind.reward_name(RunState.room_reward)
	return text


# --- Armar la sala ---

func build_room(type: int) -> void:
	room_type = type
	_done = false
	_doors_shown = false
	_riddle_solved = false
	_secret_found = false
	_cracked_rock = null
	_event = null
	_chest = null
	director = null
	if _room_root != null:
		remove_child(_room_root)
		_room_root.queue_free()
	_room_root = Node3D.new()
	_room_root.name = "Room"
	add_child(_room_root)
	var rng: RandomNumberGenerator = RunState.room_rng(&"layout")
	template = config.templates[rng.randi_range(0, config.templates.size() - 1)].instantiate()
	_room_root.add_child(template)
	_place_players()
	var spots: Array[Vector3] = template.vase_spots()
	if _can_hide_treasure(type) and rng.randf() < config.hidden_treasure_chance:
		_cracked_rock = CrackedRock.new()
		_cracked_rock.hits_needed = config.cracked_rock_hits
		_cracked_rock.position = spots.pop_at(rng.randi_range(0, spots.size() - 1))
		_room_root.add_child(_cracked_rock)
		_cracked_rock.broken.connect(_on_secret_found)
	_spawn_vases(rng, spots, type == RoomKind.Type.TREASURE)
	match type:
		RoomKind.Type.COMBAT:
			_start_director(config.combat_waves[rng.randi_range(0, config.combat_waves.size() - 1)])
		RoomKind.Type.ELITE:
			_start_director(config.elite_waves[rng.randi_range(0, config.elite_waves.size() - 1)])
		RoomKind.Type.TREASURE:
			_chest = Chest.new()
			_chest.position = template.chest_spot()
			_room_root.add_child(_chest)
			_chest.opened.connect(func(_by: PlayerCharacter) -> void: _room_done())
			if rng.randf() < config.treasure_guard_chance:
				_chest.locked = true
				_start_director(config.treasure_guard_waves)
		RoomKind.Type.MIMICS:
			var mimics := MimicEvent.new()
			_room_root.add_child(mimics)
			mimics.setup(template.feature_spots(), rng)
			mimics.resolved.connect(func(perfect: bool) -> void: _room_done(perfect))
			_event = mimics
		RoomKind.Type.PRISONERS:
			var prisoners := PrisonerEvent.new()
			_room_root.add_child(prisoners)
			prisoners.setup(template.feature_spots(), config.prisoner_count, config.cage_open_time,
					config.prisoner_gold, template.chest_spot())
			prisoners.resolved.connect(func(all_saved: bool) -> void: _room_done(true, all_saved))
			_event = prisoners
			_start_director(config.prisoner_waves)
		RoomKind.Type.PIPO_CABIN:
			var cabin := PipoCabin.new()
			_room_root.add_child(cabin)
			cabin.resolved.connect(func() -> void: _room_done())
			_event = cabin
	if RunState.turret_pending and type != RoomKind.Type.PIPO_CABIN:
		RunState.turret_pending = false
		var turret := AllyTurret.new()
		turret.setup(config)
		turret.position = Vector3(3.5, 0, 8.0)
		_room_root.add_child(turret)
	Events.floating_text_requested.emit(Vector3(0, 3.5, 7.0), room_title(), Color.WHITE)
	if HINTS.has(type):
		show_banner(HINTS[type], 6.0)
	else:
		show_banner("", 0.0)


func _place_players() -> void:
	for player: PlayerCharacter in players:
		if not is_instance_valid(player):
			continue
		player.global_position = ENTRY_SPOTS[player.slot.index % ENTRY_SPOTS.size()]
		player.velocity = Vector3.ZERO
		player.knockback_velocity = Vector3.ZERO
		player.reset_physics_interpolation()
		var duo := player.kit as MaestroKit
		if duo != null and is_instance_valid(duo.companion):
			duo.companion.global_position = player.global_position + Vector3(1.4, 0, 1.0)
			duo.companion.reset_physics_interpolation()
	_camera.snap_to_targets()


func _spawn_vases(rng: RandomNumberGenerator, spots: Array[Vector3], all_spots: bool) -> void:
	var count: int = spots.size() if all_spots else rng.randi_range(config.vases_min, config.vases_max)
	for i: int in mini(count, spots.size()):
		var vase := Vase.new()
		vase.position = spots.pop_at(rng.randi_range(0, spots.size() - 1))
		_room_root.add_child(vase)


func _start_director(waves: RoomWaves) -> void:
	director = CombatDirector.new()
	director.name = "CombatDirector"
	director.waves = waves
	director.count_multiplier = 1.0 + config.count_bonus_per_scenario * RunState.scenario
	if RunState.room_reward == RoomKind.Reward.CHALLENGE and not RoomKind.is_bonus(room_type):
		director.extra_elites = config.challenge_extra_elites
		director.count_multiplier *= config.challenge_count_multiplier
	_room_root.add_child(director)
	director.room_cleared.connect(_on_combat_cleared)


func _on_combat_cleared() -> void:
	match room_type:
		RoomKind.Type.TREASURE:
			if _chest != null:
				_chest.locked = false
		RoomKind.Type.PRISONERS:
			(_event as PrisonerEvent).finish_combat()
		_:
			_room_done()


# --- Terminar la sala: premios y puertas ---

## Premios al terminar. Hay UNA mejora por sala como máximo (pedido del grupo: se juntaban
## demasiadas): la da la puerta "Mejora" o "Desafío", la élite (GDD) o un evento perfecto.
## Si se juntan dos de esas cosas, en vez de otra mejora se elige entre 4 opciones.
## `event_perfect`: el evento salió perfecto. `bonus_item`: objeto extra (salvaron a todos).
func _room_done(event_perfect: bool = false, bonus_item: bool = false) -> void:
	if _done or _failed:
		return
	_done = true
	Events.room_cleared.emit()
	await get_tree().create_timer(0.8).timeout
	var reward: int = RunState.room_reward if not RoomKind.is_bonus(room_type) else RoomKind.Reward.NONE
	if reward == RoomKind.Reward.GOLD:
		await _give_gold_reward()
	var sources: int = 0
	for source: bool in [reward == RoomKind.Reward.UPGRADE, reward == RoomKind.Reward.CHALLENGE,
			RoomKind.gives_upgrade(room_type), event_perfect]:
		sources += 1 if source else 0
	if sources > 0:
		var better: bool = sources >= 2 or reward == RoomKind.Reward.CHALLENGE
		var heading: String = "¡Mejora de lujo! Elegí entre 4" if better else ""
		await _pick(RewardPicker.Kind.UPGRADE, heading,
				config.upgrade_options_bonus if better else config.upgrade_options)
	if bonus_item:
		await _pick(RewardPicker.Kind.ITEM, "¡Salvaron a todos! Un objeto de regalo")
	if _riddle_here():
		_spawn_riddle()
	if RunState.is_last_room_of_scenario(config.rooms_per_scenario):
		await _finish_scenario()
		if RunState.scenario >= config.scenario_names.size() - 1:
			_finish_stage()
			return
	_show_doors()


func _give_gold_reward() -> void:
	var center: Vector3 = _players_center()
	Events.floating_text_requested.emit(center + Vector3.UP * 4.0, "¡Bolsa de oro!", Color(1.0, 0.82, 0.3))
	Loot.drop_for_all(_room_root, center + Vector3(0, 0, -2.0), [config.gold_reward])
	await get_tree().create_timer(0.6).timeout
	Events.room_cleared.emit()  # que vuelen solas
	await get_tree().create_timer(0.8).timeout


## La roca del pasaje escondido: no en las salas extra ni en la última del stage (ahí no hay puertas).
func _can_hide_treasure(type: int) -> bool:
	if RoomKind.is_bonus(type):
		return false
	var last_of_stage: bool = RunState.scenario >= config.scenario_names.size() - 1 \
			and RunState.room_index >= config.rooms_per_scenario - 1
	return not last_of_stage


func _on_secret_found() -> void:
	_secret_found = true
	if _doors_shown:
		_add_room_door(RoomKind.Type.TREASURE, _secret_door_spot())
	else:
		show_banner("¡Un pasaje escondido! Se abre cuando terminen la sala.", 4.0)


func _secret_door_spot() -> Vector3:
	var at: Vector3 = _cracked_rock.global_position if is_instance_valid(_cracked_rock) else Vector3(0, 0, -6)
	return Vector3(at.x, 0, at.z)


func _riddle_here() -> bool:
	return not RunState.pipo_visited and not RoomKind.is_bonus(room_type) \
			and RunState.stage_room_number(config.rooms_per_scenario) == RunState.riddle_room


func _finish_scenario() -> void:
	var center: Vector3 = _players_center()
	Events.floating_text_requested.emit(center + Vector3.UP * 4.0, "¡Escenario superado!", Color(1.0, 0.82, 0.3))
	Loot.drop_for_all(_room_root, center + Vector3(0, 0, -2.5), Balance.economy.scenario_gold)
	await get_tree().create_timer(0.6).timeout
	Events.room_cleared.emit()  # que las monedas del final vuelen solas
	await get_tree().create_timer(1.2).timeout
	var scenario_name: String = config.scenario_names[RunState.scenario]
	await _pick(RewardPicker.Kind.ITEM, "Fin del %s: elegí un objeto" % scenario_name.get_slice(" · ", 0))


func _finish_stage() -> void:
	_result_screen.show_result(true, "¡%s liberado!" % config.stage_name,
			"Bueno, casi: el Gronk Gigante los espera en el 1-4 (llega en la Fase 7).")


func _pick(kind: RewardPicker.Kind, heading: String = "", option_count: int = 3) -> void:
	var eligible: Array[PlayerCharacter] = []
	for player: PlayerCharacter in players:
		if is_instance_valid(player) and not player.is_out():
			eligible.append(player)
	if eligible.is_empty():
		return
	var picker := RewardPicker.new()
	add_child(picker)
	picker.start(kind, eligible, heading, option_count)
	await picker.finished
	picker.queue_free()


func _spawn_riddle() -> void:
	var riddle := PipoRiddle.new()
	riddle.position = template.riddle_spot()
	_room_root.add_child(riddle)
	riddle.setup(RunState.room_rng(&"riddle_answers"))
	riddle.solved.connect(_on_riddle_solved)


func _on_riddle_solved() -> void:
	_riddle_solved = true
	show_banner("Se abrió un sendero escondido... ¿una tercera puerta?", -1.0)
	if _doors_shown:
		_add_room_door(RoomKind.Type.PIPO_CABIN, Vector3(0, 0, DOOR_Z))


func _show_doors() -> void:
	_doors_shown = true
	var rewards: Array[int] = pick_distinct(config.reward_weights, 2, RunState.room_rng(&"doors"))
	var extra: String = ""
	if RunState.room_index >= config.rooms_per_scenario - 1:
		extra = "\n" + config.scenario_names[RunState.scenario + 1].get_slice(" · ", 0)
	_add_reward_door(rewards[0], Vector3(-DOOR_X, 0, DOOR_Z), extra)
	_add_reward_door(rewards[1], Vector3(DOOR_X, 0, DOOR_Z), extra)
	if _riddle_solved:
		_add_room_door(RoomKind.Type.PIPO_CABIN, Vector3(0, 0, DOOR_Z))
	if _secret_found:
		_add_room_door(RoomKind.Type.TREASURE, _secret_door_spot())
	show_banner("¡Se abrieron las puertas! Vayan para arriba y elijan una con E / X.", -1.0)


## `count` índices distintos según los pesos (los de peso 0 no salen).
static func pick_distinct(weights: Array[int], count: int, rng: RandomNumberGenerator) -> Array[int]:
	var result: Array[int] = []
	while result.size() < count:
		var total: int = 0
		for i: int in weights.size():
			if not result.has(i):
				total += weights[i]
		if total <= 0:
			break
		var roll: int = rng.randi_range(1, total)
		for i: int in weights.size():
			if result.has(i):
				continue
			roll -= weights[i]
			if roll <= 0:
				result.append(i)
				break
	return result


## Lo que hay detrás de una puerta de premio: sorpresa. No repite el mismo evento seguido,
## y la primera sala de cada escenario nunca es élite.
func roll_room_type(rng: RandomNumberGenerator) -> int:
	var weights: Array[int] = config.room_weights.duplicate()
	if room_type in [RoomKind.Type.MIMICS, RoomKind.Type.PRISONERS]:
		weights[room_type] = 0
	if RunState.room_index >= config.rooms_per_scenario - 1 and not RoomKind.is_bonus(room_type):
		weights[RoomKind.Type.ELITE] = 0
	return pick_distinct(weights, 1, rng)[0]


func _add_reward_door(reward: int, at: Vector3, extra: String = "") -> void:
	var door := RoomDoor.new()
	door.position = at
	_room_root.add_child(door)
	door.setup_reward(reward, extra)
	door.chosen.connect(go_through)


func _add_room_door(type: int, at: Vector3) -> void:
	var door := RoomDoor.new()
	door.position = at
	_room_root.add_child(door)
	door.setup(type)
	door.chosen.connect(go_through)


## Cruza la puerta: si es de premio, lo de adentro sale al azar.
func go_through(door: RoomDoor) -> void:
	if door.room_type >= 0:
		go_to(door.room_type)
	else:
		go_to(roll_room_type(RunState.room_rng(&"next_room")), door.reward)


## Cruza a la sala elegida, con un fundido.
func go_to(type: int, reward: int = RoomKind.Reward.NONE) -> void:
	if _transitioning:
		return
	_transitioning = true
	var tween: Tween = create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.35)
	await tween.finished
	_collect_leftover_coins()
	RunState.advance_to(type, config.rooms_per_scenario, reward)
	build_room(type)
	var back: Tween = create_tween()
	back.tween_property(_fade, "color:a", 0.0, 0.35)
	await back.finished
	_transitioning = false


func _collect_leftover_coins() -> void:
	for node: Node in _room_root.find_children("*", "", true, false):
		if node is GoldCoin:
			(node as GoldCoin).collect()


## Cartel abajo del título de la sala. `duration` < 0 = queda hasta la próxima sala.
func show_banner(text: String, duration: float) -> void:
	if _banner_tween != null:
		_banner_tween.kill()
	_banner.text = text
	_banner.modulate.a = 1.0 if text != "" else 0.0
	if duration > 0.0:
		_banner_tween = create_tween()
		_banner_tween.tween_interval(duration)
		_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.6)


func _build_fade() -> void:
	var banner_layer := CanvasLayer.new()
	banner_layer.layer = 31
	add_child(banner_layer)
	_banner = Label.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.offset_top = 52.0
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 30)
	_banner.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_banner.add_theme_constant_override("outline_size", 10)
	banner_layer.add_child(_banner)
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)


func _players_center() -> Vector3:
	var sum := Vector3.ZERO
	var count: int = 0
	for player: PlayerCharacter in players:
		if is_instance_valid(player) and not player.is_out():
			sum += player.global_position
			count += 1
	return sum / maxf(count, 1)


func _all_players_down() -> bool:
	if players.is_empty():
		return false
	for player: PlayerCharacter in players:
		if is_instance_valid(player) and not player.health.is_dead:
			return false
	return true
