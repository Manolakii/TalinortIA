class_name Mimic
extends TalinorteanoCegado
## Mimic (evento "Cofres sospechosos"): un cofre con dientes. Pedido del grupo: como castigo por
## elegir mal, sale ENORME y es un problema. Muerde rápido y con mucho alcance (con el aviso
## naranja de siempre) y, si te alejás, escupe un abanico de monedas truchas y dientes.

const WOOD := Color(0.36, 0.24, 0.15)
## Tamaño del cofre (el original medía 1 m de ancho).
const SIZE := 2.0
## Aviso del escupitajo (lo multiplica la dificultad, como todos los avisos).
const SPIT_WINDUP := 0.7

var _lid: Node3D
var _spit_cooldown: float = 2.0
var _spit_time: float = -1.0
var _spit_direction: Vector3 = Vector3.FORWARD


func _ready() -> void:
	enemy_id = &"mimic"
	drops_gold = false  # el premio lo da el evento
	super._ready()


func _think(delta: float) -> void:
	if _spit_time >= 0.0:
		if status.has(StatusEffects.STUN) or status.has(StatusEffects.FEAR):
			_cancel_spit()
		else:
			stop(delta)
			_spit_time += delta
			if _spit_time >= SPIT_WINDUP * Scaling.current_windup():
				_spit()
			return
	_spit_cooldown -= delta
	super._think(delta)


## Si el objetivo se alejó, en vez de perseguirlo le escupe.
func _chase(delta: float) -> void:
	var target: Node3D = nearest_target()
	if target != null and _spit_cooldown <= 0.0:
		var distance: float = flat_distance_to(target.global_position)
		if distance > data.attack_range + 1.5 and distance <= data.projectile_range:
			_start_spit(target)
			return
	super._chase(delta)


func _start_spit(target: Node3D) -> void:
	_spit_time = 0.0
	_spit_cooldown = attack_interval_time()
	_spit_direction = flat_direction_to(target.global_position)
	facing = _spit_direction
	telegraph.rotation.y = atan2(-facing.x, -facing.z)
	telegraph.show_sector(data.projectile_range * 0.6, data.spread_deg + 12.0, SPIT_WINDUP * Scaling.current_windup())
	# Abre la boca grande antes de escupir.
	var tween: Tween = create_tween()
	tween.tween_property(_lid, "rotation:x", -1.1, 0.25)


func _spit() -> void:
	_spit_time = -1.0
	telegraph.hide_telegraph()
	var pool: ProjectilePool = enemy_projectiles()
	for i: int in data.projectile_count:
		var t: float = float(i) / maxf(data.projectile_count - 1, 1) - 0.5
		var direction: Vector3 = _spit_direction.rotated(Vector3.UP, deg_to_rad(t * data.spread_deg))
		var info: DamageInfo = make_attack(0.6)
		info.is_melee = false
		info.knockback = 3.0
		pool.fire(global_position + Vector3.UP * 1.2 + direction * 1.4, direction,
				data.projectile_speed, data.projectile_range, 0.3, info, attack_team())
	var tween: Tween = create_tween()
	tween.tween_property(_lid, "rotation:x", -0.5, 0.3)
	Sound.play("shot", -4.0)


func _cancel_spit() -> void:
	if _spit_time >= 0.0:
		_spit_time = -1.0
		telegraph.hide_telegraph()
		_lid.rotation.x = -0.5


func _on_interrupted() -> void:
	_cancel_spit()
	super._on_interrupted()


func _build_body() -> void:
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.1, 0.9, 0.8) * SIZE
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = 0.45 * SIZE
	add_child(collision)
	var body := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, 0.5, 0.7) * SIZE
	body.mesh = mesh
	body.position.y = 0.25 * SIZE
	_body_material = _make_material(WOOD)
	body.material_override = _body_material
	visual.add_child(body)
	_lid = Node3D.new()
	_lid.position = Vector3(0, 0.5, 0.35) * SIZE
	visual.add_child(_lid)
	var lid := MeshInstance3D.new()
	var lid_mesh := BoxMesh.new()
	lid_mesh.size = Vector3(1.0, 0.22, 0.7) * SIZE
	lid.mesh = lid_mesh
	lid.position = Vector3(0, 0.11, -0.35) * SIZE
	lid.material_override = _body_material
	_lid.add_child(lid)
	# Dientes y lengua.
	for i: int in 7:
		var tooth := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.12, 0.18, 0.06) * SIZE
		tooth.mesh = prism
		tooth.rotation.z = PI
		tooth.position = Vector3(-0.42 + i * 0.14, -0.06, -0.66) * SIZE
		tooth.material_override = _make_material(Color(0.92, 0.9, 0.82), false)
		_lid.add_child(tooth)
	var tongue := MeshInstance3D.new()
	var tongue_mesh := BoxMesh.new()
	tongue_mesh.size = Vector3(0.3, 0.05, 0.5) * SIZE
	tongue.mesh = tongue_mesh
	tongue.position = Vector3(0, 0.52, -0.25) * SIZE
	tongue.material_override = _make_material(Color(0.6, 0.25, 0.3), false)
	visual.add_child(tongue)
	# La boca abierta, con hambre.
	_lid.rotation.x = -0.5


func _build_extras() -> void:
	pass


## Mordisco: cierra la tapa de golpe.
func _swing_stick() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_lid, "rotation:x", 0.0, 0.05)
	tween.tween_property(_lid, "rotation:x", -0.5, 0.3)
	Events.camera_shake_requested.emit(Balance.combat.shake_light)
