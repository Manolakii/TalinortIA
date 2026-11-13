class_name CombatQuery
## Búsqueda de objetivos por forma (círculo, sector, línea), sobre el plano del piso.
## Es geometría simple sobre los Hurtbox registrados: rápida, exacta y fácil de testear.


static func hurtboxes(tree: SceneTree, team: DamageInfo.Team) -> Array[Hurtbox]:
	var result: Array[Hurtbox] = []
	for node: Node in tree.get_nodes_in_group(Hurtbox.group_for(team)):
		var hurtbox := node as Hurtbox
		if hurtbox != null and hurtbox.is_targetable():
			result.append(hurtbox)
	return result


static func in_circle(tree: SceneTree, team: DamageInfo.Team, center: Vector3,
		radius: float) -> Array[Hurtbox]:
	var result: Array[Hurtbox] = []
	var c := _flat(center)
	for hurtbox: Hurtbox in hurtboxes(tree, team):
		if c.distance_to(hurtbox.flat_position()) <= radius + hurtbox.radius:
			result.append(hurtbox)
	return result


## Sector (abanico) hacia `forward`, con ángulo total `angle_deg`.
static func in_sector(tree: SceneTree, team: DamageInfo.Team, center: Vector3, forward: Vector3,
		radius: float, angle_deg: float) -> Array[Hurtbox]:
	var result: Array[Hurtbox] = []
	var c := _flat(center)
	var dir := _flat(forward).normalized()
	var half_angle: float = deg_to_rad(angle_deg) * 0.5
	for hurtbox: Hurtbox in hurtboxes(tree, team):
		var to_target: Vector3 = hurtbox.flat_position() - c
		var distance: float = to_target.length()
		if distance > radius + hurtbox.radius:
			continue
		# Si está pegado, cuenta aunque el centro quede apenas fuera del ángulo.
		if distance <= hurtbox.radius + 0.3:
			result.append(hurtbox)
			continue
		# El ángulo se amplía un poco según el tamaño del objetivo.
		var extra: float = asin(clampf(hurtbox.radius / distance, 0.0, 1.0))
		if dir.angle_to(to_target) <= half_angle + extra:
			result.append(hurtbox)
	return result


## Rectángulo de `width` de ancho entre `from` y `to`.
static func in_line(tree: SceneTree, team: DamageInfo.Team, from: Vector3, to: Vector3,
		width: float) -> Array[Hurtbox]:
	var result: Array[Hurtbox] = []
	var a := _flat(from)
	var b := _flat(to)
	for hurtbox: Hurtbox in hurtboxes(tree, team):
		var p: Vector3 = hurtbox.flat_position()
		var closest: Vector3 = Geometry3D.get_closest_point_to_segment(p, a, b)
		if p.distance_to(closest) <= width * 0.5 + hurtbox.radius:
			result.append(hurtbox)
	return result


## Como hurtboxes(), sin los objetos rompibles: para apuntar y para las IA.
static func targets(tree: SceneTree, team: DamageInfo.Team) -> Array[Hurtbox]:
	var result: Array[Hurtbox] = []
	for hurtbox: Hurtbox in hurtboxes(tree, team):
		if not hurtbox.is_prop:
			result.append(hurtbox)
	return result


static func nearest(tree: SceneTree, team: DamageInfo.Team, position: Vector3,
		max_distance: float = INF) -> Hurtbox:
	var best: Hurtbox = null
	var best_distance: float = max_distance
	var p := _flat(position)
	for hurtbox: Hurtbox in targets(tree, team):
		var d: float = p.distance_to(hurtbox.flat_position())
		if d < best_distance:
			best_distance = d
			best = hurtbox
	return best


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
