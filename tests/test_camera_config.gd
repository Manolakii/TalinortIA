extends GutTest
## La distancia de la cámara tiene que dar personajes de ~75 px a 1080p.


func test_character_projects_to_target_pixels() -> void:
	var config: CameraConfig = Balance.camera
	var distance: float = config.get_base_distance()
	var visible_height_m: float = 2.0 * distance * tan(deg_to_rad(config.fov_degrees) * 0.5)
	var projected_m: float = config.character_height_m * cos(deg_to_rad(config.pitch_degrees))
	var px: float = projected_m / visible_height_m * config.reference_viewport_height
	assert_almost_eq(px, config.target_character_px, 0.01)


func test_max_zoom_out_keeps_characters_above_64px() -> void:
	var config: CameraConfig = Balance.camera
	assert_gte(config.target_character_px / config.max_zoom_out, 64.0)


func test_distance_override() -> void:
	var config := CameraConfig.new()
	config.distance_override = 30.0
	assert_eq(config.get_base_distance(), 30.0)
