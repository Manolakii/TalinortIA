# Plan del MVP — Stage 1 completo con Birig Bamba

**Objetivo del MVP:** una partida jugable de punta a punta para 1 a 4 jugadores en cooperativo local:

> Birig Bamba → Stage 1 en Talinorthland (1-1, 1-2, 1-3, cada uno con 3 salas) → Gronk Gigante (1-4) → vuelta a Birig Bamba.

**Personajes:** Tali, Mercenario Croco, Agucci, y el Maestro Uwey con Stewie.
**Queda afuera:** General Pipo y Capitán Champaka como jugables, Stages 2 y 3, online, modelos finales y kits alternativos.

Cada fase termina con algo **jugable**. No se pasa a la siguiente hasta que la anterior funcione y el grupo la haya probado.

---

## Fase 0 — Base del proyecto

- Proyecto Godot 4.7 (Forward+), estructura de carpetas, git y `.gitignore` de Godot.
- Autoloads: `Events`, `RunState`, `PlayerManager`, `Balance` y `GameSettings`.
- Pantalla de unión: hasta 4 jugadores, cada uno con su dispositivo (un teclado y mouse como máximo), su color P1 a P4 y la elección de personaje sin repetir.
- Sala de prueba de Talinorthland con piso, paredes, luz, `WorldEnvironment` semirrealista y presets de calidad.
- Cámara compartida según el GDD: frontal 3/4 a 55°, FOV ~32, sigue al grupo, se aleja como máximo un 12% y frena a los jugadores en el borde.
- Personajes placeholder: cápsulas con aro del color del jugador y contorno.

**Listo cuando:** 1 a 4 jugadores se unen, eligen personaje y se mueven por la sala, y la cámara los encuadra a todos sin que nadie salga de pantalla.

## Fase 1 — Combate y feel con Tali

- Sistema de combate genérico: hitbox y hurtbox, daño con críticos, invulnerabilidad de la esquiva (0,25 s), knockback y aturdimiento.
- Feel: hitstop, sacudida de cámara, flash al recibir daño, números de daño (con pool), cancelar animaciones con la esquiva.
- **Tali completo** según `KITS_MVP.md`: Normal y Furia, barra de Furia, Resaca, Suerte, Piedrazo, Llamado Salvaje, Tropezón, la definitiva y todo lo de Furia.
- Un enemigo: Talinorteano cegado.
- Escena de prueba con enemigos que reaparecen.

**Listo cuando:** pegarle a un enemigo con Tali se siente bien y la Furia funciona de punta a punta.

## Fase 2 — El resto de los personajes del MVP

- **Mercenario Croco:** arma adaptativa (escopeta, pistola, rifle) con el bonus por cambio de modo, Tiro por Contrato, Ruta de Escape y el Riel.
- **Agucci:** barra de Hambre con sus 3 zonas, Posesión (incluidas Mordida de Sombra y Abrazo del Valle sin Luz), Paso de Sombra, Disolverse y Noche del Valle sin Luz.
- **Maestro Uwey y Stewie:** dos cuerpos para un jugador, Vínculo, Caída, Relevo (Cambio y Relevo Total) e IA del compañero. Versiones base, con el sistema de Sendas preparado.
- Sinergia Tali → Agucci: cerca de Tali, el Hambre baja sola.

**Listo cuando:** los 4 personajes son jugables en la sala de prueba, en co-op.

## Fase 3 — Enemigos del Stage 1

- Hondero cegado, Soldado Agucci, Tirador Agucci, Chamán de la Sombra (al matarlo, los cegados se aturden) y Gronk.
- Todos los ataques con aviso naranja.
- Oleadas (2 o 3 por sala) y élites con afijos (Blindado, Veloz, Sombrío, Explosivo).
- La recompensa del Croco sobre un élite por sala.
- Dificultad (Fácil, Normal y Difícil) y escalado por jugador según las tablas del GDD.

**Listo cuando:** una sala de combate completa con oleadas variadas se puede ganar o perder.

## Fase 4 — HUD, muerte y revivir

- HUD según el GDD (sección Interfaz), adaptado a la cámara frontal:
  - un panel por jugador abajo, con retrato, vida, barra propia, habilidades con cooldown encima del ícono y oro;
  - barritas y efectos sobre los personajes;
  - nombres al empezar la sala y al revivir.
- Muerte y revivir:
  - el tiempo para levantarlo baja de 25 s a 19, 13 y 8 s según las caídas;
  - se mantiene interactuar 3,8 s para revivir;
  - el caído se arrastra solo, despacio, hacia sus compañeros;
  - si se acaba el tiempo, vuelve en Birig Bamba con 40% de vida y sin fuente;
  - si caen todos, se termina la partida.
- Paredes del sur transparentes y silueta del personaje cuando queda tapado.

**Listo cuando:** 4 jugadores pueden pelear, caer y revivirse, y se entiende todo en pantalla.

## Fase 5 — Estructura del Stage 1

- Escenarios 1-1, 1-2 y 1-3, con 3 salas cada uno, generadas desde plantillas con semilla. Dos puertas al terminar cada sala, con el ícono de lo que hay detrás.
- **Tipos de sala:**
  - Combate y Élite.
  - Tesoro.
  - Dos eventos: Mimics y Colonia de presos.
  - Cabaña del General Pipo: oculta, se llega con un acertijo simple, y sin Pipo jugable te deja una torreta aliada.
- **Mejoras de personaje** (elegir 1 de 3) en algunas salas, en las de élite y en los cofres de evento. Las Sendas cuentan como mejoras del Maestro y Stewie.
- **Objeto genérico** (elegir 1 de 3) al terminar cada escenario.
- Oro individual: cada uno ve sus monedas, con las fuentes y valores del GDD. Vasijas y cofres.

**Listo cuando:** se puede jugar del 1-1 al final del 1-3 eligiendo puertas, juntando oro, mejoras y objetos.

## Fase 6 — Birig Bamba

- Hub: asteroide con luces de neón y el Salón Beláustegui en el centro, una cantina llena de gente (NPCs placeholder).
- Fuente que cura, una vez por visita.
- **Yole Sajor:** cada jugador ve su stock de 4 objetos especiales más 1 mejora de kit, con la rareza según la visita. Volver a tirar el stock cuesta 25 y sube de a 25.
- 2 o 3 diálogos de NPCs con retrato, en español rioplatense, que cambian según el personaje.
- Oro inicial de 150. Flujo: Birig Bamba → Stage 1 → vuelta a Birig Bamba.

**Listo cuando:** se arranca en Birig Bamba, se compra, se juega el Stage 1 y se vuelve.

## Fase 7 — Boss: Gronk Gigante

- Las 3 fases del GDD:
  1. Cargas que chocan contra columnas (aturdido 3 s y +50% de daño recibido).
  2. Fase de sombra.
  3. Columnas rotas y onda circular.
- Barra de boss arriba con sus fases y el escalado por jugador.
- El Llamado Salvaje de Tali puede aturdirlo.

**Listo cuando:** la partida completa se puede ganar.

## Fase 8 — Presentación y pulido

- Pasada de iluminación y posprocesado por sala.
- Sonidos y música placeholder libres de derechos (en `CREDITS.md`).
- Intro de viñetas placeholder (30 a 60 s, se puede saltear).
- McoinIA básico al terminar la partida.
- Ajuste de números con lo que el grupo vaya testeando.
- Cambio de los placeholders por los modelos `.glb` que vayan llegando.
