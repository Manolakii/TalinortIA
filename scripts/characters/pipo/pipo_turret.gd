class_name PipoTurret
extends Combatant
## Torreta de chatarra del General Pipo: le tira a lo mismo que viene acertando Pipo (si no, al más cercano).
## Dura un rato o hasta que la rompan (los enemigos la pueden atacar).
## Mejora de la tienda "Refugio del Bosque Tuerto": los aliados cerca quedan ocultos para los
## enemigos lejanos.

const METAL := Color(0.45, 0.5, 0.42)
const SHOT_COLOR := Color(0.85, 1.0, 0.75)

var kit: PipoKit
var _time_left: float = 12.0
var _cooldown: float = 0.4
var _head: Node3D
var _visual: Node3D
var _done: bool = false


func setup(owner_kit: PipoKit) -> void:
	kit = owner_kit
	_time_left = kit.turret_duration()
	collision_layer = 0
	collision_mask = 0
	_build(kit.player.slot.color)
	setup_combatant(DamageInfo.Team.PLAYERS, kit.turret_health(), 0.45, 1.2, _visual)
	add_to_group(&"enemy_targets")
	health.died.connect(func(_info: DamageInfo) -> void: dismantle())


func can_be_targeted_by_enemies() -> bool:
	return is_targetable() and not _done


## Los enemigos prefieren a los jugadores.
func target_priority() -> float:
	return 1.3


func _modify_incoming(info: DamageInfo) -> void:
	info.knockback = 0.0
	info.stun = 0.0


func _physics_process(delta: float) -> void:
	if _done or not is_instance_valid(kit):
		return
	_time_left -= delta
	if _time_left <= 0.0:
		dismantle()
		return
	if kit.has_upgrade(&"pipo_refugio"):
		_camouflage()
	if kit.has_upgrade(&"pipo_torretas_patas"):
		_follow(delta)
	_cooldown -= delta
	var target: Hurtbox = _pick_target()
	if target == null:
		return
	var direction: Vector3 = target.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		_head.rotation.y = lerp_angle(_head.rotation.y, atan2(-direction.x, -direction.z), minf(delta * 12.0, 1.0))
	if _cooldown > 0.0:
		return
	_cooldown = 1.0 / kit.turret_fire_rate()
	var info: DamageInfo = kit.make_hit(kit.kd.turret_damage)
	info.is_melee = false
	info.knockback = 0.5
	info.hitstop = 0.0
	info.origin = global_position
	target.take_hit(info)
	var from: Vector3 = _head.global_position
	var to: Vector3 = target.global_position + Vector3.UP * 0.9
	Fx.beam(get_parent(), from, (to - from).normalized(), from.distance_to(to), 0.06, SHOT_COLOR, 0.08)


## Kit de Yole "Torretas con patas": caminan detrás de Pipo, cada una en su lugar.
func _follow(delta: float) -> void:
	var owner_player: PlayerCharacter = kit.player
	if not is_instance_valid(owner_player) or owner_player.health.is_dead:
		return
	var index: int = maxi(kit.turrets.find(self), 0)
	var count: int = maxi(kit.turrets.size(), 1)
	# Detrás de Pipo (según hacia dónde apunta), repartidas en abanico.
	var back: Vector3 = -owner_player.aim_direction
	back.y = 0.0
	back = back.normalized() if back.length_squared() > 0.01 else Vector3.BACK
	var spread: float = 0.0 if count == 1 else lerpf(-0.9, 0.9, float(index) / (count - 1))
	var goal: Vector3 = owner_player.global_position + back.rotated(Vector3.UP, spread) * kit.kd.legs_follow_distance
	var to_goal: Vector3 = goal - global_position
	to_goal.y = 0.0
	if to_goal.length() < 0.3:
		return
	var step: float = minf(kit.kd.legs_speed * delta, to_goal.length())
	global_position += to_goal.normalized() * step
	_visual.rotation.z = sin(Time.get_ticks_msec() * 0.03) * 0.08  # caminadito


## Primero al último enemigo que acertó Pipo; si no, el más cercano.
func _pick_target() -> Hurtbox:
	var best: Hurtbox = null
	var best_score: float = INF
	for hurtbox: Hurtbox in CombatQuery.targets(get_tree(), DamageInfo.Team.ENEMIES):
		var d: float = hurtbox.global_position.distance_to(global_position)
		if d > kit.kd.turret_range:
			continue
		var score: float = d - (100.0 if hurtbox.receiver == kit.last_target else 0.0)
		if score < best_score:
			best_score = score
			best = hurtbox
	return best


func _camouflage() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var ally := node as PlayerCharacter
		if ally == null or ally.global_position.distance_to(global_position) > 4.0:
			continue
		if CombatQuery.nearest(get_tree(), DamageInfo.Team.ENEMIES, ally.global_position, 6.0) == null:
			ally.status.apply(StatusEffects.HIDDEN, 0.3)


func dismantle() -> void:
	if _done:
		return
	_done = true
	remove_from_group(&"enemy_targets")
	Fx.ring_burst(get_parent(), global_position, 1.0, Color(0.6, 0.6, 0.55), 0.2)
	var tween: Tween = create_tween()
	tween.tween_property(_visual, "scale", Vector3(1, 0.05, 1), 0.25)
	tween.tween_callback(queue_free)


func _build(color: Color) -> void:
	_visual = Node3D.new()
	add_child(_visual)
	for i: int in 3:
		var angle: float = TAU * i / 3.0
		var leg := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.08, 0.9, 0.08)
		leg.mesh = mesh
		leg.position = Vector3(cos(angle) * 0.3, 0.4, sin(angle) * 0.3)
		leg.rotation = Vector3(sin(angle) * 0.35, 0, -cos(angle) * 0.35)
		leg.material_override = Fx.flat_material(METAL)
		_visual.add_child(leg)
	_head = Node3D.new()
	_head.position.y = 0.95
	_visual.add_child(_head)
	var box := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.5, 0.35, 0.6)
	box.mesh = box_mesh
	box.material_override = Fx.flat_material(METAL)
	_head.add_child(box)
	var barrel := MeshInstance3D.new()
	var barrel_mesh := BoxMesh.new()
	barrel_mesh.size = Vector3(0.12, 0.12, 0.7)
	barrel.mesh = barrel_mesh
	barrel.position = Vector3(0, 0.02, -0.55)
	barrel.material_override = Fx.flat_material(METAL.darkened(0.3))
	_head.add_child(barrel)
	# Luz del color del jugador: se sabe de quién es.
	var lamp := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.08
	sphere.height = 0.16
	lamp.mesh = sphere
	lamp.position = Vector3(0, 0.24, 0.1)
	lamp.material_override = Fx.flat_material(color, 2.5)
	_head.add_child(lamp)
