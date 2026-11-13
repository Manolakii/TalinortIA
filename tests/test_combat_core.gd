extends GutTest
## Núcleo de combate: cooldowns con cargas, vida, estados, críticos y búsqueda de objetivos.


# --- AbilityCooldown ---

func test_charges_recharge_one_after_another() -> void:
	var cd := AbilityCooldown.new(4.0, 2)
	assert_true(cd.use())
	assert_true(cd.use())
	assert_false(cd.use(), "Sin cargas no se puede")
	cd.tick(3.9)
	assert_eq(cd.charges, 0)
	cd.tick(0.2)
	assert_eq(cd.charges, 1, "A los 4 s vuelve una carga")
	cd.tick(4.0)
	assert_eq(cd.charges, 2, "A los 8 s, las dos")


func test_time_until_ready_and_reduce() -> void:
	var cd := AbilityCooldown.new(12.0)
	cd.use()
	cd.tick(2.0)
	assert_almost_eq(cd.time_until_ready(), 10.0, 0.001)
	cd.reduce(6.0)
	assert_almost_eq(cd.time_until_ready(), 4.0, 0.001)


# --- HealthComponent ---

func _hit(amount: float) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = amount
	return info


func test_damage_multiplier_and_death() -> void:
	var health := HealthComponent.new()
	add_child_autofree(health)
	health.setup(150.0)
	health.damage_taken_multiplier = 0.7
	var info := _hit(100.0)
	assert_almost_eq(health.apply_damage(info), 70.0, 0.001, "En Furia, 30% menos")
	assert_almost_eq(info.final_amount, 70.0, 0.001)
	watch_signals(health)
	health.apply_damage(_hit(500.0))
	assert_true(health.is_dead)
	assert_eq(health.current, 0.0)
	assert_signal_emitted(health, "died")


func test_invulnerability_runs_out() -> void:
	var health := HealthComponent.new()
	add_child_autofree(health)
	health.make_invulnerable(0.25)
	assert_true(health.is_invulnerable())
	health.tick(0.3)
	assert_false(health.is_invulnerable())


# --- StatusEffects ---

func test_status_keeps_longest_and_expires() -> void:
	var status := StatusEffects.new()
	add_child_autofree(status)
	status.apply(StatusEffects.STUN, 1.0)
	status.apply(StatusEffects.STUN, 0.3)
	assert_almost_eq(status.remaining(StatusEffects.STUN), 1.0, 0.001)
	status.tick(1.01)
	assert_false(status.has(StatusEffects.STUN))


# --- Críticos y sorteos ---

func test_crit_multiplies_damage() -> void:
	var always := Combat.make_hit(null, DamageInfo.Team.PLAYERS, 20.0, 1.0, 1.75)
	assert_true(always.is_crit)
	assert_almost_eq(always.amount, 35.0, 0.001)
	var never := Combat.make_hit(null, DamageInfo.Team.PLAYERS, 20.0, 0.0, 1.75)
	assert_false(never.is_crit)
	assert_eq(never.amount, 20.0)


func test_weighted_pick_respects_weights() -> void:
	Combat.rng.seed = 7
	var counts: Array[int] = [0, 0, 0]
	for i: int in 10000:
		counts[Combat.weighted_pick([45.0, 45.0, 10.0])] += 1
	assert_almost_eq(counts[2] / 10000.0, 0.10, 0.02, "El Gronk sale ~10%")
	assert_almost_eq(counts[0] / 10000.0, 0.45, 0.02)


# --- CombatQuery ---

func _make_target(pos: Vector3) -> Hurtbox:
	var holder := Node3D.new()
	holder.set_script(load("res://tests/helpers/dummy_receiver.gd"))
	add_child_autofree(holder)
	holder.global_position = pos
	var hurtbox := Hurtbox.new()
	hurtbox.team = DamageInfo.Team.ENEMIES
	hurtbox.radius = 0.4
	holder.add_child(hurtbox)
	return hurtbox


func test_sector_only_hits_in_front() -> void:
	var front := _make_target(Vector3(0, 0, -2))
	var behind := _make_target(Vector3(0, 0, 2))
	var side := _make_target(Vector3(2, 0, 0))
	var hits := CombatQuery.in_sector(get_tree(), DamageInfo.Team.ENEMIES, Vector3.ZERO,
			Vector3.FORWARD, 2.5, 120.0)
	assert_true(hits.has(front))
	assert_false(hits.has(behind))
	assert_false(hits.has(side), "90° queda fuera de un abanico de 120°")


func test_line_and_circle() -> void:
	var on_line := _make_target(Vector3(5, 0, 0.8))
	var off_line := _make_target(Vector3(5, 0, 3))
	var line_hits := CombatQuery.in_line(get_tree(), DamageInfo.Team.ENEMIES, Vector3.ZERO,
			Vector3(10, 0, 0), 1.0)
	assert_true(line_hits.has(on_line), "Cuenta el radio del objetivo")
	assert_false(line_hits.has(off_line))
	var circle_hits := CombatQuery.in_circle(get_tree(), DamageInfo.Team.ENEMIES,
			Vector3(5, 0, 3), 0.5)
	assert_eq(circle_hits, [off_line] as Array[Hurtbox])


func test_dead_targets_are_ignored() -> void:
	var target := _make_target(Vector3(0, 0, -1))
	target.receiver.targetable = false
	assert_eq(CombatQuery.in_circle(get_tree(), DamageInfo.Team.ENEMIES, Vector3.ZERO, 5.0).size(), 0)
