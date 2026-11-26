# QA-02 — Protocolo reproducible de teléfono físico
Baseline R0754, SHA-256 6821281d3c7ea20680430426947b933c69dc9933a159e030840719e65a8b545d, CI 74. Próxima R0755 añade telemetría, sin alterar arte, armas, zona ni mapa. No marcar validación física hasta recibir evidencia.
## Preparación
- Registrar modelo exacto, Android, batería, carga conectada o no, resolución, perfil, versión y temperatura inicial si se dispone de lectura del sistema. No inferir temperatura a partir de FPS.
- Actualizar sobre versión anterior sin desinstalar. Antes, anotar perfil seleccionado. Comprobar que persiste al abrir. Si Android rechaza actualización, conservar instalación y reportar error.
- Cerrar otras apps, usar misma orientación y condiciones. Comparar grabaciones solo con grabación activada en ambas, o preferir medición sin grabación. Empezar desde lobby nuevo y perfil bajo.
## Ruta repetible
- Abrir FRONTIER, semilla inicial 7300 al entrar desde lobby. Durante 15 minutos repetir rondas, regresar al lobby y reentrar para restaurar semilla. Registrar cada muerte/victoria y duración; no mezclar pausas con tiempo activo.
- 0–30 s: 10 s en punto inicial mirando al centro, caminar hacia los suministros iniciales, recoger munición/escudo, apuntar/disparar/recargar.
- 30–90 s: caminar al borde norte/sur siguiendo minimapa, cruzar de zona segura a exterior y volver; mirar horizonte, cielo, suelo, personaje y edificios. Anotar aproximación, exposición y pérdida de visibilidad.
- Resto: recorrer edificios, usar sprint/salto/slide, cambiar de hombro y combatir. Reiniciar desde lobby al acabar. Registrar perfil sin cambiarlo durante cada intervalo.
- Repetir en medio/alto como sesiones separadas si el teléfono lo permite. Si no, registrar limitación.
## Datos
R0755 muestra P95 (ms) y 1% low en HUD y emite LAST IMPACT TELEMETRY JSON cada 10 s de partida activa. El intervalo monotónico entre llamadas de proceso aproxima cadencia, no es tiempo de GPU/presentación real. Mediana/p95/p99 nearest rank (mediana convencional); 1% low = inverso del promedio de peores ceil(n*0.01) intervalos. FPS = n / tiempo acumulado. No juntar perfiles. CPU process/physics, draw calls/primitives y memoria estática son muestras de monitor, no perfiles completos. 
Con ADB (opcional desde PC): adb logcat -v brief -s godot:I; adb shell dumpsys meminfo com.lastimpact.prototype; adb shell dumpsys thermalservice. PSS/RSS y temperatura según disponibilidad; el emulador no representa GPU física. Sin ADB, aportar video y capturas de HUD. 
Meta inicial baja: 30 FPS, p95 <= 40 ms, 1% low >= 20 FPS, sin crash/ANR; registrar cualquier regresión >10% en condiciones comparables, no declarar éxito por un instante. Mantener la prueba pendiente hasta completar recorrido y comparar métricas. 
