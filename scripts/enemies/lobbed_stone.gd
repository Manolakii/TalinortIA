class_name LobbedStone
extends Node3D
## Piedra del Hondero: vuela en parábola y marca con un círculo naranja dónde va a caer.

var _from: Vector3
var _to: Vector3
var _flight: float = 1.0
var _time: float = 0.0
var _radius: float = 1.3
var _info: DamageInfo
var _stone: MeshInstance3D
var _telegraph: Telegraph
var _landed: bool = false


func launch(from: Vector3, to: Vector3, flight_time: float, radius: float, info: DamageInfo) -> void:
	_from = from
	_to = Vector3(to.x, 0.0, to.z)
	_flight = maxf(flight_time, 0.1)
	_radius = radius
	_info = info
	_stone = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.3
	_stone.mesh = mesh
	_stone.material_override = Fx.flat_material(Color(0.5, 0.47, 0.42))
	add_child(_stone)
	_stone.global_position = from
	_telegraph = Telegraph.new()
	add_child(_telegraph)
	_telegraph.global_position = _to
	_telegraph.position.y = Telegraph.HEIGHT
	_telegraph.show_circle(radius, _flight)


func _physics_process(delta: float) -> void:
	if _landed:
		return
	_time += delta
	var t: float = clampf(_time / _flight, 0.0, 1.0)
	var flat: Vector3 = _from.lerp(_to, t)
	flat.y = lerpf(_from.y, 0.0, t) + sin(t * PI) * 3.5
	_stone.global_position = flat
	if t >= 1.0:
		_land()


func _land() -> void:
	_landed = true
	set_physics_process(false)
	if not is_instance_valid(_info.attacker):
		_info.attacker = null
	_info.origin = _to
	Combat.deliver(_info, CombatQuery.in_circle(get_tree(), DamageInfo.Team.PLAYERS, _to, _radius))
	Fx.ring_burst(get_parent(), _to, _radius, Color(0.6, 0.55, 0.5), 0.25)
	queue_free()
