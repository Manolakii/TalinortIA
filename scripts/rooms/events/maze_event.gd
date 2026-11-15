class_name MazeEvent
extends Node3D
## Evento "Laberinto de los Gronks" (GDD, ideas de eventos): un laberinto con Gronks dormidos.
## Si hacés ruido cerca (pegar o esquivar) o pasás muy pegado, se despiertan y cargan. El cofre
## está a la salida, al norte. Si se despiertan más de `maze_max_woken`, se comen el cofre y se
## pierde el evento (pedido del grupo: hay que ganarlo).

signal resolved(won: bool)

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
## Para ubicar a los Gronks dejando siempre un paso (pedido del grupo: a veces no se podía pasar
## al lado de un Gronk sin despertarlo y no había otro camino).
const GRONK_RADIUS := 1.0
const PLAYER_RADIUS := 0.45
## Distancia extra al radio de "pasar pegado", para que se pueda pasar sin rozarlo de casualidad.
const PASS_MARGIN := 0.35
const GRID_STEP := 0.25

var _config: StageRoomsConfig
var _gronks: Array[Enemy] = []
var _snore_timers: Dictionary = {}
var _woken: int = 0
var _finished: bool = false
var _noise_positions: Array[Vector3] = []
var _chest: Chest
var _passages: Array = []
## Celdas del camino de la entrada a la salida (las trampas y Gronks van sobre todo ahí).
var _path: Array[Vector2i] = []
var _right_walls: Array = []
var _bottom_walls: Array = []
var _label: Label
var _entrance_col: int = 0
var _exit_col: int = 0
## Celda y lugar (respecto del centro de la celda) de cada Gronk.
var gronk_spots: Array[Dictionary] = []


func setup(config: StageRoomsConfig, template: Node3D, rng: RandomNumberGenerator) -> void:
	_config = config
	# El laberinto reemplaza las rocas y vasijas de la plantilla.
	var holder: Node = template.get_parent()
	for node: Node in holder.find_children("*", "", true, false):
		if node is RockProp or node is Vase or node is CrackedRock:
			node.queue_free()
	var exit_col: int = rng.randi_range(0, COLS - 1)
	_entrance_col = COLS / 2
	_exit_col = exit_col
	_build_maze(rng, COLS / 2, exit_col)
	_place_gronks(rng)
	_place_traps(rng)
	var chest := Chest.new()
	chest.gold_table = Balance.economy.event_chest_gold
	# Cerca de la salida, sin pisar el lugar de las puertas (x = ±7).
	var chest_x: float = _cell_center(exit_col, 0).x
	if absf(absf(chest_x) - 7.0) < 2.6:
		chest_x = signf(chest_x) * 3.4
	chest.position = Vector3(chest_x, 0, MIN_Z - 1.4)
	add_child(chest)
	chest.opened.connect(_on_chest_opened)
	_chest = chest
	Events.hit_landed.connect(_on_hit_landed)
	var layer := CanvasLayer.new()
	layer.layer = 31
	add_child(layer)
	_label = Label.new()
	_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.offset_top = 92.0
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 34)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 10)
	layer.add_child(_label)
	_update_label()


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
			_update_label()
			if _woken > _config.maze_max_woken:
				_lose()
				return
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
	_send_gronks_away()
	_label.text = "¡Llegaron al cofre!"
	resolved.emit(true)


## Se despertaron demasiados: se comen el cofre y se pierde el evento.
func _lose() -> void:
	_finished = true
	if is_instance_valid(_chest):
		Events.floating_text_requested.emit(_chest.global_position + Vector3.UP * 2.0,
				"¡Los Gronks se comieron el cofre!", Color(1.0, 0.6, 0.4))
		_chest.queue_free()
	_label.text = "Se despertaron demasiados Gronks: perdieron el evento"
	var tween: Tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_callback(func() -> void:
		_send_gronks_away()
		resolved.emit(false))


## Los despiertos se cansan y se van.
func _send_gronks_away() -> void:
	for gronk: Enemy in _gronks:
		if is_instance_valid(gronk) and gronk.is_targetable() and not gronk.asleep:
			gronk.wake_and_flee()


func _update_label() -> void:
	_label.text = "Gronks despiertos: %d de %d permitidos" % [_woken, _config.maze_max_woken]


func woken_count() -> int:
	return _woken


# --- Armado ---

## Guillotinas en pasillos y pinchos en celdas (pedido del grupo: era muy fácil).
func _place_traps(rng: RandomNumberGenerator) -> void:
	# Pedido del grupo (a veces el camino quedaba libre): la mayoría de las guillotinas van en
	# pasillos del camino a la salida, así no se pueden esquivar del todo.
	var on_path: Array = _passages.filter(func(p: Array) -> bool: return _path.has(p[3]) and _path.has(p[4]))
	var others: Array = _passages.filter(func(p: Array) -> bool: return not on_path.has(p))
	var wanted_on_path: int = ceili(_config.maze_guillotines * 0.65)
	var chosen: Array = []
	while chosen.size() < wanted_on_path and not on_path.is_empty():
		chosen.append(on_path.pop_at(rng.randi_range(0, on_path.size() - 1)))
	others.append_array(on_path)
	while chosen.size() < _config.maze_guillotines and not others.is_empty():
		chosen.append(others.pop_at(rng.randi_range(0, others.size() - 1)))
	for passage: Array in chosen:
		var trap := MazeTrap.new()
		trap.position = passage[0]
		add_child(trap)
		trap.setup(MazeTrap.Kind.GUILLOTINE, passage[1], passage[2], _config.maze_trap_damage, rng.randf())
	var cells: Array[Vector2i] = _ordered_cells(rng, ceili(_config.maze_spikes * 0.5))
	for i: int in mini(_config.maze_spikes, cells.size()):
		var cell: Vector2i = cells[i]
		var trap := MazeTrap.new()
		trap.position = _cell_center(cell.x, cell.y) + Vector3(rng.randf_range(-1.2, 1.2), 0, 0)
		add_child(trap)
		trap.setup(MazeTrap.Kind.SPIKES, Vector3.BACK, 2.6, _config.maze_trap_damage * 0.8, rng.randf())

func _place_gronks(rng: RandomNumberGenerator) -> void:
	var cells: Array[Vector2i] = _ordered_cells(rng, 3)
	for cell: Vector2i in cells:
		if _gronks.size() >= _config.maze_gronks:
			break
		# Solo donde quede un paso libre entre todas las entradas de la celda.
		var spots: Array[Vector3] = passable_spots(cell)
		if spots.is_empty():
			continue
		var offset: Vector3 = spots[rng.randi_range(0, spots.size() - 1)]
		gronk_spots.append({"cell": cell, "offset": offset})
		var gronk: Enemy = GRONK_SCENE.instantiate()
		gronk.asleep = true
		gronk.position = _cell_center(cell.x, cell.y) + offset
		var angle: float = rng.randf() * TAU
		gronk.facing = Vector3(cos(angle), 0, sin(angle))
		gronk.gold_chance = 0.0
		gronk.elite_gold = false
		get_parent().add_child(gronk)
		gronk.visual.rotation.z = 0.25  # echado, durmiendo
		_gronks.append(gronk)


## Lugares de la celda (respecto de su centro) donde un Gronk dormido deja pasar.
func passable_spots(cell: Vector2i) -> Array[Vector3]:
	var half_w: float = (MAX_X - MIN_X) / COLS * 0.5 - WALL_THICKNESS * 0.5 - GRONK_RADIUS
	var half_h: float = (MAX_Z - MIN_Z) / ROWS * 0.5 - WALL_THICKNESS * 0.5 - GRONK_RADIUS
	var result: Array[Vector3] = []
	var x: float = -half_w
	while x <= half_w + 0.001:
		var z: float = -half_h
		while z <= half_h + 0.001:
			if is_passable(cell, Vector3(x, 0, z)):
				result.append(Vector3(x, 0, z))
			z += 0.3
		x += 0.5
	return result


## ¿Con un Gronk en `offset`, se puede ir de cualquier entrada de la celda a cualquier otra sin
## pasar a menos de `maze_touch_radius` (+ margen)? Recorre una grilla de la celda.
func is_passable(cell: Vector2i, offset: Vector3) -> bool:
	var openings: Array[StringName] = _openings(cell)
	if openings.size() <= 1:
		return true
	var half_w: float = (MAX_X - MIN_X) / COLS * 0.5 - WALL_THICKNESS * 0.5 - PLAYER_RADIUS
	var half_h: float = (MAX_Z - MIN_Z) / ROWS * 0.5 - WALL_THICKNESS * 0.5 - PLAYER_RADIUS
	var nx: int = int(half_w * 2.0 / GRID_STEP) + 1
	var nz: int = int(half_h * 2.0 / GRID_STEP) + 1
	var safe: float = _config.maze_touch_radius + PASS_MARGIN
	var free: Dictionary = {}
	for i: int in nx:
		for j: int in nz:
			var p := Vector3(-half_w + i * GRID_STEP, 0, -half_h + j * GRID_STEP)
			if p.distance_to(offset) > safe:
				free[Vector2i(i, j)] = true
	# Desde un punto libre del borde de la primera entrada, ¿se llega al borde de todas las otras?
	var start: Variant = null
	for key: Vector2i in free:
		if _on_side(key, openings[0], nx, nz):
			start = key
			break
	if start == null:
		return false
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var here: Vector2i = queue.pop_back()
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = here + step
			if free.has(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	for side: StringName in openings:
		var reached: bool = false
		for key: Vector2i in seen:
			if _on_side(key, side, nx, nz):
				reached = true
				break
		if not reached:
			return false
	return true


func _on_side(key: Vector2i, side: StringName, nx: int, nz: int) -> bool:
	match side:
		&"west":
			return key.x == 0
		&"east":
			return key.x == nx - 1
		&"north":
			return key.y == 0
		_:
			return key.y == nz - 1


## Lados abiertos de la celda (pasillos, más la entrada y la salida del laberinto).
func _openings(cell: Vector2i) -> Array[StringName]:
	var result: Array[StringName] = []
	if cell.x > 0 and not _right_walls[cell.x - 1][cell.y]:
		result.append(&"west")
	if cell.x < COLS - 1 and not _right_walls[cell.x][cell.y]:
		result.append(&"east")
	if (cell.y > 0 and not _bottom_walls[cell.x][cell.y - 1]) or (cell.y == 0 and cell.x == _exit_col):
		result.append(&"north")
	if (cell.y < ROWS - 1 and not _bottom_walls[cell.x][cell.y]) 			or (cell.y == ROWS - 1 and cell.x == _entrance_col):
		result.append(&"south")
	return result


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
	_right_walls = right_walls
	_bottom_walls = bottom_walls
	_path = _solve(Vector2i(entrance_col, ROWS - 1), Vector2i(exit_col, 0))
	var cell_w: float = (MAX_X - MIN_X) / COLS
	var cell_h: float = (MAX_Z - MIN_Z) / ROWS
	# Pasillos abiertos (para las guillotinas): centro, dirección de la cuchilla y largo.
	for col: int in COLS:
		for row: int in ROWS:
			var here: Vector3 = _cell_center(col, row)
			if col < COLS - 1 and not right_walls[col][row]:
				_passages.append([here + Vector3(cell_w * 0.5, 0, 0), Vector3.BACK, cell_h - WALL_THICKNESS,
						Vector2i(col, row), Vector2i(col + 1, row)])
			if row < ROWS - 1 and not bottom_walls[col][row]:
				_passages.append([here + Vector3(0, 0, cell_h * 0.5), Vector3.RIGHT, cell_w - WALL_THICKNESS,
						Vector2i(col, row), Vector2i(col, row + 1)])
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


## Celdas (sin la fila de la entrada) en orden: primero `on_path` al azar del camino a la
## salida, después el resto al azar.
func _ordered_cells(rng: RandomNumberGenerator, on_path: int) -> Array[Vector2i]:
	var path_cells: Array[Vector2i] = []
	var other_cells: Array[Vector2i] = []
	for col: int in COLS:
		for row: int in ROWS - 1:
			var cell := Vector2i(col, row)
			if _path.has(cell):
				path_cells.append(cell)
			else:
				other_cells.append(cell)
	var result: Array[Vector2i] = []
	while result.size() < on_path and not path_cells.is_empty():
		result.append(path_cells.pop_at(rng.randi_range(0, path_cells.size() - 1)))
	other_cells.append_array(path_cells)
	while not other_cells.is_empty():
		result.append(other_cells.pop_at(rng.randi_range(0, other_cells.size() - 1)))
	return result


## Camino de la entrada a la salida (búsqueda a lo ancho por los pasillos abiertos).
func _solve(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var came_from: Dictionary = {from: from}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if cell == to:
			break
		for next: Vector2i in _neighbors(cell):
			if not came_from.has(next):
				came_from[next] = cell
				queue.append(next)
	var path: Array[Vector2i] = []
	var step: Vector2i = to
	while came_from.has(step) and step != from:
		path.push_front(step)
		step = came_from[step]
	path.push_front(from)
	return path


func _neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if cell.x < COLS - 1 and not _right_walls[cell.x][cell.y]:
		result.append(cell + Vector2i(1, 0))
	if cell.x > 0 and not _right_walls[cell.x - 1][cell.y]:
		result.append(cell + Vector2i(-1, 0))
	if cell.y < ROWS - 1 and not _bottom_walls[cell.x][cell.y]:
		result.append(cell + Vector2i(0, 1))
	if cell.y > 0 and not _bottom_walls[cell.x][cell.y - 1]:
		result.append(cell + Vector2i(0, -1))
	return result


func path_cells() -> Array[Vector2i]:
	return _path
