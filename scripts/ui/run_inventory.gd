class_name RunInventory
extends RefCounted
## Lo que juntó un jugador en la partida, listo para mostrar (la tabla de Tab / Back y la pantalla
## de estadísticas del final). Cada entrada es un Dictionary:
##   title (con el nivel), tag (tipo y rareza), color (de la rareza), description,
##   icon_color, letters, badge ("Lv2" o ""), border.

const UPGRADE_COLOR := Color(0.85, 0.65, 0.3)
const UPGRADE_TAG_COLOR := Color(0.95, 0.75, 0.45)


## Objetos de sala, con su nivel (el nivel nuevo reemplaza al anterior).
static func items(index: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var counted: Dictionary = _count(RunState.get_items(index))
	for id: Variant in counted:
		var item: GenericItem = Balance.generic_items.get_item(id)
		if item == null:
			continue
		var level: int = mini(counted[id], item.max_level())
		var color: Color = GenericItem.RARITY_COLORS[item.rarity]
		result.append({"title": item.title_at(level),
				"tag": "Objeto %s" % GenericItem.RARITY_NAMES[item.rarity].to_lower(),
				"color": color, "description": item.describe(level),
				"icon_color": item.icon_color,
				"letters": item.icon_text if item.icon_text != "" else ItemIcon.letters_of(item.display_name),
				"badge": "Lv%d" % level, "border": color})
	return result


## Reliquias del Black Market: las generales y las de su personaje (que se guardan como mejoras
## de tienda).
static func relics(index: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: Variant in RunState.get_specials(index):
		var relic: SpecialItem = Balance.shop.get_item(id)
		if relic == null:
			continue
		var color: Color = SpecialItem.RARITY_COLORS[relic.rarity]
		result.append({"title": relic.display_name,
				"tag": "Reliquia %s" % SpecialItem.RARITY_NAMES[relic.rarity].to_lower(),
				"color": color, "description": relic.description, "icon_color": color.darkened(0.45),
				"letters": ItemIcon.letters_of(relic.display_name), "badge": "", "border": color})
	for id: Variant in _count(RunState.get_upgrades(index)):
		var upgrade: CharacterUpgrade = Balance.upgrades.get_upgrade(id)
		if upgrade == null or not upgrade.shop_only:
			continue
		var legendary: bool = upgrade.price > 0
		var rarity: int = SpecialItem.Rarity.LEGENDARY if legendary else SpecialItem.Rarity.RARE
		var color: Color = SpecialItem.RARITY_COLORS[rarity]
		result.append({"title": upgrade.display_name,
				"tag": "Reliquia %s de tu personaje" % ("legendaria" if legendary else "rara"),
				"color": color, "description": upgrade.description, "icon_color": color.darkened(0.45),
				"letters": ItemIcon.letters_of(upgrade.display_name), "badge": "", "border": color})
	return result


## Mejoras de personaje (las de las elecciones), con su nivel si tienen.
static func upgrades(index: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var counted: Dictionary = _count(RunState.get_upgrades(index))
	for id: Variant in counted:
		var upgrade: CharacterUpgrade = Balance.upgrades.get_upgrade(id)
		if upgrade == null or upgrade.shop_only:
			continue
		var level: int = mini(counted[id], upgrade.max_level())
		result.append({"title": upgrade.title_at(level),
				"tag": "Mejora única" if upgrade.is_unique() else "Mejora",
				"color": UPGRADE_TAG_COLOR, "description": upgrade.describe(level),
				"icon_color": UPGRADE_COLOR.darkened(0.2),
				"letters": ItemIcon.letters_of(upgrade.display_name),
				"badge": "" if upgrade.is_unique() else "Lv%d" % level, "border": Color(0, 0, 0, 0.6)})
	return result


static func icon_for(entry: Dictionary) -> ItemIcon:
	var icon: ItemIcon = ItemIcon.make(entry["icon_color"], entry["letters"],
			"%s [%s]" % [entry["title"], entry["tag"]], entry["description"], 1, entry["border"])
	icon.badge = entry["badge"]
	return icon


static func _count(ids: Array) -> Dictionary:
	var counted: Dictionary = {}
	for id: Variant in ids:
		counted[id] = counted.get(id, 0) + 1
	return counted
