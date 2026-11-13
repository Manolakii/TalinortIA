extends GutTest
## Zona muerta del stick.


func test_inside_deadzone_is_zero() -> void:
	assert_eq(PlayerInput.apply_radial_deadzone(Vector2(0.1, 0.1), 0.2), Vector2.ZERO)


func test_full_tilt_is_length_one() -> void:
	var v: Vector2 = PlayerInput.apply_radial_deadzone(Vector2(1, 0), 0.2)
	assert_almost_eq(v.length(), 1.0, 0.0001)


func test_rescaled_without_jump() -> void:
	# Justo pasando la zona muerta, el valor arranca cerca de 0, no de 0,2.
	var v: Vector2 = PlayerInput.apply_radial_deadzone(Vector2(0.21, 0), 0.2)
	assert_lt(v.length(), 0.05)


func test_keeps_direction() -> void:
	var v: Vector2 = PlayerInput.apply_radial_deadzone(Vector2(0.5, -0.5), 0.2)
	assert_almost_eq(v.normalized(), Vector2(0.5, -0.5).normalized(), Vector2(0.0001, 0.0001))
