class_name EscortEvent
extends Node3D
## Evento "Escoltá la carreta" (idea del grupo): una carreta con Talinorteanos cruza la sala de
## sur a norte, despacio, mientras llegan enemigos sin parar. Solo avanza si alguien la empuja
## (un jugador cerca). Si llega: cofre de evento y se gana. Si la rompen: se pierde y los
## enemigos se van (no tiene sentido seguir peleando).

signal resolved(perfect: bool)

const ENEMY_POOL: Array[StringName] = [&"talinorteano_cegado", &"talinorteano_cegado",
		&"soldado_agucci", &"hondero_cegado", &"tirador_agucci"]

var cart: EscortCart
var _config: StageRoomsConfig
var _spawn_timer: float = 1.0
var _spawning: bool = true
var _broken: bool = false
var _finished: bool = false
var _rng: RandomNumberGenerator
## Cada cuánto cada enemigo vuelve a decidir si va por la carreta o por los jugadores.
var _focus_timers: Dictionary = {}


func setup(config: StageRoomsConfig, template: Node3D, rng: RandomNumberGenerator) -> void:
	_config = config
	_rng = rng
	# Camino en zigzag (pedido del grupo: el recto era corto). A veces espejado.
	var flip: float = -1.0 if rng.randf() < 0.5 else 1.0
	var waypoints := PackedVector3Array()
	for point: Vector3 in config.cart_path:
		waypoints.append(Vector3(point.x * flip, 0.0, point.z))
	var to: Vector3 = waypoints[waypoints.size() - 1]
	for i: int in waypoints.size() - 1:
		_clear_path(template, waypoints[i], waypoints[i + 1])
	_draw_path(waypoints)
	cart = EscortCart.new()
	add_child(cart)
	cart.setup(waypoints[0], to, config.cart_health, config.cart_speed, waypoints)
	cart.arrived.connect(_on_arrived)
	cart.destroyed.connect(_on_destroyed)
	var exit_mark := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 2.0
	disc.bottom_radius = 2.0
	disc.height = 0.04
	exit_mark.mesh = disc
	exit_mark.position = to + Vector3.UP * 0.03
	exit_mark.material_override = Fx.flat_material(Color(1.0, 0.82, 0.3, 0.8), 1.0)
	add_child(exit_mark)


func _physics_process(delta: float) -> void:
	if _finished:
		return
	if _broken:
		return
	_update_focus(delta)
	if not _spawning:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = _config.cart_spawn_interval
		_spawn_group()


func _spawn_group() -> void:
	var alive: int = get_tree().get_nodes_in_group(&"enemies").size()
	var count: int = Scaling.enemy_count(Balance.difficulty, RunState.difficulty,
			Scaling.players_for_scaling(), _config.cart_spawn_group)
	for i: int in mini(count, _config.cart_max_enemies - alive):
		var id: StringName = ENEMY_POOL[_rng.randi_range(0, ENEMY_POOL.size() - 1)]
		var enemy: Enemy = load("res://scenes/enemies/%s.tscn" % id).instantiate()
		var side: float = -1.0 if _rng.randf() < 0.5 else 1.0
		var z: float = clampf(cart.global_position.z + _rng.randf_range(-6.0, 6.0), -13.0, 12.0)
		enemy.position = Vector3(side * _rng.randf_range(17.0, 21.0), 0, z)
		enemy.gold_chance = Balance.economy.common_drop_chance * 0.5 \
				/ maxf(Scaling.current_count_multiplier(), 1.0)
		get_parent().add_child(enemy)
		Fx.ring_burst(get_parent(), enemy.position, 1.2, Color(0.6, 0.55, 0.65), 0.3)


func _on_arrived() -> void:
	_spawning = false
	# Los que quedan se van corriendo: llegó la carreta y se terminó la joda.
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy != null and enemy.is_targetable():
			enemy.wake_and_flee()
	var chest := Chest.new()
	chest.gold_table = Balance.economy.event_chest_gold
	chest.position = cart.path_to + Vector3(3.0, 0, 1.0)
	add_child(chest)
	chest.opened.connect(func(_by: PlayerCharacter) -> void:
		if not _finished:
			_finished = true
			resolved.emit(true))


## La rompieron: el evento terminó (se pierde) y los enemigos se van con el botín.
func _on_destroyed() -> void:
	_spawning = false
	_broken = true
	var tween: Tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_callback(func() -> void:
		for node: Node in get_tree().get_nodes_in_group(&"enemies"):
			var enemy := node as Enemy
			if enemy != null and enemy.is_targetable():
				enemy.wake_and_flee()
		_finished = true
		resolved.emit(false))


## Huellas de ruedas en el piso para que se vea por dónde va a ir.
func _draw_path(waypoints: PackedVector3Array) -> void:
	var material := Fx.flat_material(Color(0.85, 0.8, 0.7, 0.45))
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i: int in waypoints.size() - 1:
		var a: Vector3 = waypoints[i]
		var b: Vector3 = waypoints[i + 1]
		var steps: int = maxi(int(a.distance_to(b) / 1.6), 1)
		for s: int in steps:
			var dot := MeshInstance3D.new()
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.35, 0.02, 0.7)
			dot.mesh = mesh
			dot.material_override = material
			dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(dot)
			var direction: Vector3 = (b - a).normalized()
			dot.position = a.lerp(b, (s + 0.5) / steps) + Vector3.UP * 0.03
			dot.rotation.y = atan2(-direction.x, -direction.z)


## Saca rocas, vasijas y rocas agrietadas del camino de la carreta.
func _clear_path(root: Node3D, from: Vector3, to: Vector3) -> void:
	var holder: Node = root.get_parent() if root.get_parent() != null else root
	for node: Node in holder.find_children("*", "", true, false):
		if not (node is RockProp or node is Vase or node is CrackedRock):
			continue
		var p: Vector3 = (node as Node3D).global_position
		var closest: Vector3 = Geometry3D.get_closest_point_to_segment(Vector3(p.x, 0, p.z), from, to)
		if closest.distance_to(Vector3(p.x, 0, p.z)) < 3.2:
			node.queue_free()


## Pedido del grupo: que no le peguen todos a la carreta. Cada enemigo va cambiando: a veces
## va por la carreta y a veces por los jugadores (y ahí ignora la carreta).
func _update_focus(delta: float) -> void:
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy == null:
			continue
		var left: float = _focus_timers.get(enemy, 0.0) - delta
		if left <= 0.0:
			left = _rng.randf_range(4.0, 8.0)
			var go_for_cart: bool = _rng.randf() < _config.cart_focus_chance and not _broken
			enemy.focus_target = cart if go_for_cart else null
			enemy.ignored_targets.clear()
			if not go_for_cart:
				enemy.ignored_targets.append(cart)
		_focus_timers[enemy] = left
