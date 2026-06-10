## Estado
- Punto estable: commit 82a4fe1 (Merge PR #36 fix-path-traversal).
- Oleada 2: Imp + GoblinGirl + GoblinBallesta. Cañonero removido.
- Assets reorganizados por entidad.

## Completado
- Mejoras previas: Corrección de tests GUT, UI de fin de nivel/diálogos, ImpShieldGirl original, ImpTrident, EscudoImp y EscudoImpRoto.
- DebugUI: Activada UI de debug por defecto, corregido el botón alternador a "🔼 UI" en la esquina superior derecha, y modificado `set_modo_minimo` para mantener el panel inferior de depuración oculto por defecto hasta interacción manual.
- ImpShieldGirl Fixes: Añadido al contador de muertes inmediatamente al romperse su escudo sin alterar el total de la oleada (se mantiene en 15). Corregido el flujo de movimiento para que retome el caminar tras recibir daño/impacto, y ajustado el rango de posición libre a `Vector2(-5.0, 1.0)` para evitar que se quede atascada fuera de pantalla.
- ImpEstandarte Fixes: Reducida la velocidad del proyectil un 40% (rango 12.0 - 18.0). Desactivada la visibilidad de la flecha en mano (`mostrar_flecha_en_mano = false`) durante la animación de apuntado/disparo (dejando solo la flecha proyectil real cuando es disparada), asegurando que cualquier nodo de flecha preexistente en la escena se mantenga oculto.

## Pendiente
- Asegurar soporte de traducción completo.
