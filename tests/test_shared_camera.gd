extends GutTest
## Cámara compartida: encuadra al grupo, se aleja como máximo un 12% y frena en el borde.

const DT := 1.0 / 60.0

var _camera: SharedCamera
var _a: Node3D
var _b: Node3D


func before_each() -> void:
	_camera = SharedCamera.new()
	add_child_autofree(_camera)
	_a = Node3D.new()
	_b = Node3D.new()
	add_child_autofree(_a)
	add_child_autofree(_b)


func _set_two(a_pos: Vector3, b_pos: Vector3) -> void:
	_a.global_position = a_pos
	_b.global_position = b_pos
	_camera.set_targets([_a, _b] as Array[Node3D])


func test_looks_north_tilted_55() -> void:
	_camera.set_targets([_a] as Array[Node3D])
	var forward: Vector3 = -_camera.global_transform.basis.z
	assert_almost_eq(rad_to_deg(asin(-forward.y)), 55.0, 0.01, "Inclinada 55° hacia abajo")
	assert_lt(forward.z, 0.0, "Mira al norte (-Z)")
	assert_almost_eq(forward.x, 0.0, 0.0001, "Sin rotación lateral: no es isométrica")


func test_close_group_uses_base_zoom() -> void:
	_set_two(Vector3(-1, 0, 0), Vector3(1, 0, 0))
	assert_almost_eq(_camera.current_zoom(), 1.0, 0.001)


func test_spread_group_zooms_out_but_never_past_max() -> void:
	_set_two(Vector3(-15, 0, 0), Vector3(15, 0, 0))
	assert_gt(_camera.current_zoom(), 1.0)
	assert_lte(_camera.current_zoom(), Balance.camera.max_zoom_out + 0.0001)
	assert_gte(_camera.current_character_px(), 64.0, "Nunca menos de ~64 px")


func test_single_player_is_never_blocked() -> void:
	_camera.set_targets([_a] as Array[Node3D])
	var v := Vector3(6, 0, 0)
	assert_eq(_camera.limit_velocity(_a.global_position, v, DT, _a), v)


func test_cannot_walk_away_past_the_edge() -> void:
	# Se separan en X hasta que el limitador los frena.
	_set_two(Vector3.ZERO, Vector3.ZERO)
	var pos := Vector3.ZERO
	for i: int in 2000:
		var v: Vector3 = _camera.limit_velocity(pos, Vector3(6.6, 0, 0), DT, _a)
		pos += v * DT
		_a.global_position = pos
	assert_lt(pos.x, 40.0, "El borde lo frenó")
	assert_gt(pos.x, 10.0, "Pero lo dejó alejarse bastante")
	# Ya en el borde, volver hacia el grupo siempre se permite.
	var back: Vector3 = _camera.limit_velocity(pos, Vector3(-6.6, 0, 0), DT, _a)
	assert_eq(back, Vector3(-6.6, 0, 0))


func test_slides_along_the_edge() -> void:
	# A se aleja hacia el norte hasta que el borde de arriba lo frena.
	_set_two(Vector3.ZERO, Vector3.ZERO)
	var pos := Vector3.ZERO
	for i: int in 2000:
		pos += _camera.limit_velocity(pos, Vector3(0, 0, -6.6), DT, _a) * DT
		_a.global_position = pos
	# Pegado arriba, camina en diagonal hacia el noreste:
	# no puede salir del cuadro, pero tiene que seguir avanzando hacia el este.
	var start_x: float = pos.x
	for i: int in 60:
		pos += _camera.limit_velocity(pos, Vector3(3.0, 0, -6.6), DT, _a) * DT
		_a.global_position = pos
		assert_true(_camera._allowed(_a, pos), "Nunca queda fuera de cuadro")
	assert_gt(pos.x, start_x + 2.0, "Siguió caminando hacia el este por el borde")
