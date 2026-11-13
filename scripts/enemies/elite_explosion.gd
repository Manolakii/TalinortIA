class_name EliteExplosion
extends Node3D
## Élite Explosivo: al morir, aviso naranja y explosión.

var _radius: float = 3.0
var _delay: float = 0.8
var _damage: float = 20.0
var _time: float = 0.0
var _telegraph: Telegraph
var _done: bool = false


func setup(radius: float, delay: float, damage: float) -> void:
	_radius = radius
	_delay = delay
	_damage = damage
	_telegraph = Telegraph.new()
	add_child(_telegraph)
	_telegraph.show_circle(radius, delay)


func _physics_process(delta: float) -> void:
	if _done:
		return
	_time += delta
	if _time < _delay:
		return
	_done = true
	set_physics_process(false)
	var info := DamageInfo.new()
	info.amount = _damage
	info.attacker_team = DamageInfo.Team.ENEMIES
	info.origin = global_position
	info.knockback = 7.0
	info.shake = Balance.combat.shake_heavy * 0.5
	Combat.deliver(info, CombatQuery.in_circle(get_tree(), DamageInfo.Team.PLAYERS,
			global_position, _radius))
	Fx.ring_burst(get_parent(), global_position, _radius, Color(1.0, 0.9, 0.8), 0.35)
	queue_free()
