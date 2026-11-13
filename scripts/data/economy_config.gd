class_name EconomyConfig
extends Resource
## Números de la economía (GDD, Economía y tienda). Las tablas tienen un valor por stage
## (Stage 1, 2 y 3); los rangos son Vector2i(mínimo, máximo).

## Oro con el que arranca cada jugador.
@export var starting_gold: int = 150
## Oro extra si el Croco mata al élite con la Recompensa (DECISIONES 2026-11-13).
@export var croco_bounty_gold: int = 30

@export_group("Fuentes de oro (cada jugador recibe lo suyo)")
## Probabilidad de que un enemigo común suelte oro (se tira por cada jugador).
@export var common_drop_chance: float = 0.4
@export var common_gold: Array[Vector2i] = [Vector2i(2, 4), Vector2i(4, 7), Vector2i(7, 11)]
@export var elite_gold: Array[int] = [20, 35, 55]
@export var scenario_gold: Array[int] = [30, 50, 75]
## Probabilidad de que una vasija tenga oro. El oro es solo del que la rompe (pedido del grupo).
@export var vase_drop_chance: float = 0.5
## Probabilidad de que una vasija tenga un honguito que cura, y cuánto cura (pedido del grupo).
@export var vase_mushroom_chance: float = 0.3
@export var mushroom_heal: float = 20.0
@export var vase_gold: Array[Vector2i] = [Vector2i(2, 6), Vector2i(4, 10), Vector2i(6, 15)]
@export var chest_gold: Array[Vector2i] = [Vector2i(50, 80), Vector2i(80, 130), Vector2i(130, 200)]
@export var boss_gold: Array[int] = [60, 110, 0]

@export_group("Monedas")
## A esta distancia del dueño, la moneda vuela hacia él.
@export var coin_magnet_radius: float = 2.6
@export var coin_fly_speed: float = 16.0
## Valor máximo de una moneda (montos grandes se reparten en varias).
@export var coin_value: int = 5
@export var max_coins_per_drop: int = 8
## Distancia para abrir un cofre con Interactuar.
@export var chest_open_radius: float = 1.9


static func roll(range_value: Vector2i, rng: RandomNumberGenerator) -> int:
	return rng.randi_range(range_value.x, range_value.y)
