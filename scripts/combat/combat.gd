class_name Combat
## Funciones de combate compartidas: armar golpes, tirar críticos y entregarlos.

static var rng := RandomNumberGenerator.new()


## Arma un golpe con el crítico ya tirado.
static func make_hit(attacker: Node3D, team: DamageInfo.Team, base_damage: float,
		crit_chance: float, crit_multiplier: float) -> DamageInfo:
	var info := DamageInfo.new()
	info.attacker = attacker
	info.attacker_team = team
	info.origin = attacker.global_position if attacker != null else Vector3.ZERO
	info.is_crit = roll(crit_chance)
	info.amount = base_damage * (crit_multiplier if info.is_crit else 1.0)
	return info


static func roll(chance: float) -> bool:
	return chance > 0.0 and rng.randf() < chance


## Entrega una copia del golpe a cada objetivo. Devuelve a cuántos les pegó.
static func deliver(info: DamageInfo, targets: Array[Hurtbox]) -> int:
	var landed: int = 0
	for hurtbox: Hurtbox in targets:
		var copy: DamageInfo = info.clone()
		if hurtbox.take_hit(copy):
			landed += 1
	return landed


## Elige una opción según pesos (por ejemplo, el animal del Llamado Salvaje).
static func weighted_pick(weights: Array[float]) -> int:
	var total: float = 0.0
	for w: float in weights:
		total += maxf(w, 0.0)
	if total <= 0.0:
		return 0
	var r: float = rng.randf() * total
	for i: int in weights.size():
		r -= maxf(weights[i], 0.0)
		if r < 0.0:
			return i
	return weights.size() - 1
