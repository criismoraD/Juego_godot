# 🏹 Arquera Tools — Addon de Blender

Panel de herramientas personalizadas para **Arrow of Anathema** (Godot 4.6).

---

## 📋 Características

### 🎬 Animaciones
- **Importar FBX Actions**: Importa múltiples archivos FBX en batch y extrae solo las animaciones
- **Limpiar Actions**: Elimina actions sin usuarios para optimizar el archivo

### 📦 Exportación
- **Preparar y Exportar Modelo**: Pipeline automatizado que:
  - Renombra material → `[nombre]_M`
  - Renombra textura difusa → `[nombre]_D`
  - Elimina texturas extra (mantiene solo difusa)
  - Coloca pivote en la base del modelo
  - Centra modelo en el origen (0,0,0)
  - Exporta GLB sin texturas embebidas
  - Exporta textura difusa como PNG separado

---

## 🔧 Instalación

### Método 1: Como Addon (Recomendado)

1. Abrir Blender
2. Ir a **Editar** → **Preferencias** → **Add-ons**
3. Clic en **Instalar...**
4. Seleccionar el archivo `arquera_tools_addon.py`
5. Activar el checkbox **"3D View: Arquera Tools"**
6. ¡Listo! Presiona **N** en el viewport 3D

### Método 2: Ejecutar desde Editor de Scripts

1. Abrir Blender
2. Cambiar a workspace **Scripting**
3. Abrir el archivo `arquera_tools_addon.py`
4. Ejecutar con **Alt + P**

---

## 🎯 Uso del Panel

Una vez instalado, presiona **N** en el viewport 3D para abrir el sidebar. Verás una nueva pestaña **ARQUERA**.

### Importar Animaciones FBX

```
1. Clic en "Importar FBX Actions"
2. Seleccionar múltiples archivos .fbx
3. Las animaciones se extraen automáticamente
4. Los nombres de archivo se usan como nombres de Action
```

### Preparar Modelo para Godot

```
1. Seleccionar el objeto MESH a exportar
2. Clic en "Preparar y Exportar"
3. Elegir carpeta de destino
4. Se generan automáticamente:
   • [nombre].glb (modelo sin texturas embebidas)
   • [nombre]_D.png (textura difusa)
```

### Limpiar Actions

```
1. Clic en "Limpiar Actions"
2. Se eliminan todas las actions sin usuarios
3. Las actions con "fake user" se preservan
```

---

## 📁 Estructura de Archivos

```
Tools/
├── arquera_tools_addon.py      # ← Addon completo (INSTALAR ESTE)
├── merge_fbx_animations.py     # Script standalone (legacy)
├── prepare_model_export.py     # Script standalone (legacy)
└── purge_unused_actions.py     # Script standalone (legacy)
```

**Nota:** Los scripts standalone son funcionales, pero el addon unifica todo en una interfaz más cómoda.

---

## 🐛 Solución de Problemas

### El panel no aparece
- Verifica que el addon esté activado en Preferencias → Add-ons
- Busca "Arquera" en el filtro de add-ons
- Presiona **N** en el viewport 3D para mostrar el sidebar

### Error al exportar textura
- Asegúrate de que el material use nodos (Shader Editor)
- Verifica que haya un nodo **Image Texture** conectado a **Base Color**
- La imagen debe estar guardada en disco (no procedural)

### El pivote no se coloca correctamente
- Aplica todas las transformaciones antes de exportar: **Ctrl + A** → **All Transforms**

---

## 📝 Notas Técnicas

- **Blender mínimo:** 4.0+
- **Formato de exportación:** GLTF 2.0 (GLB)
- **Convención de nombres:**
  - Materiales: `NOMBRE_M`
  - Texturas difusas: `NOMBRE_D`
- **Pivote:** Centro horizontal (X, Y) + Base inferior (Z mínimo)

---

## 📜 Licencia

Herramientas para uso interno del proyecto **Arrow of Anathema**.

---

## 👤 Autor

**Arrow of Anathema Team**  
Godot 4.6 • Jolt Physics • GDScript
