class_name SharedCamera
extends Camera3D
## Cámara compartida (GDD, Presentación > Cámara, decidido):
## frontal 3/4 mirando al norte, inclinada ~55°, FOV ~32. Encuadra al grupo,
## se aleja como máximo un 12% y el borde del cuadro frena a los jugadores.
##
## Para frenar, cada jugador le pregunta a limit_velocity() antes de moverse: se proyecta
## la posición nueva a una cámara virtual al máximo alejamiento y, si alguien quedaría
## afuera de los márgenes, se lo deja deslizar por el borde o se lo frena.

## Paso con el que se busca el alejamiento mínimo que encuadra a todos.
const ZOOM_SEARCH_STEP := 0.005

var targets: Array[Node3D] = []

var _config: CameraConfig
var _pitch: float = 0.0
var _focus: Vector3 = Vector3.ZERO
var _zoom: float = 1.0
## Sacudida acumulada (0 a 1). Se ve como trauma²: los golpes chicos casi no mueven.
var _trauma: float = 0.0
var _shake_time: float = 0.0
var _shake_noise := FastNoiseLite.new()


func _ready() -> void:
	_shake_noise.frequency = 2.5
	Events.camera_shake_requested.connect(add_trauma)
	_config = Balance.camera
	fov = _config.fov_degrees
	_pitch = deg_to_rad(_config.pitch_degrees)
	near = 1.0
	far = 200.0
	# La cámara se mueve en _process usando las posiciones interpoladas de los jugadores.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	make_current()
	global_transform = _transform_for(_focus, _zoom)


func set_targets(new_targets: Array[Node3D]) -> void:
	targets = new_targets
	snap_to_targets()


## Salta directo al encuadre ideal, sin suavizado (al entrar a una sala).
func snap_to_targets() -> void:
	if targets.is_empty():
		return
	var points: PackedVector3Array = _frame_points(_interpolated_positions())
	_focus = _group_center(points)
	_zoom = _required_zoom(points, _focus)
	global_transform = _transform_for(_focus, _zoom)


func _process(delta: float) -> void:
	if targets.is_empty():
		return
	var points: PackedVector3Array = _frame_points(_interpolated_positions())
	var center: Vector3 = _group_center(points)
	var wanted_zoom: float = _required_zoom(points, center)
	_focus = _focus.lerp(center, 1.0 - exp(-_config.follow_speed * delta))
	_zoom = lerpf(_zoom, wanted_zoom, 1.0 - exp(-_config.zoom_speed * delta))
	global_transform = _transform_for(_focus, _zoom)
	_apply_shake(delta)


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _apply_shake(delta: float) -> void:
	if _trauma <= 0.0:
		return
	var combat: CombatConfig = Balance.combat
	_shake_time += delta * 60.0
	var strength: float = _trauma * _trauma * combat.shake_max_offset
	var offset := Vector3(
			_shake_noise.get_noise_2d(_shake_time, 0.0),
			_shake_noise.get_noise_2d(0.0, _shake_time), 0.0) * strength
	global_transform.origin += global_transform.basis * offset
	_trauma = maxf(_trauma - combat.shake_decay * delta, 0.0)


## Devuelve la velocidad que se le permite a `body` para no salirse del cuadro.
## Pensado para usarse como PlayerCharacter.velocity_limiter con bind(body).
func limit_velocity(position: Vector3, velocity: Vector3, delta: float, body: Node3D) -> Vector3:
	if targets.size() <= 1 or velocity == Vector3.ZERO:
		return velocity
	if _allowed(body, position + velocity * delta):
		return velocity
	# Deslizar por el borde: probar cada eje por separado.
	var only_x := Vector3(velocity.x, 0.0, 0.0)
	var only_z := Vector3(0.0, 0.0, velocity.z)
	var x_ok: bool = only_x != Vector3.ZERO and _allowed(body, position + only_x * delta)
	var z_ok: bool = only_z != Vector3.ZERO and _allowed(body, position + only_z * delta)
	if x_ok and not z_ok:
		return only_x
	if z_ok and not x_ok:
		return only_z
	if x_ok and z_ok:
		return only_x if absf(velocity.x) >= absf(velocity.z) else only_z
	# Si ya estaba afuera (por ejemplo, al aparecer), lo dejamos volver hacia el grupo.
	if not _allowed(body, position):
		var center: Vector3 = _group_center(_frame_points(_positions_with(body, position)))
		var closer: bool = (position + velocity * delta).distance_squared_to(center) \
				< position.distance_squared_to(center)
		return velocity if closer else Vector3.ZERO
	return Vector3.ZERO


## Cuántos píxeles mide en pantalla la silueta de referencia con el alejamiento actual.
func current_character_px() -> float:
	var visible_h: float = 2.0 * _config.get_base_distance() * _zoom * tan(deg_to_rad(fov) * 0.5)
	return _config.silhouette_height_m() / visible_h * _config.reference_viewport_height


func current_zoom() -> float:
	return _zoom


# --- Cálculos ---

func _allowed(body: Node3D, new_position: Vector3) -> bool:
	var points: PackedVector3Array = _frame_points(_positions_with(body, new_position))
	return _fits(points, _group_center(points), _config.max_zoom_out)


func _positions_with(body: Node3D, new_position: Vector3) -> PackedVector3Array:
	var result := PackedVector3Array()
	for target: Node3D in targets:
		if not is_instance_valid(target):
			continue
		result.append(new_position if target == body else target.global_position)
	return result


func _interpolated_positions() -> PackedVector3Array:
	var result := PackedVector3Array()
	for target: Node3D in targets:
		if is_instance_valid(target):
			result.append(target.get_global_transform_interpolated().origin)
	return result


## Por cada jugador, los pies y la cabeza: así tampoco se corta la cabeza arriba.
func _frame_points(feet: PackedVector3Array) -> PackedVector3Array:
	var result := PackedVector3Array()
	var head := Vector3(0.0, _config.character_height_m, 0.0)
	for foot: Vector3 in feet:
		var ground := Vector3(foot.x, 0.0, foot.z)
		result.append(ground)
		result.append(ground + head)
	return result


## Centro de la caja que contiene a todos, sobre el piso.
func _group_center(points: PackedVector3Array) -> Vector3:
	if points.is_empty():
		return _focus
	var min_v := Vector2(INF, INF)
	var max_v := Vector2(-INF, -INF)
	for p: Vector3 in points:
		min_v = min_v.min(Vector2(p.x, p.z))
		max_v = max_v.max(Vector2(p.x, p.z))
	var mid: Vector2 = (min_v + max_v) * 0.5
	return Vector3(mid.x, 0.0, mid.y)


func _required_zoom(points: PackedVector3Array, focus: Vector3) -> float:
	var zoom: float = 1.0
	while zoom < _config.max_zoom_out:
		if _fits(points, focus, zoom):
			return zoom
		zoom += ZOOM_SEARCH_STEP
	return _config.max_zoom_out


func _transform_for(focus: Vector3, zoom: float) -> Transform3D:
	var basis := Basis.from_euler(Vector3(-_pitch, 0.0, 0.0))
	# La cámara mira hacia -Z de su base; basis.z apunta hacia atrás (arriba y al sur).
	return Transform3D(basis, focus + basis.z * _config.get_base_distance() * zoom)


## ¿Todos los puntos entran en pantalla, respetando los márgenes, con esta cámara?
func _fits(points: PackedVector3Array, focus: Vector3, zoom: float) -> bool:
	var to_camera: Transform3D = _transform_for(focus, zoom).affine_inverse()
	var tan_half: float = tan(deg_to_rad(fov) * 0.5)
	var aspect: float = _aspect()
	var ref_h: float = _config.reference_viewport_height
	var ref_w: float = ref_h * aspect
	var top: float = 1.0 - 2.0 * _config.margin_px_top / ref_h
	var bottom: float = -1.0 + 2.0 * _config.margin_px_bottom / ref_h
	var side: float = 1.0 - 2.0 * _config.margin_px_sides / ref_w
	for p: Vector3 in points:
		var c: Vector3 = to_camera * p
		if c.z > -0.01:
			return false
		var ndc_x: float = (c.x / -c.z) / (tan_half * aspect)
		var ndc_y: float = (c.y / -c.z) / tan_half
		if absf(ndc_x) > side or ndc_y > top or ndc_y < bottom:
			return false
	return true


func _aspect() -> float:
	var size: Vector2 = get_viewport().get_visible_rect().size
	return size.x / size.y if size.y > 0.0 else 16.0 / 9.0
