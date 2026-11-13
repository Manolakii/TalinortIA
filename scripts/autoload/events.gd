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

# --- Juego en general ---
signal pause_changed(paused: bool)
signal quality_changed(preset: QualityPreset)
