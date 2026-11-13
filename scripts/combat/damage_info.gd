class_name DamageInfo
extends RefCounted
## Un golpe: cuánto pega, de dónde viene y qué efectos tiene.

enum Team { PLAYERS, ENEMIES }

var amount: float = 0.0
var is_crit: bool = false
var attacker: Node3D
var attacker_team: Team = Team.PLAYERS
## Desde dónde viene el golpe (para saber si fue por la espalda y hacia dónde empuja).
var origin: Vector3 = Vector3.ZERO
## Empuje, en m/s.
var knockback: float = 0.0
var stun: float = 0.0
var hitstop: float = 0.0
## Sacudida de cámara que genera este golpe (0 a 1).
var shake: float = 0.0
var is_melee: bool = true
## Etiquetas libres (por ejemplo &"lucky_shot", &"thrown").
var tags: Array[StringName] = []
## Lo que realmente se descontó de vida, después de resistencias. Lo llena HealthComponent.
var final_amount: float = 0.0


func clone() -> DamageInfo:
	var copy := DamageInfo.new()
	copy.amount = amount
	copy.is_crit = is_crit
	copy.attacker = attacker
	copy.attacker_team = attacker_team
	copy.origin = origin
	copy.knockback = knockback
	copy.stun = stun
	copy.hitstop = hitstop
	copy.shake = shake
	copy.is_melee = is_melee
	copy.tags = tags.duplicate()
	return copy


## Dirección horizontal desde el origen del golpe hacia `target`.
func push_direction(target: Vector3) -> Vector3:
	var flat := Vector3(target.x - origin.x, 0.0, target.z - origin.z)
	return flat.normalized() if flat.length_squared() > 0.0001 else Vector3.FORWARD


func has_tag(tag: StringName) -> bool:
	return tags.has(tag)
