# TalinortIA

Roguelike de acción 3D para 1 a 4 jugadores en cooperativo local, hecho en Godot.

## Preparar la compu (una sola vez)

1. **Godot 4.7, versión estándar** (no la .NET), desde godotengine.org. Es un ejecutable, no se instala.
2. **Git**, y una cuenta de GitHub para compartir el repositorio entre todos.
3. **Visual Studio Code** con estas extensiones:
   - **Claude Code**.
   - **godot-tools**: autocompletado de GDScript. En Godot, activá *Editor > Editor Settings > Text Editor > External > Use External Editor* y apuntalo a VS Code.
4. Creá una carpeta para el proyecto, copiá adentro todo este kit (este README, `CLAUDE.md`, `PROMPT_INICIAL.md` y `docs/`) y abrila en VS Code.
5. Iniciá git (`git init`) y subilo a un repositorio privado de GitHub para que los demás lo puedan clonar.

## Empezar

Abrí Claude Code en VS Code y pegá el **primer mensaje** de `PROMPT_INICIAL.md`.

## Qué hay en el kit

| Archivo | Para qué sirve |
| --- | --- |
| `CLAUDE.md` | Reglas del proyecto. Claude Code lo lee solo en cada conversación |
| `PROMPT_INICIAL.md` | Mensajes para copiar y pegar en cada etapa |
| `docs/PLAN_MVP.md` | Las 9 fases del MVP: Stage 1 completo con Birig Bamba |
| `docs/GDD.md` | Diseño completo del juego |
| `docs/KITS_MVP.md` | Kits de Tali, Croco, Agucci y el Maestro con Stewie |
| `docs/LORE.md` | Resumen del lore para los textos del juego |
| `docs/DECISIONES.md` | Registro de decisiones con fecha |
| `docs/referencias/` | Imágenes de estilo (va el B, semirrealista) y la vista previa del modelo de Fadied |

La biblia completa (lore, los 6 kits y el GDD) sigue en el doc compartido. Si cambian algo importante ahí, actualicen también `docs/` para que Claude Code lo sepa.

## Probar el juego

- **Desde el editor:** abrí el proyecto en Godot y apretá **F5**. Arranca en la pantalla de unión y de ahí a una sala de combate (3 oleadas, se gana o se pierde).
- **Sala de prueba (enemigos infinitos, te levantás solo):** abrí `scenes/rooms/test_room_talinorthland.tscn` y apretá **F6**. Se unen solos el teclado y todos los joysticks conectados.
- **Tests:** en Godot, panel **GUT** (abajo) > *Run All*. Desde la consola:
  `Godot_v4.7.2-stable_win64_console.exe --headless --path . -s addons/gut/gut_cmdln.gd`

| En la pantalla de unión | Teclado | Joystick |
| --- | --- | --- |
| Unirse | Enter | A / Cruz |
| Elegir personaje | A y D, o flechas | Cruceta o stick izquierdo |
| Confirmar | Enter | A / Cruz |
| Desconfirmar o salir | Esc | B / Círculo |
| Arrancar (con todos listos) | Enter | Start |
| Cambiar la dificultad | E | X / Cuadrado |

| En la sala | Teclado y mouse | Joystick |
| --- | --- | --- |
| Moverse | WASD | Stick izquierdo |
| Apuntar | Mouse | Stick derecho (si no, hacia donde caminás) |
| Golpe común (mantener = continuo) | Clic izquierdo | RT / R2 |
| Habilidad fuerte | Clic derecho | LT / L2 |
| Esquiva | Espacio | A / Cruz |
| Definitiva (el Maestro: Cambio) | Q | RB / R1 |
| Relevo Total (solo Maestro y Stewie, barra llena) | R | Y / Triángulo + RB / R1 |
| Revivir (mantener al lado del caído) | E | X / Cuadrado |
| Pausa | Esc | Start |
| Volver a la pantalla de unión (en pausa) | Retroceso | B / Círculo |
| Calidad baja / media / alta | F1 / F2 / F3 | — |
| Mostrar u ocultar datos de debug | F4 | — |
| Pantalla completa | F11 | — |
| Un enemigo más / menos / matar a todos | F7 / F8 / F9 | — |
