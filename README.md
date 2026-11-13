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
