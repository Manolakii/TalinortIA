class_name Loot
extends RefCounted
## Reparte oro: cuando cae oro, cae para cada jugador por separado (GDD, Economía).
## Usa el generador de la partida para que una semilla repita los mismos premios.


## Monto de una fuente para el stage actual (Vector2i = rango, int = fijo).
static func amount_for(table: Array, stage: int) -> int:
	var value: Variant = table[clampi(stage, 0, table.size() - 1)]
	if value is Vector2i:
		return EconomyConfig.roll(value, RunState.rng)
	return int(value)


## Suelta oro de `table` para cada jugador. Con `chance` < 1, se tira por cada uno.
static func drop_for_all(parent: Node, origin: Vector3, table: Array, chance: float = 1.0) -> void:
	for node: Node in parent.get_tree().get_nodes_in_group(&"players"):
		var player := node as PlayerCharacter
		if player == null or player.is_out():
			continue
		if chance < 1.0 and RunState.rng.randf() >= chance:
			continue
		drop(parent, origin, player, amount_for(table, RunState.stage))


## Suelta `amount` de oro (con el multiplicador del jugador) en monedas suyas.
static func drop(parent: Node, origin: Vector3, player: PlayerCharacter, amount: int) -> void:
	var total: int = roundi(amount * player.modifiers.gold_multiplier())
	if total <= 0:
		return
	var economy: EconomyConfig = Balance.economy
	var coins: int = clampi(ceili(float(total) / economy.coin_value), 1, economy.max_coins_per_drop)
	var base: int = total / coins
	var extra: int = total - base * coins
	for i: int in coins:
		var coin := GoldCoin.new()
		parent.add_child(coin)
		coin.global_position = Vector3(origin.x, 0.8, origin.z)
		var angle: float = RunState.rng.randf() * TAU
		var spread: float = RunState.rng.randf_range(1.2, 3.2)
		var launch := Vector3(cos(angle) * spread, RunState.rng.randf_range(5.0, 7.5), sin(angle) * spread)
		coin.setup(player, base + (1 if i < extra else 0), launch)
