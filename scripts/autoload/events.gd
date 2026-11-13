extends Node
## Bus de señales global. Solo declara señales: nadie guarda estado acá.

# --- Jugadores y dispositivos ---
signal player_joined(slot: PlayerSlot)
signal player_left(slot_index: int)
signal player_character_changed(slot: PlayerSlot)
signal player_ready_changed(slot: PlayerSlot)
## Se desconectó el joystick de un jugador en plena partida (hay que pausar).
signal device_disconnected(slot: PlayerSlot)
signal device_reconnected(slot: PlayerSlot)

# --- Partida ---
signal run_started(seed_value: int)
signal gold_changed(slot_index: int, new_amount: int)
## Cambiaron los objetos o mejoras de un jugador (hay que recalcular sus estadísticas).
signal loadout_changed(slot_index: int)
## Se terminó una oleada (las Vendas del Bosque Tuerto curan).
signal wave_cleared(index: int)

# --- Combate ---
## Un golpe conectó (para números de daño, barras de Furia y de definitiva, etc.).
signal hit_landed(info: DamageInfo, target: Node3D)
## Un golpe se esquivó por algo propio del objetivo ("¡Falló!", "¡De casualidad!").
signal hit_avoided(target: Node3D, text: String)
## Texto flotante libre sobre algo del mundo (por ejemplo "¡FURIA!").
signal floating_text_requested(position: Vector3, text: String, color: Color)
signal camera_shake_requested(amount: float)
## Teñir la sala un rato (la Noche del Valle sin Luz la pone violeta).
signal room_tint_requested(color: Color, duration: float)
signal enemy_died(enemy: Node3D)
## Muerte y revivir (Fase 4).
signal player_downed(player: Node3D)
signal player_revived(player: Node3D)
## Se le acabó el tiempo: queda afuera hasta Birig Bamba.
signal player_out(player: Node3D)

# --- Juego en general ---
signal pause_changed(paused: bool)
signal quality_changed(preset: QualityPreset)
