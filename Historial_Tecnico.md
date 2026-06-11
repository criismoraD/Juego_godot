## Estado
- Punto estable: Oleada 3 y Nivel 3 completados.
- Oleada 3: 25 enemigos (7 ImpShieldGirl y 18 Goblins/GoblinGirls). Rampa, muros y escudo enemigo dinámicos.

## Completado
- Mejoras previas y Muro_Plataforma: Corrección de tests GUT, UI de fin de nivel/diálogos, ImpShieldGirl, ImpTrident, EscudoImp, EscudoImpRoto, DebugUI, optimización de velocidad de proyectiles del ImpEstandarte y creación del Muro_Plataforma.
- Calidad y Optimización: Configurado el juego a 30 FPS y calidad mínima al arrancar. Agregado selector gráfico (Bajo, Medio, Alto) en el menú de escape en `GameUI.gd` y creados nuevos tests unitarios de calidad en `test_game_ui.gd`.
- Oleada 3 y Nivel 3: Implementada la tercera oleada con 25 enemigos totales (7 Imps con Escudo y 18 Goblins de ballesta/arco). La rampa (`EscenaRampaNivel3`), los muros de plataforma (`Muro_Plataforma`/`Muro_Plataforma2`) y el escudo de cobertura (`Escudo_enemigo`) permanecen invisibles y sin colisiones físicas al inicio, y se activan recursivamente al arrancar la oleada 3.
- Flechas en Escudo_enemigo: Modificado `Arrow.gd` para que las flechas aliadas que impactan en el escudo enemigo se queden clavadas temporalmente (reparentándolas diferidamente para mantener su orientación y escala global) durante unos segundos antes de disolverse.



## Pendiente
- Asegurar soporte de traducción completo.
