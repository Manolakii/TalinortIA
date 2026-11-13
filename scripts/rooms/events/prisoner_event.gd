class_name PrisonerEvent
extends Node3D
## Evento "Colonia de presos" (GDD): jaulas con Talinorteanos conscientes mientras los Aguccis
## atacan. Cada preso liberado da oro, y si se salva a todos, un objeto extra. Los que sigan
## en la jaula cuando termina la pelea se los llevan. Al final aparece el cofre de evento.

## Se abrió el cofre de evento. `all_saved`: salvaron a todos (objeto extra).
signal resolved(all_saved: bool)

var _cages: Array[PrisonerCage] = []
var _saved: int = 0
var _chest_spot: Vector3
var _gold: int = 6


func setup(spots: Array[Vector3], count: int, open_time: float, gold: int, chest_spot: Vector3) -> void:
	_chest_spot = chest_spot
	_gold = gold
	for i: int in mini(count, spots.size()):
		var cage := PrisonerCage.new()
		cage.open_time = open_time
		cage.position = spots[i]
		add_child(cage)
		cage.freed.connect(_on_freed.bind(cage))
		_cages.append(cage)
	var title := Label3D.new()
	title.text = "¡Liberá a los presos antes de que se los lleven!\n(mantené E / X al lado de la jaula)"
	title.font_size = 42
	title.outline_size = 12
	title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	title.position = Vector3(0, 4.0, 0)
	add_child(title)
	var fade: Tween = title.create_tween()
	fade.tween_interval(6.0)
	fade.tween_property(title, "modulate:a", 0.0, 1.0)


func _on_freed(cage: PrisonerCage) -> void:
	_saved += 1
	Loot.drop_for_all(self, cage.global_position, [_gold])


## Terminó la pelea: los que quedan se pierden y aparece el cofre de evento.
func finish_combat() -> void:
	for cage: PrisonerCage in _cages:
		if is_instance_valid(cage):
			cage.lose()
	var all_saved: bool = saved_count() == _cages.size()
	var text: String = "¡Salvaron a todos!" if all_saved else "Salvaron a %d de %d" % [saved_count(), _cages.size()]
	Events.floating_text_requested.emit(_chest_spot + Vector3.UP * 3.0, text, Color(1.0, 0.82, 0.3))
	var chest := Chest.new()
	chest.position = _chest_spot
	add_child(chest)
	chest.opened.connect(func(_by: PlayerCharacter) -> void: resolved.emit(all_saved))


func saved_count() -> int:
	return _saved
