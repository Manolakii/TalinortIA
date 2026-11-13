class_name HealMushroom
extends Node3D
## Honguito que sale a veces de las vasijas (pedido del grupo: no había forma de curarse).
## Lo agarra el primer jugador que pasa por encima y no tiene la vida llena. Verde agua = curación.

const CAP_COLOR := Color(0.35, 0.95, 0.85)
const STEM_COLOR := Color(0.92, 0.9, 0.82)
const PICK_RADIUS := 1.0

var heal_amount: float = 20.0
var _visual: Node3D
var _age: float = 0.0
var _taken: bool = false


func _ready() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var stem := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.07
	cylinder.bottom_radius = 0.09
	cylinder.height = 0.22
	stem.mesh = cylinder
	stem.position.y = 0.11
	stem.material_override = Fx.flat_material(STEM_COLOR)
	_visual.add_child(stem)
	var cap := MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.radius = 0.2
	dome.height = 0.2
	dome.is_hemisphere = true
	cap.mesh = dome
	cap.position.y = 0.2
	cap.material_override = Fx.flat_material(CAP_COLOR, 1.3)
	_visual.add_child(cap)
	for i: int in 3:
		var dot := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.035
		sphere.height = 0.07
		dot.mesh = sphere
		var angle: float = TAU * i / 3.0
		dot.position = Vector3(cos(angle) * 0.11, 0.33, sin(angle) * 0.11)
		dot.material_override = Fx.flat_material(Color.WHITE, 0.6)
		_visual.add_child(dot)
	# Sale de la vasija con un saltito.
	_visual.scale = Vector3.ONE * 0.1
	var tween: Tween = create_tween()
	tween.tween_property(_visual, "scale", Vector3.ONE * 1.4, 0.25).set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)


func _physics_process(delta: float) -> void:
	if _taken:
		return
	_age += delta
	_visual.position.y = absf(sin(_age * 3.0)) * 0.08
	if _age < 0.3:
		return
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var player := node as PlayerCharacter
		if player == null or player.health.is_dead or player.health.current >= player.health.max_health:
			continue
		var offset: Vector3 = player.global_position - global_position
		if Vector2(offset.x, offset.z).length() <= PICK_RADIUS:
			take(player)
			return


func take(player: PlayerCharacter) -> void:
	_taken = true
	player.health.heal(heal_amount)
	Events.floating_text_requested.emit(player.global_position + Vector3.UP * 2.2,
			"+%d" % roundi(heal_amount), CAP_COLOR)
	Fx.ring_burst(get_parent(), global_position, 0.9, CAP_COLOR, 0.25)
	queue_free()
