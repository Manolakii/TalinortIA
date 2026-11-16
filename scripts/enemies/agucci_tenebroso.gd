class_name AgucciTenebroso
extends Enemy
## El Agucci tenebroso (pedido del grupo, 2026-11-15): un NPC de Talinorthland que aparece una
## sola vez por stage, después del primer escenario, al terminar una sala de combate.
##   Ofrenda: a cada jugador le ofrece UNA vez la mitad de su vida actual por un objeto al azar.
##   Si le pegan una vez, avisa ("se pudre el queso"). Si le pegan otra vez, pelea: es muy
##   picado, se mueve para todos lados, pega rápido de cerca, tira un rayo largo con aviso y
##   bombas de veneno.
##   Si lo matan, deja dos cofres: uno es un mimic y el otro tiene un objeto de la tienda de
##   Yole. Se abre uno solo. Si sale el mimic y lo matan, suelta oro de consuelo.

signal turned_hostile
signal defeated

enum Mode { PEACEFUL, MOVE, MELEE_WINDUP, BEAM_WINDUP, RECOVER }

const SHADOW := Color(0.45, 0.2, 0.72)
const USE_RADIUS := 2.6
## Golpes que llegan juntos (perdigones, combos) cuentan como un solo toque.
const TOUCH_GAP := 0.6
const OFFER_LINES: Array[String] = [
	"Psst. Vos. Dame la mitad de tu vida y te doy algo lindo.",
	"La sombra tiene hambre... y yo tengo cosas. Hagamos negocios.",
	"Media vida por un objeto. Barato. Lo más barato de Talinorthland.",
]

var mode: Mode = Mode.PEACEFUL
## Quiénes ya hicieron la ofrenda (índice del jugador).
var offered: Array[int] = []
var touches: int = 0
## Números de la pelea.
var beam_length: float = 24.0
var beam_width: float = 1.8
var beam_windup: float = 0.85
var beam_damage_ratio: float = 2.4
var beam_cooldown: float = 5.0
var bomb_cooldown: float = 6.0
var bomb_count: int = 3
var bomb_damage_ratio: float = 0.9
var blink_cooldown: float = 2.6
var consolation_gold: int = 40

var _time: float = 0.0
var _last_touch: float = -10.0
var _beam_timer: float = 3.0
var _bomb_timer: float = 4.5
var _blink_timer: float = 2.0
var _strafe_timer: float = 0.0
var _strafe_side: float = 1.0
var _beam_direction: Vector3 = Vector3.FORWARD
var _speech: Label3D
var _prompt: Label3D


func _ready() -> void:
	enemy_id = &"agucci_tenebroso"
	drops_gold = true
	super._ready()
	remove_from_group(&"enemies")  # mientras está tranquilo no es una pelea
	add_to_group(&"npcs")
	_say(OFFER_LINES.pick_random(), 5.0)


func is_peaceful() -> bool:
	return mode == Mode.PEACEFUL


# --- Tranquilo: ofrenda y toques ---

func _physics_process(delta: float) -> void:
	if is_peaceful() and not health.is_dead:
		_peaceful_tick()
	super._physics_process(delta)


func _peaceful_tick() -> void:
	var someone_can_offer: bool = false
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var player := node as PlayerCharacter
		if player == null or player.health.is_dead or player.menu_locked or offered.has(player.slot.index):
			continue
		if flat_distance_to(player.global_position) > USE_RADIUS:
			continue
		someone_can_offer = true
		if player.slot.input.just_pressed(PlayerInput.Action.INTERACT):
			make_offer(player)
	_prompt.visible = someone_can_offer


## La ofrenda: la mitad de la vida actual por un objeto al azar (una vez por jugador).
func make_offer(player: PlayerCharacter) -> void:
	if not is_peaceful() or offered.has(player.slot.index):
		return
	offered.append(player.slot.index)
	Achievements.unlock("negocios_turbios")
	player.health.current = maxf(player.health.current * 0.5, 1.0)
	player.health.changed.emit(player.health.current, player.health.max_health)
	player.flash()
	var items: Array[GenericItem] = Balance.generic_items.items
	var item: GenericItem = items[RunState.rng.randi_range(0, items.size() - 1)]
	RunState.add_item(player.slot.index, item.id)
	Events.floating_text_requested.emit(player.global_position + Vector3.UP * 2.8,
			"Media vida por: %s" % item.display_name, Color(0.8, 0.65, 1.0))
	Fx.ring_burst(get_parent(), player.global_position, 1.4, SHADOW, 0.3)
	Sound.play("ui_confirm", -4.0)
	_say("Trato hecho. Un placer hacer negocios con vos.", 3.0)


func receive_hit(info: DamageInfo) -> bool:
	if not is_peaceful():
		return super.receive_hit(info)
	if info.attacker_team != DamageInfo.Team.PLAYERS:
		return false
	flash()
	var now: float = _time
	if now - _last_touch < TOUCH_GAP:
		return true
	_last_touch = now
	touches += 1
	if touches == 1:
		_say("Ey. Si me volvés a tocar, se pudre el queso.", 3.5)
		Events.camera_shake_requested.emit(0.1)
	else:
		turn_hostile()
	return true


func turn_hostile() -> void:
	if not is_peaceful():
		return
	mode = Mode.MOVE
	_prompt.visible = false
	add_to_group(&"enemies")
	remove_from_group(&"npcs")
	_say("Bueno. Vos lo pediste.", 3.0)
	Events.camera_shake_requested.emit(0.35)
	Sound.play("roar", -6.0)
	Fx.ring_burst(get_parent(), global_position, 3.5, SHADOW, 0.4)
	turned_hostile.emit()


# --- Pelea ---

func _think(delta: float) -> void:
	_time += delta
	if is_peaceful():
		stop(delta)
		var target: Node3D = nearest_target()
		if target != null:
			turn_towards(flat_direction_to(target.global_position), delta)
		return
	if status.has(StatusEffects.STUN):
		stop(delta)
		return
	_beam_timer -= delta
	_bomb_timer -= delta
	_blink_timer -= delta
	var target: Node3D = nearest_target()
	if target == null:
		stop(delta)
		return
	match mode:
		Mode.MOVE:
			_move(target, delta)
		Mode.MELEE_WINDUP:
			stop(delta)
			if _mode_time() >= windup_time():
				_melee()
		Mode.BEAM_WINDUP:
			stop(delta)
			if _mode_time() >= beam_windup:
				_fire_beam()
		Mode.RECOVER:
			stop(delta)
			if _mode_time() >= recovery_time():
				_set_mode(Mode.MOVE)


var _mode_start: float = 0.0


func _mode_time() -> float:
	return _time - _mode_start


func _set_mode(new_mode: Mode) -> void:
	mode = new_mode
	_mode_start = _time


func _move(target: Node3D, delta: float) -> void:
	var distance: float = flat_distance_to(target.global_position)
	var to_target: Vector3 = flat_direction_to(target.global_position)
	if distance <= data.attack_range:
		facing = to_target
		_set_mode(Mode.MELEE_WINDUP)
		telegraph.rotation.y = facing_angle()
		telegraph.show_sector(data.attack_radius, data.attack_angle_deg, windup_time())
		return
	if _beam_timer <= 0.0 and distance <= beam_length - 2.0:
		_beam_timer = beam_cooldown
		_beam_direction = to_target
		facing = to_target
		_set_mode(Mode.BEAM_WINDUP)
		telegraph.rotation.y = facing_angle()
		telegraph.show_rect(beam_length, beam_width, beam_windup)
		_say("¡Mirá la luz!", 1.2)
		return
	if _bomb_timer <= 0.0:
		_bomb_timer = bomb_cooldown
		_throw_bombs()
	if _blink_timer <= 0.0:
		_blink_timer = blink_cooldown
		_blink(to_target)
		return
	# Se mueve para todos lados: rodea al objetivo cambiando de lado seguido, y se le tira encima.
	_strafe_timer -= delta
	if _strafe_timer <= 0.0:
		_strafe_timer = randf_range(0.4, 0.9)
		_strafe_side = -_strafe_side
	var side: Vector3 = to_target.rotated(Vector3.UP, PI * 0.5 * _strafe_side)
	var closing: float = 0.8 if distance > 5.0 else 0.2
	move_looking((to_target * closing + side).normalized(), data.move_speed, to_target, delta)


## Salto de sombra corto hacia un costado del objetivo.
func _blink(to_target: Vector3) -> void:
	var side: Vector3 = to_target.rotated(Vector3.UP, PI * 0.5 * (1.0 if randf() < 0.5 else -1.0))
	var from: Vector3 = global_position
	var step: Vector3 = (side + to_target * 0.5).normalized() * 4.0
	var to: Vector3 = from + step
	to.x = clampf(to.x, -21.0, 21.0)
	to.z = clampf(to.z, -12.0, 12.0)
	Fx.ring_burst(get_parent(), from, 1.2, SHADOW, 0.2)
	global_position = Vector3(to.x, from.y, to.z)
	reset_physics_interpolation()
	Fx.ring_burst(get_parent(), global_position, 1.2, SHADOW, 0.2)


func _melee() -> void:
	telegraph.hide_telegraph()
	for hurtbox: Hurtbox in CombatQuery.in_sector(get_tree(), attack_team(), global_position, facing,
			data.attack_radius, data.attack_angle_deg):
		hurtbox.take_hit(make_attack())
	Fx.slash(get_parent(), global_position, facing, data.attack_radius, data.attack_angle_deg, SHADOW, 0.1)
	_set_mode(Mode.RECOVER)


func _fire_beam() -> void:
	telegraph.hide_telegraph()
	var from: Vector3 = global_position
	var to: Vector3 = from + _beam_direction * beam_length
	for hurtbox: Hurtbox in CombatQuery.in_line(get_tree(), attack_team(), from, to, beam_width):
		var info: DamageInfo = make_attack(beam_damage_ratio)
		info.knockback = 7.0
		info.shake = Balance.combat.shake_heavy * 0.5
		hurtbox.take_hit(info)
	Fx.beam(get_parent(), from + Vector3.UP * 1.2, _beam_direction, beam_length, beam_width * 0.5, SHADOW, 0.3)
	Events.camera_shake_requested.emit(0.25)
	_set_mode(Mode.RECOVER)


func _throw_bombs() -> void:
	var spots: Array[Vector3] = []
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var player := node as PlayerCharacter
		if player != null and not player.health.is_dead and spots.size() < bomb_count:
			spots.append(player.global_position)
	while spots.size() < bomb_count:
		spots.append(global_position + Vector3(randf_range(-7, 7), 0, randf_range(-7, 7)))
	for spot: Vector3 in spots:
		var bomb := PoisonBomb.new()
		get_parent().add_child(bomb)
		bomb.launch(global_position + Vector3.UP * 1.6, spot, 1.0, 1.8, make_attack(bomb_damage_ratio))
		bomb.zone_dps = 8.0 * damage_multiplier


func _on_interrupted() -> void:
	if mode == Mode.MELEE_WINDUP or mode == Mode.BEAM_WINDUP:
		telegraph.hide_telegraph()
		_set_mode(Mode.RECOVER)


# --- Al morir: dos cofres, uno muerde ---

func _drop_gold() -> void:
	_say("Esto... no... termina acá...", 2.5)
	var center := Vector3(clampf(global_position.x, -17.0, 17.0), 0.0, clampf(global_position.z, -9.0, 9.0))
	Achievements.unlock("queso_podrido")
	var reward := ShadeChests.new()
	reward.consolation_gold = consolation_gold
	get_parent().add_child(reward)
	reward.global_position = center
	reward.setup(RunState.rng.randf() < 0.5)
	defeated.emit()


# --- Visual y textos ---

func _say(text: String, seconds: float) -> void:
	if _speech == null:
		return
	_speech.text = text
	_speech.modulate.a = 1.0
	var fade: Tween = _speech.create_tween()
	fade.tween_interval(seconds)
	fade.tween_property(_speech, "modulate:a", 0.0, 0.4)


func _build_extras() -> void:
	if not has_model():
		_build_hood()
	_build_smoke_and_labels()


## Capucha y ojos violetas (solo con la forma simple; el modelo ya tiene capucha).
func _build_hood() -> void:
	var hood := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = data.body_radius + 0.12
	cone.height = 0.8
	hood.mesh = cone
	hood.position.y = data.body_height + 0.1
	hood.material_override = _make_material(data.body_color.darkened(0.3))
	visual.add_child(hood)
	for side: float in [-1.0, 1.0]:
		var eye := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.06
		sphere.height = 0.12
		eye.mesh = sphere
		eye.position = Vector3(side * 0.13, data.body_height * 0.86, -data.body_radius + 0.02)
		eye.material_override = Fx.flat_material(SHADOW.lightened(0.4), 3.0)
		visual.add_child(eye)


func _build_smoke_and_labels() -> void:
	var smoke := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.1
	disc.bottom_radius = 1.1
	disc.height = 0.03
	smoke.mesh = disc
	smoke.position.y = 0.04
	var smoke_material := Fx.flat_material(Color(SHADOW, 0.45), 1.0)
	smoke_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smoke.material_override = smoke_material
	add_child(smoke)
	_speech = Label3D.new()
	_speech.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_speech.no_depth_test = true
	_speech.font_size = 40
	_speech.outline_size = 12
	_speech.width = 700.0
	_speech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech.modulate = Color(0.85, 0.75, 1.0)
	_speech.position.y = data.body_height + 1.6
	add_child(_speech)
	_prompt = Label3D.new()
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.no_depth_test = true
	_prompt.font_size = 34
	_prompt.outline_size = 10
	_prompt.text = "E / X: ofrenda (la mitad de tu vida por un objeto)"
	_prompt.modulate = Color(1.0, 0.95, 0.85)
	_prompt.position.y = data.body_height + 0.9
	_prompt.visible = false
	add_child(_prompt)
