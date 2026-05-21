## 🛡️ Componentes de Jugador

### MovementComponent.gd
Maneja toda la lógica de movimiento físico del jugador.

### CombatComponent.gd
Gestiona disparo, recarga y selección de armas.

### HealthComponent.gd
Sistema de vida, daño y muerte reutilizable.

---

## 🚀 Optimización

### EnemyPool.gd
Object pooling para enemigos (similar a ProjectilePool pero con soporte para diferentes tipos).

### RenderOptimizer.gd
Gestión automática de LOD, culling de luces y desactivación de nodos fuera de pantalla.

---

## 🧪 Testing Avanzado

### test_integration_full_game.gd
Simula partida completa desde menú hasta victoria/derrota.

### test_wave_system.gd
Pruebas de estrés del sistema de oleadas.

---

## 🎮 UX y Accesibilidad

### AccessibilityManager.gd
Centraliza opciones de daltonismo, tamaño de texto, subtítulos y controles adaptativos.

### ContextualTutorial.gd
Sistema inteligente que detecta patrones de fallo y ofrece ayudas contextuales.

### ControlRemapper.gd
Interfaz completa para remapeo de teclas con detección de conflictos.

---

## 🎯 Game Feel

### ScreenShake.gd
Sistema de screen shake con curvas de intensidad y duración configurables.

### HitPause.gd
Pausas dramáticas al impactar con configuración por tipo de enemigo.

### ImpactParticles.gd
Sistema de partículas de impacto contextual según superficie y arma.

---

## 🛠️ Herramientas

### AdvancedLevelBuilder.gd
Editor visual con drag-and-drop, rutas de patrulla y previsualización de oleadas.

### AutoBalancer.gd
Simulador de miles de partidas para ajuste automático de dificultad.

---

## 🔄 CI/CD

### .github/workflows/godot-ci.yml
Pipeline completo con tests, linting y exportación multiplataforma.
