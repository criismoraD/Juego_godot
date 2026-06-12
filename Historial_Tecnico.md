## Estado
- Punto estable: Oleada 3 y Nivel 3 completados.
- Oleada 3: 25 enemigos (7 ImpShieldGirl y 18 Goblins/GoblinGirls). Rampa, muros y escudo enemigo dinámicos.

## Completado
- Mejoras previas, Platform, Calidad, Fondos Estáticos y Reinicio: Resueltos tests GUT, selectores, y visibilidad/escalado de fondos estáticos en `NIVEL01.gd`.
- Oleada 3 y Nivel 3: Tercera oleada de 25 enemigos con rampa, plataformas y escudo de cobertura dinámicos.
- Flechas en Escudo_enemigo: Las flechas que impactan en el escudo enemigo se quedan clavadas temporalmente.
- Luciérnagas en Nivel 6: Creado e integrado el plano de luciérnagas (`LuciernagasPlane.tscn`, `MAT_luciernagas.tres` y `luciernagas.gdshader`) en `NIVEL06_ASALTO.tscn` a profundidad `Z = -10.0` y asignado a `layers = 2` para aprovechar el efecto de desenfoque de profundidad.
- Alineación Z de Proyectiles: Modificados `Arrow.gd` y `EnemyProjectileBase.gd` para obtener dinámicamente la coordenada Z del jugador en _ready() y en la activación del pool, forzando a los proyectiles a volar en dicho plano de juego, corrigiendo la desalineación en el nivel 6 sin romper el nivel 1.
- Colisión Física de Proyectiles: Modificado `Player.gd` para excluir la capa de proyectiles enemigos (capa 4, bit 3) de la máscara de colisiones del jugador, evitando bloqueos físicos mientras se mantiene la detección de daño y colisiones visuales.



## Pendiente
- Asegurar soporte de traducción completo.
