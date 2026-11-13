# Prompts para Claude Code

## 1. Primer mensaje (copiar y pegar tal cual)

```
Hola. Vamos a hacer TalinortIA, un roguelike de acción 3D en Godot 4.7 para 1 a 4 jugadores en cooperativo local.

Antes de escribir código, leé todo esto:
- CLAUDE.md (las reglas del proyecto)
- docs/PLAN_MVP.md (las fases)
- docs/GDD.md (el diseño completo)
- docs/KITS_MVP.md (los kits de los 4 personajes)
- docs/LORE.md (el tono y los nombres)
- y mirá las imágenes de docs/referencias/ (usamos el estilo B, semirrealista)

Después:
1. Resumime en 10 líneas qué entendiste del juego y del MVP.
2. Decime qué dudas o contradicciones encontraste en los documentos.
3. Proponé el plan detallado de la Fase 0: archivos, escenas, autoloads y en qué orden los vas a crear.

No escribas código todavía. Esperá a que aprobemos el plan.
```

## 2. Arrancar una fase (cuando aprobaron el plan)

```
Aprobado. Hacé la Fase N de docs/PLAN_MVP.md, de a un paso por vez.
Después de cada paso, corré el proyecto para ver que no haya errores y hacé un commit.
Al terminar la fase, decime cómo probarla: qué escena abrir y qué botones apretar.
```

## 3. Cuando algo no se siente bien

```
Probamos [tal cosa] y [qué pasa / qué se siente mal].
Lo que queremos es [cómo debería sentirse], como en [Hades / Ravenswatch / etc.].
Antes de cambiar código, decime qué creés que lo causa y qué vas a cambiar.
```

## 4. Cuando cambia una decisión de diseño

```
Cambiamos esto del diseño: [cambio].
Actualizá docs/GDD.md (o el doc que corresponda) y anotalo en docs/DECISIONES.md con la fecha.
Después ajustá el código y los datos que dependan de eso.
```

## 5. Cuando llega un modelo nuevo

```
Agregué assets/models/[personaje].glb. Reemplazá el placeholder de [personaje] por este modelo,
manteniendo el aro del color del jugador y el contorno. Si el modelo tiene animaciones, conectalas
a la máquina de estados. Si falta alguna, dejá el placeholder de animación y avisame cuál.
```

## Consejos

- **Una fase por vez.** No le pidas "hacé el juego entero".
- **Prueben después de cada fase**, idealmente con 2 o más jugadores, y cuéntenle a Claude Code qué sintieron.
- **Si una conversación se hace muy larga**, empiecen una nueva con: *"Leé CLAUDE.md y docs/PLAN_MVP.md. Estamos en la Fase N; lo último que hicimos fue [X]."*
- **Los números se ajustan en `data/`, no en el código.** Si algo pega muy fuerte o muy suave, pídanle que lo cambie ahí.
