class_name McoiniaUpgrade
extends Resource
## Una mejora permanente que se compra con McoinIA (GDD). General (para todos) o de Héroe
## (de un personaje: mejora sus habilidades, nunca le cambia la mecánica).

@export var id: StringName
## Vacío = general. Si no, el personaje (tali, croco, agucci, maestro).
@export var character: StringName = &""
@export var display_name: String = ""
## Qué hace por nivel (texto para el menú).
@export var description: String = ""
## Costo de cada nivel (la cantidad de niveles es el largo de esta lista).
@export var costs: Array[int] = [15, 35, 60]
## Cuánto suma por nivel (lo usa cada efecto a su manera).
@export var amount: float = 0.0
## Si suma una estadística como los objetos (crit_chance, lifesteal, max_health...).
@export var stat: StringName = &""


func max_level() -> int:
	return costs.size()
