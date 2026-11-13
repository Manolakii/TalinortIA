class_name EscortEvent
extends Node3D
## Evento "Escoltá la carreta" (idea del grupo): una carreta con Talinorteanos cruza la sala de
## sur a norte, despacio, mientras llegan enemigos sin parar. Solo avanza si alguien la empuja
## (un jugador cerca). Si llega: cofre de evento y evento perfecto. Si la rompen: hay que
## terminar de pelear y no hay premio del evento.

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


func setup(config: StageRoomsConfig, template: Node3D, rng: RandomNumberGenerator) -> void:
	_config = config
	_rng = rng
	var from := Vector3(0, 0, 9.0)
	var to := Vector3(0, 0, -11.0)
	_clear_path(template, from, to)
	cart = EscortCart.new()
	add_child(cart)
	cart.setup(from + Vector3(0, 0, -2.5), to, config.cart_health, config.cart_speed)
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
		if get_tree().get_nodes_in_group(&"enemies").is_empty():
			_finished = true
			resolved.emit(false)
		return
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


func _on_destroyed() -> void:
	_spawning = false
	_broken = true


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
