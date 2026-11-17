class_name HudThemes
## Paneles del HUD con el arte de cada personaje (prueba con los diseños del grupo, 2026-11-17).
## Cada tema tiene retrato, 4 íconos (golpe común, habilidad, esquiva, definitiva) recortados de
## los diseños, y los colores del marco. Tali tiene dos: Normal y Furia (cambia solo).
## Los personajes sin tema (todavía sin arte) usan el panel de siempre.

const DIR := "res://assets/ui/hud/%s/"

const THEMES: Dictionary = {
	"champaka": {"bg": Color(0.22, 0.17, 0.11), "border": Color(0.36, 0.5, 0.24),
			"glow": Color(0.35, 0.95, 0.75, 0.35), "title": Color(0.96, 0.9, 0.78),
			"special": Color(0.5, 0.33, 0.18), "trough": Color(0.12, 0.08, 0.05), "basic": "Aplauso"},
	"pipo": {"bg": Color(0.15, 0.16, 0.17), "border": Color(0.46, 0.42, 0.37),
			"glow": Color(0.3, 0.9, 0.75, 0.25), "title": Color(0.92, 0.9, 0.85),
			"special": Color(0.3, 0.68, 0.58), "trough": Color(0.08, 0.1, 0.1), "basic": "Bláster"},
	"agucci": {"bg": Color(0.08, 0.08, 0.11), "border": Color(0.24, 0.29, 0.52),
			"glow": Color(0.9, 0.08, 0.12, 0.5), "title": Color(0.95, 0.9, 0.82),
			"special": Color(0.62, 0.08, 0.12), "trough": Color(0.1, 0.03, 0.05), "basic": "Katana"},
	"tali": {"bg": Color(0.12, 0.14, 0.17), "border": Color(0.5, 0.38, 0.24),
			"glow": Color(0.0, 0.0, 0.0, 0.0), "title": Color(0.95, 0.9, 0.8),
			"special": Color(0.78, 0.32, 0.12), "trough": Color(0.12, 0.06, 0.04), "basic": "Piedrazo"},
	"tali_furia": {"bg": Color(0.11, 0.09, 0.09), "border": Color(0.5, 0.16, 0.1),
			"glow": Color(0.95, 0.22, 0.1, 0.5), "title": Color(0.98, 0.88, 0.78),
			"special": Color(0.9, 0.22, 0.12), "trough": Color(0.15, 0.04, 0.03), "basic": "Zarpazos"},
}

static var _textures: Dictionary = {}


## Qué tema le toca ahora a este jugador ("" si no tiene arte todavía).
static func state_for(player: PlayerCharacter) -> String:
	var id: String = String(player.data.id)
	if id == "tali" and player.kit is TaliKit and (player.kit as TaliKit).in_fury:
		return "tali_furia"
	return id if THEMES.has(id) and ResourceLoader.exists((DIR % id) + "portrait.png") else ""


static func portrait(state: String) -> Texture2D:
	return _texture(state, "portrait")


static func icon(state: String, index: int) -> Texture2D:
	return _texture(state, "icon_%d" % index)


static func _texture(state: String, file: String) -> Texture2D:
	var path: String = (DIR % state) + file + ".png"
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path]
