class_name Telegraph
extends MeshInstance3D
## Aviso de ataque en el piso. El relleno avanza durante `duration` y llega al borde
## justo cuando pega el golpe.

const SHADER: Shader = preload("res://assets/shaders/telegraph.gdshader")
## Altura sobre el piso: por encima de la mayoría del pasto, debajo de los personajes.
const HEIGHT := 0.22

var _material: ShaderMaterial
var _plane: PlaneMesh
var _duration: float = 0.0
var _elapsed: float = 0.0


func _ready() -> void:
	_plane = PlaneMesh.new()
	mesh = _plane
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	position.y = HEIGHT
	visible = false


## Abanico hacia -Z del nodo (360 = círculo).
func show_sector(radius: float, angle_deg: float, duration: float) -> void:
	_plane.size = Vector2.ONE * radius * 2.0
	_plane.center_offset = Vector3.ZERO
	_material.set_shader_parameter("shape", 0)
	_material.set_shader_parameter("angle_deg", angle_deg)
	_material.set_shader_parameter("size_m", _plane.size)
	_start(duration)


func show_circle(radius: float, duration: float) -> void:
	show_sector(radius, 360.0, duration)


## Rectángulo que arranca en el nodo y se extiende `length` hacia -Z.
func show_rect(length: float, width: float, duration: float) -> void:
	_plane.size = Vector2(width, length)
	_plane.center_offset = Vector3(0.0, 0.0, -length * 0.5)
	_material.set_shader_parameter("shape", 1)
	_material.set_shader_parameter("size_m", _plane.size)
	_start(duration)


func hide_telegraph() -> void:
	visible = false
	set_process(false)


func _start(duration: float) -> void:
	_duration = maxf(duration, 0.01)
	_elapsed = 0.0
	_material.set_shader_parameter("progress", 0.0)
	visible = true
	set_process(true)


func _process(delta: float) -> void:
	_elapsed += delta
	_material.set_shader_parameter("progress", clampf(_elapsed / _duration, 0.0, 1.0))
