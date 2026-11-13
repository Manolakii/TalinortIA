class_name PrisonerEvent
extends Node3D
## Evento "Colonia de presos" (GDD): jaulas con Talinorteanos conscientes mientras los Aguccis
## atacan. Hay un tiempo límite para liberarlos (pedido del grupo: que sea difícil); los que
## sigan en la jaula cuando se acaba se los llevan. Cada preso liberado da oro, y si se salva
## a todos es "perfecto" (mejora de 4 y un objeto extra). Al terminar la pelea, cofre de evento.

## Se abrió el cofre de evento. `all_saved`: salvaron a todos (objeto extra).
signal resolved(all_saved: bool)

var _cages: Array[PrisonerCage] = []
var _saved: int = 0
var _chest_spot: Vector3
var _gold: int = 6
var _time_left: float = 35.0
var _timer_label: Label
var _timer_over: bool = false


func setup(spots: Array[Vector3], count: int, open_time: float, gold: int, chest_spot: Vector3,
		time_limit: float = 35.0) -> void:
	_chest_spot = chest_spot
	_gold = gold
	_time_left = time_limit
	var layer := CanvasLayer.new()
	layer.layer = 31
	add_child(layer)
	_timer_label = Label.new()
	_timer_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_timer_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_timer_label.offset_top = 92.0
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.add_theme_font_size_override("font_size", 34)
	_timer_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_timer_label.add_theme_constant_override("outline_size", 10)
	layer.add_child(_timer_label)
	for i: int in mini(count, spots.size()):
		var cage := PrisonerCage.new()
		cage.open_time = open_time
		cage.position = spots[i]
		add_child(cage)
		cage.freed.connect(_on_freed.bind(cage))
		_cages.append(cage)
	var title := Label3D.new()
	title.text = "¡Liberá a los presos antes de que se los lleven!"
	title.font_size = 42
	title.outline_size = 12
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.position = Vector3(0, 4.0, 0)
	add_child(title)
	var fade: Tween = title.create_tween()
	fade.tween_interval(6.0)
	fade.tween_property(title, "modulate:a", 0.0, 1.0)


func _physics_process(delta: float) -> void:
	if _timer_over:
		return
	_time_left -= delta
	var left: int = 0
	for cage: PrisonerCage in _cages:
		if is_instance_valid(cage) and not cage.is_free and not cage.is_lost:
			left += 1
	if left == 0:
		_timer_over = true
		_timer_label.text = "¡Liberaron a todos!"
		_timer_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3))
		_hide_timer_later()
		return
	_timer_label.text = "Presos: %d · ¡Quedan %d s!" % [left, ceili(maxf(_time_left, 0.0))]
	_timer_label.add_theme_color_override("font_color",
			Color(1.0, 0.45, 0.3) if _time_left < 10.0 else Color.WHITE)
	if _time_left <= 0.0:
		_timer_over = true
		_lose_remaining()
		_timer_label.text = "Se acabó el tiempo: se llevaron a %d" % left
		_hide_timer_later()


func _lose_remaining() -> void:
	for cage: PrisonerCage in _cages:
		if is_instance_valid(cage):
			cage.lose()


func _hide_timer_later() -> void:
	var tween: Tween = create_tween()
	tween.tween_interval(3.0)
	tween.tween_property(_timer_label, "modulate:a", 0.0, 0.5)


func _on_freed(cage: PrisonerCage) -> void:
	_saved += 1
	Loot.drop_for_all(self, cage.global_position, [_gold])


## Terminó la pelea: los que quedan se pierden y aparece el cofre de evento.
func finish_combat() -> void:
	_timer_over = true
	_lose_remaining()
	_timer_label.modulate.a = 0.0
	var all_saved: bool = saved_count() == _cages.size()
	var text: String = "¡Salvaron a todos!" if all_saved else "Salvaron a %d de %d" % [saved_count(), _cages.size()]
	Events.floating_text_requested.emit(_chest_spot + Vector3.UP * 3.0, text, Color(1.0, 0.82, 0.3))
	var chest := Chest.new()
	chest.gold_table = Balance.economy.event_chest_gold
	chest.position = _chest_spot
	add_child(chest)
	chest.opened.connect(func(_by: PlayerCharacter) -> void: resolved.emit(all_saved))


func saved_count() -> int:
	return _saved
