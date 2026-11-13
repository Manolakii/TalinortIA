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
| 2026-11-13 | Combate: los golpes buscan objetivos por forma (círculo, abanico, línea) sobre los Hurtbox, sin áreas de física. Es más simple, exacto y testeable |
| 2026-11-13 | Hitstop por personaje (solo el que pega y el que recibe se congelan un instante), no global: con 4 jugadores, un congelado global cortaría todo el tiempo. Valores en `data/combat_config.tres` |
| 2026-11-13 | Buffer de input de 0,15 s. La esquiva corta cualquier acción. La habilidad fuerte y la definitiva cortan la recuperación del golpe común (una vez que el golpe conectó) |
| 2026-11-13 | Modo prueba hasta la Fase 4: si un jugador cae, se levanta solo a los 1,5 s |
| 2026-11-13 | Barra de definitiva de todos: 0,04 por punto de daño hecho y 0,35 por punto recibido (se ajusta por personaje en `data/characters/`) |
| 2026-11-13 | Talinorteano cegado: 3,2 m/s, ataca a 1,7 m, golpe en abanico de 2 m y 100°, 0,9 s de recuperación, empuja 4 m/s. Lleva una venda violeta (lo ciega la sombra) |
| 2026-11-13 | Tali, Furia: 0,8 por punto de daño recibido y 0,12 por punto hecho. En Furia el cuerpo crece 30%. Resaca: 50% de velocidad |
| 2026-11-13 | Tali, Piedrazo: piedra a 20 m/s, alcance 13 m, desvío de ±8°, empuje leve. El Tiro de Suerte (10%) es aparte del crítico base: si sale, siempre es crítico y aturde 1 s |
| 2026-11-13 | Tali, Llamado Salvaje: pájaros a 6 m, área de 3,5 m, 40 de daño y 3 s de ceguera (los ciegos deambulan y no atacan). Bichos: línea de 10 m, 25 de daño y empuje fuerte. Gronk: línea de 16 m, 120 de daño y 1,5 s de aturdimiento |
| 2026-11-13 | Tali, Zarpazos: alcance 2,4 m en abanico de 120°; el tercero aturde 0,5 s y levanta. Aplastón: salto de hasta 7 m en 0,45 s, área de 3 m. Embestida: 5 m, sin daño, tira al piso 1 s |
| 2026-11-13 | Tali, definitiva. Rugido: empuja y asusta 2 s a todo lo que está a 5 m. Revoleo: agarra al más grande a 4 m, lo tira 8 m (60 de daño al lanzado y 60 en 2,5 m a los demás). Si no hay a quién revolear, no gasta la barra |
| 2026-11-13 | Números de daño: blanco al pegarle a enemigos; crítico más grande, blanco cálido y con "!"; rojo claro al recibir; celeste para lo que se esquiva ("¡Se resbaló!", "¡De casualidad!"). Ninguno usa dorado, amarillo ni naranja |
