class_name ProjectilePool
extends Node3D
## Pool de proyectiles simples (piedras, balas): se reutilizan en vez de crear nodos.
## Cada proyectil va en línea recta y le pega al primer objetivo que toca.

class Shot:
	var node: MeshInstance3D
	var active: bool = false
	var velocity: Vector3
	var traveled: float
	var max_range: float
	var radius: float
	var info: DamageInfo
	var target_team: DamageInfo.Team
	var on_hit: Callable

var _shots: Array[Shot] = []
var _mesh: Mesh
var _material: Material


## `mesh` y `material` definen cómo se ve cada proyectil de este pool.
func setup(mesh: Mesh, material: Material, size: int = 16) -> void:
	_mesh = mesh
	_material = material
	for i: int in size:
		_add_shot()


## Dispara. `info` es la plantilla del golpe (ya con el crítico tirado).
## `on_hit(target: Node3D, info: DamageInfo)` se llama si conecta.
func fire(from: Vector3, direction: Vector3, speed: float, max_range: float, radius: float,
		info: DamageInfo, target_team: DamageInfo.Team, on_hit: Callable = Callable()) -> void:
	var shot: Shot = _free_shot()
	shot.active = true
	shot.velocity = direction.normalized() * speed
	shot.traveled = 0.0
	shot.max_range = max_range
	shot.radius = radius
	shot.info = info
	shot.target_team = target_team
	shot.on_hit = on_hit
	shot.node.global_position = from
	shot.node.visible = true


func _physics_process(delta: float) -> void:
	for shot: Shot in _shots:
		if not shot.active:
			continue
		var step: Vector3 = shot.velocity * delta
		var from: Vector3 = shot.node.global_position
		var to: Vector3 = from + step
		shot.node.global_position = to
		shot.node.rotate_x(delta * 14.0)
		shot.traveled += step.length()
		var hits: Array[Hurtbox] = CombatQuery.in_line(get_tree(), shot.target_team, from, to,
				shot.radius * 2.0)
		if not hits.is_empty():
			var target: Hurtbox = _closest(hits, from)
			var info: DamageInfo = shot.info.clone()
			info.origin = from - shot.velocity.normalized()
			if target.take_hit(info) and shot.on_hit.is_valid():
				shot.on_hit.call(target.receiver, info)
			_release(shot)
		elif shot.traveled >= shot.max_range:
			_release(shot)


func _closest(hits: Array[Hurtbox], from: Vector3) -> Hurtbox:
	var best: Hurtbox = hits[0]
	for hurtbox: Hurtbox in hits:
		if hurtbox.global_position.distance_to(from) < best.global_position.distance_to(from):
			best = hurtbox
	return best


func _release(shot: Shot) -> void:
	shot.active = false
	shot.node.visible = false


func _free_shot() -> Shot:
	for shot: Shot in _shots:
		if not shot.active:
			return shot
	return _add_shot()


func _add_shot() -> Shot:
	var shot := Shot.new()
	shot.node = MeshInstance3D.new()
	shot.node.mesh = _mesh
	shot.node.material_override = _material
	shot.node.visible = false
	add_child(shot.node)
	_shots.append(shot)
	return shot
