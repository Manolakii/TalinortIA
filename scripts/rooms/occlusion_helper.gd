class_name OcclusionHelper
extends Node
## Lo que tapa a los personajes (GDD, Choques: "las paredes del sur tapan personajes"):
## si una pared o roca queda entre la cámara y un personaje, se vuelve semitransparente,
## y el personaje tapado se ve como una silueta del color de su jugador, con su nombre.

const FADED := 0.65
const FADE_SPEED := 6.0
## Paredes (1) y obstáculos como rocas (512).
const OCCLUDER_MASK := 1 | 512

var _faded: Dictionary = {}  # GeometryInstance3D -> transparencia objetivo
var _silhouettes: Dictionary = {}  # PlayerCharacter -> MeshInstance3D


func _process(delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var space: PhysicsDirectSpaceState3D = camera.get_world_3d().direct_space_state
	var occluding_now: Array[GeometryInstance3D] = []
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var player := node as PlayerCharacter
		if player == null or player.is_out():
			continue
		var hidden: bool = false
		for height: float in [0.4, 1.2]:
			var query := PhysicsRayQueryParameters3D.create(camera.global_position,
					player.global_position + Vector3.UP * height, OCCLUDER_MASK)
			var hit: Dictionary = space.intersect_ray(query)
			if hit.is_empty():
				continue
			hidden = true
			for geometry: GeometryInstance3D in _geometry_of(hit["collider"] as Node):
				if not occluding_now.has(geometry):
					occluding_now.append(geometry)
		_set_silhouette(player, hidden)
	for geometry: GeometryInstance3D in occluding_now:
		_faded[geometry] = FADED
	for geometry: Variant in _faded.keys():
		if not is_instance_valid(geometry):
			_faded.erase(geometry)
			continue
		var target: float = FADED if occluding_now.has(geometry) else 0.0
		var instance := geometry as GeometryInstance3D
		instance.transparency = move_toward(instance.transparency, target, FADE_SPEED * delta)
		if target == 0.0 and instance.transparency <= 0.0:
			_faded.erase(geometry)


func _geometry_of(collider: Node) -> Array[GeometryInstance3D]:
	var result: Array[GeometryInstance3D] = []
	if collider == null:
		return result
	for child: Node in collider.get_children():
		if child is GeometryInstance3D:
			result.append(child)
	return result


func _set_silhouette(player: PlayerCharacter, on: bool) -> void:
	var silhouette: MeshInstance3D = _silhouettes.get(player)
	if silhouette == null or not is_instance_valid(silhouette):
		if not on:
			return
		silhouette = _make_silhouette(player)
		_silhouettes[player] = silhouette
	silhouette.visible = on


## Copia del cuerpo que se dibuja por encima de todo, del color del jugador.
func _make_silhouette(player: PlayerCharacter) -> MeshInstance3D:
	var body := player.get_node("Visual/Body") as MeshInstance3D
	var silhouette := MeshInstance3D.new()
	silhouette.name = "Silhouette"
	silhouette.mesh = body.mesh
	silhouette.position = body.position
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(player.slot.color.lightened(0.2), 0.55)
	material.no_depth_test = true
	material.render_priority = 4
	silhouette.material_override = material
	silhouette.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var label := Label3D.new()
	label.text = player.slot.label
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.pixel_size = 0.0011
	label.font_size = 30
	label.outline_size = 8
	label.modulate = player.slot.color.lightened(0.35)
	label.position.y = body.position.y + 1.2
	silhouette.add_child(label)
	player.visual.add_child(silhouette)
	return silhouette
