class_name Chest
extends StaticBody3D
## Cofre: se abre con Interactuar (E / X) estando cerca y suelta oro para cada jugador
## (GDD: 50 a 80 en el Stage 1). Más adelante, los cofres de evento también traen mejoras.

signal opened(by: PlayerCharacter)

const WOOD := Color(0.42, 0.26, 0.14)
const TRIM := Color(1.0, 0.78, 0.2)

## Si está cerrado con llave, no se puede abrir (por ejemplo, hasta terminar la sala).
@export var locked: bool = false
## Si suelta oro al abrirse (los cofres de los eventos lo manejan aparte).
var drops_gold: bool = true
## Evento Mimics: este cofre en realidad es un mimic. La pista: "breath" (respira) o "teeth" (marcas de dientes).
var is_mimic: bool = false
var mimic_clue: StringName = &""

var is_open: bool = false
var _lid: Node3D
var _prompt: Label3D
var _glow: OmniLight3D


func _ready() -> void:
	collision_layer = 512
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.1, 0.8, 0.75)
	shape.shape = box
	shape.position.y = 0.4
	add_child(shape)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = WOOD
	wood.roughness = 0.8
	var trim := Fx.flat_material(TRIM, 0.6)
	trim.metallic = 0.7
	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(1.0, 0.5, 0.65)
	base.mesh = base_mesh
	base.position.y = 0.25
	base.material_override = wood
	add_child(base)
	var band := MeshInstance3D.new()
	var band_mesh := BoxMesh.new()
	band_mesh.size = Vector3(1.04, 0.08, 0.69)
	band.mesh = band_mesh
	band.position.y = 0.45
	band.material_override = trim
	add_child(band)
	# La tapa gira sobre la bisagra de atrás.
	_lid = Node3D.new()
	_lid.position = Vector3(0, 0.5, -0.32)
	add_child(_lid)
	var lid := MeshInstance3D.new()
	var lid_mesh := BoxMesh.new()
	lid_mesh.size = Vector3(1.0, 0.22, 0.65)
	lid.mesh = lid_mesh
	lid.position = Vector3(0, 0.11, 0.32)
	lid.material_override = wood
	_lid.add_child(lid)
	var lock := MeshInstance3D.new()
	var lock_mesh := BoxMesh.new()
	lock_mesh.size = Vector3(0.16, 0.18, 0.06)
	lock.mesh = lock_mesh
	lock.position = Vector3(0, 0.05, 0.66)
	lock.material_override = trim
	_lid.add_child(lock)
	_glow = OmniLight3D.new()
	_glow.light_color = TRIM
	_glow.light_energy = 0.0
	_glow.omni_range = 3.0
	_glow.position.y = 0.9
	add_child(_glow)
	_prompt = Label3D.new()
	_prompt.text = "Abrir (E / X)"
	_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_prompt.no_depth_test = true
	_prompt.font_size = 40
	_prompt.outline_size = 10
	_prompt.modulate = TRIM
	_prompt.position.y = 1.5
	_prompt.visible = false
	add_child(_prompt)
	add_to_group(&"chests")
	if is_mimic:
		_build_clue()


func _physics_process(_delta: float) -> void:
	if is_open:
		return
	var near: PlayerCharacter = _nearest_player()
	_prompt.visible = near != null and not locked
	if near != null and not locked and near.slot.input.just_pressed(PlayerInput.Action.INTERACT):
		open(near)


func open(by: PlayerCharacter = null) -> void:
	if is_open:
		return
	is_open = true
	_prompt.visible = false
	var tween: Tween = create_tween()
	tween.tween_property(_lid, "rotation:x", -1.9, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_glow, "light_energy", 2.5, 0.15)
	tween.tween_property(_glow, "light_energy", 0.0, 0.8)
	Events.camera_shake_requested.emit(0.15)
	if drops_gold and not is_mimic:
		Loot.drop_for_all(get_parent(), global_position + Vector3.FORWARD * 0.3, Balance.economy.chest_gold)
	opened.emit(by)


func _nearest_player() -> PlayerCharacter:
	var radius: float = Balance.economy.chest_open_radius
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var player := node as PlayerCharacter
		if player == null or not player.is_targetable() or player.is_downed():
			continue
		var offset: Vector3 = player.global_position - global_position
		if Vector2(offset.x, offset.z).length() <= radius:
			return player
	return null


## La pista del mimic: respira despacito, o tiene marcas de dientes en la tapa.
func _build_clue() -> void:
	if mimic_clue == &"teeth":
		for i: int in 4:
			var tooth := MeshInstance3D.new()
			var mesh := PrismMesh.new()
			mesh.size = Vector3(0.1, 0.12, 0.04)
			tooth.mesh = mesh
			tooth.rotation.z = PI
			tooth.position = Vector3(-0.3 + i * 0.2, -0.03, 0.67)
			tooth.material_override = Fx.flat_material(Color(0.95, 0.93, 0.85))
			_lid.add_child(tooth)
	else:
		var tween: Tween = create_tween().set_loops()
		tween.tween_property(_lid, "rotation:x", -0.08, 1.4).set_trans(Tween.TRANS_SINE)
		tween.tween_property(_lid, "rotation:x", 0.0, 1.4).set_trans(Tween.TRANS_SINE)
