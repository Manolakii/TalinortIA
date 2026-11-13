class_name MimicEvent
extends Node3D
## Evento "Cofres sospechosos" (GDD, Mimics): tres cofres iguales y uno es un mimic.
## Se puede abrir UNO. Si es de verdad: oro, y cuenta como evento perfecto (mejora de 4).
## Si es el mimic: hay que matarlo, y da solo el oro. La pista: respira o tiene marcas de dientes.

## Se resolvió. `perfect`: eligieron bien (mejora "mejorada"); si salió el mimic, solo oro.
signal resolved(perfect: bool)

const MIMIC_SCENE: PackedScene = preload("res://scenes/enemies/mimic.tscn")

var _chests: Array[Chest] = []
var _mimic: Mimic
var _done: bool = false


func setup(spots: Array[Vector3], rng: RandomNumberGenerator) -> void:
	var mimic_index: int = rng.randi_range(0, 2)
	var clue: StringName = &"teeth" if rng.randf() < 0.5 else &"breath"
	for i: int in 3:
		var chest := Chest.new()
		chest.is_mimic = i == mimic_index
		chest.mimic_clue = clue
		chest.gold_table = Balance.economy.event_chest_gold
		chest.position = spots[i]
		add_child(chest)
		chest.opened.connect(_on_opened.bind(chest))
		_chests.append(chest)
	var sign_label := Label3D.new()
	sign_label.text = "Uno de estos cofres muerde.\nAbrí uno solo."
	sign_label.font_size = 44
	sign_label.outline_size = 12
	sign_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign_label.position = (spots[0] + spots[1] + spots[2]) / 3.0 + Vector3.UP * 3.0
	add_child(sign_label)
	var fade: Tween = sign_label.create_tween()
	fade.tween_interval(6.0)
	fade.tween_property(sign_label, "modulate:a", 0.0, 1.0)


func _on_opened(_by: PlayerCharacter, chest: Chest) -> void:
	# Los otros se hunden: se puede abrir uno solo.
	for other: Chest in _chests:
		if other != chest and is_instance_valid(other):
			other.locked = true
			var sink: Tween = other.create_tween()
			sink.tween_property(other, "position:y", -1.5, 0.8)
			sink.tween_callback(other.queue_free)
	if chest.is_mimic:
		_mimic = MIMIC_SCENE.instantiate()
		_mimic.position = chest.position
		add_child(_mimic)
		_mimic.died.connect(_on_mimic_died)
		Events.floating_text_requested.emit(chest.global_position + Vector3.UP * 2.0, "¡Era un mimic!",
				Color(1.0, 0.55, 0.2))
		Events.camera_shake_requested.emit(0.4)
		chest.queue_free()
	else:
		Events.floating_text_requested.emit(chest.global_position + Vector3.UP * 2.0, "¡Bien elegido!",
				Color(1.0, 0.82, 0.3))
		_resolve(true)


func _on_mimic_died(_info: DamageInfo) -> void:
	Loot.drop_for_all(self, _mimic.global_position, Balance.economy.event_chest_gold)
	_resolve(false)


func _resolve(perfect: bool) -> void:
	if _done:
		return
	_done = true
	resolved.emit(perfect)


## Hay un mimic suelto (para saber si se puede perder la sala).
func mimic_alive() -> bool:
	return is_instance_valid(_mimic) and not _mimic.health.is_dead
