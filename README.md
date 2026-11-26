# LAST IMPACT R07.8.7

Abrí project.godot con Godot 4.6 y elegí Battle Royale en el lobby. Los dos operadores conservan RAZE y usan el IGNIS original con agarre a dos manos. Detectan al jugador y a otros operadores, disparan con línea de visión y recargan tras seis disparos. Cuando tienen poca salud o recargan buscan una posición accesible protegida por geometría.

En perfil bajo, a distancia se ocultan los detalles del módulo de energía mientras no se recarga. La lógica de daño continúa aunque el operador esté fuera de cámara.

Las capturas de duelo y recarga están en docs/previews. La prueba tests/rival_combat.gd se ejecuta con Godot 4.6, --fixed-fps 60 y --script. En un entorno gráfico se puede agregar -- preview. Ejecución comprobada en Linux con OpenGL Compatibility por software. Pendiente medir tiempos de cuadro, memoria y temperatura en Android físico.
