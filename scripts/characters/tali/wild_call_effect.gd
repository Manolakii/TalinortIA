class_name WildCallEffect
extends Node3D
## Llamado Salvaje de Tali: los animales lo entienden mal y sale algo al azar.
##   Pájaros: vuelan a una zona adelante, pegan en área y dejan ciegos.
##   Bichos: una manada que avanza en línea y empuja.
##   Gronk: pasa a la carga atravesando todo (raro, pero el más fuerte).

enum Kind { BIRDS, BUGS, GRONK }

const BIRDS_ARRIVAL := 0.45
const BIRDS_LIFETIME := 1.2
const BUGS_TRAVEL_TIME := 0.6
const BIRD_COLOR := Color(0.13, 0.13, 0.16)
const BUG_COLOR := Color(0.2, 0.14, 0.08)
const GRONK_COLOR := Color(0.42, 0.37, 0.3)

var kind: Kind = Kind.BIRDS
var kit: CharacterKit
var data: TaliKitData
var direction: Vector3 = Vector3.FORWARD
var start_point: Vector3 = Vector3.ZERO

var _time: float = 0.0
var _already_hit: Array[Node] = []
var _pieces: Array[Node3D] = []
var _offsets: Array[Vector3] = []
var _birds_struck: bool = false


func launch(owner_kit: CharacterKit, kit_data: TaliKitData, which: Kind, aim: Vector3) -> void:
	kit = owner_kit
	data = kit_data
	kind = which
	direction = Vector3(aim.x, 0.0, aim.z).normalized()
	var p: Vector3 = owner_kit.player.global_position
	start_point = Vector3(p.x, 0.0, p.z)
	match kind:
		Kind.BIRDS:
			_build_pieces(7, Vector3(0.38, 0.05, 0.14), BIRD_COLOR, 1.6)
		Kind.BUGS:
			_build_pieces(16, Vector3(0.2, 0.12, 0.28), BUG_COLOR, data.bugs_width * 0.5)
		Kind.GRONK:
			_build_gronk()


func _physics_process(delta: float) -> void:
	_time += delta
	match kind:
		Kind.BIRDS:
			_update_birds()
		Kind.BUGS:
			_update_line(data.bugs_length / BUGS_TRAVEL_TIME, data.bugs_length, data.bugs_width,
					BUGS_TRAVEL_TIME + 0.25)
		Kind.GRONK:
			_update_line(data.gronk_speed, data.gronk_length, data.gronk_width,
					data.gronk_length / data.gronk_speed + 0.2)


# --- Pájaros ---

func _update_birds() -> void:
	var center: Vector3 = start_point + direction * data.birds_distance
	var t: float = clampf(_time / BIRDS_ARRIVAL, 0.0, 1.0)
	for i: int in _pieces.size():
		var swirl: float = _time * 7.0 + i * TAU / _pieces.size()
		var around := Vector3(cos(swirl), 0.0, sin(swirl)) * data.birds_radius * 0.55 * t
		var flying: Vector3 = start_point.lerp(center, t) + _offsets[i] * (1.0 - t) + around
		flying.y = 1.8 + sin(_time * 12.0 + i) * 0.25 + (1.0 - t) * 0.8
		if _time > BIRDS_LIFETIME - 0.3:
			flying.y += (_time - (BIRDS_LIFETIME - 0.3)) * 12.0
		_pieces[i].global_position = flying
		_pieces[i].rotation.y = -swirl
	if t >= 1.0 and not _birds_struck:
		_birds_struck = true
		Fx.ring_burst(get_parent(), center, data.birds_radius, kit.player.slot.color)
		var targets: Array[Hurtbox] = CombatQuery.in_circle(get_tree(), DamageInfo.Team.ENEMIES,
				center, data.birds_radius)
		for hurtbox: Hurtbox in targets:
			var info: DamageInfo = _make_hit(data.birds_damage)
			info.origin = center
			info.knockback = 2.0
			if hurtbox.take_hit(info):
				var enemy := hurtbox.receiver as Combatant
				if enemy != null:
					enemy.status.apply(StatusEffects.BLIND, data.birds_blind)
	if _time >= BIRDS_LIFETIME:
		queue_free()


# --- Bichos y Gronk: algo que avanza en línea y le pega una vez a cada uno ---

func _update_line(speed: float, length: float, width: float, lifetime: float) -> void:
	var front: float = minf(_time * speed, length)
	var front_point: Vector3 = start_point + direction * front
	var targets: Array[Hurtbox] = CombatQuery.in_line(get_tree(), DamageInfo.Team.ENEMIES,
			start_point, front_point, width)
	for hurtbox: Hurtbox in targets:
		if _already_hit.has(hurtbox.receiver):
			continue
		_already_hit.append(hurtbox.receiver)
		_hit_in_line(hurtbox)
	_place_line_pieces(front_point)
	if _time >= lifetime:
		queue_free()


func _hit_in_line(hurtbox: Hurtbox) -> void:
	var info: DamageInfo
	if kind == Kind.BUGS:
		info = _make_hit(data.bugs_damage)
		info.knockback = data.bugs_knockback
	else:
		info = _make_hit(data.gronk_damage)
		info.knockback = 8.0
		info.stun = data.gronk_stun
		info.hitstop = Balance.combat.hitstop_heavy
		info.shake = Balance.combat.shake_heavy * 0.6
	# Empuja en la dirección en que avanza la manada.
	info.origin = hurtbox.global_position - direction
	hurtbox.take_hit(info)


func _place_line_pieces(front_point: Vector3) -> void:
	var side := Vector3(-direction.z, 0.0, direction.x)
	for i: int in _pieces.size():
		var piece: Node3D = _pieces[i]
		if kind == Kind.GRONK:
			piece.global_position = front_point + Vector3.UP * 0.05
			piece.rotation.y = atan2(-direction.x, -direction.z)
			piece.position.y = absf(sin(_time * 18.0)) * 0.15
		else:
			var offset: Vector3 = _offsets[i]
			var along: float = -absf(offset.z) * 1.4
			piece.global_position = front_point + direction * along + side * offset.x \
					+ Vector3.UP * (0.08 + absf(sin(_time * 30.0 + i)) * 0.08)
			piece.rotation.y = atan2(-direction.x, -direction.z) + sin(_time * 25.0 + i) * 0.4


func _make_hit(amount: float) -> DamageInfo:
	var player: PlayerCharacter = kit.player
	var info: DamageInfo = Combat.make_hit(player, DamageInfo.Team.PLAYERS, amount,
			player.data.crit_chance, player.data.crit_multiplier)
	info.hitstop = Balance.combat.hitstop_light
	info.is_melee = false
	return info


# --- Placeholders ---

func _build_pieces(count: int, size: Vector3, color: Color, spread: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material: StandardMaterial3D = Fx.flat_material(color)
	for i: int in count:
		var piece := MeshInstance3D.new()
		piece.mesh = mesh
		piece.material_override = material
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(piece)
		_pieces.append(piece)
		_offsets.append(Vector3(randf_range(-spread, spread), 0.0, randf_range(-spread, spread)))
		piece.global_position = start_point


func _build_gronk() -> void:
	var gronk := Node3D.new()
	add_child(gronk)
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.85
	capsule.height = 2.6
	body.mesh = capsule
	body.rotation.x = PI * 0.5
	body.position.y = 0.95
	body.material_override = Fx.flat_material(GRONK_COLOR)
	gronk.add_child(body)
	for side: float in [-1.0, 1.0]:
		var horn := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.16
		cone.height = 0.7
		horn.mesh = cone
		horn.position = Vector3(side * 0.45, 1.45, -1.1)
		horn.rotation.x = -0.9
		horn.material_override = Fx.flat_material(Color(0.92, 0.88, 0.8))
		gronk.add_child(horn)
	_pieces.append(gronk)
	_offsets.append(Vector3.ZERO)
	# Arranca un poco detrás de Tali, como si viniera corriendo.
	start_point -= direction * 1.5
	gronk.global_position = start_point
