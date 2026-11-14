class_name BossArena
extends Node3D
## Sala del 1-4: la arena del Gronk Gigante, con columnas para hacerlo chocar (GDD).

signal resolved(won: bool)

const BOSS_SCENE: PackedScene = preload("res://scenes/enemies/gronk_gigante.tscn")
const STONE: Material = preload("res://assets/materials/rock_material.tres")
const COLUMNS: Array[Vector3] = [Vector3(-9, 0, -6), Vector3(9, 0, -6), Vector3(-9, 0, 4),
		Vector3(9, 0, 4), Vector3(-17, 0, -1), Vector3(17, 0, -1)]

var boss: GronkGigante
var bar: BossBar


func setup(template: Node3D) -> void:
	# La arena es abierta: solo las columnas.
	var holder: Node = template.get_parent()
	for node: Node in holder.find_children("*", "", true, false):
		if node is RockProp or node is Vase or node is CrackedRock:
			node.queue_free()
	for spot: Vector3 in COLUMNS:
		_column(spot)
	boss = BOSS_SCENE.instantiate()
	boss.position = Vector3(0, 0, -9)
	boss.facing = Vector3.BACK
	get_parent().add_child(boss)
	boss.defeated.connect(func() -> void: resolved.emit(true))
	bar = BossBar.new()
	add_child(bar)
	bar.setup(boss)


func _column(spot: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 512
	body.collision_mask = 0
	body.position = spot
	body.add_to_group(&"boss_columns")
	add_child(body)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 1.1
	cylinder.height = 4.0
	shape.shape = cylinder
	shape.position.y = 2.0
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var column := CylinderMesh.new()
	column.top_radius = 1.0
	column.bottom_radius = 1.2
	column.height = 4.0
	column.material = STONE
	mesh.mesh = column
	mesh.position.y = 2.0
	body.add_child(mesh)
