class_name CharacterUpgrade
extends Resource
## Mejora de personaje (GDD). Es propia de un personaje y juega con su kit (documento del grupo,
## 2026-11-20: nada de "+10% de daño"). Puede tener niveles (Lv 1 a Lv 3: volver a elegirla la
## sube; cada nivel tiene su valor en `levels`) o ser única (un solo nivel, sin "Lv" en el nombre).
## El kit la reconoce por su id y lee el valor del nivel con upgrade_value().

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
## Solo se compra en la tienda de Yole Sajor (la "Mejora en Birig Bamba" de cada kit).
@export var shop_only: bool = false
## Precio en la tienda de Yole (0 = el precio de siempre de la mejora de kit). Los "kits de
## Yole" transformadores cuestan más (pedido del grupo: que sean más especiales).
@export var price: int = 0
## Valor de cada nivel (si tiene). Su largo es el nivel máximo. La descripción usa {v}.
@export var levels: PackedFloat32Array = PackedFloat32Array()
## Cómo se muestra {v}: "pct" (porcentaje) o "num" (número).
@export var value_format: String = "pct"
## Mejoras que se excluyen entre sí (por ejemplo, las variantes de "Ahora sí te entiendo").
@export var exclusive_group: StringName = &""


func max_level() -> int:
	return levels.size() if not levels.is_empty() else max_stacks


func is_unique() -> bool:
	return max_level() <= 1


func value_at(level: int) -> float:
	return levels[clampi(level, 1, levels.size()) - 1] if not levels.is_empty() else 0.0


## "Piedra que rebota Lv 2" (las únicas, sin "Lv").
func title_at(level: int) -> String:
	return display_name if is_unique() else "%s Lv %d" % [display_name, level]


func describe(level: int) -> String:
	if levels.is_empty():
		return description
	var value: float = value_at(level)
	return description.replace("{v}", GenericItem._pct(value) if value_format == "pct" else GenericItem._num(value))
