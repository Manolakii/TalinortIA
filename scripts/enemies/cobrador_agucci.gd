class_name CobradorAgucci
extends Enemy
## Cobrador Agucci (pedido del grupo, 2026-11-15): aparece en algunas salas de combate con una
## bolsa de oro (los "impuestos" que junta para pagarle a Fadied el crédito de los Aguccis).
## No pega: se escapa de los jugadores zigzagueando. Si lo bajan antes de que se acabe el
## tiempo, suelta la bolsa; si no, se va con la plata. Es una misión aparte: no cuenta para
## terminar la sala y su tiempo se ve arriba de su cabeza.

signal escaped
signal robbed

const BAG_COLOR := Color(1.0, 0.82, 0.3)  # dorado = oro
const TAUNTS: Array[String] = ["¡Esto es para Fadied!", "¡Impuesto a la piedra!",
		"¡El crédito no se paga solo!", "¡Al día con los Agucci!"]

## Segundos para bajarlo y oro de la bolsa (para cada jugador). Los pone StageRun.
var time_left: float = 20.0
var bag_gold: int = 30
var _label: Label3D
var _zig_timer: float = 0.0
var _zig_side: float = 1.0
var _taunt_timer: float = 2.0
var _gone: bool = false


func _ready() -> void:
	enemy_id = &"cobrador_agucci"
	drops_gold = true
	super._ready()
	# No frena las oleadas ni el final de la sala.
	remove_from_group(&"enemies")
	add_to_group(&"thieves")


func _think(delta: float) -> void:
	if _gone:
		return
	time_left -= delta
	_update_label()
	if time_left <= 0.0:
		_escape()
		return
	_taunt_timer -= delta
	if _taunt_timer <= 0.0:
		_taunt_timer = randf_range(3.5, 5.5)
		Events.floating_text_requested.emit(global_position + Vector3.UP * 3.0, TAUNTS.pick_random(),
				Color(0.85, 0.8, 0.95))
	if status.has(StatusEffects.STUN):
		stop(delta)
		return
	# Se aleja del jugador más cercano zigzagueando; si nadie está cerca, da vueltas.
	_zig_timer -= delta
	if _zig_timer <= 0.0:
		_zig_timer = randf_range(0.5, 1.0)
		_zig_side = -_zig_side
	var target: Node3D = nearest_target()
	var away: Vector3 = facing
	if target != null:
		away = -flat_direction_to(target.global_position)
		if flat_distance_to(target.global_position) > 9.0:
			away = away.rotated(Vector3.UP, PI * 0.5 * _zig_side)
	away = away.rotated(Vector3.UP, 0.6 * _zig_side)
	# Que no se quede pegado a una pared: si está cerca del borde, tira para el centro.
	var to_center := Vector3(-global_position.x, 0.0, -global_position.z)
	if absf(global_position.x) > 19.0 or absf(global_position.z) > 11.0:
		away = (away + to_center.normalized() * 1.5).normalized()
	steer(away.normalized(), data.move_speed, delta)


## Suelta la bolsa: oro para cada jugador.
func _drop_gold() -> void:
	if _gone:
		return
	Loot.drop_for_all(get_parent(), global_position, [bag_gold])
	Achievements.unlock("recaudacion")
	Events.floating_text_requested.emit(global_position + Vector3.UP * 3.0, "¡Recuperaron la bolsa!", BAG_COLOR)
	if _label != null:
		_label.visible = false
	robbed.emit()


func _escape() -> void:
	_gone = true
	collision_layer = 0
	health.make_invulnerable(99.0)  # ya no se lo puede tocar
	_label.visible = false
	Events.floating_text_requested.emit(global_position + Vector3.UP * 3.0, "¡Se fue con la plata!",
			Color(0.85, 0.8, 0.95))
	Fx.ring_burst(get_parent(), global_position, 1.6, Color(0.45, 0.2, 0.72), 0.3)
	var tween: Tween = create_tween()
	tween.tween_property(visual, "scale", Vector3(0.05, 1.4, 0.05), 0.35)
	tween.tween_callback(queue_free)
	escaped.emit()


func is_targetable() -> bool:
	return super.is_targetable() and not _gone


func _update_label() -> void:
	if _label != null:
		_label.text = "Cobrador · %d s" % ceili(maxf(time_left, 0.0))


func _build_extras() -> void:
	# Bolsa de oro al hombro (placeholder) y un aro dorado en el piso para encontrarlo rápido.
	var bag := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.38
	sphere.height = 0.7
	bag.mesh = sphere
	bag.position = Vector3(0.0, data.body_height * 0.85, 0.35)
	bag.material_override = Fx.flat_material(BAG_COLOR, 1.2)
	visual.add_child(bag)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.7
	torus.outer_radius = 0.85
	ring.mesh = torus
	ring.position.y = 0.05
	ring.material_override = Fx.flat_material(BAG_COLOR, 1.5)
	add_child(ring)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 44
	_label.outline_size = 12
	_label.modulate = BAG_COLOR
	_label.position.y = data.body_height + 1.0
	add_child(_label)
	_update_label()
