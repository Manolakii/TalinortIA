class_name GronkGigante
extends Enemy
## Boss del 1-4 (GDD, Bosses): un Gronk enorme que la sombra de los Aguccis tiene controlado.
##   Fase 1 (100% a 66%): carga con aviso; contra una columna queda aturdido 3 s y recibe +50%.
##     Pisotón en área si estás cerca y rugido que llama Talinorteanos cegados.
##   Fase 2 (66% a 33%): la sombra toma el control (ojos violetas). Dos cargas seguidas, rocas
##     con aviso y charcos de sombra que ralentizan.
##   Fase 3 (menos de 33%): rompe las columnas. Tres cargas seguidas y onda de sombra en círculo
##     con un hueco para pasar (o se atraviesa con la invulnerabilidad de la esquiva).
## El Llamado Salvaje de Tali lo hace dudar y lo aturde. Al "morir", la sombra se le escapa y
## el Gronk queda libre.
## No lo empujan ni lo aturden los golpes comunes.

signal phase_changed(phase: int)
signal defeated

enum Mode { IDLE, CHARGE_WINDUP, CHARGE, RECOVER, STOMP_WINDUP, ROAR, WAVE_WINDUP }

const CONFIG: BossGronkConfig = preload("res://data/bosses/gronk_gigante.tres")
const CEGADO_SCENE: PackedScene = preload("res://scenes/enemies/talinorteano_cegado.tscn")
const EYE_NORMAL := Color(0.95, 0.85, 0.4)
const EYE_SHADOW := Color(0.6, 0.25, 0.95)

var cfg: BossGronkConfig = CONFIG
var phase: int = 1
var mode: Mode = Mode.IDLE
var _time: float = 0.0
var _charges_left: int = 0
var _charge_direction: Vector3 = Vector3.FORWARD
var _charge_length: float = 0.0
var _traveled: float = 0.0
var _hit: Array[Node] = []
var _vulnerable_time: float = 0.0
var _roar_timer: float = 8.0
var _rocks_timer: float = 3.0
var _wave_timer: float = 4.0
var _wild_call_cooldown: float = 0.0
var _eyes: Array[MeshInstance3D] = []
var _beaten: bool = false
var _stomp_timer: float = 0.0
var _last_flash: int = 0


func _ready() -> void:
	enemy_id = &"gronk_gigante"
	drops_gold = false  # paga el oro del boss al ser derrotado
	if health_multiplier < 0.0:
		health_multiplier = Scaling.current_health_multiplier(true)
	super._ready()
	add_to_group(&"boss")


func is_vulnerable() -> bool:
	return _vulnerable_time > 0.0


func _think(delta: float) -> void:
	_vulnerable_time = maxf(_vulnerable_time - delta, 0.0)
	_wild_call_cooldown = maxf(_wild_call_cooldown - delta, 0.0)
	_roar_timer -= delta
	_rocks_timer -= delta
	_wave_timer -= delta
	_stomp_timer -= delta
	if status.has(StatusEffects.STUN):
		stop(delta)
		return
	_check_phase()
	_time += delta
	var target: Node3D = nearest_target()
	match mode:
		Mode.IDLE:
			if target == null:
				stop(delta)
				return
			steer(flat_direction_to(target.global_position), data.move_speed * speed_multiplier(), delta)
			if _time >= cfg.idle_time * Scaling.current_attack_pace():
				_pick_attack(target)
		Mode.CHARGE_WINDUP:
			stop(delta)
			if _time >= cfg.charge_windup * Scaling.current_windup():
				telegraph.hide_telegraph()
				_hit.clear()
				_traveled = 0.0
				_set_mode(Mode.CHARGE)
		Mode.CHARGE:
			_charge_step(delta)
		Mode.RECOVER:
			stop(delta)
			if _time >= recovery_time():
				_set_mode(Mode.IDLE)
		Mode.STOMP_WINDUP:
			stop(delta)
			if _time >= cfg.stomp_windup * Scaling.current_windup():
				_stomp()
				_set_mode(Mode.RECOVER)
		Mode.ROAR:
			stop(delta)
			if _time >= cfg.phase_roar_time:
				_set_mode(Mode.IDLE)
		Mode.WAVE_WINDUP:
			stop(delta)
			if _time >= cfg.wave_windup * Scaling.current_windup():
				telegraph.hide_telegraph()
				_shadow_wave()
				_set_mode(Mode.RECOVER)


func _pick_attack(target: Node3D) -> void:
	var distance: float = flat_distance_to(target.global_position)
	if phase >= 2 and _rocks_timer <= 0.0:
		_rocks_timer = cfg.rocks_interval
		_throw_rocks()
	if phase == 3 and _wave_timer <= 0.0:
		_wave_timer = cfg.wave_interval
		_set_mode(Mode.WAVE_WINDUP)
		telegraph.rotation.y = 0.0
		telegraph.show_circle(6.0, cfg.wave_windup * Scaling.current_windup())
		Events.floating_text_requested.emit(global_position + Vector3.UP * 5.5, "¡Onda de sombra!", EYE_SHADOW)
		return
	if phase == 1 and _roar_timer <= 0.0 and get_tree().get_nodes_in_group(&"enemies").size() < 4:
		_roar_timer = cfg.roar_interval
		_summon()
		return
	if distance <= cfg.stomp_radius * 0.9 and _stomp_timer <= 0.0:
		_stomp_timer = cfg.stomp_cooldown
		_set_mode(Mode.STOMP_WINDUP)
		telegraph.rotation.y = 0.0
		telegraph.show_circle(cfg.stomp_radius, cfg.stomp_windup * Scaling.current_windup())
		return
	_charges_left = cfg.charges_per_phase[clampi(phase - 1, 0, cfg.charges_per_phase.size() - 1)]
	_start_charge(target)


# --- Carga ---

func _start_charge(target: Node3D) -> void:
	_set_mode(Mode.CHARGE_WINDUP)
	if target != null:
		facing = flat_direction_to(target.global_position)
	_charge_direction = facing
	_charge_length = _distance_to_obstacle(cfg.charge_max_distance)
	telegraph.rotation.y = facing_angle()
	telegraph.show_rect(_charge_length + data.body_radius, cfg.charge_width,
			cfg.charge_windup * Scaling.current_windup())


func _charge_step(_delta: float) -> void:
	var previous: Vector3 = global_position
	move_with_knockback(_charge_direction * cfg.charge_speed * speed_multiplier())
	_traveled += previous.distance_to(global_position)
	_trample(previous, global_position)
	var column: Node = _collided_column()
	if column != null:
		_hit_column()
		return
	if get_slide_collision_count() > 0 and _collided_static():
		status.apply(StatusEffects.STUN, cfg.wall_stun)
		Events.floating_text_requested.emit(global_position + Vector3.UP * 5.0, "¡PUM!", Color.WHITE)
		Events.camera_shake_requested.emit(Balance.combat.shake_heavy * 0.5)
		_charges_left = 0
		_set_mode(Mode.RECOVER)
		return
	if _traveled >= _charge_length or _time > _charge_length / cfg.charge_speed + 0.5:
		_end_charge()


func _end_charge() -> void:
	if phase >= 2:
		_drop_puddle()
	_charges_left -= 1
	if _charges_left > 0:
		_start_charge(nearest_target())
	else:
		_set_mode(Mode.RECOVER)


## GDD: si choca contra una columna queda aturdido 3 s y recibe 50% más de daño.
func _hit_column() -> void:
	_charges_left = 0
	status.apply(StatusEffects.STUN, cfg.column_stun)
	_vulnerable_time = cfg.column_stun
	if phase >= 2:
		_drop_puddle()
	Events.camera_shake_requested.emit(Balance.combat.shake_heavy)
	Events.floating_text_requested.emit(global_position + Vector3.UP * 5.5,
			"¡Se la dio contra la columna! ¡Denle!", Color(1.0, 0.82, 0.3))
	_set_mode(Mode.RECOVER)


func _collided_column() -> Node:
	for i: int in get_slide_collision_count():
		var collider: Object = get_slide_collision(i).get_collider()
		if collider is Node and (collider as Node).is_in_group(&"boss_columns"):
			return collider
	return null


func _collided_static() -> bool:
	for i: int in get_slide_collision_count():
		if get_slide_collision(i).get_collider() is StaticBody3D:
			return true
	return false


## Hasta dónde puede cargar antes de chocar algo (para que el aviso sea honesto).
func _distance_to_obstacle(max_distance: float) -> float:
	var from: Vector3 = global_position + Vector3.UP * 1.2
	var query := PhysicsRayQueryParameters3D.create(from, from + _charge_direction * max_distance, 1 | 512)
	query.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return max_distance
	return maxf(from.distance_to(hit["position"]), 2.0)


func _trample(from: Vector3, to: Vector3) -> void:
	var reach: Vector3 = to + _charge_direction * data.body_radius
	for hurtbox: Hurtbox in CombatQuery.in_line(get_tree(), DamageInfo.Team.PLAYERS, from, reach,
			cfg.charge_width):
		if _hit.has(hurtbox.receiver):
			continue
		_hit.append(hurtbox.receiver)
		var info: DamageInfo = make_attack(cfg.charge_damage / data.damage)
		var closest: Vector3 = Geometry3D.get_closest_point_to_segment(hurtbox.global_position, from, reach)
		info.origin = closest - (hurtbox.global_position - closest).normalized() * 0.1
		info.knockback = 11.0
		info.hitstop = Balance.combat.hitstop_heavy
		info.shake = Balance.combat.shake_heavy * 0.5
		hurtbox.take_hit(info)


# --- Otros ataques ---

func _stomp() -> void:
	telegraph.hide_telegraph()
	var info: DamageInfo = make_attack(cfg.stomp_damage / data.damage)
	info.knockback = 9.0
	info.hitstop = Balance.combat.hitstop_heavy
	Combat.deliver(info, CombatQuery.in_circle(get_tree(), DamageInfo.Team.PLAYERS, global_position,
			cfg.stomp_radius))
	Fx.ring_burst(get_parent(), global_position, cfg.stomp_radius, Color(0.6, 0.5, 0.4), 0.35)
	Events.camera_shake_requested.emit(Balance.combat.shake_heavy * 0.6)


## Ruge y llama Talinorteanos cegados desde los bordes (GDD: 3 o 4).
func _summon() -> void:
	_set_mode(Mode.ROAR)
	Events.floating_text_requested.emit(global_position + Vector3.UP * 5.5, "¡GRRROOOOAAAAR!", Color(1.0, 0.7, 0.5))
	Events.camera_shake_requested.emit(Balance.combat.shake_heavy * 0.6)
	var count: int = cfg.summon_count + (1 if Scaling.players_for_scaling() >= 3 else 0)
	for i: int in count:
		var cegado: Enemy = CEGADO_SCENE.instantiate()
		var angle: float = TAU * i / count + randf() * 0.5
		cegado.position = Vector3(cos(angle) * 19.0, 0, sin(angle) * 11.0)
		cegado.gold_chance = Balance.economy.common_drop_chance / maxf(Scaling.current_count_multiplier(), 1.0)
		get_parent().add_child(cegado)
		Fx.ring_burst(get_parent(), cegado.position, 1.2, Color(0.6, 0.55, 0.65), 0.3)


func _throw_rocks() -> void:
	var spots: Array[Vector3] = []
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var player := node as PlayerCharacter
		if player != null and not player.health.is_dead:
			spots.append(player.global_position + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5)))
	for i: int in 2:
		spots.append(Vector3(randf_range(-18, 18), 0, randf_range(-11, 11)))
	for spot: Vector3 in spots:
		var stone := LobbedStone.new()
		get_parent().add_child(stone)
		var info: DamageInfo = make_attack(cfg.rocks_damage / data.damage)
		info.is_melee = false
		info.knockback = 5.0
		stone.launch(global_position + Vector3.UP * 4.0, spot, cfg.rocks_flight * Scaling.current_windup(),
				cfg.rocks_radius, info)


func _drop_puddle() -> void:
	var puddle := ShadowZone.new()
	puddle.radius = cfg.puddle_radius
	puddle.slow_time = 0.4
	puddle.lifetime = cfg.puddle_duration
	get_parent().add_child(puddle)
	puddle.global_position = Vector3(global_position.x, 0.0, global_position.z)


func _shadow_wave() -> void:
	var wave := ShadowWave.new()
	get_parent().add_child(wave)
	var info: DamageInfo = make_attack(cfg.wave_damage / data.damage)
	info.is_melee = false
	info.knockback = 6.0
	wave.setup(Vector3(global_position.x, 0, global_position.z), randf() * TAU,
			deg_to_rad(cfg.wave_gap_deg), cfg.wave_speed, info)
	Events.camera_shake_requested.emit(Balance.combat.shake_heavy * 0.4)


# --- Fases ---

func _check_phase() -> void:
	var ratio: float = health.ratio()
	if phase == 1 and ratio <= cfg.phase_two_at:
		_enter_phase(2)
	elif phase == 2 and ratio <= cfg.phase_three_at:
		_enter_phase(3)


func _enter_phase(new_phase: int) -> void:
	phase = new_phase
	telegraph.hide_telegraph()
	_charges_left = 0
	_set_mode(Mode.ROAR)
	health.make_invulnerable(cfg.phase_roar_time)
	Events.camera_shake_requested.emit(Balance.combat.shake_heavy)
	Events.room_tint_requested.emit(EYE_SHADOW, 1.6)
	if new_phase == 2:
		for eye: MeshInstance3D in _eyes:
			eye.material_override = Fx.flat_material(EYE_SHADOW, 3.0)
		Events.floating_text_requested.emit(global_position + Vector3.UP * 5.5,
				"¡La sombra toma el control!", EYE_SHADOW)
	else:
		Events.floating_text_requested.emit(global_position + Vector3.UP * 5.5,
				"¡Rompió las columnas!", EYE_SHADOW)
		for column: Node in get_tree().get_nodes_in_group(&"boss_columns"):
			_crumble(column as Node3D)
	phase_changed.emit(new_phase)


func _crumble(column: Node3D) -> void:
	if column == null:
		return
	column.remove_from_group(&"boss_columns")
	if column is StaticBody3D:
		(column as StaticBody3D).collision_layer = 0
	Fx.ring_burst(get_parent(), column.global_position, 2.0, Color(0.6, 0.55, 0.5), 0.4)
	var tween: Tween = column.create_tween()
	tween.tween_property(column, "scale", Vector3(1.3, 0.05, 1.3), 0.5).set_ease(Tween.EASE_IN)
	tween.tween_callback(column.queue_free)


# --- Daño ---

## No lo empujan ni lo aturden los golpes; el Llamado de Tali sí lo hace dudar. Contra una
## columna recibe +50%.
func _modify_incoming(info: DamageInfo) -> void:
	super._modify_incoming(info)
	info.knockback = 0.0
	if info.has_tag(&"wild_call") and _wild_call_cooldown <= 0.0:
		_wild_call_cooldown = cfg.wild_call_cooldown
		info.stun = cfg.wild_call_stun
		Events.floating_text_requested.emit(global_position + Vector3.UP * 5.5,
				"¡El Gronk duda!", Color(0.75, 0.9, 1.0))
	else:
		info.stun = 0.0
	if is_vulnerable():
		info.amount *= cfg.vulnerable_multiplier


## Con varios jugadores pegándole, el destello de cada golpe lo dejaba blanco todo el tiempo:
## el boss destella como mucho cada 0,25 s.
func flash() -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_flash < 250:
		return
	_last_flash = now
	super.flash()


func _on_interrupted() -> void:
	telegraph.hide_telegraph()


## Derrotado: la sombra sale de su cuerpo y se escapa; el Gronk queda libre (GDD).
func _on_died(_info: DamageInfo) -> void:
	if _beaten:
		return
	_beaten = true
	release_attack_slot()
	telegraph.hide_telegraph()
	collision_layer = 0
	remove_from_group(&"enemies")
	Events.enemy_died.emit(self)
	Loot.drop_for_all(get_parent(), global_position, Balance.economy.boss_gold)
	for eye: MeshInstance3D in _eyes:
		eye.material_override = Fx.flat_material(EYE_NORMAL, 2.0)
	Events.floating_text_requested.emit(global_position + Vector3.UP * 6.0,
			"¡La sombra se escapa! El Gronk queda libre", Color(1.0, 0.82, 0.3))
	Events.camera_shake_requested.emit(Balance.combat.shake_heavy)
	# La sombra sube y se va.
	for i: int in 6:
		var wisp := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		wisp.mesh = sphere
		wisp.material_override = Fx.flat_material(EYE_SHADOW, 2.0)
		get_parent().add_child(wisp)
		wisp.global_position = global_position + Vector3(randf_range(-1.5, 1.5), 2.0, randf_range(-1.5, 1.5))
		var tween: Tween = wisp.create_tween()
		tween.tween_property(wisp, "global_position:y", 12.0, 2.0).set_ease(Tween.EASE_IN)
		tween.parallel().tween_property(wisp, "scale", Vector3.ONE * 0.1, 2.0)
		tween.tween_callback(wisp.queue_free)
	# El Gronk, libre, se sienta tranquilo.
	var calm: Tween = create_tween()
	calm.tween_property(visual, "position:y", -0.6, 0.8)
	calm.tween_interval(1.2)
	calm.tween_callback(func() -> void: defeated.emit())


func _set_mode(new_mode: Mode) -> void:
	mode = new_mode
	_time = 0.0


# --- Placeholder: un Gronk enorme en cuatro patas, con cuernos y ojos ---

func _build_extras() -> void:
	var body := visual.get_child(0) as MeshInstance3D
	body.rotation.x = PI * 0.5
	body.position.y = data.body_radius * 1.05
	for side: float in [-1.0, 1.0]:
		var horn := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.4
		cone.height = 1.8
		horn.mesh = cone
		horn.position = Vector3(side * 1.0, data.body_radius * 1.7, -data.body_height * 0.5)
		horn.rotation.x = -0.9
		horn.material_override = Fx.flat_material(Color(0.92, 0.88, 0.8))
		visual.add_child(horn)
		var eye := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.22
		sphere.height = 0.44
		eye.mesh = sphere
		eye.position = Vector3(side * 0.6, data.body_radius * 1.35, -data.body_height * 0.5 - 0.25)
		eye.material_override = Fx.flat_material(EYE_NORMAL, 2.0)
		visual.add_child(eye)
		_eyes.append(eye)
