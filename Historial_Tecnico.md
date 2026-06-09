## Estado
- Punto estable: commit 82a4fe1 (Merge PR #36 fix-path-traversal).
- Oleada 2: Imp + GoblinGirl + GoblinBallesta. Cañonero removido.
- Assets reorganizados por entidad.

## Completado
- GUT: Instalado framework GUT v9.6.0 y corregidos tests unitarios (26/26 exitosos).
- UI y Oleadas: Añadidos carteles de nivel, UI interactiva de fin de nivel y parametrización de Oleada 2.
- DialogoComic: Añadido botón físico "Saltar Diálogo" en `Dialogo_Protagonista.tscn` con comportamiento dinámico.
- ImpShieldGirl: Reducido velocidad a 0.6, evitación lógica de sobreposición en X, y flujo de huida/escape suavizado con Tween (-180°) y rotación forzada a la derecha al morir sin escudo.
- ImpTrident & EscudoImp: Corregido bug de invisibilidad de tridente en pool de proyectiles (`mesh.visible = true`) y creada escena independiente `EscudoImp.tscn` manteniendo escala.
- EscudoImpRoto: Creado script `EscudoImpRoto.gd` y escena `EscudoImpRoto.tscn` con el modelo `IMP_ESCUDO_ROTO.glb`. Configurado `ImpShieldGirl.gd` para instanciar dinámicamente las piezas físicas del escudo roto con un offset de 0.15 a la derecha e impulsos intensificados (fuerza horizontal de 1.2) junto con partículas de destello e chispas de `VFXFactory`.

## Pendiente
- Asegurar soporte de traducción completo.
