class_name MazeTrap
extends Node3D
## Trampas del Laberinto de los Gronks (pedido del grupo: era demasiado fácil).
##   GUILLOTINE: una cuchilla que cae sobre un pasillo, cada tanto y con su ritmo.
##   SPIKES: pinchos que salen del piso de una celda.
## Las dos avisan antes con el naranja de siempre. Si te pegan, hace ruido (puede despertar Gronks).

enum Kind { GUILLOTINE, SPIKES }

const STEEL := Color(0.75, 0.77, 0.8)
const WOOD := Color(0.36, 0.25, 0.15)

var kind: Kind = Kind.GUILLOTINE
## Largo (a lo ancho del pasillo) y ancho de la zona que pega.
var length: float = 4.0
var width: float = 1.0
var damage: float = 25.0
## Tiempos: quieta, aviso y abajo (o arriba, los pinchos).
var rest_time: float = 2.2
var warn_time: float = 0.6
var active_time: float = 0.6

var _phase: int = 0  # 0 quieta, 1 aviso, 2 pegando
var _timer: float = 0.0
var _hit: Array[Node] = []
var _blade: Node3D
var _telegraph: Telegraph


## `along`: dirección de la cuchilla (a lo ancho del pasillo). `offset`: para que no caigan todas juntas.
func setup(which: Kind, along: Vector3, span: float, trap_damage: float, offset: float) -> void:
	kind = which
	length = span
	damage = trap_damage
	rotation.y = atan2(-along.x, -along.z)
	_timer = rest_time * offset
	if kind == Kind.SPIKES:
		width = span
		rest_time = 2.0
		warn_time = 0.7
		active_time = 0.9
	_build()


func _physics_process(delta: float) -> void:
	_timer -= delta
	match _phase:
		0:
			if _timer <= 0.0:
				_phase = 1
				_timer = warn_time * Scaling.current_windup()
				_telegraph.position = Vector3(0, 0.05, length * 0.5)
				_telegraph.show_rect(length, width + 0.4, _timer)
		1:
			if _timer <= 0.0:
				_phase = 2
				_timer = active_time
				_hit.clear()
				_telegraph.hide_telegraph()
				_animate(true)
		2:
			_strike()
			if _timer <= 0.0:
				_phase = 0
				_timer = rest_time
				_animate(false)


## Pega a los jugadores que estén en la zona (una vez por golpe).
func _strike() -> void:
	var along: Vector3 = -global_basis.z
	var a: Vector3 = global_position - along * length * 0.5
	var b: Vector3 = global_position + along * length * 0.5
	for hurtbox: Hurtbox in CombatQuery.in_line(get_tree(), DamageInfo.Team.PLAYERS, a, b, width):
		if _hit.has(hurtbox.receiver):
			continue
		_hit.append(hurtbox.receiver)
		var info := DamageInfo.new()
		info.amount = damage * Scaling.current_damage_multiplier()
		info.attacker_team = DamageInfo.Team.ENEMIES
		var closest: Vector3 = Geometry3D.get_closest_point_to_segment(hurtbox.global_position, a, b)
		info.origin = closest - (hurtbox.global_position - closest).normalized() * 0.1
		info.knockback = 7.0
		info.hitstop = Balance.combat.hitstop_heavy
		hurtbox.take_hit(info)


func _animate(down: bool) -> void:
	var tween: Tween = create_tween()
	if kind == Kind.GUILLOTINE:
		tween.tween_property(_blade, "position:y", 0.35 if down else 2.6, 0.12 if down else 0.6) \
				.set_ease(Tween.EASE_IN if down else Tween.EASE_OUT)
		if down:
			Events.camera_shake_requested.emit(0.08)
	else:
		tween.tween_property(_blade, "position:y", 0.25 if down else -0.6, 0.1 if down else 0.4)


func _build() -> void:
	_telegraph = Telegraph.new()
	add_child(_telegraph)
	_telegraph.rotation.y = 0.0
	_blade = Node3D.new()
	add_child(_blade)
	if kind == Kind.GUILLOTINE:
		for end: float in [-0.5, 0.5]:
			var post := _box(Vector3(0.25, 3.2, 0.25), Vector3(0, 1.6, end * length), Fx.flat_material(WOOD))
			add_child(post)
		var beam := _box(Vector3(0.3, 0.25, length), Vector3(0, 3.2, 0), Fx.flat_material(WOOD))
		add_child(beam)
		var blade := _box(Vector3(0.12, 0.7, length - 0.3), Vector3.ZERO, Fx.flat_material(STEEL, 0.3))
		_blade.add_child(blade)
		_blade.position.y = 2.6
	else:
		var plate := _box(Vector3(width, 0.04, length), Vector3(0, 0.03, 0), Fx.flat_material(Color(0.25, 0.22, 0.2)))
		add_child(plate)
		var rows: int = int(width / 0.6)
		for x: int in rows:
			for z: int in int(length / 0.6):
				var spike := MeshInstance3D.new()
				var cone := CylinderMesh.new()
				cone.top_radius = 0.0
				cone.bottom_radius = 0.1
				cone.height = 0.5
				spike.mesh = cone
				spike.position = Vector3(-width * 0.5 + 0.3 + x * 0.6, 0.0, -length * 0.5 + 0.3 + z * 0.6)
				spike.material_override = Fx.flat_material(STEEL)
				_blade.add_child(spike)
		_blade.position.y = -0.6


func _box(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	node.material_override = material
	return node
