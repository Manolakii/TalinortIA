extends "res://scripts/rooms/test_room.gd"
## Recorrido de un stage (GDD, Estructura de la partida): escenarios X-1 a X-3 con 3 salas
## cada uno. Cada sala sale de una plantilla al azar (con la semilla de la partida).
## Al terminarla se cobra el premio que mostraba la puerta (objeto u oro); al cerrar el
## escenario, oro y una MEJORA de personaje (pedido del grupo, 2026-11-15: antes era al revés). Después salen dos puertas con su premio, y adentro hay
## una sala de combate sorpresa (normal, élite o aguante). Pedido del grupo: cada tanto aparece
## además una puerta de DESAFÍO: un evento de ida y vuelta (como una grieta); al terminarlo,
## ganes o pierdas, se vuelve a la misma sala. Los desafíos no dan oro: dan mejora. El Tesoro y la Cabaña de Pipo son escondidos.
##
## Los jugadores, la cámara y el HUD quedan; lo de la sala vive en `_room_root` y se cambia
## entero al cruzar una puerta.

const HUB_SCENE := "res://scenes/hub/birig_bamba.tscn"
const DOOR_Z := -12.5
const DOOR_X := 7.0
## Qué hay que hacer en cada tipo de sala (cartel en pantalla al entrar).
const HINTS: Dictionary = {
	RoomKind.Type.TREASURE: "¡Encontraron un tesoro escondido! Abrí el cofre con E / X.",
	RoomKind.Type.MIMICS: "Uno de estos cofres muerde. Se puede abrir uno solo: mirá bien antes.",
	RoomKind.Type.PRISONERS: "¡Liberá a los presos antes de que se los lleven! Mantené E / X al lado de cada jaula.",
	RoomKind.Type.PIPO_CABIN: "Shhh... alguien vive acá. Acercate a la cabaña.",
	RoomKind.Type.ESCORT: "¡Escoltá la carreta hasta la salida! Solo avanza si alguien está cerca empujando.",
	RoomKind.Type.MAZE: "Shhh... los Gronks duermen. Si peleás o esquivás cerca, se despiertan. El cofre está a la salida.",
	RoomKind.Type.BOSS: "¡El Gronk Gigante! Hacelo chocar contra las columnas: queda aturdido y recibe más daño.",
	RoomKind.Type.STAMPEDE: "¡Estampida de Gronks! Aguanten sin que caiga nadie: cuando tiembla el piso, ¡muévanse!",
}
## Lugar de la puerta de Desafío (a un costado, para no pisar la de la Cabaña).
const CHALLENGE_DOOR_SPOT := Vector3(14.0, 0, -12.5)
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
## Dentro de un desafío (la sala principal queda guardada en `_main` hasta volver).
var in_challenge: bool = false
var _main: Dictionary = {}


func _ready() -> void:
	add_to_group(&"stage_run")
	add_to_group(&"room_title")
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
	# La capa de combate de la música entra cuando hay enemigos.
	Sound.set_combat(not get_tree().get_nodes_in_group(&"enemies").is_empty())
	# Sala de aguante: cuenta regresiva arriba.
	if room_type == RoomKind.Type.SURVIVAL and director != null and not _done and director.time_left > 0.0:
		if _banner_tween != null:
			_banner_tween.kill()
			_banner_tween = null
		_banner.text = "¡Aguanten! Quedan %d s" % ceili(director.time_left)
		_banner.modulate.a = 1.0
	if not _failed and not _transitioning and _all_players_down():
		_failed = true
		_result_screen.show_result(false)


## Título para el HUD: "1-2 · Ruinas de Ciudad Derrumbe · Sala 2 de 3 · Élite".
func room_title() -> String:
	if room_type == RoomKind.Type.BOSS:
		return config.boss_scenario_name
	var scenario_name: String = config.scenario_names[mini(RunState.scenario, config.scenario_names.size() - 1)]
	if in_challenge:
		var challenge_name: String = RoomKind.display_name(room_type).replace("Evento: ", "")
		return "%s · Desafío: %s" % [scenario_name, challenge_name.left(1).to_upper() + challenge_name.substr(1)]
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
	_clear_leftovers()
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
	if not in_challenge:
		_spawn_vases(rng, spots, type == RoomKind.Type.TREASURE)
	match type:
		RoomKind.Type.COMBAT:
			_start_director(config.combat_waves[rng.randi_range(0, config.combat_waves.size() - 1)])
		RoomKind.Type.ELITE:
			_start_director(config.elite_waves[rng.randi_range(0, config.elite_waves.size() - 1)])
		RoomKind.Type.SURVIVAL:
			_start_director(config.survival_waves)
			director.survival_time = config.survival_time
			director.survival_interval = config.survival_spawn_interval
			director.survival_max_alive = config.survival_max_alive
			director.gold_factor = config.survival_gold_factor
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
			mimics.resolved.connect(_on_event_resolved)
			_event = mimics
		RoomKind.Type.PRISONERS:
			var prisoners := PrisonerEvent.new()
			_room_root.add_child(prisoners)
			var avoid: Array[Vector3] = template.rock_spots()
			avoid.append_array(template.vase_spots())
			avoid.append(template.chest_spot())
			prisoners.defense_time = config.prisoner_defense_time
			prisoners.setup(PrisonerEvent.spread_spots(config.prisoner_count, avoid, config.cage_spacing, rng),
					config.prisoner_count, config.cage_open_time, config.prisoner_gold, template.chest_spot(),
					config.prisoner_time_limit)
			prisoners.defense_started.connect(func(time: float) -> void:
				if director != null:
					director.start_defense(time, config.prisoner_defense_burst,
							config.prisoner_defense_interval, config.prisoner_defense_max_alive))
			prisoners.resolved.connect(func(won: bool) -> void: _on_event_resolved(won, won))
			prisoners.ended.connect(func() -> void:
				if director != null:
					director.stop_and_scatter()
				prisoners.finish_combat())
			_event = prisoners
			_start_director(config.prisoner_waves)
		RoomKind.Type.ESCORT:
			var escort := EscortEvent.new()
			_room_root.add_child(escort)
			escort.setup(config, template, rng)
			escort.resolved.connect(_on_event_resolved)
			_event = escort
		RoomKind.Type.MAZE:
			var maze := MazeEvent.new()
			_room_root.add_child(maze)
			maze.setup(config, template, rng)
			maze.resolved.connect(_on_event_resolved)
			_event = maze
		RoomKind.Type.BOSS:
			var arena := BossArena.new()
			_room_root.add_child(arena)
			arena.setup(template)
			arena.resolved.connect(func(_won: bool) -> void: _room_done())
			_event = arena
		RoomKind.Type.STAMPEDE:
			var stampede := StampedeEvent.new()
			_room_root.add_child(stampede)
			stampede.setup(config, rng)
			stampede.resolved.connect(_on_event_resolved)
			_event = stampede
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
	Sound.music("boss" if type == RoomKind.Type.BOSS else "talinorthland_explore")
	_apply_light(config.boss_light if type == RoomKind.Type.BOSS
			else config.scenario_lights[mini(RunState.scenario, config.scenario_lights.size() - 1)]
			if not config.scenario_lights.is_empty() else null)
	Events.floating_text_requested.emit(Vector3(0, 3.5, 7.0), RoomKind.display_name(type).replace("Evento: ", ""),
			Color.WHITE)
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

## Pedido del grupo: un evento hay que ganarlo sí o sí. Si se pierde, no hay NINGÚN premio
## (ni el de la puerta). Si se gana, el premio de la puerta y la mejora sale "de lujo" (4 opciones).
func _on_event_resolved(won: bool, bonus_item: bool = false) -> void:
	if won:
		_room_done(true, bonus_item)
	else:
		_room_done(false, false, true)


## Premios al terminar. Hay UN objeto por sala como máximo: lo da la puerta "Objeto", la élite
## o un evento perfecto. Si se juntan dos de esas cosas, se elige entre 4 opciones.
## Las mejoras de personaje salen al cerrar el escenario y en los desafíos (pedido del grupo).
## `event_perfect`: el evento salió perfecto. `bonus_item`: objeto extra (salvaron a todos).
func _room_done(event_perfect: bool = false, bonus_item: bool = false, event_lost: bool = false) -> void:
	if _done or _failed:
		return
	_done = true
	Events.room_cleared.emit()
	await get_tree().create_timer(0.8).timeout
	if in_challenge:
		await _challenge_done(not event_lost, bonus_item)
		return
	var reward: int = RunState.room_reward if not RoomKind.is_bonus(room_type) else RoomKind.Reward.NONE
	if event_lost:
		reward = RoomKind.Reward.NONE
		show_banner("Perdieron el evento: esta vez no hay premio.", 4.0)
	if reward == RoomKind.Reward.GOLD:
		await _give_gold_reward()
	var sources: int = 0
	for source: bool in [reward == RoomKind.Reward.ITEM, RoomKind.gives_item(room_type), event_perfect]:
		sources += 1 if source else 0
	if sources > 0:
		var better: bool = sources >= 2
		var heading: String = "¡Objeto de lujo! Elegí entre 4" if better else ""
		await _pick(RewardPicker.Kind.ITEM, heading,
				config.upgrade_options_bonus if better else config.upgrade_options)
	if bonus_item:
		await _pick(RewardPicker.Kind.ITEM, "¡Salvaron a todos! Un objeto de regalo")
	if room_type == RoomKind.Type.BOSS:
		_finish_stage()
		return
	if _riddle_here():
		_spawn_riddle()
	if RunState.is_last_room_of_scenario(config.rooms_per_scenario):
		await _finish_scenario()
		if RunState.scenario >= config.scenario_names.size() - 1:
			_show_boss_door()
			return
	_show_doors()


## Después del 1-3: una sola puerta, la del 1-4 (GDD: el X-4 es una sola sala, la del boss).
func _show_boss_door() -> void:
	_doors_shown = true
	_add_room_door(RoomKind.Type.BOSS, Vector3(0, 0, DOOR_Z))
	show_banner("¡El 1-4! El Gronk Gigante los espera. Entren cuando estén listos (E / X).", -1.0)


func _give_gold_reward() -> void:
	var center: Vector3 = _players_center()
	Events.floating_text_requested.emit(center + Vector3.UP * 4.0, "¡Bolsa de oro!", Color(1.0, 0.82, 0.3))
	Loot.drop_for_all(_room_root, center + Vector3(0, 0, -2.0), [config.gold_reward])
	await get_tree().create_timer(0.6).timeout
	Events.room_cleared.emit()  # que vuelen solas
	await get_tree().create_timer(0.8).timeout


## La roca del pasaje escondido: no en las salas extra ni en la última del stage (ahí no hay puertas).
func _can_hide_treasure(type: int) -> bool:
	if in_challenge or RoomKind.is_bonus(type) or type in RoomKind.EVENTS or type == RoomKind.Type.BOSS:
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
	return not in_challenge and not RunState.pipo_visited and not RoomKind.is_bonus(room_type) \
			and RunState.stage_room_number(config.rooms_per_scenario) == RunState.riddle_room


func _finish_scenario() -> void:
	RunState.scenarios_cleared += 1
	var center: Vector3 = _players_center()
	Events.floating_text_requested.emit(center + Vector3.UP * 4.0, "¡Escenario superado!", Color(1.0, 0.82, 0.3))
	Loot.drop_for_all(_room_root, center + Vector3(0, 0, -2.5), Balance.economy.scenario_gold)
	await get_tree().create_timer(0.6).timeout
	Events.room_cleared.emit()  # que las monedas del final vuelen solas
	await get_tree().create_timer(1.2).timeout
	var scenario_name: String = config.scenario_names[RunState.scenario]
	await _pick(RewardPicker.Kind.UPGRADE, "Fin del %s: elegí una mejora" % scenario_name.get_slice(" · ", 0),
			config.upgrade_options)


## Terminó el stage (ganaron al boss): vuelven a Birig Bamba.
func _finish_stage() -> void:
	show_banner("¡%s liberado! El Gronk queda libre. Volviendo a Birig Bamba..." % config.stage_name, -1.0)
	await get_tree().create_timer(4.0).timeout
	_transitioning = true
	var tween: Tween = create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.5)
	await tween.finished
	_collect_leftover_coins()
	RunState.save_party(players)
	RunState.return_to_hub()
	get_tree().change_scene_to_file(HUB_SCENE)


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
	if _offers_challenge():
		_add_reward_door(RoomKind.Reward.CHALLENGE, CHALLENGE_DOOR_SPOT, "\n(ida y vuelta)")
		show_banner("¡Se abrieron las puertas! Y apareció un Desafío: si lo ganan, mejora de lujo, y vuelven acá.", -1.0)
		return
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


## Lo que hay detrás de una puerta de premio: una sala de combate sorpresa (normal, élite o
## aguante). La primera sala de cada escenario nunca es élite.
func roll_room_type(rng: RandomNumberGenerator) -> int:
	var weights: Array[int] = config.room_weights.duplicate()
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


## Cruza la puerta: si es de premio, lo de adentro sale al azar. La de Desafío es de ida y vuelta.
func go_through(door: RoomDoor) -> void:
	if door.room_type < 0 and door.reward == RoomKind.Reward.CHALLENGE:
		enter_challenge(door)
	elif door.room_type >= 0:
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


# --- Desafíos de ida y vuelta (pedido del grupo, como las grietas) ---

## ¿Aparece la puerta de Desafío en esta sala? Cada tanto, nunca adentro de otro desafío.
func _offers_challenge() -> bool:
	if in_challenge or RoomKind.is_bonus(room_type):
		return false
	return RunState.room_rng(&"challenge").randf() < config.challenge_door_chance


## Qué desafío sale. Como un mazo: no repite hasta que salieron todos (pedido del grupo: la
## carreta no salía nunca por pura mala suerte), y al empezar otra vuelta no repite el último.
func roll_challenge_type(rng: RandomNumberGenerator) -> int:
	var weights: Array[int] = config.challenge_weights.duplicate()
	for seen: int in RunState.challenges_seen:
		if seen >= 0 and seen < weights.size():
			weights[seen] = 0
	var picked: Array[int] = pick_distinct(weights, 1, rng)
	if picked.is_empty():
		RunState.challenges_seen.clear()
		weights = config.challenge_weights.duplicate()
		if RunState.last_challenge >= 0 and RunState.last_challenge < weights.size():
			weights[RunState.last_challenge] = 0
		picked = pick_distinct(weights, 1, rng)
	RunState.challenges_seen.append(picked[0])
	return picked[0]


## Entra al desafío: la sala de ahora queda guardada tal cual (puertas incluidas) para volver.
func enter_challenge(door: RoomDoor) -> void:
	if _transitioning or in_challenge:
		return
	_transitioning = true
	var tween: Tween = create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.35)
	await tween.finished
	_collect_leftover_coins()
	var type: int = roll_challenge_type(RunState.room_rng(&"challenge_type"))
	RunState.last_challenge = type
	RunState.rift += 1
	_main = {"root": _room_root, "type": room_type, "template": template, "done": _done,
			"doors": _doors_shown, "riddle": _riddle_solved, "secret": _secret_found,
			"rock": _cracked_rock, "back": door.global_position + Vector3(0, 0, 3.5)}
	door.queue_free()
	remove_child(_room_root)
	_room_root = null
	in_challenge = true
	# Los desafíos no dan oro (pedido del grupo): la recompensa es la mejora.
	RunState.no_gold = true
	build_room(type)
	var back: Tween = create_tween()
	back.tween_property(_fade, "color:a", 0.0, 0.35)
	await back.finished
	_transitioning = false


## Terminó el desafío: si se ganó, mejora de lujo (y objeto si salió perfecto); después se vuelve.
func _challenge_done(won: bool, bonus_item: bool) -> void:
	if won:
		await _pick(RewardPicker.Kind.UPGRADE, "¡Desafío superado! Mejora de lujo: elegí entre 4",
				config.upgrade_options_bonus)
		if bonus_item:
			await _pick(RewardPicker.Kind.ITEM, "¡Salvaron a todos! Un objeto de regalo")
		show_banner("¡Desafío superado! Volviendo a la sala...", 3.0)
	else:
		show_banner("Perdieron el desafío: esta vez no hay premio. Volviendo a la sala...", 3.0)
	await get_tree().create_timer(2.0).timeout
	if _failed:
		return
	await return_from_challenge()


## Vuelve a la sala de antes, como estaba (con sus puertas), al lado de donde estaba el Desafío.
func return_from_challenge() -> void:
	if not in_challenge:
		return
	_transitioning = true
	var tween: Tween = create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.35)
	await tween.finished
	_collect_leftover_coins()
	remove_child(_room_root)
	_room_root.queue_free()
	_room_root = _main["root"]
	add_child(_room_root)
	room_type = _main["type"]
	template = _main["template"]
	_done = _main["done"]
	_doors_shown = _main["doors"]
	_riddle_solved = _main["riddle"]
	_secret_found = _main["secret"]
	_cracked_rock = _main["rock"]
	_event = null
	_chest = null
	director = null
	in_challenge = false
	RunState.no_gold = false
	_clear_leftovers()
	var back_at: Vector3 = _main["back"]
	_main = {}
	for player: PlayerCharacter in players:
		if not is_instance_valid(player):
			continue
		var i: int = player.slot.index
		player.global_position = back_at + Vector3((i % 2) * 2.0 - 1.0, 0, (i / 2) * 1.6)
		player.velocity = Vector3.ZERO
		player.knockback_velocity = Vector3.ZERO
		player.reset_physics_interpolation()
		var duo := player.kit as MaestroKit
		if duo != null and is_instance_valid(duo.companion):
			duo.companion.global_position = player.global_position + Vector3(1.4, 0, 1.0)
			duo.companion.reset_physics_interpolation()
	_camera.snap_to_targets()
	Sound.music("talinorthland_explore")
	show_banner("¡Volvieron! Elijan una puerta con E / X.", -1.0)
	var back: Tween = create_tween()
	back.tween_property(_fade, "color:a", 0.0, 0.35)
	await back.finished
	_transitioning = false


## Lo que dejaron los personajes en el piso (minas, torretas, hongos, zonas, señuelos) no pasa
## a la sala siguiente (pedido del grupo). Viven al lado de los jugadores, no en la sala.
func _clear_leftovers() -> void:
	for child: Node in _players_root.get_children():
		if child is PlayerCharacter or child is DuoCompanion:
			continue
		_players_root.remove_child(child)
		child.queue_free()


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


## Luz y posprocesado del escenario (cada parte del Stage 1 tiene su clima).
func _apply_light(preset: LightPreset) -> void:
	if preset == null:
		return
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun != null:
		sun.light_color = preset.sun_color
		sun.light_energy = preset.sun_energy
		sun.rotation_degrees.x = preset.sun_pitch_deg
		# El tinte de sala (Noche del Agucci, fases del boss) vuelve a esta luz.
		set_meta(&"sun_color", preset.sun_color)
		set_meta(&"sun_energy", preset.sun_energy)
	var env: Environment = _environment.environment
	env.ambient_light_energy = preset.ambient_energy
	env.fog_light_color = preset.fog_color
	env.fog_density = preset.fog_density
	env.adjustment_saturation = preset.saturation
	env.adjustment_contrast = preset.contrast
