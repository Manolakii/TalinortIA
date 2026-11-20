class_name ShadeChests
extends Node3D
## Los dos cofres que deja el Agucci tenebroso: uno es un mimic y el otro tiene un objeto de la
## tienda de Yole para cada jugador. Se abre uno solo (el otro se hunde). Si sale el mimic y lo
## matan, suelta oro de consuelo. Va aparte del Agucci, que se borra al morir.

const MIMIC_SCENE: PackedScene = preload("res://scenes/enemies/mimic.tscn")

var consolation_gold: int = 40
var chests: Array[Chest] = []


func setup(mimic_first: bool) -> void:
	for i: int in 2:
		var chest := Chest.new()
		chest.is_mimic = (i == 0) == mimic_first
		chest.mimic_clue = &""  # acá no hay pistas: es una apuesta
		chest.drops_gold = false
		chest.position = Vector3(-2.0 + i * 4.0, 0.0, 0.0)
		add_child(chest)
		chest.opened.connect(_on_opened.bind(chest))
		chests.append(chest)
	Events.floating_text_requested.emit(global_position + Vector3.UP * 3.2,
			"Dos cofres... uno muerde. Abrí uno solo.", Color(0.8, 0.65, 1.0))


func _on_opened(_by: PlayerCharacter, chest: Chest) -> void:
	for other: Chest in chests:
		if other != chest and is_instance_valid(other):
			other.locked = true
			var sink: Tween = other.create_tween()
			sink.tween_property(other, "position:y", -1.5, 0.8)
			sink.tween_callback(other.queue_free)
	if chest.is_mimic:
		var mimic: Mimic = MIMIC_SCENE.instantiate()
		mimic.position = chest.position
		add_child(mimic)
		var at: Vector3 = chest.global_position
		mimic.died.connect(func(_info: DamageInfo) -> void:
			Loot.drop_for_all(self, at, [consolation_gold])
			Events.floating_text_requested.emit(at + Vector3.UP * 2.5, "Oro de consuelo", Color(1.0, 0.82, 0.3)))
		Events.floating_text_requested.emit(at + Vector3.UP * 2.0, "¡Era un mimic!", Color(1.0, 0.55, 0.2))
		Events.camera_shake_requested.emit(0.4)
		chest.queue_free()
	else:
		give_shop_items(chest.global_position)


## El cofre bueno: un objeto de la tienda de Yole para cada jugador (uno que no tenga).
func give_shop_items(at: Vector3) -> void:
	Achievements.unlock("ojo_clinico")
	var row: int = 0
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var player := node as PlayerCharacter
		if player == null or player.slot == null or player.is_out():
			continue
		var owned: Array = RunState.get_specials(player.slot.index)
		var pool: Array[SpecialItem] = []
		for item: SpecialItem in Balance.shop.items:
			if not owned.has(item.id) and item.rarity != SpecialItem.Rarity.CURSED:
				pool.append(item)
		if pool.is_empty():
			continue
		var item: SpecialItem = pool[RunState.rng.randi_range(0, pool.size() - 1)]
		RunState.add_special(player.slot.index, item.id)
		Events.floating_text_requested.emit(at + Vector3.UP * (2.4 + 0.6 * row),
				"%s: %s" % [player.slot.label, item.display_name], Color(1.0, 0.82, 0.3))
		row += 1
