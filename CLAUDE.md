# TalinortIA — Instrucciones para Claude Code

Roguelike de acción 3D en Godot, cooperativo local de 1 a 4 jugadores, hecho por un grupo de amigos para jugar entre ellos. Cada personaje está basado en uno de nosotros. Prioridad número uno: **que se sienta bien jugar** (fluido, con respuesta inmediata y buen "feel" al pegar).

## Documentos (fuente de verdad, en este orden)

1. `docs/GDD.md`: diseño completo. Números, enemigos, bosses, salas, economía, co-op, presentación.
2. `docs/KITS_MVP.md`: kits de los 4 personajes de la primera versión, con daño por golpe.
3. `docs/PLAN_MVP.md`: fases del MVP y qué tiene que funcionar al final de cada una.
4. `docs/LORE.md`: resumen del lore, para nombres, textos y tono.
5. `docs/referencias/`: imágenes de referencia de estilo (usamos la opción **B, semirrealista**).

Reglas:
- **No inventes diseño.** Si algo no está en los docs, preguntá antes de decidir. Si tenés que asumir algo para seguir, dejalo anotado en `docs/DECISIONES.md` con la fecha.
- Lo marcado como **decidido** en el GDD no se cambia. Lo marcado como **propuesta** se puede ajustar, explicando por qué.
- Si un cambio contradice el GDD, avisá primero.

## Tecnología

- **Godot 4.7** (la última 4.x estable), versión estándar con **GDScript** (no .NET).
- Ejecutable en esta compu: `C:\Users\USUARIO\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe` (para la consola, `Godot_v4.7.2-stable_win64_console.exe` en la misma carpeta).
- Renderer **Forward+**. Objetivo: 60 fps a 1080p en una PC media. Presets de calidad (bajo, medio, alto) desde el principio, porque se va a jugar por Remote Play y la compu del anfitrión dibuja y transmite a la vez.
- GDScript **tipado** (`var vida: float`, `func recibir_danio(cantidad: float) -> void`).
- Control de versiones con git. Commits chicos, uno por cambio que funciona.

## Arquitectura

- **Datos separados del código.** Todos los números del GDD (vida, daño, cooldowns, precios, escalado) van en archivos de datos (`Resource` `.tres` o JSON en `data/`), nunca hardcodeados en scripts. El grupo los va a ajustar testeando.
- **Personajes por componentes:** `HealthComponent`, `Hitbox` y `Hurtbox`, `AbilityComponent` (una por hueco: golpe común, habilidad fuerte, esquiva, definitiva), `StatusEffects` y una máquina de estados para el movimiento.
- **Autoloads:**
  - `Events`: bus de señales global.
  - `RunState`: oro por jugador, objetos, mejoras, escenario actual.
  - `PlayerManager`: dispositivos, colores P1 a P4 y personaje elegido por cada jugador.
  - `Balance`: carga los datos.
  - `GameSettings`: presets de calidad y flags de debug.
- **Estructura de carpetas propuesta:** `scenes/` (personajes, enemigos, salas, ui, hub), `scripts/`, `data/`, `assets/` (modelos, texturas, audio, shaders), `docs/`.
- **Salas** como escenas plantilla que se eligen y se pueblan al azar, con una semilla por partida para poder reproducir errores.

## Co-op local y controles

- De 1 a 4 jugadores en la misma pantalla. Pantalla de "apretá un botón para unirte", sin repetir personaje.
- Como máximo **un** jugador con teclado y mouse; el resto, joystick. Hay que leer los eventos por dispositivo (`InputEvent.device`), porque el `InputMap` de Godot no separa joysticks por sí solo.
- Apuntado: con mouse, raycast al plano del piso. Con joystick, stick derecho con un leve imán al enemigo más cercano en esa dirección; si no se usa el stick derecho, se apunta hacia donde se camina.
- El mapeo de botones está en el GDD, sección Controles.
- No hay fuego amigo, nadie entra ni sale a mitad de partida, y la pausa sirve para todos. Si se desconecta un joystick, se pausa.

## Cámara (decidido, no cambiar)

- Frontal, desde arriba en 3/4: mira hacia el norte, inclinada unos 55°, FOV de 30 a 35. Las paredes de las salas quedan alineadas con la pantalla. **No** es isométrica rotada 45°.
- Encuadra el centro del grupo y se aleja como máximo un 12% cuando se separan. Los jugadores no pueden salir del cuadro: el borde los frena.
- A la distancia de juego, un personaje mide de 70 a 80 px de alto (nunca menos de ~64 px).

## Estilo visual (decidido)

- **Estilizado semirrealista** (referencias: Ravenswatch, Torchlight, V Rising, Diablo III). Ver `docs/referencias/`.
- `WorldEnvironment`: tonemap ACES, SSAO, SSIL, glow en efectos, niebla leve, un poco más de contraste y saturación. Pasto con MultiMesh.
- Legibilidad: contorno finito solo en personajes y enemigos, más un aro del color del jugador bajo los pies.
- **Colores de jugador:** P1 azul, P2 rojo, P3 verde lima, P4 amarillo.
- **Colores reservados:** avisos de ataque enemigo en naranja intenso con borde blanco y relleno que avanza (nunca rojo ni violeta). Violeta = sombra. Verde agua = curación. Dorado = oro y recompensa (moneda con brillo o rombo).
- Enemigos con colores más apagados que los jugadores.
- Mientras no haya modelos finales, se usan **placeholders** (cápsulas o formas simples con el color del jugador), pero con el entorno y la iluminación ya semirrealistas.

## Assets y licencias

- Solo assets de uso libre (CC0) o hechos por nosotros: KayKit, Quaternius, Poly Haven, música libre de derechos. Anotá cada asset de terceros en `CREDITS.md`.
- Nada de HeroForge en el juego, ni música o arte con derechos de autor.
- Los modelos de personajes llegan como `.glb` desde Blender. Un Gaussian splat (`.ply` con `f_dc` y `opacity`) **no** sirve como modelo del juego.

## Textos

- Todo el texto del juego en **español rioplatense** (vos, tenés, querés), con el tono del lore: humor, nada solemne.
- Nombres de código, variables y archivos en inglés. Comentarios en español.

## Cómo trabajar

- **Pasos chicos.** Una cosa por vez, y después de cada cambio corré el proyecto para ver que no se rompió nada: `godot --headless --quit` para detectar errores de scripts, y una escena de prueba para lo jugable.
- Tests de lógica pura con GUT (`addons/gut`): `Godot_..._console.exe --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`.
- Al terminar cada tarea, explicá en pocas líneas qué hiciste y cómo probarlo (qué escena abrir y qué botones apretar).
- Lógica pura (cálculo de daño, economía, escalado) con tests si se puede (GUT).
- **Feel primero:** respuesta inmediata al input, hitstop corto al pegar, sacudida de cámara, flash al recibir daño, números de daño, cancelar animaciones con la esquiva. Ante la duda, priorizá que se sienta bien.
- No optimices antes de tiempo, pero no generes miles de nodos por frame: usá pools para proyectiles y números de daño.
- La carpeta también es una bóveda de Obsidian: `.obsidian/` no se toca, y `docs/` tiene un `.gdignore` para que Godot no la importe.
