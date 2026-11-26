# LAST IMPACT — Backlog maestro y criterios de aceptación
Fecha de auditoría: 2026-11-26. Baseline: r0754-volume / e90ee74c036b15712378d264fa6b9fb31d97c640. [CI 74](https://github.com/nicolasandinoleites-sketch/Last-impact-battle-royale-/actions/runs/45838254472) exitosa. Estado: [x] verificado; [ ] pendiente. La numeración es planificada, no promesa de entrega ni fecha. P0 bloqueante; P1 núcleo; P2 extensión; P3 escalado. Cada tarea requiere evidencia y changelog. R07.5.4 no validada en teléfono físico en esta auditoría.

## F0 — Control técnico y calidad (P0)
- [x] QA-00 Verificar baseline, motor, paquete y export ARM mediante CI 74.
- [ ] QA-01 Descargar APK R0754, comprobar SHA-256, firma, ABI, versionCode y actualización sin perder guardados; registrar artefacto. **Parcial:** CI 74, artefacto 15125209899; SHA-256 6821281d3c7ea20680430426947b933c69dc9933a159e030840719e65a8b545d verificado en archivo extraído, ARM64/ARMv7, firmas v2/v3 en CI, versionCode 19. Actualización física y conservación de preferencias pendientes.
- [ ] QA-02 Crear prueba física repetible de 15 min, mismo dispositivo, semilla, perfil y recorrido; registrar modelo/OS/temperatura. **Protocolo documentado:** docs/QA_DEVICE_PROTOCOL.md. Video físico R0755 1000013433.mp4 (88.96 s), 11 muestras HUD cada 8 s: FPS 17,21,22,20,22,27,23,24,25,22,22; P95 50–61 ms, 1% low 15–18 FPS, memoria estática 39 MB. No es prueba de 15 min; perfil y temperatura sin confirmar.
- [ ] QA-03 Instrumentar mediana, p95/p99 de frame time, FPS promedio y 1% low; registrar CPU/GPU, draw calls, triángulos y PSS/RSS donde disponibles. **En desarrollo:** R0755, scripts/frame_telemetry.gd, test percentiles y separación de perfiles; CI 79 aprobada: percentiles y separación de perfiles, JSON Android validado. APK R0755 artefacto 15130862380, SHA-256 384b9a4fb7fbd06db1ef60eafad0427efee64d22d5381b7dd237d906d98ab67f comprobado. Emulador x86_64, perfil 0: 40 intervalos, 10280.924 ms, 3.8907 FPS, mediana 237.1105 ms, p95 335.388 ms, p99 612.651 ms, 1% low 1.6323 FPS, 228 draw calls, 64574 primitivas, 36.8322 MB estática. Intervalo de proceso no equivale a tiempo GPU ni presentación Android; primitivas no son exclusivamente triángulos. PSS/RSS via ADB, CPU/GPU y térmica física pendientes.
- [ ] QA-04 Automatizar ADB: joystick, cámara, apuntado, fuego, recarga, salto, deslizamiento, botín, perfil, pausa/retorno, multitouch cuando el entorno lo permita. No afirmar multitouch si solo se prueba un dedo. **R0756: CI 82 fallida en entrada a partida por ANR externo de Pixel Launcher (captura 01_lobby y window.xml, artefacto 15131899952).** Fixtures touch aprobadas (desplazamiento, slide, disparo, recarga, apuntado, salto, loot, curación). Corrección de launcher específico validada en CI 85 (45856660342): ADB SHOT, RELOAD_COMPLETE, AIM_ON/OFF, JUMP, MOVE_RELEASE, LOOK_RELEASE, SHOULDER; emulador PASS. APK R0756 artefacto 15136875788, SHA-256 6877b62021a1b7ac4f8c71632e46c212c035b6bbd17e055e47a0171ca2a952f4 verificado, ARM64/ARMv7, firma v2/v3 según CI. ADB joystick, mirada, disparo real, recarga efectiva, apuntado, salto, hombro y retorno lobby; fixtures de eventos Godot verifican slide con dos índices, pickup cercano, curación y liberación. No son multitouch físico. ADB recogida, cambio de perfil, pausa/reanudación y prueba física aún pendientes.
- [ ] QA-05 Crear comparación visual de cámaras y semillas fijas, más capturas antes/dentro/después de la tormenta y de cada sector.
- [ ] QA-06 Matriz bajo/medio/alto + Compatibility, emulador Android, teléfono físico ARM. Agregar backend Mobile opcional solo tras prueba Vulkan.
- [ ] QA-07 Prueba de reinicio 10 rondas, lobby, foco, suspensión y reanudación sin controles pegados ni crashes.
- [ ] QA-08 Mantener exportación APK debug firmada, SHA-256 y changelog; excluir tests, fuentes de producción y secretos del paquete. Mantener versión de respaldo.
- [ ] ARC-01 Separar datos de ronda, input y simulación autoritativa de presentación. Contratos para comandos, entidades, daño e inventario. No crear aún backend público.
Puerta F0: pruebas automáticas reproducibles, baseline físico medido, APK con integridad y evidencia.

## F1 — R07.5.x: tormenta y rendimiento (P0, depende de F0)
- [ ] STM-01 Validar R0754 en teléfono: centro, 10/5/0 m al borde, exterior, cruzar en ambos sentidos y cámara apuntando al cielo/suelo. Eliminar pared, bandas, discontinuidades y recorte del personaje.
- [ ] STM-02 Verificar reconstrucción de profundidad reverse-Z para Compatibility y casos cielo/objetos opacos/transparentes; validar rayos tangentes y cámara exterior mirando al interior.
- [ ] STM-03 Sustituir muestreo uniforme que puede omitir nubes cercanas por integración analítica de densidad suave y muestreo acotado por segmentos; evaluar 1/2/4 muestras, comparar error y coste.
- [ ] STM-04 Diseñar silueta de frente meteorológico con ruido espacial multiescala, altura variable, color arena abajo y gris oscuro arriba; sin textura marmolada ni cilindro visible.
- [ ] STM-05 Compartir vector de viento y ráfagas entre cielo, polvo, vegetación y sonido; partículas reutilizadas con límite por perfil.
- [ ] STM-06 Mejorar visibilidad según distancia: jugador/arma legibles; objetos cercanos (0–3 m) claros; objetivo inicial dentro de tormenta: silueta 15–25 m, sujeto a ajuste de juego.
- [ ] STM-07 Añadir avisos HUD/minimapa y mezcla de audio; no confundir efectos cosméticos con daño real. Zona conserva radio, cronograma y reglas.
- [ ] STM-08 Fallback de niebla simple / partículas limitadas para incompatibilidad de profundidad; prueba A/B de coste GPU sin tormenta, borde y dentro.
- [ ] PERF-01 Identificar cuello CPU/GPU en dispositivo; perfilar IK, bots, shaders, render y carga de texturas antes de optimizar. **R0757 en desarrollo:** auditoría estática encontró 49 bloques repetidos de FRONTIER con MeshInstance3D independiente; MultiMesh por región/material/dimensiones reduce a 19 grupos potenciales, colisión separada sin cambios. Prueba A/B CI 89 aprobada (run 45859256449): 113 vs 90 draw calls, 50 cuerpos estáticos en ambos; mediana 14.580 vs 14.529 ms, P95 15.230 vs 14.949 ms, 24 intervalos por variante, render software. APK R0757 artefacto 15138256074, SHA-256 73fced5fe657641e336726438fad9c97dd94a59abfa99354676edc37c9e3f261 verificado; no equivale a GPU ARM. Cuello de botella físico aún no aislado; no declarar ganancia FPS. Godot 4.6: https://docs.godotengine.org/en/4.6/tutorials/performance/using_multimesh.html
- [ ] PERF-02 Resolución dinámica con histéresis, FPS objetivo, perfiles, HUD legible y protección térmica; no cambiar escala cada fotograma.
Puerta F1: capturas sin cortina artificial, daño y minimapa correctos, coste medido A/B, sin regresión severa frente a baseline.

## F2 — R07.6: movimiento, cámara y animación (P0/P1)
- [ ] MOV-01 Auditar colisión, aceleración/frenado, gravedad, pendientes, pasos, sprint, agachado, slide, coyote time y salto buffer. Conservar controles previos. **R076 en desarrollo:** aceleración vectorial uniforme cardinal/diagonal, frenado antes de inversión, control aéreo limitado, cuerpo hacia dirección real salvo combate, balance de peso y lean procedural. Pruebas de aceleración/giros/continuidad añadidas, CI pendiente. Conserva sprint/slide/jump y velocidad máxima. No es aún animación profesional basada en clips.
- [ ] MOV-02 Cámara hombros izquierda/derecha, colisión SpringArm, zoom ADS, FOV y sensibilidad configurables, evitar clips de cámara y vértigo.
- [ ] MOV-03 Definir máquina de estados: idle/walk/run/sprint/aim/crouch/slide/jump/fall/land/vault/reload/hit/death. Transiciones y cancelación coherentes.
- [ ] ANI-01 Inventariar huesos RAZE, escala, rest pose, pesos y clips; preparar mapeo humanoide Blender/Godot. **R076:** auditoría automática del rig importado, matrices de reposo, parentesco, clips, duración y pistas JSON en artefacto de CI; **Informe real CI 102, artefacto 15139832298: 78 huesos, único clip dance_05 (2.875 s).** ANI-02/03 requieren recursos licenciados y retargeting, no se declaran completadas. CI 97: import/smoke y capturas desktop/safe aprobados; export ARM y emulador aprobados en CI 97. APK R076 artefacto 15140052139, SHA-256 bbe6f3733a23352f996e21296957b48bdd767f1e21588c8e6efd50206f65a879 verificado.
- [ ] ANI-02 Crear/obtener clips licenciados y retargeting: locomoción ocho direcciones, sprint, giros, salto, caída, aterrizaje, slide y agachado. Mantener fallback procedural. **En desarrollo:** Quaternius UAL Standard CC0 seleccionado; archivo fijado por commit y SHA-256, auditoría GLB y candidatos de mapeo en tools/audit_animation_source.py, CI y docs/ANIMATION_PIPELINE.md. Fuente audit aprobada en CI 102 (artefacto 15139832298): 65 huesos, 43 clips en GLB in-place y RM. Mapeo explícito Hip (ancestro común de Pelvis/Waist), 3 espinas, cuello, piernas/brazos y ball/toe; 22 roles. Código de transferencia de rotaciones, tests sintéticos y bake experimental de 9 clips con capturas añadido. CI 111: bake experimental aprobado, artefacto 15139473274 contiene 9 clips x 22 tracks, 36 capturas y library TRES de 696072 bytes. Poses revisadas: caminar/trotar/sprint presentan ciclos diferenciados; crouch/jump necesitan corrección vertical de pelvis. R0762 integra únicamente 3 ciclos de piernas en movimiento libre mediante interpolación de quaternions; CI 116: prueba de clips en gameplay, render desktop y material safe aprobados; ADB y export ARM aprobados en CI 116 (45866173994), CLIP_ACTIVE observado, firma v2/v3, artefacto 15140807450; SHA-256 88357e229479d9bb80b87abc35a4375c0708c68d01826c13c7b200aba65682db verificado, APK contiene recurso raze_locomotion. Error máximo de altura toe 0.188752 m en prueba sintética; grip residual <1 micrómetro en checkpoint. No equivalen a aprobación visual física. No existen strafes ocho direcciones en la edición Standard.
- [ ] ANI-03 AnimationTree con BlendSpace2D, blend de torso, aim offset, one-shot de disparo/recarga/impacto; elegir movimiento in-place y velocidad física como fuente de verdad, o root motion explícitamente reconciliado. **R0762 primera fase:** mezclador manual de 3 clips in-place por velocidad/fase normalizada, máscara de 6 huesos de pierna, transición a fallback procedural en combate/giro/deslizamiento/salto. Biblioteca generada en CI desde CC0; requiere prueba clip_gameplay y marcador CLIP_ACTIVE en Android. AnimationTree completo aún pendiente.
- [ ] ANI-04 IK manos con sockets IGNIS, anclaje pies y suelo, pelvis, orientación de arma, sin penetración evidente ni pies deslizantes. **R0763 en desarrollo:** calibración offline de 120 muestras por ciclo de caminar/trotar/sprint, fase de apoyo izquierda y recorrido por ciclo estimado desde tobillos reales de RAZE; ritmo acotado y mezcla por fase. Fallback si no se obtienen datos válidos. A/B replay a 1.8/3.8/6.2 m/s con proxy de deslizamiento horizontal en candidatos de apoyo, no medición real de presión plantar. CI 119: calibración, prueba de clips y gait A/B, visual desktop/safe aprobados; Android aún en ejecución. Artefacto 15139329673 contiene gait_calibration.json: Walk 113 candidatos / 1.28765 m por ciclo / offset 0; Jog 47 / 4.68264 m / offset 0; Sprint 40 / 2.09503 m / offset 0.15. Los valores son estimaciones de tobillo, no distancias de desplazamiento real. **R0764:** incorpora máscaras de apoyo y anclaje de tobillo mundial con corrección máx. 0.10 m por evaluación y liberación al perder apoyo, deriva >0.28 m, salto, combate o movimiento no frontal; no modifica física. A/B triple y test de liberación en aire implementados. CI pendiente; no declarar reducción hasta evidencia. R0762 capturas gameplay del artefacto 15141031568 muestran ciclos diferenciados pero zancada de sprint exagerada y torso aún rígido. Anclaje mundial y pelvis vertical pendientes.
- [ ] ANI-05 LOD de animaciones por distancia y visibilidad sin detener simulación de enemigos.
- [ ] MOV-04 Vault sobre obstáculos definidos; no trepar objetos arbitrarios; verificar altura y espacio de aterrizaje.
- [ ] MOV-05 Prueba 8 direcciones, 30/60 FPS, pendientes, pared, techo bajo, ADS/sprint/slide, giro 180°, salto y aterrizaje, sin animación congelada.
Puerta F2: captura comparativa, controles completos y movimientos consistentes, sin regresión de contacto ni arma.

## F3 — R07.7: FRONTIER, arte y mapa (P1)
- [ ] ART-01 Biblia artística: paleta, escala, siluetas, materiales, iluminación, facciones, señalética propia. HELIX, NEXUS, FORGE, HARBOR con identidad diferenciada.
- [ ] ART-02 Pipeline Tripo/Blender/GLB: malla limpia, triangulación, UV, origen/pivote, escala metros, materiales PBR, licencia/procedencia, LOD0/1/2 y colisión separada.
- [ ] ART-03 Kit modular original: suelos, muros, puertas, techos, escaleras, rampas, columnas, ventanas, tuberías.
- [ ] ART-04 Sustituir bloques de cobertura por contenedores, barricadas, cajas, vehículos estáticos dañados; conservar posiciones de colisión hasta revalidar rutas.
- [ ] ART-05 Terreno con desniveles jugables, asfalto, arena, rocas, grietas y marcas; colisión y normal de suelo coherentes.
- [ ] ART-06 Rediseñar cuatro POI, interiores explorables, salidas múltiples, cobertura, loot y rutas de flanqueo; priorizar un sector vertical slice completo antes de replicar.
- [ ] ART-07 Props, vegetación, luces, cielos y ambientación por sector; materiales compartidos y MultiMesh por células, no por mundo completo.
- [ ] ART-08 Lightmaps si perfil/renderer y memoria lo permiten; sombras económicas, baked AO en textura, compresión ETC2/ASTC con fallback verificado.
- [ ] ART-09 LOD de malla, HLOD por edificios y culling por sectores; prueba de entradas, cámara y navegación.
- [ ] MAP-01 Navmesh por regiones con radio/altura de agente, rampas y links; validar conectividad con colisiones reales y rutas hacia botín.
- [ ] MAP-02 Minimap derivado del mundo, iconos, orientación, sectores y tormenta sincronizados.
Puerta F3: cuatro sectores terminados, sin bloqueos de ruta ni colisiones invisibles, rendimiento comparado.

## F4 — R07.8: combate (P1)
- [ ] CMB-01 Datos de arma independientes: daño, cadencia, cargador, reserva, dispersión, recoil, alcance, recarga y audio.
- [ ] CMB-02 Raycast cámara/muzzle y verificación de obstáculos; hitboxes cuerpo/cabeza, daño/armadura y reglas de fuego coherentes.
- [ ] CMB-03 ADS, recoil visual y recuperación, dispersión coherente con movimiento; HUD retícula reactiva.
- [ ] CMB-04 VFX económicos: fogonazo, trazadoras, impacto por material, casquillos con pool; evitar nodos temporales ilimitados.
- [ ] CMB-05 Audio de disparo, recarga, pasos según suelo, impactos, mezcla direccional y volumen configurable.
- [ ] CMB-06 Animaciones de recarga/equipar/guardar con eventos de cargador; no sumar munición si se cancela antes del momento válido.
- [ ] CMB-07 Añadir armas originales de roles distintos (fusil, SMG, precisión); estadísticas y tests; conservar IGNIS.
- [ ] CMB-08 Pruebas de disparo, munición, hitboxes, paredes, recarga cancelada, muerte y reinicio.
Puerta F4: combate reproducible, sin disparar a través de paredes o munición infinita accidental.

## F5 — R07.9: IA táctica (P1, depende MAP-01 y F4)
- [ ] AI-01 FSM/utility AI: patrulla, percibir, buscar, atacar, cubrirse, flanquear, curar, huir de tormenta.
- [ ] AI-02 Percepción por FOV, distancia, LOS y sonido; memoria temporal, reacción humana configurable; sin omnisciencia.
- [ ] AI-03 Coberturas válidas y puntos de disparo, rutas alternativas, recuperación de bloqueo.
- [ ] AI-04 Combate a distancia con misma lógica de daño/munición y dispersión, puntería no perfecta.
- [ ] AI-05 Selección de objetivos incluyendo otros bots, equipos futuros, evitar stacking de agentes.
- [ ] AI-06 Botín y curación; priorizar zona segura, ruta anticipada a siguiente círculo.
- [ ] AI-07 Modelos diferenciados mediante recursos propios, paletas y equipamiento; presupuestos LOD de rig.
- [ ] AI-08 Benchmark 6/12/24 bots progresivo; planificar decisiones espaciadas y navegación en tandas; no escalar sin evidencia.
Puerta F5: combate bots vs bots vs jugador, rutas, cobertura, zona, derrota/victoria sin bloqueos.

## F6 — R08.0: inventario e interfaz (P1)
- [ ] INV-01 Resource/data item definitions con ID, categoría, rareza, tamaño de stack y peso si aporta juego.
- [ ] INV-02 Mochila, 2 armas, munición por tipo, escudo, botiquín, equipo y accesorios; reglas equipar/soltar/intercambiar.
- [ ] INV-03 Loot seed, puntos válidos y distribución justa; ítems originales visualmente reconocibles.
- [ ] INV-04 Persistencia solo de preferencias y progreso permitido, no guardar estado competitivo para hacer trampas; versionar formato.
- [ ] UI-01 HUD contextual, controles reubicables/escalables, safe areas, sensibilidad, retícula, indicadores de daño y tormenta.
- [ ] UI-02 Inventario táctil, selección rápida, feedback de audio/visual; navegación accesible y texto español.
- [ ] UI-03 Lobby, tutorial, selección de modo, ajustes, resultados y estadísticas locales.
- [ ] INV-05 Pruebas de pila, full, pickup duplicado, cancelación, muerte, reset, desincronización UI.
Puerta F6: ciclo encontrar/equipar/usar/soltar sin duplicaciones, HUD legible en varios formatos.

## F7 — R08.1: Battle Royale ampliado (P2)
- [ ] BR-01 Formalizar bucle de partida: espera, despliegue, loot, círculos, combate, final, resultados y reinicio.
- [ ] BR-02 Círculos por etapas, centros/semillas válidas, aviso previo y daño configurable; datos comunes cliente/servidor.
- [ ] BR-03 Ampliar FRONTIER 128m a 256m, luego 512m solo si pasa benchmark; bloques de carga por sectores, límites, navegación/loot y pruebas de recorrido.
- [ ] BR-04 Roster 12/24 bots por etapas; definir duración, densidad de cobertura y loot a partir de playtests.
- [ ] BR-05 Espectador básico, cámara de final, desempate y desconexión local; tests de victoria/derrota.
Puerta F7: partida completa offline reproducible, mapa y escala medidos, no prometer 100 jugadores.

## F8 — R08.2/R08.3/R08.4: despliegue, vehículos y personalización (P2)
- [ ] DEP-01 Transporte aéreo original, ruta, cámara y elección de punto de salto.
- [ ] DEP-02 Caída libre, paracaídas, control aéreo, aterrizaje, colisión; evitar quedar fuera del mapa.
- [ ] VEH-01 Prototipo buggy con manejo, cámara, entrar/salir y colisiones, recuperación cuando vuelca.
- [ ] VEH-02 Daño, combustible si tiene sentido, ocupantes, interacción con zona y audio.
- [ ] VEH-03 Verificar rendimiento, navegación y física de vehículos; no introducir multijugador de vehículos antes del MVP de red.
- [ ] COS-01 Roster original con compatibilidad de rig, skins y accesorios; no alterar hitbox por cosmético.
- [ ] COS-02 Vista previa de personaje, equipamiento cosmético, guardado y catálogo con derechos verificados.
Puerta F8: cada sistema tiene fallback y prueba completa, sin romper partida base.

## F9 — R09.0: multijugador y publicación (P3, contratos desde F0)
- [ ] NET-01 Servidor Godot headless + ENet, separación servidor/cliente; primero LAN/localhost 2–4 jugadores.
- [ ] NET-02 Comandos de entrada numerados, snapshots, interpolación y reconciliación; validar velocidad/colisión y límites de RPC.
- [ ] NET-03 Autoridad exclusiva de daño, recarga, loot, inventario, zona y resultado; tests de comandos inválidos y duplicados.
- [ ] NET-04 Interés espacial, prioridades de replicación, límites de ancho de banda, pérdida/latencia simulada; métricas de tick.
- [ ] NET-05 Matchmaking, autenticación, sesión/reconexión, desconexión y cierre; no guardar secretos en cliente ni repo.
- [ ] NET-06 Hosting, regiones, costes y escalado medidos; primero 4, 8, 16, 32 clientes y bots según capacidad; 50/100 solo tras prueba de carga.
- [ ] NET-07 Seguridad, abuso, reportes/moderación, privacidad y políticas de publicación; validación de entrada, rate limits, logs sin secretos.
- [ ] REL-01 QA físico en gama baja/media/alta, 15–30 min y partidas completas; crashes/ANR, consumo y termal. Pruebas de red reales separadas.
- [ ] REL-02 AAB/Gradle y firma de release distinta de debug; revisar requisitos Google Play vigentes, privacidad, derechos de assets y clasificación.
- [ ] REL-03 Beta cerrada, telemetría consentida, problemas priorizados, rollback y plan de mantenimiento.
Puerta F9: beta cerrada con estabilidad, seguridad y rendimiento demostrados; no declarar release comercial sin criterios.

## Presupuestos iniciales (hipótesis, ajustar después de perfilar)
- Bajo: meta 30 FPS (33,3 ms/fotograma), p95 <= 40 ms, 1% low >= 20 FPS, 15 min sin crash/ANR ni degradación térmica severa. Medio 45 FPS (22,2 ms); alto 60 FPS (16,7 ms) en hardware capaz. No garantizar 60 FPS en dispositivo básico.
- Evitar regresión >10% de mediana/p95 frente a misma escena/perfil sin justificación y aprobación. Medir con y sin tormenta, sin captura de video si se puede; si se graba, comparar en mismas condiciones.
- Mantener APK debug inicial en torno a 60 MB; no fijar límite definitivo sin inventario de recursos. Texturas 512–1024 para props y 1024–2048 para héroes como punto de partida; LOD según pantalla y pruebas, no por número arbitrario de polígonos.
- Comenzar con 6 bots existentes; escalar por pasos. No ampliar mapa, assets y roster en la misma prueba. Rendimiento emulador solo comprueba compatibilidad funcional, no representa GPU ARM.
- Estado de tareas: pendiente / en desarrollo / CI aprobada / validación física pendiente / completada / bloqueada. Una tarea visual no se completa por compilación.

## Fuentes de investigación verificadas
- Godot 4.6 [optimización 3D](https://docs.godotengine.org/en/4.6/tutorials/performance/optimizing_3d_performance.html), [HLOD](https://docs.godotengine.org/en/4.6/tutorials/3d/visibility_ranges.html), [MultiMesh](https://docs.godotengine.org/en/stable/tutorials/performance/using_multimesh.html).
- [Renderizadores y límites](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html), [profundidad](https://docs.godotengine.org/en/4.6/tutorials/shaders/screen-reading_shaders.html), [postproceso reverse-Z](https://docs.godotengine.org/en/4.5/tutorials/shaders/advanced_postprocessing.html). Confirmar cada API contra 4.6. No niebla volumétrica nativa en Compatibility; renderizado de profundidad no incluye necesariamente transparencias.
- Godot 4.6 [retargeting](https://docs.godotengine.org/en/4.6/tutorials/assets_pipeline/retargeting_3d_skeletons.html), [AnimationTree](https://docs.godotengine.org/en/4.6/tutorials/animation/animation_tree.html), [SpringArm](https://docs.godotengine.org/en/4.6/tutorials/3d/spring_arm.html), [interpolación](https://docs.godotengine.org/en/4.6/tutorials/physics/interpolation/using_physics_interpolation.html).
- Godot 4.6 [importación 3D](https://docs.godotengine.org/en/4.6/tutorials/assets_pipeline/importing_3d_scenes/index.html), [texturas](https://docs.godotengine.org/en/4.6/tutorials/assets_pipeline/importing_images.html), [navigation mesh](https://docs.godotengine.org/en/4.6/tutorials/navigation/navigation_using_navigationmeshes.html).
- Godot 4.6 [multijugador](https://docs.godotengine.org/en/4.6/tutorials/networking/high_level_multiplayer.html), [export dedicado](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_dedicated_servers.html), [Android](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html), [monitores](https://docs.godotengine.org/en/4.6/classes/class_performance.html).
- Android Developers [rendimiento](https://developer.android.com/games/optimize/gameperformance), [ADPF térmico](https://developer.android.com/games/optimize/adpf/best-practices-adpf), [frame rate](https://developer.android.com/games/optimize/framerate). Integración ADPF condicionada a acceso nativo y soporte.

## Evidencia R0763–R0765 (26/11/2026)
- CI 119 (45866788149) y CI 122 (45867383091) aprobadas, Android y export ARM. R0763 artefacto 15141237476 SHA-256 8da41ea6f083e7daffebd5a31468c6acd1f8f427335e976d74b58d6ff08278f6; R0764 artefacto 15142195084 SHA-256 277305aec841e731d5ac98301f25d4b5ac55d91e77dac26c596b6016005bc32d. Ambos hashes verificados y bibliotecas ARMv7/ARM64 presentes; firma v2/v3 R0764 verificada en CI.
- A/B CI 122, proxy de deslizamiento horizontal de tobillo m/s, baseline/calibrado/anclado: 1.8 m/s 0.891/0.441/0.229; 3.8 m/s 2.118/1.558/0.725; 6.2 m/s 2.647/4.490/3.229. Sprint regresa 22% respecto a baseline. No equivale a presión plantar real ni rendimiento físico. R0765 atenúa calibración entre 4.2 y 5.8 m/s y deshabilita lock a partir de 5.5 m/s; exige no superar 10% de regresión en comparación. CI pendiente. No declarar sprint corregido aún.
- Video físico 1000013471.mp4, 51.620 s, HUD R076; 13 muestras cada 4 s: FPS 15,15,15,16,20,16,15,14,13,15,16,16,18; P95 71–87 ms; memoria estática 38 MB. Perfil, temperatura, PSS y 15 minutos no confirmados. Personaje gira al retroceder, torso rígido, avisos persistentes. No es prueba de R0762/3/4. R0765 conserva orientación cámara al retroceder y lateral, giro hacia diagonal frontal, sprint limitado a dirección frontal, avisos temporales 2.4 s excepto recarga/fin de ronda. Pruebas de orientación y gait A/B actualizadas. FPS físicos y torso siguen pendientes. Prompt maestro sin cambios.

## R0766 — capa superior y transporte de arma
- R0765 CI 125 (45868920491): import, retarget, gameplay de clips, gait A/B con gate de regresión, capturas, static A/B y safe render aprobados; validación Android todavía en ejecución al registrar.
- ANI-03/04: R0766 añade mezcla de rotaciones Spine01, Spine02 y Head desde los tres ciclos importados, en fase con piernas, influencia de torso 0.25–0.40 (cabeza mitad); excluye Hip/Pelvis para no alterar calibración de piernas. Capa procedural y arma IK se conservan. Oscilación cosmética de IGNIS vinculada a fase durante marcha/carrera libre, desplazamiento por eje limitado a 18 mm y roll a 0.035 rad, supresión de sway en ADS/disparo/recarga/slide. Sin cambiar velocidad física, daño o colisiones. No es AnimationTree completo ni nuevos clips tácticos.
- Tests añadidos: peso de capa, amplitud de oscilación, agarre durante marcha (<0.08 m), desactivación en ADS, reset, dos capturas carry sprint/ADS; telemetría peso torso. CI  R0766 y Android pendientes. No afirmar que ya se observa mejora de torso en teléfono ni que se alcanzan 30 FPS. Pendiente pelvis, animaciones direccionales, agachado/salto y rendimiento físico. Prompt maestro intacto.

- CI 125 R0765 aprobada completamente (run 45868920491); APK artifact 15143340010, SHA-256 500c60ee9b9f0715d7c1b38028be41634febfc4fe46f1c59e430b765164bef32, 60996093 bytes, ARMv7/ARM64. Gait AB locked 0.22938/0.72548/2.83609 m/s (walk/jog/sprint), sprint dentro gate 10% vs baseline 2.64728, mejora respecto R0764 3.22891 pero residual pendiente. CI 128 R0766 falló import por inferencia de free_carry en ignis.gd; corregido tipo bool explícito en ecb6c28eae1901937b5ef47bd0654d3d529c39f9. Revalidación pendiente.
