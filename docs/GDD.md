# GDD — TalinortIA

Documento de diseño del juego (exportado de la biblia). Todos los números son un punto de partida para testear, no valores cerrados. Lo marcado como **Propuesta** lo armé yo y el grupo lo puede cambiar.

## Resumen y alcance

TalinortIA es un roguelike de acción en 3D para 1 a 4 jugadores en cooperativo local, hecho en Godot 4. La cámara es frontal, desde arriba en 3/4. Cada partida recorre 3 stages de 4 escenarios, con paradas en Birig Bamba entre stage y stage.

**Primera versión (decidido):**

- **Personajes:** Tali, Mercenario Croco, Agucci, y el Maestro Uwey con Stewie.
- **Lugares:** Birig Bamba (hub) y el Stage 1 completo en Talinorthland, del 1-1 al 1-4 con el Gronk Gigante.
- **Queda para después:** General Pipo, Capitán Champaka, los Stages 2 y 3, y el online.

## Controles

Se juega con teclado y mouse o con joystick, y se apunta con el mouse. La esquiva da invulnerabilidad y además tiene el efecto propio de cada personaje.

**Propuesta de mapeo:**

| Acción | Teclado y mouse | Joystick |
| --- | --- | --- |
| Moverse | WASD | Stick izquierdo |
| Apuntar | Mouse | Stick derecho (si no se usa, apunta hacia donde caminás) |
| Golpe común (mantener = continuo) | Clic izquierdo | RT / R2 |
| Habilidad fuerte | Clic derecho | LT / L2 |
| Esquiva | Espacio | A / Cruz |
| Definitiva | Q | RB / R1 |
| Relevo Total (solo Maestro y Stewie) | R | Y / Triángulo + RB / R1 |
| Interactuar y revivir (mantener) | E | X / Cuadrado |
| Pausa | Esc | Start |

**Pantalla de unión (decidido):** Enter o A para unirse, izquierda y derecha para elegir personaje, A (o Enter) para confirmar, B (o Esc) para salir, y Start (o Enter, con todos listos) para arrancar.

- **Invulnerabilidad de la esquiva:** 0,25 s al inicio del movimiento. Champaka es la excepción (ver Choques).
- **Ayuda de apuntado con joystick:** un leve imán hacia el enemigo más cercano en la dirección del stick, para que no juegue en desventaja contra el mouse.
- **Pausa:** al ser local, cualquier jugador puede pausar, y la partida se pausa sola si se desconecta un joystick.

## Estadísticas base

La regla que pidieron: **los personajes tienen menos vida que los enemigos, pero pegan mucho más.** Un enemigo común del Stage 1 tiene más vida que casi todos los personajes, pero muere en 2 a 3 segundos de golpes comunes, y en menos con habilidades. A cambio, un personaje aguanta entre 6 y 15 golpes enemigos, así que esquivar importa.

**Reglas generales (propuesta):**

- **Referencia:** Stage 1, dificultad Normal, 1 jugador, sin objetos.
- **Crítico:** 5% de chance base y 150% de daño, salvo que el personaje diga otra cosa.
- **Definitiva:** la barra se llena en unos 40 s de pelea continua, combinando el daño que hacés y el que recibís. El reparto exacto se ajusta por personaje testeando.
- **Crecimiento:** con los objetos y mejoras de una partida, el daño de un personaje debería multiplicarse por 3 o 4 entre el 1-1 y el boss final, y la vida por 1,5 a 2.

| Personaje | Rol | Vida | Velocidad (m/s) | Daño por segundo del golpe común | Crítico | Detalle |
| --- | --- | --- | --- | --- | --- | --- |
| Agucci | Asesino, movilidad y daño explosivo | 90 | 6,3 | \~77 | 15%, daño 175% | El más frágil. Su daño explota con Paso de Sombra (110 por enemigo) y la Noche (todo doble) |
| Mercenario Croco | Tirador carry, rápido | 100 | 6,6 | \~51 a 70 según el modo | 10% | El más rápido. Gana daño en toda la run con Tiro por Contrato |
| Tali | Bruiser, luchador | 150 | 5,6 | \~22 en Normal, \~92 en Furia | 5% | En Furia recibe 30% menos de daño. La Suerte esquiva el 20% de los ataques en Normal |
| Maestro Uwey + Stewie | Versátil, caster | Maestro 110, Stewie 80 / 110 / 140 según forma | Maestro 5,6, Stewie 5,8 | \~65 entre los dos | 5% | Con el Vínculo (menos de 8 m) los dos ganan 10% de daño y resistencia |
| General Pipo | Soldado táctico, daño que escala | 115 | 5,2 | \~46 | 5%, 30% dentro de su cono | Su daño real viene de torretas (20 por segundo cada una), la Marca (+20%) y el bombardeo |
| Capitán Champaka | Tanque, support, sanador | 220 | 4,8 | \~51 | 5% | Recibe 15% menos de daño siempre. Cada hongo cura 20 de vida |

**Daño por golpe, para programar:**

- **Agucci:** cortes 20 / 20 / 24, patada 14, UZI 5 balas de 6. Combo completo en \~1,4 s. Kunai 40.
- **Croco:** pistola tipo revólver, 34 por tiro (1,6 tiros/s); escopeta 7 perdigones de 10 (1 disparo/s); rifle ráfaga de 3 × 22 (1 ráfaga/s). Tiro por Contrato de 60 a 180 según la carga. Riel 120 por segundo durante 4 s.
- **Tali:** Piedrazo 18 cada 0,8 s. Zarpazos 34 / 34 / 52 cada 1,3 s. Aplastón 90 en área.
- **Maestro:** bastón 18 / 18 / 34 (onda) cada 1,4 s. Bastonazo de 60 a 120 según la carga. **Stewie:** Cabezazo 14 cada 0,9 s.
- **Pipo:** Bláster 32 cada 0,7 s. Torreta 10 por tiro, 2 tiros/s. Bombardeo 6 impactos de 90.
- **Champaka:** Manotazo 22 / 22 / 38 cada 1,6 s. Abrazo de Oso 80.

La vida de los enemigos y los bosses está calculada sobre estos valores (secciones siguientes).

## Enemigos

Cada stage tiene enemigos cuerpo a cuerpo, a distancia y de apoyo, más uno especial que define el lugar. Los valores son de Normal con 1 jugador. Todos los ataques fuertes tienen un aviso visible antes de pegar.

### Stage 1: Talinorthland

| Enemigo | Tipo | Vida | Daño | Comportamiento |
| --- | --- | --- | --- | --- |
| Talinorteano cegado | Cuerpo a cuerpo | 160 | 10 | Corre directo en grupo y pega con un palo después de 0,6 s de aviso. Lento y torpe |
| Hondero cegado | Distancia | 120 | 8 | Se queda a unos 8 m y tira piedras en parábola, con círculo de aviso donde caen |
| Soldado Agucci | Cuerpo a cuerpo | 260 | 16 | Se acerca de a poco y hace un corte con dash corto, marcado en el piso |
| Tirador Agucci | Distancia | 200 | 6 × 3 balas | Se mueve de costado y dispara ráfagas de UZI en abanico |
| Chamán de la Sombra | Apoyo | 220 | 4 por segundo en su zona | Mantiene ciegos a los Talinorteanos y los acelera un 20%. **Si lo matás, los cegados cercanos se aturden 3 s y algunos despiertan y huyen** (dan oro sin pelear) |
| Gronk | Bestia | 700 | 25 | Carga en línea recta con aviso. Si choca contra una pared queda aturdido 2 s. Atropella también a otros enemigos |

### Stage 2: Ciudades Flotantes de Uwey

| Enemigo | Tipo | Vida | Daño | Comportamiento |
| --- | --- | --- | --- | --- |
| Guardia con escudo | Cuerpo a cuerpo | 450 | 22 | El escudo frontal bloquea todo lo que viene de frente: hay que rodearlo o romperle la guardia |
| Dron de seguridad | Distancia, vuela | 160 | 12 | Sobrevuela el combate y dispara láseres cortos. Ignora los obstáculos del piso |
| Francotirador Uwey | Distancia | 220 | 35 | Marca una línea láser durante 1,5 s y después dispara un rayo que atraviesa todo |
| Ingeniero | Apoyo | 260 | 10 | Arma torretas y repara drones. Prioridad para matarlo |
| Cobrador de Deudas | Especial | 900 | 28 | Mecha de Fadied. Si te pega, te roba oro, y lo recuperás si lo matás. Guiño a la deuda de los Aguccis |

### Stage 3: Planeta Gucci

| Enemigo | Tipo | Vida | Daño | Comportamiento |
| --- | --- | --- | --- | --- |
| Guardia de palacio | Cuerpo a cuerpo | 600 | 30 | Tiene una postura de bloqueo: si le pegas mientras bloquea, te devuelve el golpe |
| Ninja del clan | Cuerpo a cuerpo, móvil | 380 | 26 | Se teletransporta por las sombras y tira shurikens antes de atacar |
| Tirador de UZI | Distancia | 420 | 10 × 4 balas | Como el del Stage 1, pero dispara mientras se mueve |
| Ritualista | Apoyo | 450 | 15 | Invoca Sombras Errantes y potencia a los Aguccis cercanos |
| Sombra Errante | Especial | 300 | 20 | Sale de las sombras largas del piso. Solo recibe daño completo cuando está en una zona iluminada |

Los Aguccis de Gucci reaccionan a la invasión: al entrar a una sala, algunos quedan sorprendidos 1 o 2 s antes de pelear, y ahí los ataques por la espalda hacen más daño.

**Élites:** cualquier enemigo puede aparecer como élite, con 2,5 veces la vida, un poco más grande y con un afijo: *Blindado* (50% menos de daño de frente), *Veloz* (+40% velocidad), *Sombrío* (deja charcos que ralentizan) o *Explosivo* (explota al morir). Uno por sala lleva la recompensa del Croco.

**Escalado por stage:** los números de las tablas ya lo incluyen. De referencia, el Stage 2 tiene unas 1,7 veces la vida y 1,5 veces el daño del Stage 1, y el Stage 3 unas 2,6 y 2 veces.

## Bosses

Cada boss tiene 3 fases, marcadas en su barra. La vida está pensada para una pelea de 2 a 3 minutos jugando solo en Normal, con el daño que un personaje debería tener a esa altura de la partida.

### Gronk Gigante (1-4)

**Vida:** 6.000. Un Gronk enorme que la sombra de los Aguccis tiene controlado.

- **Fase 1 (100% a 66%):** carga en línea recta con aviso. Si choca contra una de las columnas de la arena queda aturdido 3 s y recibe 50% más de daño: la idea es hacerlo chocar. También hace un pisotón en área y ruge para llamar a 3 o 4 Talinorteanos cegados.
- **Fase 2 (66% a 33%):** la sombra toma el control y los ojos se le ponen violetas. Encadena dos cargas, tira rocas (con círculos de aviso) y deja charcos de sombra que ralentizan.
- **Fase 3 (menos de 33%):** rompe las columnas, así que hay menos cobertura. Carga tres veces seguidas y lanza una onda de sombra en círculo con un hueco para pasar (o se atraviesa con la invulnerabilidad de la esquiva).
- **Detalles:** el Llamado Salvaje de Tali puede hacerlo dudar y aturdirlo (está en su kit). Al morir, la sombra sale de su cuerpo y se escapa: el Gronk queda libre.

### Fadied (2-4)

**Vida:** 14.000. El magnate pelea en la cima de su torre de las Ciudades Flotantes.

- **Fase 1:** está arriba de una plataforma blindada, protegido por un escudo. Ataca con drones y láseres de barrido. Para dañarlo hay que romper los 3 generadores del escudo.
- **Fase 2, "La Cobranza":** baja con un exoesqueleto. Hace dashes y tira misiles, y marca al jugador con más oro: si lo golpea, le roba oro, que vuelve si se lo saca de la fase. Si el Croco usó su definitiva, Fadied reconoce el arma (*"¿De dónde sacaste ESO?"*) y en esta fase intenta desarmarlo: si lo agarra, el Croco queda 5 s solo con la pistola.
- **Fase 3:** sobrecarga la torre. La arena se va cayendo por partes y hay que pelear saltando entre plataformas, mientras Fadied dispara un rayo que gira.

### Hermanos Agucci (3-4)

**Vida:** 24.000 entre todos. Son varios hermanos, pero no pelean todos (decidido): propuesta de 3 que pelean, de 6.000 cada uno, más la Sombra del Alto Mando de 6.000. El resto mira desde el trono. La Princesa Mia no aparece: queda para un volumen 2.

- **Fase 1:** pelean dos hermanos juntos, uno de katana y uno de UZI, con ataques combinados. Cuando uno cae, el otro se enfurece.
- **Fase 2:** entra el tercero, el místico, y la sombra se empodera. Las sombras del piso se vuelven peligrosas y los hermanos se teletransportan entre ellas.
- **Fase 3:** la sombra fusiona a los hermanos que quedan en la **Sombra del Alto Mando**, una figura gigante. Es la pelea final.
- **Si Agucci está en el equipo:** su sombra le habla durante la pelea y lo tienta a entrar en Posesión (está en su kit), y los hermanos le reclaman la deserción.

## Estructura de la partida y salas

Una partida es Birig Bamba → Stage 1 → Birig Bamba → Stage 2 → Birig Bamba → Stage 3. Cada stage tiene 4 escenarios y el cuarto es el boss.

**Escenarios y salas (decidido):** los escenarios X-1, X-2 y X-3 tienen varias salas seguidas cada uno, y el X-4 es una sola sala: la del boss. **Propuesta:** 3 salas por escenario, generadas al azar. Al terminar una sala aparecen dos puertas con el ícono de lo que hay detrás y el grupo elige por cuál seguir, como en Hades. Son unas 30 salas por partida, de 45 a 55 minutos.

### Tipos de sala

| Sala | Cómo se pasa | Premio |
| --- | --- | --- |
| Combate | Vencer a todos los enemigos, que aparecen en 2 o 3 oleadas | Oro, y en algunas una mejora de personaje (elegir 1 de 3) |
| Élite | Igual, con 1 o 2 élites y menos enemigos comunes | Mejora de personaje asegurada y más oro |
| Evento | Resolver el evento (abajo) | Un cofre de evento, que puede traer una mejora de personaje |
| Tesoro | Sin pelea, o con un guardia | Un cofre y vasijas |
| Cabaña del General Pipo | Solo en el Stage 1. Está escondida y se encuentra resolviendo un acertijo | Easter egg si jugás con Pipo. Si no, Pipo te echa, pero te deja una torreta aliada para la sala siguiente |
| Valles Antiguos | Solo en el Stage 2. Sala pacífica, sin pelea | Una fuente que cura y lore. Diálogos especiales si el Maestro está en el equipo |

### Ideas de eventos

- **Mimics:** tres cofres o vasijas iguales y uno es un mimic que ataca. Hay pistas para adivinar (uno respira, otro tiene marcas de dientes).
- **Colonia de presos:** jaulas con Talinorteanos conscientes mientras los Aguccis atacan. Cada preso liberado da oro, y si salvás a todos, un objeto extra. En el Stage 1 conecta con el lore.
- **El enemigo correcto:** entre un grupo de Talinorteanos cegados hay uno que está consciente y finge. Si lo matás perdés el premio; si lo encontrás, te da un objeto.
- **Laberinto de los Gronks:** un laberinto con Gronks dormidos. Si hacés ruido (pelear, esquivar cerca), se despiertan y cargan.
- **Braseros de sombra:** apagar 4 braseros en el orden correcto para romper la ceguera de la sala. El orden se deduce de unos dibujos en las paredes.
- **Ritmo del Bombo:** pisar baldosas al ritmo de un tambor de Birig Bamba, como un Simon dice. Sirve en cualquier stage.
- **La apuesta del Croco:** un Birigbambense te ofrece apostar oro a qué vasija tiene el premio.

### Mejoras de personaje: elegir 1 de 3 (decidido)

Son beneficios propios de cada personaje, no objetos. Salen en algunas salas de combate (la puerta lo muestra con un ícono), siempre en las de élite y en los cofres de evento. Cada jugador elige la suya en su panel. Las Sendas del Maestro y Stewie funcionan como sus mejoras.

| Personaje | Ejemplos de mejoras |
| --- | --- |
| Agucci | +1 carga de esquiva · los cortes por la espalda hacen +30% · el kunai de Paso de Sombra envenena |
| Mercenario Croco | La escopeta tira 2 perdigones más · el señuelo de Ruta de Escape explota al desaparecer · la recompensa también da 10 de vida |
| Tali | El Piedrazo rebota a un segundo enemigo · en Furia corre 15% más rápido · el Tropezón da 25 de Furia en vez de 15 |
| Maestro Uwey y Stewie | Las Sendas: Caparazón, Embestida y Espíritu para Stewie; Guía, Combate y Niebla para el Maestro |
| General Pipo | +1 torreta como máximo · Marca Táctica cada 2 tiros · el bombardeo suma 2 impactos |
| Capitán Champaka | El tercer golpe seguido da un escudo de 15 · Abrazo de Oso cura 10 a los aliados cercanos · el Panzazo deja un hongo |

### Objeto al terminar un escenario: elegir 1 de 3 (decidido)

Al pasar de un escenario al siguiente (del 1-1 al 1-2, por ejemplo), cada jugador elige 1 de 3 **objetos genéricos**, que se apilan y suben estadísticas. Son 3 por stage y 9 por partida, más lo que se compre en Birig Bamba.

| Objeto genérico | Efecto por copia |
| --- | --- |
| Piedra de afilar | +8% de daño |
| Guantes de Gronk | +8% de velocidad de ataque |
| Corazón de Gronk | +12 de vida máxima |
| Ojo de vidrio | +4% de chance de crítico |
| Colmillo filoso | +15% de daño crítico |
| Botas gastadas | +5% de velocidad de movimiento |
| Reloj Uwey | -6% de cooldown en habilidades |
| Batería robada | +10% de velocidad de carga de la definitiva |
| Vendas del Bosque Tuerto | Cura 3 de vida al terminar cada oleada |
| Escama | -4% de daño recibido |
| Moneda con agujero | +10% de oro recogido |
| Sanguijuela | +1,5% de robo de vida |

Para que no se rompa el juego, los porcentajes se suman (no se multiplican) y algunos tienen tope: cooldowns hasta -40%, daño recibido hasta -30% y robo de vida hasta 10%.

## Economía y tienda

El oro es individual. Para que nadie se pelee por las monedas, **cada jugador ve y junta sus propias monedas**, del color de su aro: cuando cae oro, cae para cada uno por separado. Así la economía de cada uno no depende de cuántos jueguen.

### De dónde sale el oro

| Fuente | Stage 1 | Stage 2 | Stage 3 |
| --- | --- | --- | --- |
| Enemigo común (40% de chance) | 2 a 4 | 4 a 7 | 7 a 11 |
| Élite (siempre) | 20 | 35 | 55 |
| Terminar un escenario | 30 | 50 | 75 |
| Vasija o recipiente | 2 a 6 | 4 a 10 | 6 a 15 |
| Cofre | 50 a 80 | 80 a 130 | 130 a 200 |
| Boss | 60 | 110 | — |

**Oro inicial:** 150, suficiente para un objeto raro o dos comunes antes del Stage 1.

**Chequeo de los precios:** como ahora hay varias salas por escenario, el oro por fuente es más bajo. Una sala de combate del Stage 1 deja unos 22, y todo el Stage 1 unos 400. Al volver a Birig Bamba después del Gronk, cada jugador debería tener entre 350 y 400: alcanza para un épico, o un raro y un común, pero no para un legendario sin ahorrar desde el principio. Los precios que propusieron (70, 150, 250 y 470) siguen funcionando.

### Yole Sajor y Birig Bamba

**Yole Sajor** es un mapache comerciante del Salón Beláustegui. Hay que hablarle para ver su mercadería.

- **Stock:** cada jugador ve sus propios 4 objetos especiales, sacados al azar, más 1 mejora de kit de su personaje (las "Mejora en Birig Bamba" de los kits), a 120.
- **Volver a tirar el stock:** 25 de oro, y sube 25 cada vez.
- **Fuente:** cura toda la vida gratis, una vez por visita.

**Chance de rareza por visita (propuesta):**

| Visita | Común (70) | Raro (150) | Épico (250) | Legendario (470) |
| --- | --- | --- | --- | --- |
| Antes del Stage 1 | 60% | 35% | 5% | 0% |
| Antes del Stage 2 | 40% | 35% | 20% | 5% |
| Antes del Stage 3 | 25% | 35% | 28% | 12% |

### Objetos especiales: ejemplos

A diferencia de los genéricos, no suben números: agregan un efecto nuevo.

| Objeto | Rareza | Efecto |
| --- | --- | --- |
| Piedra de la Suerte | Común | El golpe común tiene 8% de chance de aturdir 0,5 s |
| Bombito de Birig Bamba | Común | Al usar la definitiva, los aliados cercanos ganan 15% de velocidad por 4 s |
| Vasija sin fondo | Común | Las vasijas sueltan el doble de oro |
| Statik | Raro | Al moverte se carga una barra. Al llegar a 100, el próximo golpe común sale energizado: daño extra en cadena a 3 enemigos |
| Escama de Gronk | Raro | Al recibir un golpe cuerpo a cuerpo, devuelve 20 de daño |
| Kunai de repuesto | Raro | La esquiva deja un kunai que explota a los 0,5 s |
| Núcleo Uwey | Épico | Cada tercera habilidad no gasta cooldown |
| Espora errante | Épico | Los enemigos que matás tienen 10% de chance de dejar un hongo que cura |
| Fragmento del Crepúsculo | Legendario | Los críticos dejan un eco de sombra que repite el golpe al 50% |
| Corona del Líder Supremo | Legendario | Una vez por partida, si caés, te levantás solo con el 40% de la vida |

## Progresión entre partidas

### McoinIA

Al terminar una partida, ganes o pierdas, cobrás **McoinIA**, la moneda intergaláctica. Se puede gastar en el momento o guardar para después. Se gasta en un menú con dos columnas:

- **General (izquierda):** mejoras básicas para todos los personajes.
- **Héroe (derecha):** mejoras del personaje con el que acabás de jugar. Mejoran sus habilidades, **nunca le cambian la mecánica**.

**Cómo se gana (propuesta):** 1 por escenario superado, 2 por élite, 8 por boss y 15 extra por ganar. Se multiplica por la dificultad: Normal ×1,5 y Difícil ×2. Una partida ganada en Normal da unas 100 McoinIA; morir en el Gronk Gigante, unas 13.

| Mejora general | Efecto por nivel | Niveles | Costo |
| --- | --- | --- | --- |
| Ojo afilado | +3% de chance de crítico | 3 | 20 / 45 / 80 |
| Colmillo | +2% de robo de vida | 3 | 20 / 45 / 80 |
| Piel dura | +8 de vida máxima | 3 | 20 / 45 / 80 |
| Bolsillo profundo | +25 de oro inicial | 3 | 15 / 35 / 60 |
| Segunda opinión | Volver a tirar una recompensa de sala por partida | 2 | 40 / 90 |
| Pierna extra | +1 carga de esquiva | 1 | 150 |

El robo de vida queda en 2% por nivel y no en 10%: con 10% de base, sumado a los objetos, la curación de Champaka y de Stewie dejaría de importar.

| Personaje | Mejoras de Héroe (3 niveles cada una: 15 / 35 / 60) |
| --- | --- |
| Tali | Resaca 0,5 s más corta · +4% de Suerte · la Furia dura +1 s |
| Mercenario Croco | El bonus del primer tiro tras cambiar de modo sube a +35 / 40 / 45% · la recompensa paga +15% · Tiro por Contrato recupera +10% de cooldown al matar |
| Agucci | Lucidez llega hasta 33 / 36 / 40 de Hambre · Disolverse recorre +15% · Paso de Sombra pega +10% |
| Maestro Uwey y Stewie | Vínculo hasta 9 / 10 / 11 m · Stewie empieza con +10 de vida · Cambio con 1 s menos de cooldown |
| General Pipo | Torretas duran +2 s · Marca Táctica cada 3 tiros sube a +25% · la mina del Repliegue pega +15% |
| Capitán Champaka | Los hongos curan +10% · Abrazo de Oso retiene 0,5 s más · Floración dura +1 s |

### Kits alternativos

Cada personaje tiene un objetivo especial. Si lo cumple, desbloquea un kit alternativo que reemplaza sus habilidades por otras. Todos aprobados por el grupo.

| Personaje | Objetivo | Kit que desbloquea |
| --- | --- | --- |
| Mercenario Croco | Vencer a Fadied sin recibir daño (decidido) | **La Espada de Fadied:** una superespada también robada a Fadied, con un kit cuerpo a cuerpo |
| Tali | Vencer al Gronk Gigante sin entrar en Furia | **Domador:** un Gronk pequeño lo acompaña y pelea con él |
| Agucci | Ganar una partida sin entrar nunca en Posesión | **Hoja de Lucidez:** sin sombra, katana pura con críticos más fuertes |
| Maestro Uwey y Stewie | Llevar a Stewie a su forma Sabia antes del Stage 2 | **El Aprendiz Supera al Maestro:** Stewie pasa a ser el personaje principal |
| General Pipo | Ganar una partida con 3 torretas activas en el boss final | **Comando de la Flota:** pide refuerzos Pipo en lugar de torretas |
| Capitán Champaka | Revivir 10 veces a aliados en una partida | **Micólogo:** hongos ofensivos en lugar de curativos |

## Agucci: habilidades durante la Posesión

Aprobado por el grupo. Durante la Posesión, la habilidad fuerte y la esquiva se reemplazan por estas dos. Cada una cuesta 5% de la vida actual y, si conecta, cura 8% del daño que hace:

- **Mordida de Sombra (en lugar de la habilidad fuerte):** un dash corto que atraviesa al enemigo y lo corta dos veces. Si lo mata, se reinicia al instante, para encadenar asesinatos.
- **Abrazo del Valle sin Luz (en lugar de la esquiva):** la sombra se expande, tira hacia Agucci a los enemigos cercanos y les drena vida durante 1 s. Sirve para entrar y borrar a un grupo.

## Co-op local y dificultad

### Reglas de grupo (decidido)

- De 1 a 4 jugadores en la misma pantalla. Para jugar desde casas distintas, Remote Play Together.
- No se puede repetir personaje, no hay fuego amigo, y nadie puede sumarse ni irse a mitad de partida.
- El oro y las mejoras son individuales: cada uno elige y compra en su propio panel.

### Cámara compartida

La cámara encuadra a todos los jugadores y se aleja un poco cuando se separan. Si alguien llega al borde del cuadro, el borde lo frena: no puede seguir alejándose. **Propuesta de límite:** la cámara se aleja como máximo un 12%, para que un personaje nunca mida menos de unos 64 píxeles en pantalla.

### Muerte y revivir

- Cuando un jugador cae, tiene un tiempo para que lo levanten. Para revivirlo, un compañero se acerca y mantiene el botón de interactuar durante 5 s.
- **Tiempo para levantarlo (propuesta):** 25 s la primera caída, 19 s la segunda, 13 s la tercera y 8 s desde la cuarta en adelante.
- **Decidido:** el caído se arrastra solo, despacio, hacia sus compañeros. **Propuesta:** el que revive no puede atacar mientras lo hace. La Floración de Champaka revive al instante, como dice su kit.
- Si se acaba el tiempo, ese jugador queda afuera hasta el final del stage y vuelve en Birig Bamba con 40% de vida, sin poder curarse en la fuente (decidido). Si caen todos, termina la partida.
- **Jugando solo:** si caés, termina la partida, salvo que tengas algo que te levante (la Corona del Líder Supremo o una mejora).

### Dificultad

Antes de cada partida se elige la dificultad base. **Desbloqueo (aprobado):** Fácil desde el principio, Normal al vencer al Gronk Gigante una vez, y Difícil al ganar una partida completa en Normal. Mientras se desarrolla, un flag de debug las desbloquea todas.

| Dificultad | Vida de enemigos | Daño de enemigos | Extras |
| --- | --- | --- | --- |
| Fácil | ×0,8 | ×0,7 | +10 s para revivir |
| Normal | ×1 | ×1 | — |
| Difícil | ×1,5 | ×1,7 | Los élites tienen 2 afijos y los bosses agregan un ataque por fase. Además (pedido del grupo, para que sea difícil de verdad): 30% más de enemigos, 15% más rápidos, avisos 20% más cortos, atacan 25% más seguido y 1 élite extra por oleada |

**Escalado por jugador extra**, según la dificultad elegida:

| Dificultad | Vida de enemigos comunes | Cantidad de enemigos | Vida de bosses |
| --- | --- | --- | --- |
| Fácil | +35% | +20% | +60% |
| Normal | +45% | +25% | +70% |
| Difícil | +55% | +30% | +80% |

Por ejemplo, con 4 jugadores en Normal, un Talinorteano cegado tiene 160 × 2,35 = 376 de vida, hay 75% más de enemigos por sala, y el Gronk Gigante tiene 6.000 × 3,1 = 18.600. El daño de los enemigos no escala con los jugadores: con más gente, cada uno sigue recibiendo los mismos golpes.

## Presentación

Lo marcado **Decidido** no se discute. Lo marcado **Recomendado** es la propuesta de partida; donde lo ajusté, lo explico en Choques.

### Cámara (decidido)

- Cámara frontal, desde arriba en 3/4: mira hacia el norte, inclinada unos 55°, con FOV bajo (30 a 35). Las paredes de las salas quedan alineadas con la pantalla. **No** se usa isométrica rotada 45°.
- A la distancia de juego, un personaje mide 70 a 80 píxeles de alto. Todo lo visual se diseña para leerse a ese tamaño.
- El mockup del HUD está en isométrica y hay que adaptarlo a esta cámara.

### 1. Estilo visual: estilizado semirrealista (decidido)

**Qué es:** proporciones apenas exageradas y formas claras, con materiales que se leen como reales: el metal brilla, la tela parece tela, la piel tiene textura y la piedra tiene relieve. Referencias: Ravenswatch, Torchlight, V Rising y Diablo III. No Diablo IV (demasiado realista) ni low poly plano. Se probó en Godot contra low poly y ganó el semirrealista.

**Legibilidad en co-op (decidido):** contorno muy finito solo en personajes y enemigos, más un aro del color del jugador (P1 a P4) bajo los pies. Sin eso, los personajes se perdían contra el pasto.

**Cómo se logra (recomendado):**

- **Iluminación y posprocesado en Godot 4 (Forward+):** sol cálido con sombras suaves, oclusión ambiental (SSAO), iluminación indirecta (SSIL), glow en efectos y hongos, niebla leve de distancia, tonemap ACES y un poco más de contraste y saturación. Es lo que más rinde por menos esfuerzo, y con la cámara fija cada escenario se puede pulir a mano.
- **Escenario:** pasto con MultiMesh (miles de briznas con variación de color), tierra con bordes suaves (decals), y rocas y árboles con texturas de relieve.
- **Personajes:** de 5.000 a 15.000 triángulos, modelados en Blender y texturizados con ArmorPaint o Substance Painter. Textura pintada, brillo real en metal y cuero, y un rim light suave.
- **Enemigos:** colores más apagados que los jugadores.
- **Colores reservados (agregado):** cada color significa una sola cosa en todo el juego. Colores de jugador (decidido): P1 azul, P2 rojo, P3 verde lima y P4 amarillo. Como P2 es rojo, los avisos de ataque enemigo pasan a naranja intenso con borde blanco y un relleno que avanza hasta el golpe. Violeta = sombra. Verde agua = curación. Dorado = oro y recompensa, siempre con brillo y forma de moneda o rombo, para no confundirse con el amarillo de P4.
- **Paleta por planeta:** Talinorthland en verdes y tierra con luz cálida. Uwey con piedra y dorado en los Valles Antiguos, contra blanco y celeste tecnológico en las Ciudades Flotantes. Gucci en crepúsculo eterno, violeta con sombras larguísimas. Birig Bamba (decidido): luces de neón sobre la roca del asteroide, con el Salón Beláustegui en el centro. El Salón es una cantina repleta de gente de todas las especies, inspirada en la Cantina de Mos Eisley.
- **Assets de escenario:** packs gratis de uso libre (KayKit, Quaternius) combinados con texturas realistas gratis (Poly Haven) para llegar al punto intermedio. Los personajes los hacen ustedes.
- **Animaciones:** Mixamo para los humanoides. Tali en Furia, Stewie y los Gronks necesitan animación propia.
- **Licencias:** los diseños actuales de HeroForge (o similar) sirven como concept, pero hasta donde saben no permiten usarse en un juego comercial. Los modelos finales se hacen en Blender.

### 2. Interfaz (recomendado)

- **Base:** el mockup. Un panel por jugador abajo (4 como máximo), la barra del boss arriba con sus fases y el rombo de recompensa sobre el élite.
- **Principio:** lo importante también se ve sobre el personaje, no solo en el panel, porque en la pelea nadie mira abajo.
- **Color de jugador:** se repite en el aro bajo los pies, el panel y los efectos. Es del jugador, no del personaje.
- **Nombres:** sin carteles fijos sobre la cabeza. El nombre aparece al empezar la sala, al revivir y cuando el personaje queda tapado por algo del escenario (ver Choques).
- **Barra propia de cada personaje,** siempre en el segundo renglón del panel:
  - **Furia (Tali):** barra naranja que se pone roja y late al llenarse. En el mundo, un aura **rojo-ocre** (decidido) que crece alrededor de Tali.
  - **Hambre (Agucci):** barra dividida en tres zonas: Lucidez (0–30), Hambre (31–99) y Posesión (100). En el mundo, su sombra en el piso se agranda.
  - **Relevo (Maestro y Stewie):** dos mini retratos con el que se controla resaltado, más la barra de Relevo Total. En el mundo, una línea suave que los une cuando están dentro del Vínculo (8 m).
  - **Arma (Croco):** chips de modo (Escopeta, Pistola, Rifle), como en el mockup.
  - **Esporas (Champaka):** barra de esporas con la cantidad de hongos.
- **Vida:** en los paneles, más una barrita sobre el personaje que aparece solo cuando recibe daño.
- **Recompensa del Croco:** rombo sobre el élite marcado, y un "+oro" dorado que vuela al panel del Croco cuando la cobra.
- **Cooldowns:** el número va encima del ícono de la habilidad, no al lado del nombre (en el mockup se pisan).
- **Oro:** individual, confirmado. El oro de cada panel es de ese jugador.
- **Estilo:** paneles limpios y legibles, que no compitan con la escena semirrealista.

### 3. Audio (recomendado)

- **Música:** un tema por stage con dos capas (exploración y combate) que se mezclan según la pelea, más un tema para cada boss. Se usa música libre de derechos elegida según el contexto (decidido).
  - **Talinorthland:** percusión tribal medio torpe.
  - **Uwey:** la dualidad del planeta, con flautas en los Valles y sintetizadores en las Ciudades Flotantes.
  - **Gucci:** oscuro, con susurros de sombras.
  - **Birig Bamba:** el asteroide late como un tambor, así que el hub tiene un ritmo constante que se escucha en todo, hasta en los pasos. En el Salón Beláustegui suena música de cantina (ver Choques).
- **Voces:** frases cortas, no diálogos largos. En los cuadros de diálogo, voz inventada tipo balbuceo (estilo Animal Crossing o Banjo-Kazooie): barata, graciosa y acorde al tono.
- **Frases grabadas por ustedes:** cada personaje está basado en un integrante del grupo, y cada uno graba las frases del suyo.
- **Cuándo suenan:** al tirar la definitiva, al matar un élite, con poca vida y en cruces entre personajes (por ejemplo, el Croco: *"Esto lo cobro doble"*). Con límite de frecuencia para que no cansen. **Propuesta:** como máximo una frase cada 8 s por personaje, y nunca dos a la vez entre los 4 jugadores.

### 4. Narrativa en el juego (recomendado)

- **Modelo Hades:** poquito, pero todo el tiempo. Todos los textos y frases en español rioplatense, como el lore (decidido).
- **Intro:** 30 a 60 segundos de viñetas tipo cómic, desde el rescate de Tali hasta la llegada a Birig Bamba. El Croco es el que junta al equipo, con una viñeta por personaje y su motivo (decidido): Tali y Champaka por la historia que ya tienen; Agucci quiere dejar de servir al Alto Mando; el Maestro y Stewie no quieren ver ganar a Fadied; y el General Pipo quiere ayudar a Talinorthland en secreto. Se ve la primera vez y después se puede saltear.
- **Birig Bamba es el corazón:** NPCs con cuadro de texto y retrato, que dicen cosas distintas según el personaje elegido y la cantidad de partidas. Así morir no frustra, porque al volver hay algo nuevo. Con 4 jugadores, el NPC le habla al personaje que interactúa.
- **Final:** al menos una escena contra los Hermanos Agucci, con variantes según quién esté en el equipo (ver Choques).
- **Primer prototipo:** alcanza con la intro y 2 o 3 diálogos en Birig Bamba.

## Choques y alternativas

Lo que en Presentación choca con el lore, los kits o el co-op de 4 jugadores, con una alternativa para cada caso. Los primeros afectan a la primera versión.

| Qué choca | Con qué | Alternativa |
| --- | --- | --- |
| P2 rojo | Avisos de ataque enemigo en rojo | Los avisos pasan a naranja intenso con borde blanco y relleno que avanza (ya aplicado en Presentación) |
| P4 amarillo | El dorado del oro y de la recompensa del Croco | El oro siempre como moneda con brillo, y la recompensa como rombo. Probar en pantalla que no se confundan con el aro amarillo |
| Aura de Furia de Tali | El naranja reservado para los avisos enemigos | El aura es rojo-ocre (decidido) |
| Canción de la Cantina de Mos Eisley en el Salón | Es música con derechos de autor, y el resto del juego usa música libre | No la puedo agregar al proyecto, y no se puede usar si el juego se publica. Propuesta: un tema libre de derechos de jazz o swing de cantina, que da la misma sensación. Inspirarse visualmente en la cantina (un bar lleno de especies raras) no tiene problema |
| Modelo de Fadied | Godot necesita modelos con mallas y esqueleto | El archivo es un Gaussian splat: una nube de 262.000 puntos de color, sin triángulos ni esqueleto. Sirve como referencia visual, pero no se puede animar en el juego. Hace falta el mismo modelo como malla (.glb, .fbx u .obj), en pose de T o de A y sin la base, para poder riggearlo |
| La cámara que se aleja | Personajes de 70 a 80 px | Alejarse como máximo un 12% (nunca menos de \~64 px) y diseñar las salas para que entren en cuadro con ese límite |
| Nombre "cuando el jugador sale de cuadro" | La cámara no deja salir a nadie | Mostrar el nombre al empezar la sala, al revivir y cuando queda tapado. Con cámara a 55°, las paredes del sur tapan personajes: esas paredes se cortan o se vuelven transparentes, y el personaje tapado se ve como silueta del color de su jugador |
| Paneles abajo | La parte de abajo de la sala, que con cámara frontal queda cerca de los paneles | Dejar un margen libre abajo en cada sala, y que un panel se vuelva semitransparente si un personaje pasa por detrás |
| Teclado y mouse | Co-op local en una sola compu | Solo un jugador puede usar teclado y mouse; los demás, joystick. Con Remote Play pasa lo mismo, porque todo entra a la compu del anfitrión: los invitados juegan con joystick |
| Iluminación Forward+ con SSIL, glow y pasto con MultiMesh | Remote Play, donde la compu del anfitrión dibuja y además transmite | Tener presets de calidad (bajo, medio, alto) desde el principio y probar en la compu más floja del grupo. Forward+ necesita una placa de video relativamente moderna |
| Violeta y sombras largas en Gucci | La sombra de Agucci que se agranda, los charcos de sombra y la Sombra Errante | Las sombras con mecánica tienen borde brillante y partículas, para distinguirlas de las del escenario |
| Colores por personaje en el mockup | Color por jugador (decidido) | Adaptar el mockup: el color de cada panel y aro sale del jugador (P1 a P4), no del personaje |
| KayKit y Quaternius, que son low poly estilizado | Texturas realistas de Poly Haven | Pueden quedar desparejos. Usarlos para la estructura y los objetos de fondo, cambiarles los materiales por los de Poly Haven y unificar con la iluminación |
| Mixamo para humanoides | Personajes que no son humanos estándar | Mixamo sirve para cuerpos de dos piernas con proporciones humanas. Capas (como la de Fadied), colas o un bastón de apoyo necesitan ajustes propios |
| Easter egg de la cabaña "en Birig Bamba" | En el lore, la cabaña está en el Bosque Tuerto de Talinorthland | Va como sala secreta del Stage 1. En Birig Bamba se puede dejar una pista para encontrarla |
| Final con la sombra de Agucci hablando | Agucci puede no estar en el equipo | Si no está, los Hermanos hablan de él como desertor, o la sombra intenta tentar a Tali, que la calma |
| Punto ciego de Pipo: "la pantalla se oscurece en ese borde" | Pantalla compartida: oscurecería la pantalla de todos | Dibujar en el mundo un cono oscuro a la izquierda de Pipo. No entra en la primera versión |
| "La esquiva da invulnerabilidad" | Panzazo de Champaka: el kit dice que no la da | Mantener la excepción y compensarla con 40% menos de daño durante el Panzazo. No entra en la primera versión |

## Preguntas abiertas

**Para cerrar Presentación:**

- [ ] **Modelos de los personajes:** ¿pueden conseguir cada modelo como malla (.glb, .fbx u .obj) en pose de T o de A? Fadied llegó como Gaussian splat (ver Choques).
- [ ] **Quién riggea y anima:** Mixamo cubre a los humanoides, pero Tali en Furia, Stewie, los Gronks y las capas necesitan trabajo en Blender.
- [ ] **Tema del Salón Beláustegui:** ¿aceptan un tema libre de derechos estilo cantina en lugar de la canción original?

**Para el resto del GDD:**

- [ ] **Salas por escenario:** ¿3 salas por escenario les parece bien? Una partida quedaría en 45 a 55 minutos.
- [ ] **Hermanos Agucci:** ¿les sirve que peleen 3 (katana, UZI y místico) y el resto mire desde el trono?
