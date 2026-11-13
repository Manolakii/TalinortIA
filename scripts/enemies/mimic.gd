class_name Mimic
extends TalinorteanoCegado
## Mimic (evento "Cofres sospechosos"): un cofre con dientes. Persigue y muerde con un aviso
## naranja, como el Talinorteano cegado, pero pega más fuerte y aguanta más.

const WOOD := Color(0.36, 0.24, 0.15)

var _lid: Node3D


func _ready() -> void:
	enemy_id = &"mimic"
	drops_gold = false  # el premio lo da el evento
	super._ready()


func _build_body() -> void:
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.1, data.body_height, 0.8)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = data.body_height * 0.5
	add_child(collision)
	var body := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, 0.5, 0.7)
	body.mesh = mesh
	body.position.y = 0.25
	_body_material = _make_material(WOOD)
	body.material_override = _body_material
	visual.add_child(body)
	_lid = Node3D.new()
	_lid.position = Vector3(0, 0.5, 0.35)
	visual.add_child(_lid)
	var lid := MeshInstance3D.new()
	var lid_mesh := BoxMesh.new()
	lid_mesh.size = Vector3(1.0, 0.22, 0.7)
	lid.mesh = lid_mesh
	lid.position = Vector3(0, 0.11, -0.35)
	lid.material_override = _body_material
	_lid.add_child(lid)
	# Dientes y lengua.
	for i: int in 5:
		var tooth := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.12, 0.16, 0.06)
		tooth.mesh = prism
		tooth.rotation.z = PI
		tooth.position = Vector3(-0.4 + i * 0.2, -0.06, -0.66)
		tooth.material_override = _make_material(Color(0.92, 0.9, 0.82), false)
		_lid.add_child(tooth)
	var tongue := MeshInstance3D.new()
	var tongue_mesh := BoxMesh.new()
	tongue_mesh.size = Vector3(0.3, 0.05, 0.5)
	tongue.mesh = tongue_mesh
	tongue.position = Vector3(0, 0.52, -0.25)
	tongue.material_override = _make_material(Color(0.6, 0.25, 0.3), false)
	visual.add_child(tongue)
	# La boca abierta, con hambre.
	_lid.rotation.x = -0.5


func _build_extras() -> void:
	pass


## Mordisco: cierra la tapa de golpe.
func _swing_stick() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_lid, "rotation:x", 0.0, 0.06)
	tween.tween_property(_lid, "rotation:x", -0.5, 0.35)
