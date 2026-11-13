class_name ReviveComponent
extends Node
## Caer y revivir (GDD, Muerte y revivir):
##   - El caído tiene un tiempo para que lo levanten: 25, 19, 13 y 8 s según las caídas
##     (+10 s en Fácil). Mientras tanto se arrastra despacio.
##   - Un compañero lo levanta manteniendo interactuar 5 s al lado (y no puede atacar).
##   - Si se acaba el tiempo, queda afuera hasta Birig Bamba.
## Jugando solo no hay caída: si caés, se termina (salvo algo que te levante).

const RING_SHADER: Shader = preload("res://assets/shaders/player_ring.gdshader")

var player: PlayerCharacter
var config: ReviveConfig
var downed: bool = false
## Quedó afuera (se le acabó el tiempo).
var out: bool = false
var time_left: float = 0.0
## Progreso del revivir, de 0 a 1.
var progress: float = 0.0
## A quién está levantando este jugador (si está vivo).
var reviving: PlayerCharacter

var _being_revived: bool = false
var _label: Label3D
var _ring: MeshInstance3D
var _ring_material: ShaderMaterial


func setup(owner_player: PlayerCharacter) -> void:
	player = owner_player
	config = Balance.revive
	_build_visuals()


## Lo llama el jugador al caer, si no hay auto-revivir.
func go_down() -> void:
	var falls: int = RunState.get_bonus(player.slot.index, &"falls")
	RunState.add_bonus(player.slot.index, &"falls", 1)
	downed = true
	progress = 0.0
	time_left = config.down_times[mini(falls, config.down_times.size() - 1)] \
			+ Balance.difficulty.revive_bonus[RunState.difficulty]
	_label.visible = true
	_ring.visible = true
	Events.player_downed.emit(player)


## Mientras está caído: corre el tiempo y se arrastra. Devuelve true si sigue caído.
func downed_tick(delta: float) -> void:
	if out:
		player.apply_movement(Vector2.ZERO, delta)
		return
	if not _being_revived:
		time_left -= delta
		progress = maxf(progress - delta / config.revive_hold * config.progress_decay, 0.0)
	_being_revived = false
	var crawl: float = config.crawl_speed / maxf(player.data.move_speed, 0.1)
	player.apply_movement(player.get_move_input(), delta, crawl)
	_update_visuals()
	if time_left <= 0.0:
		_go_out()


## Un compañero lo está levantando este frame.
func add_progress(delta: float) -> void:
	if not downed or out:
		return
	_being_revived = true
	progress += delta / config.revive_hold
	if progress >= 1.0:
		complete_revive()


func complete_revive() -> void:
	if not downed:
		return
	downed = false
	progress = 0.0
	player.health.restore_full()
	player.health.current = player.health.max_health * config.revive_health
	player.health.changed.emit(player.health.current, player.health.max_health)
	player.health.make_invulnerable(config.revive_invulnerability)
	_label.visible = false
	_ring.visible = false
	var tween: Tween = player.create_tween()
	tween.tween_property(player.visual, "rotation:x", 0.0, 0.25)
	Fx.ring_burst(player.get_parent(), player.global_position, 2.0, player.slot.color, 0.4)
	Events.player_revived.emit(player)


func _go_out() -> void:
	out = true
	downed = false
	_label.visible = false
	_ring.visible = false
	var tween: Tween = player.create_tween()
	tween.tween_property(player.visual, "scale", Vector3.ONE * 0.01, 0.6)
	Events.floating_text_requested.emit(player.global_position + Vector3.UP * 2.0,
			"%s quedó afuera hasta Birig Bamba" % player.slot.label, Color(1.0, 0.7, 0.7))
	Events.player_out.emit(player)


## Lo llama el jugador vivo cada frame. Si está manteniendo interactuar al lado de un
## caído, lo levanta y devuelve true (ese frame no puede moverse ni atacar).
func reviver_tick(delta: float) -> bool:
	reviving = null
	if not player.slot.input.is_held(PlayerInput.Action.INTERACT):
		return false
	var target: PlayerCharacter = _downed_ally_nearby()
	if target == null:
		return false
	reviving = target
	target.revive.add_progress(delta)
	var to_target: Vector3 = target.global_position - player.global_position
	to_target.y = 0.0
	if to_target.length_squared() > 0.01:
		player.aim_direction = to_target.normalized()
	return true


func _downed_ally_nearby() -> PlayerCharacter:
	var best: PlayerCharacter = null
	var best_distance: float = config.revive_radius
	for node: Node in player.get_tree().get_nodes_in_group(&"players"):
		var other := node as PlayerCharacter
		if other == null or other == player or other.revive == null:
			continue
		if not other.revive.downed or other.revive.out:
			continue
		var distance: float = Vector2(other.global_position.x - player.global_position.x,
				other.global_position.z - player.global_position.z).length()
		if distance <= best_distance:
			best_distance = distance
			best = other
	return best


func _build_visuals() -> void:
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.fixed_size = true
	_label.pixel_size = 0.0011
	_label.font_size = 40
	_label.outline_size = 12
	_label.outline_modulate = Color(0.05, 0.05, 0.08, 0.9)
	_label.modulate = player.slot.color.lightened(0.3)
	_label.position.y = 1.6
	_label.visible = false
	player.add_child(_label)
	_ring = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * config.revive_radius * 2.0
	_ring.mesh = plane
	_ring.position.y = 0.06
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring_material = ShaderMaterial.new()
	_ring_material.shader = RING_SHADER
	_ring_material.set_shader_parameter("ring_color", Color(player.slot.color, 0.8))
	_ring_material.set_shader_parameter("inner_radius", 0.9)
	_ring_material.set_shader_parameter("fill_alpha", 0.0)
	_ring.material_override = _ring_material
	_ring.visible = false
	player.add_child(_ring)


func _update_visuals() -> void:
	_label.text = "%d" % ceili(maxf(time_left, 0.0))
	if progress > 0.0:
		_label.text = "Levantando... %d%%" % roundi(progress * 100.0)
	# El aro marca hasta dónde llega el que revive; se llena con el progreso.
	_ring_material.set_shader_parameter("fill_alpha", 0.08 + progress * 0.45)
