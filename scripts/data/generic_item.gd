class_name GenericItem
extends Resource
## Objeto de sala (pedido del grupo, 2026-11-20: rarezas y niveles). Se consigue en las
## elecciones de las salas. Cada objeto tiene una rareza y sube de nivel cuando lo volvés a
## elegir: el nivel nuevo REEMPLAZA al anterior (no se suman). Comunes y raros llegan a Lv 3,
## épicos y legendarios a Lv 2. Con el nivel máximo, ya no aparece más.
## (2026-11-20, pedido del grupo: vuelve la rareza Épico, entre Raro y Legendario.)
## Si `effect` está vacío suma la estadística `stat`; si no, ItemEffects hace algo.

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

const RARITY_NAMES: Array[String] = ["Común", "Raro", "Épico", "Legendario"]
## Colores del texto de cada rareza (gris, celeste, lila y dorado), legibles sobre fondo oscuro.
## El lila del Épico es solo de interfaz (el violeta en el mundo sigue siendo la sombra).
const RARITY_COLORS: Array[Color] = [Color(0.78, 0.78, 0.8), Color(0.45, 0.8, 1.0),
		Color(0.85, 0.55, 1.0), Color(1.0, 0.8, 0.3)]

## Estadísticas posibles (las mismas que suma StatModifiers).
const STATS: Array[StringName] = [&"damage", &"attack_speed", &"max_health", &"crit_chance",
		&"crit_damage", &"move_speed", &"cooldown_reduction", &"ult_charge", &"heal_per_wave",
		&"damage_reduction", &"gold", &"lifesteal", &"ability_damage", &"evasion"]

@export var id: StringName
@export var display_name: String = ""
## Texto con marcas que se completan según el nivel: {v} el valor, {c} la chance, {x} el extra.
@export var description: String = ""
@export var rarity: Rarity = Rarity.COMMON
@export var stat: StringName = &""
## Valor de cada nivel (Lv 1, Lv 2, Lv 3). Porcentajes como fracción; vida y curación en puntos.
## El largo dice el nivel máximo.
@export var levels: PackedFloat32Array = PackedFloat32Array([0.05, 0.1, 0.15])
## Objetos con efecto (ItemEffects): si no está vacío, no suma una estadística.
@export var effect: StringName = &""
## Chance por nivel (si el efecto la usa). Vacío = sin chance.
@export var level_chances: PackedFloat32Array = PackedFloat32Array()
## Número extra por nivel (saltos, radio, segundos...). Vacío = sin extra.
@export var level_extras: PackedFloat32Array = PackedFloat32Array()
## Cómo se muestra {v}: "pct" (porcentaje) o "num" (número).
@export var value_format: String = "pct"
## Ícono placeholder (hasta que haya arte): color de fondo y una o dos letras.
@export var icon_color: Color = Color(0.5, 0.5, 0.55)
@export var icon_text: String = ""


func max_level() -> int:
	return levels.size()


func value_at(level: int) -> float:
	return levels[clampi(level, 1, levels.size()) - 1] if not levels.is_empty() else 0.0


func chance_at(level: int) -> float:
	return level_chances[clampi(level, 1, level_chances.size()) - 1] if not level_chances.is_empty() else 0.0


func extra_at(level: int) -> float:
	return level_extras[clampi(level, 1, level_extras.size()) - 1] if not level_extras.is_empty() else 0.0


## "Cuerno de Gronk Lv 2".
func title_at(level: int) -> String:
	return "%s Lv %d" % [display_name, level]


## La descripción con los números de ese nivel.
func describe(level: int) -> String:
	var value: float = value_at(level)
	var shown: String = _pct(value) if value_format == "pct" else _num(value)
	return description.replace("{v}", shown).replace("{c}", _pct(chance_at(level))) \
			.replace("{x}", _num(extra_at(level)))


static func _pct(value: float) -> String:
	return _num(value * 100.0) + "%"


static func _num(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(roundi(value))
	return ("%.1f" % value).replace(".", ",")
