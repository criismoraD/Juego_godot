## Estado
- Punto estable: Oleada 3 y Nivel 3 completados.
- Oleada 3: 25 enemigos (7 ImpShieldGirl y 18 Goblins/GoblinGirls). Rampa, muros y escudo enemigo dinámicos.
- Sistema de sombras procedurales corregido y optimizado para bordes y plataformas.

## Completado
- Optimización y Corrección de Sombras Procedurales: Implementado sistema de control de bordes mediante 3 RayCast3D (centro, izquierda, derecha) en `SombraPersonaje.gd` y desvanecimiento progresivo en los extremos (`corte_izq` y `corte_der`) en `sombra_personaje.gdshader`. Cambiado `mascara_colision` por defecto a `65` (Capa 1 y Capa 7). Actualizado test GUT `test_sombra_personaje.gd`. Establecidos nuevos valores por defecto (Opacidad: 1.0, Tamaño: 0.6x0.6, Suavizado: 0.8, Altura Max: 0.2) para todos los personajes. Corregido error de tipado estricto en la inferencia de escala del padre (`ps` cast a `Vector3` y `padre` cast a `Node3D`). Corregido parpadeo/destello de sombra en el origen `(0, 0, 0)` al instanciarse nuevos enemigos inicializando la visibilidad de la malla en `false`.
- Modificación de Oleada 3: Cambiado el comportamiento de `ImpShieldGirl` en la oleada 3 en `NIVEL01.gd` para que sea dinámico por temporizador (como en oleadas 1 y 2) en lugar de prefijado en la cola. Se permite un máximo de 2 activas en pantalla y con un intervalo de aparición/chequeo de 6.0 segundos (antes 8.0).
- Contorno en Proyectiles Enemigos: Creado shader `TOON_PROYECTIL_LINEA.gdshader` y asignado como `next_pass` al material base de proyectiles enemigos en `EnemyProjectileBase.gd`. Agregado botón debug interactivo (`BORDES PROY: ON/OFF`) en `GameUI.gd` y parámetro global en `ShaderGlobals.gd` para controlarlo en runtime. Ajustado el radio del cuerpo de las flechas procedurales a `0.025` para evitar que el brillo de la emisión oculte el contorno negro.
- Tareas Antiguas: Corrección de grosor de colisión en muro plataforma, outline desactivado en editor, alineación Z de proyectiles, tests GUT, selectores, visibilidad de fondos, luciérnagas en nivel 6, Oleada 3 con rampa y muros dinámicos, y flechas clavadas en escudo. (Nota: Se descartó aplicar sombras a elementos estáticos/obstáculos por diseño).

## Pendiente
- Asegurar soporte de traducción completo.
