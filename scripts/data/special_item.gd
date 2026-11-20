class_name SpecialItem
extends Resource
## Reliquia del Black Market de Yole Sajor (documento del grupo, 2026-11-20). No es un objeto de
## sala: no tiene niveles y se compra una sola vez.
##   Común (75): estadísticas o chances de cosas.
##   Rara (150): juega con habilidades o da una mejora grande a cambio de una desmejora.
##   Legendaria (550): cambia mucho cómo se juega.
##   Maldita: solo sale de la Mystery Box; baja una estadística (como un objeto común Lv 2).
## Los efectos están en SpecialItemEffects; las que solo suman números usan `stat` / `stat2`.

enum Rarity { COMMON, RARE, LEGENDARY, CURSED }

const RARITY_NAMES: Array[String] = ["Común", "Rara", "Legendaria", "Maldita"]
const RARITY_COLORS: Array[Color] = [Color(0.8, 0.8, 0.82), Color(0.45, 0.8, 1.0), Color(1.0, 0.8, 0.3),
		Color(0.85, 0.3, 0.3)]

@export var id: StringName
@export var display_name: String = ""
@export var description: String = ""
@export var rarity: Rarity = Rarity.COMMON
## Estadísticas que suma (o resta, en las malditas y en las de "mejora a cambio de desmejora").
@export var stat: StringName = &""
@export var amount: float = 0.0
@export var stat2: StringName = &""
@export var amount2: float = 0.0
