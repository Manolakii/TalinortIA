class_name Combatant
extends CharacterBody3D
## Base de todo lo que pelea (jugadores y enemigos): vida, estados, hurtbox,
## empuje, hitstop y destello al recibir daño.
##
## Las subclases llaman a setup_combatant() y, en su _physics_process, a combat_tick():
## si devuelve false, están congeladas por hitstop y no hacen nada en ese frame.

signal hit_taken(info: DamageInfo)
signal hit_avoided(info: DamageInfo)
signal died(info: DamageInfo)

var team: DamageInfo.Team = DamageInfo.Team.ENEMIES
var health: HealthComponent
var status: StatusEffects
var hurtbox: Hurtbox
## Empuje recibido; se suma al movimiento y se va frenando solo.
var knockback_velocity: Vector3 = Vector3.ZERO
var hitstop_left: float = 0.0

var _config: CombatConfig
var _flash_materials: Array[StandardMaterial3D] = []
var _flash_tween: Tween
var _jitter_node: Node3D
var _jitter_base: Vector3 = Vector3.ZERO


func setup_combatant(which_team: DamageInfo.Team, max_health: float, radius: float,
		height: float, jitter_node: Node3D) -> void:
	_config = Balance.combat
	team = which_team
	_jitter_node = jitter_node
	if health == null:
		health = HealthComponent.new()
		health.name = "Health"
		add_child(health)
		health.died.connect(_on_health_died)
		status = StatusEffects.new()
		status.name = "Status"
		add_child(status)
		hurtbox = Hurtbox.new()
		hurtbox.name = "Hurtbox"
		hurtbox.team = which_team
		add_child(hurtbox)
	health.setup(max_health)
	hurtbox.radius = radius
	hurtbox.height = height


## Devuelve false si está congelado por hitstop.
func combat_tick(delta: float) -> bool:
	if hitstop_left > 0.0:
		hitstop_left -= delta
		if _jitter_node != null:
			var shake := Vector3(randf_range(-0.06, 0.06), 0.0, randf_range(-0.04, 0.04))
			_jitter_node.position = _jitter_base + (shake if hitstop_left > 0.0 else Vector3.ZERO)
		return false
	health.tick(delta)
	status.tick(delta)
	knockback_velocity = knockback_velocity.lerp(Vector3.ZERO,
			1.0 - exp(-_config.knockback_damping * delta))
	return true


func freeze(seconds: float) -> void:
	if seconds <= 0.0:
		return
	if hitstop_left <= 0.0 and _jitter_node != null:
		_jitter_base = _jitter_node.position
	hitstop_left = maxf(hitstop_left, seconds)


func is_frozen() -> bool:
	return hitstop_left > 0.0


func is_targetable() -> bool:
	return health != null and not health.is_dead


func receive_hit(info: DamageInfo) -> bool:
	if health.is_dead:
		return false
	if health.is_invulnerable():
		_on_blocked_by_invulnerability(info)
		hit_avoided.emit(info)
		return false
	var miss_text: String = _try_avoid(info)
	if miss_text != "":
		Events.hit_avoided.emit(self, miss_text)
		hit_avoided.emit(info)
		return false

	if is_instance_valid(info.attacker) and info.attacker.has_method("outgoing_damage_multiplier"):
		info.amount *= info.attacker.outgoing_damage_multiplier()
	_modify_incoming(info)
	health.apply_damage(info)
	if info.knockback > 0.0:
		knockback_velocity = info.push_direction(global_position) * info.knockback
	if info.stun > 0.0:
		status.apply(StatusEffects.STUN, info.stun)
	freeze(info.hitstop)
	flash()
	if info.shake > 0.0:
		Events.camera_shake_requested.emit(info.shake)
	_after_hit(info)
	hit_taken.emit(info)
	Events.hit_landed.emit(info, self)
	return true


func clear_flash_materials() -> void:
	_flash_materials.clear()


## Las subclases registran acá los materiales que tienen que destellar.
func register_flash_material(material: StandardMaterial3D) -> void:
	material.emission_enabled = true
	material.emission = Color.WHITE
	material.emission_energy_multiplier = 0.0
	_flash_materials.append(material)


func flash() -> void:
	if _flash_materials.is_empty():
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.set_parallel(true)
	for material: StandardMaterial3D in _flash_materials:
		material.emission_energy_multiplier = _config.flash_energy
		_flash_tween.tween_property(material, "emission_energy_multiplier", 0.0,
				_config.flash_duration)


## Velocidad de movimiento más el empuje recibido.
func move_with_knockback(move_velocity: Vector3) -> void:
	velocity = move_velocity + knockback_velocity
	velocity.y = 0.0
	move_and_slide()


# --- Para sobreescribir ---

## Si el golpe se esquiva por algo propio (por ejemplo, la Suerte de Tali),
## devuelve el texto a mostrar. Si no, "".
func _try_avoid(_info: DamageInfo) -> String:
	return ""


## Ajusta un golpe antes de aplicarlo (por ejemplo, el élite Blindado recibe menos de frente).
func _modify_incoming(_info: DamageInfo) -> void:
	pass


## Lo llamó un golpe mientras era invulnerable (por ejemplo, durante la esquiva).
func _on_blocked_by_invulnerability(_info: DamageInfo) -> void:
	pass


func _after_hit(_info: DamageInfo) -> void:
	pass


func _on_health_died(info: DamageInfo) -> void:
	died.emit(info)
