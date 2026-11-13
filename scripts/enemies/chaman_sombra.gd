class_name ChamanSombra
extends Enemy
## Chamán de la Sombra (GDD, Stage 1): mantiene ciegos a los Talinorteanos y los acelera
## un 20%. Tiene una zona de sombra que lastima (4 por segundo). Se mantiene lejos.
## Si lo matás, los cegados cercanos se aturden 3 s y algunos despiertan y huyen.

const AURA_REFRESH := 0.25

var _zone: ShadowZone
var _aura_timer: float = 0.0


func _ready() -> void:
	enemy_id = &"chaman_sombra"
	super._ready()
	_zone = ShadowZone.new()
	_zone.radius = data.zone_radius
	_zone.dps = data.zone_dps
	_zone.follow = self
	_zone.source = self
	_zone.damage_multiplier = damage_multiplier
	get_parent().add_child.call_deferred(_zone)


func _think(delta: float) -> void:
	_aura_timer -= delta
	if _aura_timer <= 0.0:
		_aura_timer = AURA_REFRESH
		for blinded: Enemy in _blinded_nearby():
			blinded.status.apply(StatusEffects.SHADOW_HASTE, AURA_REFRESH * 2.0)
	if status.has(StatusEffects.STUN):
		stop(delta)
		return
	var target: Node3D = nearest_target()
	if target == null:
		stop(delta)
		return
	keep_distance(target, data.preferred_distance, delta, 0.3)


## Los cegados (Talinorteanos y Honderos) dentro del aura.
func _blinded_nearby() -> Array[Enemy]:
	var result: Array[Enemy] = []
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy == self or enemy.awake:
			continue
		if not (enemy is TalinorteanoCegado or enemy is HonderoCegado):
			continue
		if flat_distance_to(enemy.global_position) <= data.aura_radius:
			result.append(enemy)
	return result


func _on_died(info: DamageInfo) -> void:
	for blinded: Enemy in _blinded_nearby():
		blinded.status.apply(StatusEffects.STUN, data.death_stun)
		if randf() < data.wake_chance:
			blinded.wake_and_flee()
	if is_instance_valid(_zone):
		_zone.queue_free()
	super._on_died(info)


func _build_extras() -> void:
	var robe := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = data.body_radius * 0.5
	cone.bottom_radius = data.body_radius * 1.25
	cone.height = data.body_height * 0.75
	robe.mesh = cone
	robe.position.y = data.body_height * 0.375
	robe.material_override = Fx.flat_material(data.body_color.darkened(0.25))
	visual.add_child(robe)
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.16
	sphere.height = 0.32
	orb.mesh = sphere
	orb.position = Vector3(data.body_radius + 0.2, data.body_height * 1.05, 0.0)
	orb.material_override = Fx.flat_material(ShadowZone.SHADOW_COLOR.lightened(0.3), 3.0)
	visual.add_child(orb)
