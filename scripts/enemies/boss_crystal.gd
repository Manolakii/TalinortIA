class_name BossCrystal
extends StaticBody3D
## Cristal de sombra de la fase 3 del Gronk Gigante (pedido del grupo, 2026-11-15): mientras
## está en pie, un hilo de sombra cura al boss de a poco (sin volver a la fase anterior).
## Se rompe a golpes (cualquier ataque); el apuntado y las IA no lo buscan, como las vasijas.

signal broken

const CRYSTAL_COLOR := Color(0.62, 0.3, 0.95)  # violeta = sombra

var max_health: float = 500.0
var health: float = 500.0
var _broken: bool = false
var _visual: Node3D
var _hurtbox: Hurtbox
var _material: StandardMaterial3D
var _label: Label3D
var _beam: MeshInstance3D
## A quién cura (para dibujar el hilo).
var linked: Node3D


func setup(hp: float) -> void:
	max_health = hp
	health = hp


func _ready() -> void:
	collision_layer = 512
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.9
	cylinder.height = 3.0
	shape.shape = cylinder
	shape.position.y = 1.5
	add_child(shape)
	_visual = Node3D.new()
	add_child(_visual)
	_material = Fx.flat_material(CRYSTAL_COLOR, 1.6)
	for i: int in 3:
		var shard := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.9 - i * 0.2, 2.8 - i * 0.6, 0.9 - i * 0.2)
		shard.mesh = prism
		shard.material_override = _material
		shard.position = Vector3((i - 1) * 0.55, (2.8 - i * 0.6) * 0.5, (i % 2) * 0.3)
		shard.rotation.z = (i - 1) * 0.25
		_visual.add_child(shard)
	var light := OmniLight3D.new()
	light.light_color = CRYSTAL_COLOR
	light.light_energy = 2.0
	light.omni_range = 5.0
	light.position.y = 1.8
	_visual.add_child(light)
	_beam = MeshInstance3D.new()
	var cylinder_mesh := CylinderMesh.new()
	cylinder_mesh.top_radius = 0.08
	cylinder_mesh.bottom_radius = 0.08
	cylinder_mesh.height = 1.0
	_beam.mesh = cylinder_mesh
	var beam_material := Fx.flat_material(Color(CRYSTAL_COLOR, 0.6), 2.0)
	beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam.material_override = beam_material
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.top_level = true
	add_child(_beam)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 40
	_label.outline_size = 12
	_label.position.y = 3.6
	add_child(_label)
	_hurtbox = Hurtbox.new()
	_hurtbox.team = DamageInfo.Team.ENEMIES
	_hurtbox.radius = 1.2
	_hurtbox.height = 3.0
	_hurtbox.is_prop = true
	add_child(_hurtbox)
	var pulse: Tween = create_tween().set_loops()
	pulse.tween_property(_material, "emission_energy_multiplier", 2.6, 0.5).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(_material, "emission_energy_multiplier", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	_update_label()


func _process(_delta: float) -> void:
	if _broken or not is_instance_valid(linked):
		_beam.visible = false
		return
	var from: Vector3 = global_position + Vector3.UP * 2.2
	var to: Vector3 = linked.global_position + Vector3.UP * 2.0
	var length: float = from.distance_to(to)
	_beam.visible = length > 0.5
	if not _beam.visible:
		return
	# El cilindro va en Y: se lo hace mirar al boss y se lo acuesta.
	_beam.global_transform = Transform3D(Basis.IDENTITY, (from + to) * 0.5)
	_beam.look_at(to, Vector3.UP)
	_beam.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
	_beam.scale = Vector3(1.0, length, 1.0)


func is_targetable() -> bool:
	return not _broken


func is_broken() -> bool:
	return _broken


func receive_hit(info: DamageInfo) -> bool:
	if _broken or info.attacker_team != DamageInfo.Team.PLAYERS:
		return false
	info.final_amount = info.amount
	health = maxf(health - info.amount, 0.0)
	Events.hit_landed.emit(info, self)
	var shake: Tween = create_tween()
	shake.tween_property(_visual, "position:x", 0.12, 0.04)
	shake.tween_property(_visual, "position:x", -0.12, 0.04)
	shake.tween_property(_visual, "position:x", 0.0, 0.04)
	_update_label()
	if health <= 0.0:
		smash()
	return true


func smash() -> void:
	if _broken:
		return
	_broken = true
	collision_layer = 0
	_hurtbox.queue_free()
	_label.visible = false
	Sound.play("hit_heavy", 0.0)
	Events.camera_shake_requested.emit(0.45)
	Events.floating_text_requested.emit(global_position + Vector3.UP * 3.0,
			"¡Rompieron el cristal! Ya no se cura", Color(1.0, 0.82, 0.3))
	Fx.ring_burst(get_parent(), global_position, 2.5, CRYSTAL_COLOR, 0.4)
	var tween: Tween = create_tween()
	tween.tween_property(_visual, "scale", Vector3(1.4, 0.05, 1.4), 0.3)
	tween.tween_callback(queue_free)
	broken.emit()


func _update_label() -> void:
	_label.text = "Cristal de sombra %d" % ceili(health)
	_label.modulate = CRYSTAL_COLOR.lightened(0.4)
