class_name PlayerCharacter
extends Combatant
## Personaje controlado por un jugador. Por ahora es un placeholder: cápsula del color
## del jugador, contorno finito, aro bajo los pies y una "nariz" que marca hacia dónde apunta.
##
## El movimiento, la esquiva y los estados viven acá; qué hace cada botón lo decide
## el kit del personaje (CharacterKit).
##
## Convención de ejes: la cámara mira al norte (-Z). Arriba en pantalla = -Z, derecha = +X.

const OUTLINE_SHADER: Shader = preload("res://assets/shaders/outline.gdshader")
const RING_SHADER: Shader = preload("res://assets/shaders/player_ring.gdshader")
## El aro mide esto veces el radio del personaje.
const RING_SCALE := 3.4
## Botones que se guardan un ratito si no se pueden usar justo (buffer de input).
const BUFFERED_ACTIONS: Array[PlayerInput.Action] = [
	PlayerInput.Action.DODGE, PlayerInput.Action.ABILITY,
	PlayerInput.Action.ULTIMATE, PlayerInput.Action.RELAY,
]
## Modo prueba: tiempo hasta levantarse solo (hasta que exista revivir, Fase 4).
const TEST_MODE_REVIVE_DELAY := 1.5

## Efectos de los objetos especiales de Yole Sajor.
var specials: SpecialItemEffects
var item_effects: ItemEffects
## Eligiendo en un menú (mejora u objeto): no se mueve ni ataca.
var menu_locked: bool = false
## En Birig Bamba no se pelea (LORE, Pacto del Bombo): camina, pero no ataca ni usa habilidades.
var peaceful: bool = false
var slot: PlayerSlot
var data: CharacterData
var kit: CharacterKit
var revive: ReviveComponent
## Lo que suman objetos y mejoras (StatModifiers).
var modifiers := StatModifiers.new()
## Dirección horizontal (normalizada) hacia donde apunta.
var aim_direction: Vector3 = Vector3.FORWARD
## Punto del piso al que apunta (con mouse es el cursor; con joystick, unos metros adelante).
var aim_point: Vector3 = Vector3.ZERO
## La pone la sala: recibe (posición, velocidad, delta) y devuelve la velocidad permitida.
## La usa la cámara compartida para frenar a los jugadores en el borde del cuadro.
var velocity_limiter: Callable
## Si no es null, la acción en curso mueve al personaje a esta velocidad (saltos, cargas).
var action_velocity: Variant = null
## Si no es null, reemplaza al stick/WASD (por ejemplo, la Posesión de Agucci camina sola).
var move_override: Variant = null
## Los enemigos no lo ven (Noche del Valle sin Luz de Agucci, mientras no ataque).
var hidden_from_enemies: bool = false

var _move_velocity: Vector3 = Vector3.ZERO
var _buffer: Dictionary[int, float] = {}
var _dodge_direction: Vector3 = Vector3.FORWARD
var _dodge_speed: float = 0.0
var _dodge_time: float = 0.0
var _action_time: float = 0.0
var _action_move_multiplier: float = 1.0
var _body_material: StandardMaterial3D

@onready var visual: Node3D = $Visual
@onready var _body: MeshInstance3D = $Visual/Body
@onready var _nose: MeshInstance3D = $Visual/Nose
@onready var _ring: MeshInstance3D = $Ring
@onready var _collision: CollisionShape3D = $CollisionShape3D
@onready var state_machine: StateMachine = $StateMachine


## Hay que llamarlo antes de agregarlo al árbol, o justo después.
func setup(player_slot: PlayerSlot) -> void:
	slot = player_slot
	data = player_slot.character
	name = "Player%d_%s" % [slot.index + 1, data.id]
	if is_node_ready():
		_build()


func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	add_to_group(&"players")
	add_to_group(&"enemy_targets")
	if slot != null:
		_build()
	state_machine.start(self)


func _build() -> void:
	_build_placeholder()
	setup_combatant(DamageInfo.Team.PLAYERS, data.max_health, data.placeholder_radius,
			data.placeholder_height, visual)
	register_flash_material(_body_material)
	if not died.is_connected(_on_died):
		died.connect(_on_died)
		Events.hit_landed.connect(_on_any_hit_landed)
		Events.loadout_changed.connect(_on_loadout_changed)
		Events.wave_cleared.connect(_on_wave_cleared)
	_create_kit()
	rebuild_modifiers()
	if revive == null:
		revive = ReviveComponent.new()
		revive.name = "Revive"
		add_child(revive)
		revive.setup(self)
		specials = SpecialItemEffects.new()
		specials.name = "Specials"
		add_child(specials)
		specials.setup(self)
		item_effects = ItemEffects.new()
		item_effects.name = "ItemEffects"
		add_child(item_effects)
		item_effects.setup(self)


func _create_kit() -> void:
	if kit != null:
		kit.queue_free()
	var script: Script = data.kit_script if data.kit_script != null else CharacterKit
	kit = script.new() as CharacterKit
	kit.name = "Kit"
	add_child(kit)
	kit.setup(self)


func _physics_process(delta: float) -> void:
	if slot == null:
		return
	_update_buffer(delta)
	if not combat_tick(delta):
		return
	_update_aim(delta)
	kit.tick(delta)
	if health.is_dead:
		if revive.downed or revive.out:
			revive.downed_tick(delta)
		else:
			apply_movement(Vector2.ZERO, delta)
		return
	if status.has(StatusEffects.STUN):
		apply_movement(Vector2.ZERO, delta)
		return
	# Levantando a un compañero: no se mueve ni ataca, y no lo empujan.
	if revive.reviver_tick(delta):
		knockback_velocity = Vector3.ZERO
		apply_movement(Vector2.ZERO, delta)
		face_aim_now()
		return
	# Eligiendo una mejora u objeto: no se mueve ni ataca.
	if menu_locked:
		_buffer.clear()
		apply_movement(Vector2.ZERO, delta)
		return
	if peaceful:
		_buffer.clear()
		state_machine.physics_update(delta)
		return
	kit.handle_input()
	state_machine.physics_update(delta)


# --- Movimiento ---

## Acelera hacia la dirección pedida (x derecha, y abajo en pantalla) y mueve el cuerpo.
func apply_movement(move: Vector2, delta: float, speed_multiplier: float = 1.0) -> void:
	var speed: float = data.move_speed * speed_multiplier
	if kit != null:
		speed *= kit.move_speed_multiplier()
	if status.has(StatusEffects.HASTE):
		speed *= Balance.combat.haste_multiplier
	if status.has(StatusEffects.SLOW):
		speed *= Balance.combat.slow_multiplier
	if status.has(StatusEffects.BOMBITO):
		speed *= 1.15
	if status.has(StatusEffects.MAILMAN):
		speed *= 1.4
	speed *= modifiers.move_speed_multiplier()
	# Energético de Fadied (objeto): más rápido cuando no hay pelea.
	var energy: int = item_stacks(&"calm_speed")
	if energy > 0 and get_tree().get_nodes_in_group(&"enemies").is_empty():
		speed *= 1.0 + ItemEffects.item_for(&"calm_speed").value_at(energy)
	var target := Vector3(move.x, 0.0, move.y) * speed
	var rate: float = data.acceleration if move != Vector2.ZERO else data.deceleration
	_move_velocity = _move_velocity.move_toward(target, rate * delta)
	_move_with(_move_velocity, delta)


## Movimiento directo (esquivas, cargas, saltos), sin aceleración.
func move_raw(raw_velocity: Vector3, delta: float) -> void:
	_move_velocity = raw_velocity
	_move_with(raw_velocity, delta)


func _move_with(move_velocity: Vector3, delta: float) -> void:
	var total: Vector3 = move_velocity + knockback_velocity
	total.y = 0.0
	if velocity_limiter.is_valid():
		total = velocity_limiter.call(global_position, total, delta)
	velocity = total
	move_and_slide()


## Lo que pide el jugador para moverse (o lo que impone el kit).
func get_move_input() -> Vector2:
	return move_override as Vector2 if move_override != null else slot.input.move


## Para los enemigos: ¿lo pueden elegir como objetivo?
func can_be_targeted_by_enemies() -> bool:
	return is_targetable() and not hidden_from_enemies and not status.has(StatusEffects.HIDDEN)


## Multiplicador de distancia para elegir objetivo (los señuelos usan menos de 1: atraen más).
func target_priority() -> float:
	return kit.target_priority() if kit != null else 1.0


# --- Esquiva y acciones (las usan los kits) ---

func start_dodge(direction: Vector3, distance: float, duration: float) -> void:
	_dodge_direction = direction.normalized() if direction != Vector3.ZERO else aim_direction
	_dodge_time = duration
	_dodge_speed = distance / maxf(duration, 0.01)
	health.make_invulnerable(Balance.combat.dodge_invulnerability)
	Sound.play("dodge", -6.0)
	Events.dodged.emit(self)
	action_velocity = null
	_action_time = 0.0
	state_machine.transition_to(&"Dodge")


func is_dodging() -> bool:
	return state_machine.current_name() == &"Dodge"


## Una acción (ataque, habilidad) que dura `duration`. Mientras tanto se mueve más lento.
func start_action(duration: float, move_multiplier: float = 0.5) -> void:
	_action_time = maxf(_action_time, duration)
	_action_move_multiplier = move_multiplier
	if state_machine.current_name() != &"Action":
		state_machine.transition_to(&"Action")


func is_in_action() -> bool:
	return state_machine.current_name() == &"Action"


## Puede empezar algo nuevo (no está esquivando ni en medio de una acción).
func can_act() -> bool:
	return not is_dodging() and not is_in_action() and not health.is_dead


## Usado por los estados Dodge y Action.
func dodge_step(delta: float) -> bool:
	move_raw(_dodge_direction * _dodge_speed, delta)
	_dodge_time -= delta
	if _dodge_time <= 0.0:
		_stop_dash_momentum()
		return false
	return true


func action_step(delta: float) -> bool:
	if action_velocity != null:
		move_raw(action_velocity as Vector3, delta)
	else:
		apply_movement(get_move_input(), delta, _action_move_multiplier)
	_action_time -= delta
	if _action_time <= 0.0:
		if action_velocity != null:
			_stop_dash_momentum()
		action_velocity = null
		return false
	return true


## Al terminar un movimiento rápido (esquiva, dash, salto), la velocidad queda como mucho
## en la de caminar. Si no, el personaje seguía patinando varios metros (bug del Paso de Sombra).
func _stop_dash_momentum() -> void:
	_move_velocity = _move_velocity.limit_length(data.move_speed)


func end_action() -> void:
	if action_velocity != null:
		_stop_dash_momentum()
	_action_time = 0.0
	action_velocity = null


# --- Buffer de input ---

func _update_buffer(delta: float) -> void:
	for action: int in _buffer.keys():
		_buffer[action] -= delta
		if _buffer[action] <= 0.0:
			_buffer.erase(action)
	for action: PlayerInput.Action in BUFFERED_ACTIONS:
		if slot.input.just_pressed(action):
			_buffer[action] = Balance.combat.input_buffer_time


## Devuelve true (y lo borra) si el botón se apretó hace menos de input_buffer_time.
func consume_buffered(action: PlayerInput.Action) -> bool:
	if _buffer.has(action):
		_buffer.erase(action)
		return true
	return false


## ¿Hay un toque guardado de este botón? (No lo borra: vence solo a los input_buffer_time.)
func has_buffered(action: PlayerInput.Action) -> bool:
	return _buffer.has(action)


# --- Combate ---

func _try_avoid(info: DamageInfo) -> String:
	# Niebla de los Valles: los enemigos adentro fallan más.
	var attacker := info.attacker as Combatant if is_instance_valid(info.attacker) else null
	if attacker != null and attacker.status.has(StatusEffects.FOGGED) and Combat.roll(0.3):
		return "¡Se perdió en la niebla!"
	# Osito de peluche (objeto): chance de bloquear que crece con cada copia, sin llegar al 100%.
	# Evasión (Osito de peluche y otros): chance de que el golpe no te toque, con tope.
	if modifiers.evasion() > 0.0 and Combat.roll(modifiers.evasion()):
		return "¡Esquivado!"
	# Trébol de cuatro Gronks (objeto especial): a veces el golpe no te toca.
	if slot != null and RunState.has_special(slot.index, &"trebol_gronk") and Combat.roll(0.1):
		return "¡Zafaste de casualidad!"
	return kit.try_avoid(info)


func _on_blocked_by_invulnerability(info: DamageInfo) -> void:
	kit.on_blocked_by_invulnerability(info)


func _after_hit(info: DamageInfo) -> void:
	if info.shake <= 0.0 and not info.has_tag(&"tick"):
		Events.camera_shake_requested.emit(Balance.combat.shake_player_hurt)
	# Vibración del joystick al recibir un golpe (se apaga en Opciones).
	if slot != null and not slot.is_keyboard and not info.has_tag(&"tick") and info.final_amount > 0.0:
		GameSettings.rumble(slot.input.joy_device, 0.35, 0.55 if info.final_amount > 15.0 else 0.25, 0.15)
	kit.on_damage_taken(info)


func _on_any_hit_landed(info: DamageInfo, target: Node3D) -> void:
	if info.attacker == self and target != self:
		kit.on_damage_dealt(info, target)
		var steal: float = modifiers.lifesteal()
		if steal > 0.0 and not health.is_dead:
			health.heal(info.final_amount * steal)


func _on_died(info: DamageInfo) -> void:
	if kit.handle_owner_death(info):
		return
	if _try_crown():
		return
	kit.cancel_scheduled()
	end_action()
	if not GameSettings.auto_revive_players:
		var fall: Tween = create_tween()
		fall.tween_property(visual, "rotation:x", -1.35, 0.3)
		Events.floating_text_requested.emit(global_position + Vector3.UP * 2.4, "¡Caíste!",
				Color(1.0, 0.6, 0.6))
		# Jugando solo no hay a quién esperar: si caés, se termina.
		if _allies_alive() > 0:
			revive.go_down()
		return
	# Modo prueba hasta la Fase 4: se levanta solo.
	Events.floating_text_requested.emit(global_position + Vector3.UP * 2.4,
			"¡Caíste! (modo prueba)", Color(1.0, 0.6, 0.6))
	kit.cancel_scheduled()
	end_action()
	var timer: SceneTreeTimer = get_tree().create_timer(TEST_MODE_REVIVE_DELAY, false)
	timer.timeout.connect(func() -> void:
		health.restore_full()
		health.make_invulnerable(1.0))


# --- Objetos y mejoras ---

## Recalcula lo que suman los objetos genéricos y mejoras del jugador (RunState).
func rebuild_modifiers() -> void:
	modifiers.clear()
	# Objetos de sala: cada uno cuenta una sola vez, con el valor de su nivel (los niveles
	# reemplazan, no se suman). El nivel es cuántas veces lo eligió.
	var owned: Array = RunState.get_items(slot.index)
	var seen: Array = []
	for item_id: Variant in owned:
		if seen.has(item_id):
			continue
		seen.append(item_id)
		var item: GenericItem = Balance.generic_items.get_item(item_id)
		if item == null:
			continue
		var level: int = mini(owned.count(item_id), item.max_level())
		if item.effect == &"":
			modifiers.add(item.stat, item.value_at(level))
		else:
			modifiers.add(item.effect, float(level))
	# Reliquias del Black Market que suman (o restan) estadísticas.
	for relic_id: Variant in RunState.get_specials(slot.index):
		var relic: SpecialItem = Balance.shop.get_item(relic_id)
		if relic == null:
			continue
		if relic.stat != &"":
			modifiers.add(relic.stat, relic.amount)
		if relic.stat2 != &"":
			modifiers.add(relic.stat2, relic.amount2)
	for upgrade_id: Variant in RunState.get_upgrades(slot.index):
		var upgrade: CharacterUpgrade = Balance.upgrades.get_upgrade(upgrade_id)
		if upgrade != null and upgrade.stat != &"":
			modifiers.add(upgrade.stat, upgrade.amount)
	for meta: McoiniaUpgrade in Balance.mcoinia.column(&""):
		if meta.stat != &"" and MetaProgress.level(meta.id) > 0:
			modifiers.add(meta.stat, MetaProgress.bonus(meta.id))
	# La esquiva vuelve a su base antes de sumarle mejoras (si no, se acumularía).
	if kit.base_dodge_charges < 0:
		kit.base_dodge_charges = kit.dodge_cooldown.max_charges
	kit.dodge_cooldown.max_charges = kit.base_dodge_charges
	kit.apply_upgrade_stats(modifiers)
	kit.dodge_cooldown.max_charges += int(MetaProgress.bonus(&"pierna_extra"))
	var feather: GenericItem = ItemEffects.item_for(&"extra_dodge")
	if feather != null and item_stacks(&"extra_dodge") > 0:
		kit.dodge_cooldown.max_charges += int(feather.value_at(item_stacks(&"extra_dodge")))
	var ratio: float = health.ratio() if health.max_health > 0.0 else 1.0
	health.max_health = kit.base_max_health() + modifiers.max_health_bonus()
	health.current = clampf(health.max_health * ratio, 0.0, health.max_health) \
			if not health.is_dead else 0.0
	health.changed.emit(health.current, health.max_health)


## Copias de un objeto con efecto (por su `effect`).
func item_stacks(effect: StringName) -> int:
	return int(modifiers.get_total(effect))


func crit_chance() -> float:
	return data.crit_chance + modifiers.crit_chance_bonus()


func crit_multiplier() -> float:
	return data.crit_multiplier + modifiers.crit_damage_bonus()


## Lo usa Combatant al pegar: daño extra de objetos y mejoras.
func outgoing_damage_multiplier() -> float:
	# Daño de habilidades: todo lo que no es el golpe común.
	var basic: bool = specials == null or specials.is_basic_hit()
	if basic:
		return modifiers.damage_multiplier() * (1.0 + modifiers.get_total(&"basic_damage"))
	return modifiers.damage_multiplier() * (1.0 + modifiers.ability_damage())


## Daño recibido con objetos (Escama), con tope.
func _modify_incoming(info: DamageInfo) -> void:
	info.amount *= modifiers.damage_taken_multiplier()
	kit.modify_incoming(info)
	# Papá del grupo (Champaka): a su lado se recibe menos daño.
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var ally := node as PlayerCharacter
		if ally != null and ally != self and not ally.health.is_dead and ally.kit is ChampakaKit \
				and ally.global_position.distance_to(global_position) <= (ally.kit as ChampakaKit).dad_radius():
			info.amount *= 1.0 - (ally.kit as ChampakaKit).dad_reduction()
			break


func _on_loadout_changed(slot_index: int) -> void:
	if slot != null and slot_index == slot.index:
		rebuild_modifiers()


## Vendas del Bosque Tuerto: cura al terminar cada oleada.
func _on_wave_cleared(_index: int) -> void:
	var amount: float = modifiers.heal_per_wave()
	if amount > 0.0 and not health.is_dead:
		health.heal(amount)


func _allies_alive() -> int:
	var count: int = 0
	for node: Node in get_tree().get_nodes_in_group(&"players"):
		var other := node as PlayerCharacter
		if other != null and other != self and not other.health.is_dead:
			count += 1
	return count


func is_out() -> bool:
	return revive != null and revive.out


## Caído esperando que lo levanten. (Funciones simples para que otros scripts no tengan que
## tocar el ReviveComponent: el editor de Godot no resolvía esa referencia circular.)
func is_downed() -> bool:
	return revive != null and revive.downed


func down_time_left() -> float:
	return revive.time_left if revive != null else 0.0


func add_revive_progress(delta: float) -> void:
	if revive != null:
		revive.add_progress(delta)


func complete_revive() -> void:
	if revive != null:
		revive.complete_revive()


# --- Apuntado ---

func _update_aim(delta: float) -> void:
	var desired: Vector3 = _read_aim_direction()
	if desired != Vector3.ZERO:
		aim_direction = desired
	if not slot.input.is_keyboard:
		aim_point = global_position + aim_direction * 6.0
	var target_yaw: float = atan2(-aim_direction.x, -aim_direction.z)
	visual.rotation.y = rotate_toward(visual.rotation.y, target_yaw, data.turn_speed * delta)


## Gira el cuerpo ya mismo hacia donde apunta (al atacar, para que el golpe salga derecho).
func face_aim_now() -> void:
	visual.rotation.y = atan2(-aim_direction.x, -aim_direction.z)


## Mouse: raycast al plano del piso. Joystick: stick derecho con imán al enemigo
## más cercano en esa dirección; sin stick derecho, hacia donde camina.
func _read_aim_direction() -> Vector3:
	var input: PlayerInput = slot.input
	if input.is_keyboard:
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera == null:
			return Vector3.ZERO
		var origin: Vector3 = camera.project_ray_origin(input.mouse_position)
		var normal: Vector3 = camera.project_ray_normal(input.mouse_position)
		var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, normal)
		if hit == null:
			return Vector3.ZERO
		aim_point = hit as Vector3
		var flat: Vector3 = aim_point - global_position
		flat.y = 0.0
		return flat.normalized() if flat.length_squared() > 0.01 else Vector3.ZERO
	var direction := Vector3.ZERO
	if input.has_aim_stick():
		direction = Vector3(input.aim_stick.x, 0.0, input.aim_stick.y).normalized()
	elif input.move != Vector2.ZERO:
		direction = Vector3(input.move.x, 0.0, input.move.y).normalized()
	return _apply_aim_magnet(direction) if direction != Vector3.ZERO else direction


func _apply_aim_magnet(direction: Vector3) -> Vector3:
	var config: CombatConfig = Balance.combat
	var best_angle: float = deg_to_rad(config.aim_magnet_angle_deg)
	var best_direction := Vector3.ZERO
	var here := Vector3(global_position.x, 0.0, global_position.z)
	for hurtbox: Hurtbox in CombatQuery.targets(get_tree(), DamageInfo.Team.ENEMIES):
		var to_enemy: Vector3 = hurtbox.flat_position() - here
		var distance: float = to_enemy.length()
		if distance < 0.01 or distance > config.aim_magnet_range:
			continue
		var angle: float = direction.angle_to(to_enemy)
		if angle < best_angle:
			best_angle = angle
			best_direction = to_enemy / distance
	if best_direction == Vector3.ZERO:
		return direction
	return direction.slerp(best_direction, config.aim_magnet_strength).normalized()


# --- Placeholder ---

## Rearma el cuerpo con otro tamaño (el dúo cambia entre Maestro y Stewie).
func rebuild_body(height: float, radius: float) -> void:
	_build_body(height, radius)
	clear_flash_materials()
	register_flash_material(_body_material)
	hurtbox.radius = radius
	hurtbox.height = height


func _build_placeholder() -> void:
	_build_body(data.placeholder_height, data.placeholder_radius)


func _build_body(height: float, radius: float) -> void:
	var shape := CapsuleShape3D.new()
	shape.height = height
	shape.radius = radius
	_collision.shape = shape
	_collision.position.y = height * 0.5

	var mesh := CapsuleMesh.new()
	mesh.height = height
	mesh.radius = radius
	_body.mesh = mesh
	_body.position.y = height * 0.5
	_body_material = _make_body_material(slot.color)
	_body.material_override = _body_material

	var nose_mesh := BoxMesh.new()
	nose_mesh.size = Vector3(radius * 0.45, radius * 0.35, radius * 0.9)
	_nose.mesh = nose_mesh
	_nose.position = Vector3(0.0, height * 0.72, -radius * 0.95)
	_nose.material_override = _make_body_material(slot.color.darkened(0.55))

	var ring_mesh := PlaneMesh.new()
	ring_mesh.size = Vector2.ONE * radius * RING_SCALE
	_ring.mesh = ring_mesh
	_ring.position.y = 0.03
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring_material := ShaderMaterial.new()
	ring_material.shader = RING_SHADER
	ring_material.set_shader_parameter("ring_color", slot.color)
	_ring.material_override = ring_material


func _make_body_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.55
	# Rim light suave, como piden las referencias semirrealistas.
	material.rim_enabled = true
	material.rim = 0.35
	material.rim_tint = 0.4
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE_SHADER
	material.next_pass = outline
	return material


## Corona del Líder Supremo: una vez por partida, al caer, te levantás solo con el 40%.
func _try_crown() -> bool:
	if not RunState.has_special(slot.index, &"corona_lider") \
			or RunState.get_bonus(slot.index, &"corona_used") > 0:
		return false
	RunState.add_bonus(slot.index, &"corona_used", 1)
	kit.cancel_scheduled()
	end_action()
	Events.floating_text_requested.emit(global_position + Vector3.UP * 2.6,
			"¡La Corona del Líder Supremo!", Color(1.0, 0.82, 0.3))
	var fall: Tween = create_tween()
	fall.tween_property(visual, "rotation:x", -1.35, 0.3)
	fall.tween_interval(0.9)
	fall.tween_callback(func() -> void:
		health.restore_full()
		health.current = health.max_health * 0.4
		health.changed.emit(health.current, health.max_health)
		health.make_invulnerable(1.5))
	fall.tween_property(visual, "rotation:x", 0.0, 0.25)
	return true
