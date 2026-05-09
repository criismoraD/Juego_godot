1: ## Estado
2: - LevelBuilder implementado como UI interna (Scripts/UI/LevelBuilder.gd).
3: - Plugin antiguo (addons/level_designer) eliminado.
4: - Sistema de guardado migrado a LevelDataStore global.
5: 
6: ## Completado
7: - **Migración LevelBuilder**:
8:   - Eliminado `addons/level_designer/` (plugin obsoleto).
9:   - Creado `LevelBuilder.tscn` y `.gd` en `Scripts/UI/` para edición in-game.
10:   - Refactorizado `LevelDataStore.gd` para manejo centralizado de niveles.
11: - **Limpieza y Optimizaciones**:
12:   - Eliminado `LevelDesigner.tscn` y `LevelEditorController.gd`.
13:   - Actualizado `WaveSpawner.gd` para integrarse con el nuevo sistema de datos.
14:   - Ajustes en `GAMEPLAY.tscn` y `NIVEL01.gd` para compatibilidad.
15: - **Tests**:
16:   - Añadido `test_security_plugin_paths.gd` para verificar integridad de rutas.
17: 
18: [Tareas antiguas resumidas: Plugin inicial, contador enemigos fix, skip diálogos ESC, fix fin nivel, remoción partículas tridente].
19: 
20: ## Pendiente
21: - Probar flujo completo de creación de nivel 01 a 30 con UI nueva.
22: - Asegurar que el build final no incluya el LevelBuilder (export toggle).

