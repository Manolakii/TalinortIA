class_name MazeEvent
extends Node3D
## Evento "Laberinto de los Gronks" (GDD, ideas de eventos): un laberinto con Gronks dormidos.
## Si hacés ruido cerca (pegar o esquivar) o pasás muy pegado, se despiertan y cargan. El cofre
## está a la salida, al norte. Si llegan sin despertar a ninguno, el evento sale perfecto.

signal resolved(perfect: bool)

const GRONK_SCENE: PackedScene = preload("res://scenes/enemies/gronk.tscn")
const STONE: Material = preload("res://assets/materials/rock_material.tres")

## Zona del laberinto (x de lado a lado de la sala; los jugadores entran por el sur).
const MIN_X := -23.6
const MAX_X := 23.6
const MIN_Z := -10.0
const MAX_Z := 8.0
const COLS := 7
const ROWS := 4
const WALL_HEIGHT := 1.5
const WALL_THICKNESS := 0.7

var _config: StageRoomsConfig
var _gronks: Array[Enemy] = []
var _snore_timers: Dictionary = {}
var _woken: int = 0
var _finished: bool = false
var _noise_positions: Array[Vector3] = []


func setup(config: StageRoomsConfig, template: Node3D, rng: RandomNumberGenerator) -> void:
	_config = config
	# El laberinto reemplaza las rocas y vasijas de la plantilla.
	var holder: Node = template.get_parent()
	for node: Node in holder.find_children("*", "", true, false):
		if node is RockProp or node is Vase or node is CrackedRock:
			node.queue_free()
	var exit_col: int = rng.randi_range(0, COLS - 1)
	_build_maze(rng, COLS / 2, exit_col)
	_place_gronks(rng)
	var chest := Chest.new()
	chest.gold_table = Balance.economy.event_chest_gold
	# Cerca de la salida, sin pisar el lugar de las puertas (x = ±7).
	var chest_x: float = _cell_center(exit_col, 0).x
	if absf(absf(chest_x) - 7.0) < 2.6:
		chest_x = signf(chest_x) * 3.4
	chest.position = Vector3(chest_x, 0, MIN_Z - 1.4)
	add_child(chest)
	chest.opened.connect(_on_chest_opened)
	Events.hit_landed.connect(_on_hit_landed)


func _physics_process(delta: float) -> void:
	if _finished:
		return
	var players: Array[Node] = get_tree().get_nodes_in_group(&"players")
	for gronk: Enemy in _gronks:
		if not is_instance_valid(gronk) or not gronk.asleep:
			continue
		if _noise_near(gronk, players):
			_woken += 1
			gronk.wake_up()
			continue
		_snore_timers[gronk] = _snore_timers.get(gronk, randf_range(0.5, 3.0)) - delta
		if _snore_timers[gronk] <= 0.0:
			_snore_timers[gronk] = randf_range(3.0, 5.0)
			Dialogue.say("gronk_dormido", gronk.global_position + Vector3.UP * 3.0, Color(0.8, 0.85, 1.0))
	_noise_positions.clear()


## ¿Hay ruido cerca de este Gronk? Pasar muy pegado, o pegar / esquivar a unos metros.
func _noise_near(gronk: Enemy, players: Array[Node]) -> bool:
	for node: Node in players:
		var player := node as PlayerCharacter
		if player == null or player.health.is_dead:
			continue
		var distance: float = player.global_position.distance_to(gronk.global_position)
		if distance <= _config.maze_touch_radius:
			return true
		if distance <= _config.maze_noise_radius and (player.is_dodging() or player.is_in_action()):
			return true
	for point: Vector3 in _noise_positions:
		if point.distance_to(gronk.global_position) <= _config.maze_noise_radius:
			return true
	return false


func _on_hit_landed(info: DamageInfo, target: Node3D) -> void:
	if is_instance_valid(target):
		_noise_positions.append(target.global_position)


func _on_chest_opened(_by: PlayerCharacter) -> void:
	if _finished:
		return
	_finished = true
	# Los despiertos se cansan y se van.
	for gronk: Enemy in _gronks:
		if is_instance_valid(gronk) and gronk.is_targetable() and not gronk.asleep:
			gronk.wake_and_flee()
	resolved.emit(_woken == 0)


func woken_count() -> int:
	return _woken


# --- Armado ---

func _place_gronks(rng: RandomNumberGenerator) -> void:
	var cells: Array[Vector2i] = []
	for col: int in COLS:
		for row: int in ROWS:
			if row < ROWS - 1:  # la fila de la entrada queda libre
				cells.append(Vector2i(col, row))
	for i: int in mini(_config.maze_gronks, cells.size()):
		var cell: Vector2i = cells.pop_at(rng.randi_range(0, cells.size() - 1))
		var gronk: Enemy = GRONK_SCENE.instantiate()
		gronk.asleep = true
		gronk.position = _cell_center(cell.x, cell.y)
		var angle: float = rng.randf() * TAU
		gronk.facing = Vector3(cos(angle), 0, sin(angle))
		gronk.gold_chance = 0.0
		gronk.elite_gold = false
		get_parent().add_child(gronk)
		gronk.visual.rotation.z = 0.25  # echado, durmiendo
		_gronks.append(gronk)


## Laberinto "perfecto" por búsqueda en profundidad: siempre hay un solo camino entre dos celdas.
func _build_maze(rng: RandomNumberGenerator, entrance_col: int, exit_col: int) -> void:
	# Paredes: verticales v[col][row] a la derecha de cada celda, horizontales h[col][row] abajo.
	var right_walls: Array = []
	var bottom_walls: Array = []
	for col: int in COLS:
		right_walls.append([])
		bottom_walls.append([])
		for row: int in ROWS:
			right_walls[col].append(true)
			bottom_walls[col].append(true)
	var visited: Dictionary = {}
	var stack: Array[Vector2i] = [Vector2i(entrance_col, ROWS - 1)]
	visited[stack[0]] = true
	while not stack.is_empty():
		var cell: Vector2i = stack.back()
		var options: Array[Vector2i] = []
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = cell + step
			if next.x >= 0 and next.x < COLS and next.y >= 0 and next.y < ROWS and not visited.has(next):
				options.append(next)
		if options.is_empty():
			stack.pop_back()
			continue
		var chosen: Vector2i = options[rng.randi_range(0, options.size() - 1)]
		if chosen.x != cell.x:
			right_walls[mini(chosen.x, cell.x)][cell.y] = false
		else:
			bottom_walls[cell.x][mini(chosen.y, cell.y)] = false
		visited[chosen] = true
		stack.append(chosen)
	var cell_w: float = (MAX_X - MIN_X) / COLS
	var cell_h: float = (MAX_Z - MIN_Z) / ROWS
	# Paredes interiores.
	for col: int in COLS:
		for row: int in ROWS:
			var center: Vector3 = _cell_center(col, row)
			if col < COLS - 1 and right_walls[col][row]:
				_wall(center + Vector3(cell_w * 0.5, 0, 0), Vector3(WALL_THICKNESS, WALL_HEIGHT, cell_h + WALL_THICKNESS))
			if row < ROWS - 1 and bottom_walls[col][row]:
				_wall(center + Vector3(0, 0, cell_h * 0.5), Vector3(cell_w + WALL_THICKNESS, WALL_HEIGHT, WALL_THICKNESS))
	# Bordes norte y sur, con la entrada y la salida abiertas.
	for col: int in COLS:
		var x: float = _cell_center(col, 0).x
		if col != exit_col:
			_wall(Vector3(x, 0, MIN_Z), Vector3(cell_w + WALL_THICKNESS, WALL_HEIGHT, WALL_THICKNESS))
		if col != entrance_col:
			_wall(Vector3(x, 0, MAX_Z), Vector3(cell_w + WALL_THICKNESS, WALL_HEIGHT, WALL_THICKNESS))


func _cell_center(col: int, row: int) -> Vector3:
	var cell_w: float = (MAX_X - MIN_X) / COLS
	var cell_h: float = (MAX_Z - MIN_Z) / ROWS
	return Vector3(MIN_X + cell_w * (col + 0.5), 0, MIN_Z + cell_h * (row + 0.5))


func _wall(center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = center
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y * 0.5
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = STONE
	mesh.mesh = box_mesh
	mesh.position.y = size.y * 0.5
	body.add_child(mesh)
