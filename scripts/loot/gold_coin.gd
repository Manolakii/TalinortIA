class_name GoldCoin
extends Node3D
## Moneda de oro de UN jugador: dorada con brillo y un canto del color de su aro.
## Salta al caer, queda girando en el piso y vuela hacia su dueño cuando se acerca.
## Al terminar la sala, todas las monedas que quedan vuelan solas a su dueño.

const GOLD := Color(1.0, 0.78, 0.2)

var owner_player: PlayerCharacter
var slot_index: int = 0
var value: int = 1

var _velocity: Vector3 = Vector3.ZERO
var _landed: bool = false
var _homing: bool = false
var _spin: Node3D
var _age: float = 0.0
var _collected: bool = false


func setup(player: PlayerCharacter, coin_value: int, launch: Vector3) -> void:
	owner_player = player
	slot_index = player.slot.index
	value = coin_value
	_velocity = launch
	_build(player.slot.color)
	Events.room_cleared.connect(_on_room_cleared)


func _build(ring_color: Color) -> void:
	_spin = Node3D.new()
	add_child(_spin)
	var face := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.2
	disc.bottom_radius = 0.2
	disc.height = 0.05
	disc.radial_segments = 16
	face.mesh = disc
	face.rotation.x = PI * 0.5
	var gold := Fx.flat_material(GOLD, 1.4)
	gold.metallic = 0.8
	gold.roughness = 0.3
	face.material_override = gold
	face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spin.add_child(face)
	# Canto del color del jugador: así cada uno reconoce las suyas.
	var rim := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.19
	torus.outer_radius = 0.25
	torus.rings = 16
	torus.ring_segments = 6
	rim.mesh = torus
	rim.rotation.x = PI * 0.5
	rim.material_override = Fx.flat_material(ring_color, 1.2)
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_spin.add_child(rim)


func _physics_process(delta: float) -> void:
	if _collected:
		return
	_age += delta
	if _spin != null:
		_spin.rotation.y += delta * 4.0
	if not _landed:
		_velocity.y -= 22.0 * delta
		global_position += _velocity * delta
		if global_position.y <= 0.35 and _velocity.y < 0.0:
			global_position.y = 0.35
			_landed = true
		return
	if not is_instance_valid(owner_player):
		return
	var target: Vector3 = owner_player.global_position + Vector3.UP * 0.8
	var to_owner: Vector3 = target - global_position
	var flat_distance: float = Vector2(to_owner.x, to_owner.z).length()
	var economy: EconomyConfig = Balance.economy
	if not _homing and _age > 0.35 and flat_distance <= economy.coin_magnet_radius \
			and not owner_player.is_downed():
		_homing = true
	if _homing:
		var speed: float = economy.coin_fly_speed * (1.0 + _age * 0.3)
		if to_owner.length() <= speed * delta + 0.3:
			collect()
		else:
			global_position += to_owner.normalized() * speed * delta
	else:
		_spin.position.y = sin(_age * 3.0) * 0.06


## Suma el oro al jugador y desaparece.
func collect() -> void:
	if _collected:
		return
	_collected = true
	RunState.add_gold(slot_index, value)
	if is_instance_valid(owner_player):
		Events.floating_text_requested.emit(owner_player.global_position + Vector3.UP * 2.3,
				"+%d" % value, GOLD)
	queue_free()


func _on_room_cleared() -> void:
	if _collected:
		return
	if not is_instance_valid(owner_player) or owner_player.is_out():
		collect()
		return
	_landed = true
	_homing = true
