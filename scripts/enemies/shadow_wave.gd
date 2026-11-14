class_name ShadowWave
extends Node3D
## Onda de sombra del Gronk Gigante (fase 3): un anillo violeta que crece desde el boss, con un
## hueco para pasar. Pega una vez a cada jugador que lo toca; la esquiva lo atraviesa (es
## invulnerable al empezar). Violeta = sombra.

const COLOR := Color(0.55, 0.25, 0.9)
const SEGMENTS := 48
const MAX_RADIUS := 28.0
const THICKNESS := 1.1

var _center: Vector3
var _gap_angle: float = 0.0
var _gap_width: float = 1.0
var _speed: float = 10.0
var _radius: float = 1.5
var _info: DamageInfo
var _hit: Array[Node] = []
var _pieces: Array[MeshInstance3D] = []


func setup(center: Vector3, gap_angle: float, gap_width: float, speed: float, info: DamageInfo) -> void:
	_center = center
	_gap_angle = gap_angle
	_gap_width = gap_width
	_speed = speed
	_info = info
	global_position = center
	var material := Fx.flat_material(COLOR, 2.5)
	for i: int in SEGMENTS:
		var angle: float = TAU * (i + 0.5) / SEGMENTS
		if _in_gap(angle):
			continue
		var piece := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.6, 0.9, THICKNESS)
		piece.mesh = box
		piece.material_override = material
		piece.set_meta(&"angle", angle)
		add_child(piece)
		_pieces.append(piece)
	_place()


func _physics_process(delta: float) -> void:
	_radius += _speed * delta
	if _radius > MAX_RADIUS:
		queue_free()
		return
	_place()
	for hurtbox: Hurtbox in CombatQuery.hurtboxes(get_tree(), DamageInfo.Team.PLAYERS):
		if _hit.has(hurtbox.receiver):
			continue
		var offset: Vector3 = hurtbox.flat_position() - _center
		var distance: float = offset.length()
		if absf(distance - _radius) > THICKNESS * 0.5 + hurtbox.radius:
			continue
		if _in_gap(atan2(offset.z, offset.x)):
			continue
		_hit.append(hurtbox.receiver)
		var info: DamageInfo = _info.clone()
		info.origin = _center
		hurtbox.take_hit(info)


func _in_gap(angle: float) -> bool:
	return absf(wrapf(angle - _gap_angle, -PI, PI)) < _gap_width * 0.5


func _place() -> void:
	var piece_width: float = TAU * _radius / SEGMENTS + 0.1
	for piece: MeshInstance3D in _pieces:
		var angle: float = piece.get_meta(&"angle")
		piece.position = Vector3(cos(angle) * _radius, 0.45, sin(angle) * _radius)
		piece.rotation.y = -angle + PI * 0.5
		piece.scale.x = piece_width / 0.6
