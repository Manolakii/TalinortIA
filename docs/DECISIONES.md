# Registro de decisiones

Cada vez que cambie una decisión de diseño o técnica, se anota acá con la fecha.

| Fecha | Decisión |
| --- | --- |
| 2026-11-12 | Motor Godot 4.7 con GDScript, renderer Forward+ |
| 2026-11-12 | Cooperativo local de 1 a 4 jugadores, sin online por ahora (para jugar a distancia, Remote Play Together) |
| 2026-11-12 | Cámara frontal 3/4 (55°, FOV de 30 a 35), no isométrica rotada |
| 2026-11-12 | Estilo visual estilizado semirrealista (opción B) |
| 2026-11-12 | Colores de jugador: P1 azul, P2 rojo, P3 verde lima, P4 amarillo. Avisos de ataque en naranja |
| 2026-11-12 | Primera versión: Tali, Croco, Agucci, y el Maestro con Stewie; Birig Bamba y el Stage 1 completo |
| 2026-11-12 | Mejoras de personaje (1 de 3) en algunas salas, en las de élite y en los cofres de evento. Objeto genérico (1 de 3) al terminar cada escenario |
| 2026-11-12 | Escenarios X-1 a X-3 con varias salas (propuesta: 3), X-4 solo boss |
| 2026-11-12 | Quinto autoload `GameSettings`: presets de calidad (bajo, medio, alto) y flags de debug |
| 2026-11-12 | Los 70 a 80 px del GDD se miden como silueta en pantalla (alto proyectado más la profundidad del cuerpo vista desde arriba). Referencia: 1,8 m de alto y 0,35 m de profundidad, 75 px a 1080p (datos ajustables en `data/camera_config.tres`). Con eso la cámara queda a ~34 m y se ven unos 34 × 24 m de piso; alejada al máximo, el personaje mide ~67 px |
| 2026-11-12 | Cámara: encuadra el centro de la caja que contiene a todos los jugadores (pies y cabeza), con márgenes de 70 px arriba y a los costados y 150 px abajo (lugar para los paneles del HUD). Al llegar al borde, el jugador se desliza por él o se frena |
| 2026-11-12 | Interpolación de física activada, para que el movimiento se vea suave en monitores de más de 60 Hz |
| 2026-11-12 | Pantalla de unión: Enter o A para unirse, izquierda/derecha para elegir personaje, A (o Enter) para confirmar, B (o Esc) para salir, Start (o Enter con todos listos) para arrancar |
| 2026-11-12 | El golpe común se repite solo mientras se mantiene el botón |
| 2026-11-12 | Maestro y Stewie: el botón de definitiva siempre hace el Cambio. El Relevo Total (con la barra llena) se lanza con Y/Triángulo + RB/R1 en joystick, y con R en teclado |
| 2026-11-12 | Al caer, el jugador se arrastra solo, despacio, hacia sus compañeros |
| 2026-11-12 | El aura de Furia de Tali es rojo-ocre (el naranja queda reservado para los avisos enemigos) |
| 2026-11-12 | Mientras se desarrolla, todas las dificultades están desbloqueadas con el flag de debug `unlock_all_difficulties` de `GameSettings` |
| 2026-11-12 | Tests de lógica pura con GUT (Godot Unit Test, licencia MIT), instalado en `addons/gut` desde la Fase 0 |
| 2026-11-12 | El grupo deja a criterio de Claude el resto de los detalles de diseño que falten; cada uno se anota acá cuando se decide y se puede cambiar después |
| 2026-11-13 | Tali: la barra de Furia se llena rápido al recibir daño y un poco más lento con el daño que hace (antes era solo al recibir). Al 100% entra en Furia sola |
| 2026-11-13 | Barra de definitiva (todos los personajes): se llena más rápido con el daño recibido que con el hecho. Valores por personaje en `data/characters/` |
| 2026-11-13 | Tropezón: distancia corta (2,8 m en 0,3 s), 2 cargas con 4 s de recarga cada una. La Embestida de Furia usa las mismas cargas |
| 2026-11-13 | Llamado Salvaje: pájaros 45%, bichos 45%, Gronk 10% |
