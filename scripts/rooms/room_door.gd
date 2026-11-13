class_name RoomDoor
extends Node3D
## Puerta al final de la sala (GDD: dos puertas con el ícono de lo que hay detrás, como en Hades).
## Sale del piso al terminar la sala. Cualquier jugador se acerca y aprieta Interactuar (E / X).

signal chosen(room_type: int)

const STONE: Material = preload("res://assets/materials/rock_material.tres")
const STEEL := Color(0.82, 0.84, 0.88)
const GOLD := Color(1.0, 0.78, 0.2)
const WOOD := Color(0.42, 0.26, 0.14)
const USE_RADIUS := 2.4

var room_type: int = RoomKind.Type.COMBAT
var _icon: Node3D
var _prompt: Label3D
var _used: bool = false
var _ready_to_use: bool = false


func setup(type: int, label_extra: String = "") -> void:
	room_type = type
	_build_frame()
	_icon = Node3D.new()
	_icon.position = Vector3(0, 4.2, 0.4)
	_icon.scale = Vector3.ONE * 1.8
	add_child(_icon)
	_build_icon(type)
	var title := _label(RoomKind.display_name(type) + label_extra, 64, Color.WHITE)
	title.pixel_size = 0.01
	title.outline_size = 18
	title.position = Vector3(0, 0.4, 1.5)
	add_child(title)
	_prompt = _label("Entrar (E / X)", 56, GOLD)
	_prompt.pixel_size = 0.01
	_prompt.position = Vector3(0, 1.4, 1.9)
	_prompt.visible = false
	add_child(_prompt)
	# Sale del piso.
	position.y = -4.5
	var tween: Tween = create_tween()
	tween.tween_property(self, "position:y", 0.0, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: _ready_to_use = true)


func _physics_process(delta: float) -> void:
	if _icon != null:
		_icon.rotation.y += delta * 1.2
	if _used or not _ready_to_use:
		return
	var near: PlayerCharacter = _nearest_player()
	_prompt.visible = near != null
	if near != null and near.slot.input.just_pressed(PlayerInput.Action.INTERACT):
		_used = true
		_prompt.visible = false
		chosen.emit(room_type)


func _nearest_player() -> PlayerCharacter:
	var front: Vector3 = global_position + Vector3(0, 0, 1.0)
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var player := node as PlayerCharacter
		if player == null or player.health.is_dead or player.menu_locked:
			continue
		var offset: Vector3 = player.global_position - front
		if Vector2(offset.x, offset.z).length() <= USE_RADIUS:
			return player
	return null


# --- Placeholder: marco de piedra, portal que brilla e ícono ---

func _build_frame() -> void:
	for x: float in [-1.5, 1.5]:
		var post := _box(Vector3(0.7, 3.4, 0.7), Vector3(x, 1.7, 0))
		post.material_override = STONE
	var lintel := _box(Vector3(3.8, 0.6, 0.8), Vector3(0, 3.4, 0))
	lintel.material_override = STONE
	var portal := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.3, 3.1)
	portal.mesh = quad
	portal.position = Vector3(0, 1.55, 0.05)
	var material := Fx.flat_material(Color(1.0, 0.82, 0.5, 0.45), 0.8)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	portal.material_override = material
	portal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(portal)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.9, 0.7)
	light.light_energy = 1.5
	light.omni_range = 5.0
	light.position = Vector3(0, 1.6, 1.2)
	add_child(light)


func _build_icon(type: int) -> void:
	match type:
		RoomKind.Type.COMBAT:
			_swords(Vector3.ZERO)
		RoomKind.Type.COMBAT_UPGRADE:
			_swords(Vector3(-0.35, 0, 0))
			_rhombus(Vector3(0.55, 0.1, 0))
		RoomKind.Type.ELITE:
			_crown()
		RoomKind.Type.TREASURE:
			_mini_chest(Vector3.ZERO)
		RoomKind.Type.MIMICS:
			_mini_chest(Vector3(-0.3, 0, 0))
			var question := _label("?", 120, Color.WHITE)
			question.position = Vector3(0.55, 0.1, 0)
			_icon.add_child(question)
		RoomKind.Type.PRISONERS:
			_cage()
		RoomKind.Type.PIPO_CABIN:
			_hut()


func _swords(offset: Vector3) -> void:
	for angle: float in [0.7, -0.7]:
		var blade := _box(Vector3(0.12, 1.1, 0.04), offset, _icon)
		blade.rotation.z = angle
		blade.material_override = Fx.flat_material(STEEL, 0.5)
		var guard := _box(Vector3(0.36, 0.08, 0.08), offset + Vector3(sin(-angle) * 0.35, -cos(angle) * 0.35, 0.02), _icon)
		guard.rotation.z = angle
		guard.material_override = Fx.flat_material(WOOD)


func _rhombus(offset: Vector3) -> void:
	var gem := _box(Vector3(0.45, 0.45, 0.12), offset, _icon)
	gem.rotation.z = PI * 0.25
	gem.material_override = Fx.flat_material(GOLD, 1.8)


func _crown() -> void:
	var band := MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = 0.42
	ring.bottom_radius = 0.42
	ring.height = 0.28
	band.mesh = ring
	band.material_override = Fx.flat_material(STEEL, 0.8)
	_icon.add_child(band)
	for i: int in 5:
		var angle: float = TAU * i / 5.0
		var spike := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.22, 0.38, 0.06)
		spike.mesh = prism
		spike.position = Vector3(cos(angle) * 0.4, 0.32, sin(angle) * 0.4)
		spike.rotation.y = -angle + PI * 0.5
		spike.material_override = Fx.flat_material(STEEL, 0.8)
		_icon.add_child(spike)


func _mini_chest(offset: Vector3) -> void:
	var body := _box(Vector3(0.8, 0.45, 0.5), offset, _icon)
	body.material_override = Fx.flat_material(WOOD, 0.3)
	var band := _box(Vector3(0.84, 0.08, 0.54), offset + Vector3(0, 0.12, 0), _icon)
	band.material_override = Fx.flat_material(GOLD, 1.2)


func _cage() -> void:
	for i: int in 8:
		var angle: float = TAU * i / 8.0
		var bar := _box(Vector3(0.06, 1.0, 0.06), Vector3(cos(angle) * 0.4, 0, sin(angle) * 0.4), _icon)
		bar.material_override = Fx.flat_material(STEEL, 0.4)
	var top := _box(Vector3(0.9, 0.08, 0.9), Vector3(0, 0.5, 0), _icon)
	top.material_override = Fx.flat_material(STEEL, 0.4)


func _hut() -> void:
	var walls := _box(Vector3(0.8, 0.55, 0.6), Vector3.ZERO, _icon)
	walls.material_override = Fx.flat_material(WOOD, 0.3)
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(1.0, 0.45, 0.7)
	roof.mesh = prism
	roof.position.y = 0.5
	roof.material_override = Fx.flat_material(Color(0.3, 0.38, 0.22), 0.3)
	_icon.add_child(roof)


func _box(size: Vector3, at: Vector3, parent: Node3D = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.position = at
	(parent if parent != null else self).add_child(node)
	return node


func _label(text: String, size: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.outline_size = 12
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	return label
