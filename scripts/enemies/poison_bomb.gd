class_name PoisonBomb
extends LobbedStone
## Bomba de veneno del Agucci tenebroso: vuela como la piedra del Hondero (con aviso naranja
## donde cae), pega al caer y deja un charco de veneno un rato.

const POISON_COLOR := Color(0.6, 0.85, 0.2)

var zone_radius: float = 2.2
var zone_dps: float = 8.0
var zone_time: float = 4.0


func _land() -> void:
	var at: Vector3 = _to
	var parent: Node = get_parent()
	super._land()
	if parent == null:
		return
	var zone := ShadowZone.new()
	zone.radius = zone_radius
	zone.dps = zone_dps
	zone.lifetime = zone_time
	zone.tint = POISON_COLOR
	parent.add_child(zone)
	zone.global_position = at
