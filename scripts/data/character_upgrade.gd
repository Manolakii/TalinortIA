class_name CharacterUpgrade
extends Resource
## Mejora de personaje (GDD, "Mejoras de personaje: elegir 1 de 3"). Es propia de un
## personaje. Si tiene `stat`, suma estadísticas; si no, el kit la reconoce por su id.

@export var id: StringName
@export var character: StringName
@export var display_name: String = ""
@export var description: String = ""
## Opcional: estadística que suma (como los objetos genéricos).
@export var stat: StringName = &""
@export var amount: float = 0.0
## Cuántas veces se puede tomar (las Sendas tienen nivel 1 y 2).
@export var max_stacks: int = 1
## Sendas del dúo: a qué cuerpo y hueco va, y qué Senda es (vacío si no es una Senda).
@export var senda_body: StringName = &""
@export var senda_slot: StringName = &""
@export var senda_path: StringName = &""
