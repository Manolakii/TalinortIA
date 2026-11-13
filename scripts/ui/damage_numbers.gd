class_name DamageNumbers
extends Node3D
## Números de daño y textos flotantes, con un pool de Label3D (no se crean nodos por golpe).

const POOL_SIZE := 48
const RISE := 1.1
const LIFETIME := 0.75

const COLOR_ENEMY_HIT := Color(1.0, 1.0, 1.0)
## Cálido pero no dorado (el dorado es del oro) ni amarillo (es de P4).
const COLOR_CRIT := Color(1.0, 0.88, 0.7)
const COLOR_PLAYER_HIT := Color(1.0, 0.55, 0.55)
const COLOR_AVOIDED := Color(0.75, 0.9, 1.0)

var _pool: Array[Label3D] = []
var _tweens: Array[Tween] = []
var _next: int = 0


func _ready() -> void:
	add_to_group(&"damage_numbers")
	for i: int in POOL_SIZE:
		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.fixed_size = true
		label.pixel_size = 0.0011
		label.font_size = 40
		label.outline_size = 14
		label.outline_modulate = Color(0.05, 0.05, 0.08, 0.9)
		label.render_priority = 10
		label.outline_render_priority = 9
		label.visible = false
		add_child(label)
		_pool.append(label)
		_tweens.append(null)
	Events.hit_landed.connect(_on_hit_landed)
	Events.hit_avoided.connect(_on_hit_avoided)
	Events.floating_text_requested.connect(show_text)


func show_text(world_position: Vector3, text: String, color: Color, scale_factor: float = 1.0) -> void:
	var index: int = _next
	var label: Label3D = _pool[index]
	_next = (_next + 1) % POOL_SIZE
	var tween: Tween = _tweens[index]
	if tween != null and tween.is_valid():
		tween.kill()
	label.text = text
	label.modulate = color
	label.outline_modulate.a = 0.9
	label.global_position = world_position + Vector3(randf_range(-0.35, 0.35), 0.0, 0.0)
	label.scale = Vector3.ONE * scale_factor * 1.5
	label.visible = true
	tween = create_tween()
	_tweens[index] = tween
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector3.ONE * scale_factor, 0.12)
	tween.tween_property(label, "global_position:y", world_position.y + RISE, LIFETIME) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, LIFETIME * 0.4).set_delay(LIFETIME * 0.6)
	tween.tween_property(label, "outline_modulate:a", 0.0, LIFETIME * 0.4).set_delay(LIFETIME * 0.6)
	tween.chain().tween_callback(label.hide)


func _on_hit_landed(info: DamageInfo, target: Node3D) -> void:
	var amount: int = roundi(info.final_amount)
	if amount <= 0:
		return
	var above: Vector3 = target.global_position + Vector3.UP * _height_of(target)
	if info.attacker_team == DamageInfo.Team.ENEMIES:
		show_text(above, str(amount), COLOR_PLAYER_HIT, 1.0)
	elif info.is_crit:
		show_text(above, "%d!" % amount, COLOR_CRIT, 1.45)
	else:
		show_text(above, str(amount), COLOR_ENEMY_HIT, 1.0)


func _on_hit_avoided(target: Node3D, text: String) -> void:
	show_text(target.global_position + Vector3.UP * _height_of(target), text, COLOR_AVOIDED, 0.9)


func _height_of(target: Node3D) -> float:
	var combatant := target as Combatant
	if combatant != null and combatant.hurtbox != null:
		return combatant.hurtbox.height + 0.3
	return 2.0
