## Estado
- Punto estable: Estructura del proyecto reorganizada y optimizada.
- 59 de 59 pruebas unitarias pasando exitosamente en GUT (100% de éxito).
- Escudos, enemigos, proyectiles, interfaz y utilidades completamente ordenados y funcionales con rutas corregidas.

## Completado
- Corrección de Pruebas Unitarias de Sombra: Solucionado error en [test_sombra_personaje.gd](file:///e:/Users/criis/Descargas/ARQUERA_JUEGO/Tests/Unit/test_sombra_personaje.gd) cambiando el orden de instanciación para que el nodo padre esté en el árbol antes de configurar su posición global. Ajustada la limpieza en `after_each` liberando las instancias de sombra creadas en cada test para eliminar pérdidas de memoria (3 huérfanos resueltos). Logrado el 100% de éxito en GUT (59/59 pasados).
- Sistema de Partículas de Hojas Caídas en NIVEL01: Creado y configurado el nodo `Hojas_Particulas` (de tipo `GPUParticles2D`) en el `Compositor3D` de [NIVEL01.tscn](file:///e:/Users/criis/Descargas/ARQUERA_JUEGO/Levels/NIVEL01/NIVEL01.tscn) usando la textura `hojas.png`. Escaladas las dimensiones a pantalla completa (Emission Box a `1200x600`, Visibility Rect a `14000x1200`), optimizada la gravedad a `120`, incrementada la velocidad lineal (`100` a `250`), aumentado amount a `200`, configurada duración de vida (`lifetime = 8.0`) y reducidas las dimensiones de las hojas 10 veces (`scale` de `0.05` a `0.12`).
- Ajuste de Velocidad de Flechas por Ángulo: Implementada la reducción dinámica de velocidad en proyectiles del jugador mediante un factor basado en la inclinación vertical (`Factor_Angulo`) para prevenir que las flechas salgan demasiado rápido de la pantalla al disparar en ángulo.
- Tareas Antiguas: Ajuste de animación de muerte de ImpShieldGirl con shader de disolución; reorganización arquitectónica modular del proyecto; corrección de Rutas y UIDs de Godot 4; resolución de errores de shader y reconstrucción de escudos en Debug UI (Oleada 3 y Nivel 3 estables); comportamiento dinámico de `ImpShieldGirl` protegiendo enemigos vivos; sistema de sombras procedurales optimizado; soporte para shader toon en proyectiles, colisiones, alineaciones de fondos y luciérnagas.

## Pendiente
- Asegurar soporte de traducción completo.
