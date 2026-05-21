# Arquera Tools - Documentación de Scripts Python

## Descripción General

Este directorio contiene herramientas de desarrollo para el proyecto **Arrow of Anathema**. Los scripts están diseñados para asistir en el pipeline de arte 3D y automatización de tareas.

---

## Scripts Disponibles

### 1. `arquera_tools_addon.py` (v1.2.0)

**Propósito:** Addon para Blender que proporciona un panel de herramientas integrado.

**Características:**
- Importación batch de animaciones FBX
- Preparación de modelos (pasos 1-5)
- Exportación a GLB + JPG (pasos 6-7)
- Pipeline completo de preparación y exportación

**Instalación:**
```bash
1. En Blender: Edit -> Preferences -> Add-ons
2. Click en "Install..."
3. Seleccionar este archivo .py
4. Activar el checkbox "3D View: Arquera Tools"
5. Presionar N en el viewport -> Pestaña "ARQUERA"
```

**Requisitos:**
- Blender 4.0.0 o superior
- Python 3.x (incluido con Blender)

**Uso:**
1. Abrir Blender
2. Presionar `N` para abrir el sidebar
3. Ir a la pestaña "ARQUERA"
4. Seguir los pasos del pipeline

---

### 2. `export_model_glb_jpg.py`

**Propósito:** Script de exportación de modelos 3D a formato GLB con texturas JPG.

**Funcionalidad:**
- Exporta mallas a formato GLTF Binary (.glb)
- Convierte texturas a JPG para optimización
- Mantiene jerarquía de nodos
- Preserva materiales y UVs

**Uso desde línea de comandos:**
```bash
blender --background --python export_model_glb_jpg.py -- \
    --input="/ruta/al/modelo.blend" \
    --output="/ruta/de/salida/" \
    --texture_quality=85
```

**Parámetros:**
- `--input`: Ruta al archivo .blend de entrada
- `--output`: Directorio de salida
- `--texture_quality`: Calidad de JPG (0-100, default: 85)
- `--compress`: Aplicar compresión Draco (default: False)

---

### 3. `merge_fbx_animations.py`

**Propósito:** Combinar múltiples archivos FBX de animación en un solo recurso.

**Funcionalidad:**
- Importa secuencias de animación FBX
- Fusiona timelines manteniendo keyframes
- Exporta animación combinada
- Útil para sheets de animación

**Uso:**
```bash
blender --background --python merge_fbx_animations.py -- \
    --output="/ruta/salida/animacion_combinada.fbx" \
    --inputs="/ruta/anim1.fbx" "/ruta/anim2.fbx" "/ruta/anim3.fbx"
```

**Consideraciones:**
- Las animaciones deben tener el mismo rig/esqueleto
- Los nombres de huesos deben coincidir exactamente
- El frame rate debe ser consistente entre archivos

---

### 4. `prepare_model_export.py`

**Propósito:** Preparar modelos 3D para exportación a Godot Engine.

**Funcionalidad:**
- Aplica transformaciones (scale, rotation, location)
- Nombra nodos según convención del proyecto
- Configura materiales para Godot
- Optimiza mallas (merge vertices, remove doubles)
- Valida UVs y normales

**Pipeline de preparación:**
1. **Aplicar transformaciones** - Resetea scale/rotation
2. **Renombrar nodos** - Sigue convención `{tipo}_{nombre}`
3. **Materiales** - Asigna shaders estándar
4. **Limpieza** - Remueve elementos duplicados
5. **Validación** - Check de errores comunes

**Uso:**
```bash
blender --background modelo.blend --python prepare_model_export.py
```

**Convenciones de nombre:**
- Personajes: `CHR_{nombre}`
- Props: `PRP_{nombre}`
- Escenario: `ENV_{nombre}`
- Armas: `WPN_{nombre}`

---

## Flujo de Trabajo Recomendado

### Para Modelos de Personajes:

```
1. Modelado inicial en Blender
2. Ejecutar `prepare_model_export.py`
3. Rigging y skinning
4. Crear animaciones individuales (FBX)
5. Ejecutar `merge_fbx_animations.py` si es necesario
6. Usar `arquera_tools_addon.py` para pipeline completo
7. Exportar con `export_model_glb_jpg.py`
8. Importar en Godot
```

### Para Props y Escenario:

```
1. Modelado en Blender
2. Ejecutar `prepare_model_export.py`
3. UV unwrapping
4. Texturizado
5. Exportar con `export_model_glb_jpg.py`
6. Importar en Godot
```

---

## Solución de Problemas

### Error: "Python module not found"
**Solución:** Asegúrate de ejecutar los scripts desde Blender, no desde Python standalone.

### Error: "FBX import failed"
**Solución:** 
- Verifica que el FBX no esté corrupto
- Asegúrate de tener el addon FBX habilitado en Blender
- Revisa que la versión de FBX sea compatible (2018 o anterior)

### Error: "Texture not found after export"
**Solución:**
- Verifica que las texturas estén en el mismo directorio o subdirectorios
- Usa rutas relativas en los materiales
- Ejecuta `File -> External Data -> Find Missing Files`

---

## Contribución

Para añadir nuevas funcionalidades:

1. Seguir convenciones de código PEP 8
2. Añadir docstrings a todas las funciones
3. Incluir manejo de errores try/except
4. Actualizar esta documentación
5. Testear en Blender 4.0+

---

## Contacto y Soporte

Para issues relacionados con estas herramientas:
- Revisar logs de consola de Blender (Window -> Toggle System Console)
- Reportar bugs con pasos para reproducir
- Incluir versión de Blender y sistema operativo

---

**Última actualización:** Mayo 2024  
**Versión del documento:** 1.0
