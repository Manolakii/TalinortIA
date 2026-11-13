class_name EnemySpawner
extends Node3D
## Sala de prueba: mantiene una cantidad de enemigos vivos y los repone cuando mueren.
##
## Atajos: F7 un enemigo más, F8 uno menos, F9 mata a todos (para ver cómo reaparecen).

@export var enemy_scene: PackedScene
@export var target_count: int = 5
@export var respawn_delay: float = 1.5
## Zona donde aparecen (centrada en el nodo), en metros.
@export var spawn_area: Vector2 = Vector2(40.0, 26.0)
@export var min_distance_from_players: float = 8.0

var _cooldown: float = 0.0
## La primera tanda aparece de golpe; después se repone de a uno.
var _filled_once: bool = false


func _physics_process(delta: float) -> void:
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	if _alive_count() < target_count:
		spawn_one()
		_cooldown = respawn_delay if _filled_once else 0.12
	else:
		_filled_once = true


func spawn_one() -> Enemy:
	if enemy_scene == null:
		return null
	var enemy: Enemy = enemy_scene.instantiate()
	enemy.position = _pick_position()
	get_parent().add_child(enemy)
	return enemy


func _alive_count() -> int:
	return get_tree().get_nodes_in_group(&"enemies").size()


func _pick_position() -> Vector3:
	var best := Vector3.ZERO
	var best_distance: float = -1.0
	for attempt: int in 12:
		var candidate := global_position + Vector3(
				randf_range(-0.5, 0.5) * spawn_area.x, 0.0, randf_range(-0.5, 0.5) * spawn_area.y)
		var nearest: float = INF
		for node: Node in get_tree().get_nodes_in_group(&"players"):
			var p := node as Node3D
			nearest = minf(nearest, Vector2(candidate.x - p.global_position.x,
					candidate.z - p.global_position.z).length())
		if nearest >= min_distance_from_players:
			return candidate
		if nearest > best_distance:
			best_distance = nearest
			best = candidate
	return best


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_F7:
			target_count += 1
		KEY_F8:
			target_count = maxi(target_count - 1, 0)
		KEY_F9:
			for node: Node in get_tree().get_nodes_in_group(&"enemies"):
				var enemy := node as Enemy
				var info := DamageInfo.new()
				info.amount = 99999.0
				enemy.health.apply_damage(info)
