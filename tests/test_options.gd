extends GutTest
## Menú de Opciones: cambia volúmenes, sacudida y demás, y lo aplica.

var _saved: Dictionary = {}


func before_each() -> void:
	# Que el test no le cambie las opciones de verdad a nadie.
	_saved = {"master": GameSettings.master_volume, "music": GameSettings.music_volume,
			"sfx": GameSettings.sfx_volume, "shake": GameSettings.shake_scale,
			"numbers": GameSettings.damage_numbers, "vibration": GameSettings.vibration}


func after_each() -> void:
	GameSettings.master_volume = _saved["master"]
	GameSettings.music_volume = _saved["music"]
	GameSettings.sfx_volume = _saved["sfx"]
	GameSettings.shake_scale = _saved["shake"]
	GameSettings.damage_numbers = _saved["numbers"]
	GameSettings.vibration = _saved["vibration"]
	GameSettings.apply_audio()
	GameSettings.save_options()


func test_music_volume_goes_to_its_bus() -> void:
	var menu := OptionsMenu.new()
	add_child_autofree(menu)
	GameSettings.music_volume = 0.5
	menu.selected = 1
	menu.change(-1)
	assert_almost_eq(GameSettings.music_volume, 0.4, 0.001)
	var bus: int = AudioServer.get_bus_index("Music")
	assert_gte(bus, 0, "Existe el bus de música")
	assert_almost_eq(AudioServer.get_bus_volume_db(bus), linear_to_db(0.4), 0.01)


func test_toggles_and_shake() -> void:
	var menu := OptionsMenu.new()
	add_child_autofree(menu)
	GameSettings.shake_scale = 1.0
	menu.selected = 5
	menu.change(-1)
	assert_almost_eq(GameSettings.shake_scale, 0.75, 0.001)
	var numbers: bool = GameSettings.damage_numbers
	menu.selected = 6
	menu.change(1)
	assert_ne(GameSettings.damage_numbers, numbers)
