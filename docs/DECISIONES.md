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
| 2026-11-13 | Los enemigos eligen objetivo entre todo lo del lado de los jugadores: jugadores, el compañero del dúo y el señuelo del Croco (que atrae más). Agucci oculto por la Noche no cuenta |
| 2026-11-13 | Croco, Arma Adaptativa: escopeta hasta 4,5 m, pistola hasta 10 m, rifle más lejos. "Enemigo apuntado" = el más cercano a la mira en un cono de 25°, hasta 26 m. Sin enemigo apuntado, el arma queda en el modo que estaba |
| 2026-11-13 | Croco: escopeta abanico de 32° y 7 m; pistola 15 m; rifle 26 m con 0,08 s entre balas. Tiro por Contrato: 26 m de largo; si lo seguís manteniendo, sale solo a los 3 s. Su bonus (+0,2% por muerte) se guarda por jugador en RunState para toda la partida |
| 2026-11-13 | Croco, Ruta de Escape: voltereta de 4,2 m en 0,3 s, 2 cargas con 4 s de recarga. El rastro dura 2 s y da +30% de velocidad por 1,5 s a los aliados (no al Croco). Riel: sigue a la mira a 50°/s, 24 m de largo, el Croco se mueve al 25% |
| 2026-11-13 | Agucci: cada golpe común que conecta baja 1,5 de Hambre; cerca de Tali (6 m) baja 3 por segundo. Disolverse (4,5 m, 2 cargas, 4 s) no suma Hambre. Paso de Sombra: kunai de 12 m; hay 4 s para reactivar y viajar hasta él |
| 2026-11-13 | Agucci, Noche: la sombra repite cada golpe 0,12 s después; si no ataca durante 0,6 s, los enemigos lo pierden de vista. La sala se tiñe de violeta |
| 2026-11-13 | Agucci, Posesión: +60% de daño y +40% de velocidad; camina sola al enemigo más cercano y ataca en área (2,2 m, 30 cada 0,5 s, 20% de robo de vida). Sin enemigos, le saca 2% de la vida máxima por segundo. Mordida de Sombra: 5 m, 2 cortes de 35, CD 3 s (se reinicia si mata). Abrazo: 5 m, 40 de daño en 1 s, CD 4 s |
| 2026-11-13 | Maestro y Stewie: el compañero (IA) sigue al jugador y ataca a lo último que golpeó el jugador; si se aleja más de 10 m vuelve, y a más de 18 m aparece al lado. En el Cambio se intercambian los lugares: tomás el control donde estaba el otro. El caído se levanta a los 15 s con 50% de vida |
| 2026-11-13 | Maestro: Bastonazo de 9 m, carga completa en 1 s. Garrocha: 4,5 m en 0,4 s, invulnerable todo el salto. Stewie: Cabezazo de 1,6 m; Refugio bloquea todo 2 s; Rodar 4 m. Relevo Total base: Forma Ancestral (Stewie el doble de grande, +50% de daño y de vida) o Lección del Maestro (Stewie copia golpes, Refugio y Rodar) |
| 2026-11-13 | Números de daño: los golpes seguidos al mismo objetivo se escalonan hacia arriba, y el daño continuo (Riel, Abrazo) se suma en un solo número cada 0,3 s |
| 2026-11-13 | Croco (pedido del grupo): la pistola cubre de 4,5 a 14 m (antes hasta 10) y su alcance sube a 18 m. Para cambiar de modo hay que pasarse 1,5 m del límite (así no cambia ida y vuelta) |
| 2026-11-13 | Arreglo: al terminar cualquier movimiento rápido (esquiva, Paso de Sombra, Aplastón, Mordida...) la velocidad queda como mucho en la de caminar. Antes Agucci seguía patinando ~7 m después de viajar al kunai |
| 2026-11-13 | Dúo (pedido del grupo, la IA moría enseguida): mientras lo maneja la IA recibe 40% menos de daño y los enemigos prefieren a los jugadores; esquiva los avisos naranjas (Stewie con Refugio o rodando, el Maestro con la garrocha, usando sus cargas); con menos de 40% de vida se repliega al lado del jugador y se recupera (3% por segundo sin enemigos a 4 m) hasta el 70%; solo ataca lo que el jugador golpeó si está a 6 m del jugador |
| 2026-11-13 | Croco (segunda prueba del grupo): pistola hasta 11 m con margen de 1 m (rifle desde ~12 m). La pistola pasa a ser tipo revólver: 34 de daño a 1,6 tiros/s, con empuje leve (antes 16 a 3,2). Actualizado en KITS_MVP y GDD |
| 2026-11-13 | Agucci (pedido del grupo, el Hambre casi no subía): cada golpe común baja 0,3 de Hambre (antes 1,5) y Disolverse suma +6 |
| 2026-11-13 | Dúo, IA con habilidades: el Maestro tira el Bastonazo (carga de 0,6 s, 96 de daño) si le pega a 2 o más en línea o a un objetivo fuera de alcance; Stewie rueda hacia el objetivo si está a más de 4 m, guardando una carga para esquivar |
| 2026-11-13 | Fase 3: la pantalla de unión arranca una sala de combate (3 oleadas, se gana o se pierde). La sala de prueba con enemigos infinitos sigue en `scenes/rooms/test_room_talinorthland.tscn` (F6). En la sala de combate quien cae no se levanta solo (revivir llega en la Fase 4); si caen todos, se pierde |
| 2026-11-13 | Oleadas como texto editable en `data/rooms/` ("id:cantidad:élites"). Sala de prueba: 6 + 6 + 6 enemigos con 1 jugador en Normal (~18 por sala, en línea con los ~22 de oro por sala del GDD). Las cantidades escalan solas por jugador; los élites no |
| 2026-11-13 | Dificultad: se elige en la pantalla de unión con E o X. Hasta que exista el progreso entre partidas, Normal y Difícil se desbloquean solo con el flag de debug |
| 2026-11-13 | Hondero: se queda a 8 m, tira cada 2,4 s con 0,35 s de preparación; la piedra vuela 1 s hacia donde va el objetivo y pega en un círculo de 1,3 m |
| 2026-11-13 | Soldado Agucci: 2,6 m/s; desde 5 m hace un aviso de 0,7 s y un dash de 4,5 m (rectángulo de 1,4 m de ancho) |
| 2026-11-13 | Tirador Agucci: se mueve de costado a ~8 m; cada 2,2 s, aviso en abanico de 0,5 s y 3 balas de 6 (abanico de 24°, 15 m/s). Los enemigos de distancia retroceden al 60% de su velocidad, para que se los pueda alcanzar |
| 2026-11-13 | Chamán de la Sombra: se queda a ~10 m. Su zona de sombra (3,5 m) lastima 4 por segundo. Acelera a los cegados (Talinorteanos y Honderos) a 10 m. Al morir aturde 3 s a los cegados cercanos y el 35% despierta y huye |
| 2026-11-13 | Gronk: 3 m/s; desde 13 m, aviso de 0,9 s y carga a 16 m/s hasta 14 m (el aviso se corta en la pared). Atropella jugadores y enemigos (25). Si choca contra una pared o roca, queda aturdido 2 s |
| 2026-11-13 | Élites: el afijo se ve escrito encima. Blindado = recibe 50% de frente (abanico de 140°); Veloz = +40%; Sombrío = charcos de 1,4 m que duran 4 s y ralentizan 40%; Explosivo = al morir, aviso de 0,8 s y explosión de 3 m (20 de daño) |
| 2026-11-13 | Recompensa del Croco: solo si el Croco está en el equipo, el primer élite de cada sala lleva el rombo dorado. Si lo mata el Croco, cobra 30 de oro (por ahora directo; con las monedas de la Fase 5, "suelta" el oro) |
| 2026-11-13 | La IA del compañero del dúo esquiva cualquier aviso naranja (también piedras, cargas y explosiones) |
| 2026-11-13 | Difícil, pedido del grupo ("tiene que ser difícil de verdad"): vida ×1,5 y daño ×1,7 (antes ×1,25 y ×1,4), 30% más enemigos, 15% más rápidos, avisos 20% más cortos, atacan 25% más seguido y 1 élite extra por oleada. Fácil, para compensar: 15% menos enemigos, 10% más lentos, avisos 15% más largos. Todo en `data/difficulty.tres`. Actualizado en el GDD |
| 2026-11-13 | Agucci, pedido del grupo (un poquito menos fuerte): +0,7% de daño por punto de Hambre (antes 1%) y Posesión ×1,4 (antes ×1,6). Actualizado en KITS_MVP |
| 2026-11-13 | Arreglo Agucci: el kunai se clava al chocar con paredes o rocas (no las atraviesa), y el viaje por la sombra atraviesa obstáculos y siempre llega al kunai. Antes una roca lo frenaba y el corte pegaba igual sin moverse |
| 2026-11-13 | Arreglo Chamán: el aura llega a 18 m y al morir afecta a los cegados a 24 m (antes 10 m: los cegados que peleaban con los jugadores quedaban afuera y "no pasaba nada"). Al morir se ve: anillo violeta, "¡Se rompió la sombra!", y cada cegado dice "¿Eh?" o "¡Desperté!". Los aturdidos se tambalean más |
| 2026-11-13 | IA del dúo, más inteligente: sale de las zonas de sombra; elige objetivo con prioridad (el que está por pegarle al jugador, lo que golpea el jugador, el que lo ataca a él, el que está encima del jugador) y lo mantiene 0,8 s; rodea al objetivo para pegarle del otro lado; no se aleja más de 7 m (para no perder el Vínculo) |
