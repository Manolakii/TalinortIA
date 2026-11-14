class_name Vase
extends StaticBody3D
## Vasija: se rompe de un golpe. A veces trae un honguito que cura (para cualquiera) y, a veces, oro (GDD: 2 a 6 en el Stage 1) solo para
## el jugador que la rompió (pedido del grupo: si no, todos se llenaban de oro).
## Tiene un Hurtbox de "objeto": se le puede pegar, pero el apuntado no la busca.

const CLAY := Color(0.62, 0.36, 0.22)

var _broken: bool = false
var _visual: Node3D
var _hurtbox: Hurtbox


func _ready() -> void:
	collision_layer = 512
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.32
	cylinder.height = 0.9
	shape.shape = cylinder
	shape.position.y = 0.45
	add_child(shape)
	_visual = Node3D.new()
	add_child(_visual)
	var clay := StandardMaterial3D.new()
	clay.albedo_color = CLAY
	clay.roughness = 0.85
	var body := MeshInstance3D.new()
	var belly := SphereMesh.new()
	belly.radius = 0.36
	belly.height = 0.62
	body.mesh = belly
	body.position.y = 0.34
	body.material_override = clay
	_visual.add_child(body)
	var neck := MeshInstance3D.new()
	var tube := CylinderMesh.new()
	tube.top_radius = 0.2
	tube.bottom_radius = 0.15
	tube.height = 0.26
	neck.mesh = tube
	neck.position.y = 0.72
	neck.material_override = clay
	_visual.add_child(neck)
	_hurtbox = Hurtbox.new()
	_hurtbox.team = DamageInfo.Team.ENEMIES
	_hurtbox.radius = 0.4
	_hurtbox.height = 1.0
	_hurtbox.is_prop = true
	add_child(_hurtbox)
	add_to_group(&"breakables")


func is_targetable() -> bool:
	return not _broken


func receive_hit(info: DamageInfo) -> bool:
	if _broken or info.attacker_team != DamageInfo.Team.PLAYERS:
		return false
	smash(_breaker_of(info.attacker))
	return true


## Rompe la vasija. El oro (si tiene) es de `breaker`; sin dueño, del jugador más cercano.
func smash(breaker: PlayerCharacter = null) -> void:
	if _broken:
		return
	_broken = true
	collision_layer = 0
	_hurtbox.queue_free()
	if breaker == null:
		breaker = _nearest_player()
	var economy: EconomyConfig = Balance.economy
	if breaker != null and RunState.rng.randf() < economy.vase_drop_chance:
		Loot.drop(get_parent(), global_position, breaker, Loot.amount_for(economy.vase_gold, RunState.stage))
	if RunState.rng.randf() < economy.vase_mushroom_chance:
		var mushroom := HealMushroom.new()
		mushroom.heal_amount = economy.mushroom_heal
		mushroom.position = position + Vector3(0.6, 0.0, 0.5)
		get_parent().add_child(mushroom)
	Fx.ring_burst(get_parent(), global_position, 0.9, CLAY.lightened(0.2), 0.2)
	# Pedazos que saltan.
	for i: int in 5:
		var shard := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.16, 0.05, 0.12)
		shard.mesh = box
		shard.material_override = Fx.flat_material(CLAY)
		add_child(shard)
		shard.position = Vector3(0, 0.4, 0)
		var angle: float = TAU * i / 5.0
		var out := Vector3(cos(angle), 0.0, sin(angle)) * 0.8
		var tween: Tween = shard.create_tween()
		tween.set_parallel(true)
		tween.tween_property(shard, "position", out + Vector3.UP * 0.05, 0.35).set_ease(Tween.EASE_OUT)
		tween.tween_property(shard, "rotation", Vector3(2.0, angle, 1.0), 0.35)
	_visual.queue_free()
	var cleanup: Tween = create_tween()
	cleanup.tween_interval(1.2)
	cleanup.tween_callback(queue_free)


## Quién la rompió: el jugador, o el dueño del compañero del dúo (o de un señuelo).
func _breaker_of(attacker: Node) -> PlayerCharacter:
	if not is_instance_valid(attacker):
		return null
	if attacker is PlayerCharacter:
		return attacker
	if attacker is DuoCompanion and is_instance_valid(attacker.kit):
		return (attacker.kit as CharacterKit).player
	return null


func _nearest_player() -> PlayerCharacter:
	var best: PlayerCharacter = null
	var best_distance: float = INF
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var player := node as PlayerCharacter
		if player == null or player.is_out():
			continue
		var d: float = player.global_position.distance_to(global_position)
		if d < best_distance:
			best_distance = d
			best = player
	return best
