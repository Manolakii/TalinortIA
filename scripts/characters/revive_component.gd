class_name ReviveComponent
extends Node
## Caer y revivir (GDD, Muerte y revivir):
##   - El caído tiene un tiempo para que lo levanten: 25, 19, 13 y 8 s según las caídas
##     (+10 s en Fácil). Mientras tanto se arrastra despacio.
##   - Un compañero lo levanta manteniendo interactuar 5 s al lado (no puede atacar y no lo
##     empujan). Si lo interrumpen un instante, el progreso espera antes de bajar.
##   - Si se acaba el tiempo, queda afuera hasta Birig Bamba.
## Jugando solo no hay caída: si caés, se termina (salvo algo que te levante).
## Sobre el caído se ve un círculo con su cara que se llena mientras lo levantan.

const BADGE_SHADER: Shader = preload("res://assets/shaders/revive_badge.gdshader")
const BADGE_SIZE := 1.6

var player: PlayerCharacter
var config: ReviveConfig
var downed: bool = false
## Quedó afuera (se le acabó el tiempo).
var out: bool = false
var time_left: float = 0.0
var max_time: float = 1.0
## Progreso del revivir, de 0 a 1.
var progress: float = 0.0
## A quién está levantando este jugador (si está vivo).
var reviving: PlayerCharacter

var _since_revived: float = 99.0
var _badge: Node3D
var _badge_material: ShaderMaterial
var _initials: Label3D
var _countdown: Label3D


func setup(owner_player: PlayerCharacter) -> void:
	player = owner_player
	config = Balance.revive
	_build_badge()


## Lo llama el jugador al caer, si no hay auto-revivir.
func go_down() -> void:
	var falls: int = RunState.get_bonus(player.slot.index, &"falls")
	RunState.add_bonus(player.slot.index, &"falls", 1)
	downed = true
	progress = 0.0
	time_left = config.down_times[mini(falls, config.down_times.size() - 1)] \
			+ Balance.difficulty.revive_bonus[RunState.difficulty]
	max_time = time_left
	_badge.visible = true
	Events.player_downed.emit(player)


## Mientras está caído: corre el tiempo (salvo que lo estén levantando) y se arrastra.
func downed_tick(delta: float) -> void:
	if out:
		player.apply_movement(Vector2.ZERO, delta)
		return
	_since_revived += delta
	if _since_revived > config.progress_grace:
		time_left -= delta
		progress = maxf(progress - delta / config.revive_hold * config.progress_decay, 0.0)
	var crawl: float = config.crawl_speed / maxf(player.data.move_speed, 0.1)
	player.apply_movement(player.get_move_input(), delta, crawl)
	_update_badge()
	if time_left <= 0.0:
		_go_out()


## Un compañero lo está levantando este frame.
func add_progress(delta: float) -> void:
	if not downed or out:
		return
	_since_revived = 0.0
	progress += delta / config.revive_hold
	_update_badge()
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
	_badge.visible = false
	var tween: Tween = player.create_tween()
	tween.tween_property(player.visual, "rotation:x", 0.0, 0.25)
	Fx.ring_burst(player.get_parent(), player.global_position, 2.0, player.slot.color, 0.4)
	Events.player_revived.emit(player)


func _go_out() -> void:
	out = true
	downed = false
	_badge.visible = false
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
	target.add_revive_progress(delta)
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
		if other == null or other == player or not other.is_downed():
			continue
		var distance: float = Vector2(other.global_position.x - player.global_position.x,
				other.global_position.z - player.global_position.z).length()
		if distance <= best_distance:
			best_distance = distance
			best = other
	return best


# --- Círculo con la cara ---

func _build_badge() -> void:
	_badge = Node3D.new()
	_badge.name = "ReviveBadge"
	_badge.top_level = true
	_badge.visible = false
	player.add_child(_badge)
	var disc := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * BADGE_SIZE
	disc.mesh = quad
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_badge_material = ShaderMaterial.new()
	_badge_material.shader = BADGE_SHADER
	_badge_material.set_shader_parameter("player_color", player.slot.color)
	_badge_material.render_priority = 6
	disc.material_override = _badge_material
	_badge.add_child(disc)
	_initials = _make_label(player.data.initials if player.data.initials != "" \
			else player.data.display_name.left(1), 44, Color.WHITE)
	_initials.position.z = 0.02
	_badge.add_child(_initials)
	_countdown = _make_label("", 30, Color(1.0, 0.8, 0.8))
	_countdown.position.y = -BADGE_SIZE * 0.68
	_badge.add_child(_countdown)


func _make_label(text: String, font_size: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.no_depth_test = true
	label.font_size = font_size
	label.pixel_size = 0.012
	label.outline_size = 10
	label.outline_modulate = Color(0.05, 0.05, 0.08, 0.9)
	label.modulate = color
	label.render_priority = 7
	label.outline_render_priority = 6
	return label


func _update_badge() -> void:
	if not _badge.visible:
		return
	_badge.global_position = player.global_position + Vector3.UP * 2.3
	var camera: Camera3D = player.get_viewport().get_camera_3d()
	if camera != null:
		_badge.global_basis = camera.global_basis
	_badge_material.set_shader_parameter("progress", progress)
	_badge_material.set_shader_parameter("time_left", clampf(time_left / maxf(max_time, 0.01), 0.0, 1.0))
	_countdown.text = "%d" % ceili(maxf(time_left, 0.0))
