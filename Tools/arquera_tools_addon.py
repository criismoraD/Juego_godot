"""
═══════════════════════════════════════════════════════════════════════════════
ARQUERA TOOLS — Addon para Blender
═══════════════════════════════════════════════════════════════════════════════
Panel de herramientas personalizadas para el proyecto Arrow of Anathema.

CARACTERÍSTICAS:
  • Panel lateral dedicado en la pestaña "ARQUERA"
  • Importar animaciones FBX en batch
  • Preparar modelos para exportar a Godot
  • Limpiar actions sin uso
  
INSTALACIÓN:
  1. Editar → Preferencias → Add-ons
  2. Instalar → Seleccionar este archivo .py
  3. Activar el checkbox "3D View: Arquera Tools"
  4. Presionar N en el viewport → Aparecerá la pestaña "ARQUERA"

═══════════════════════════════════════════════════════════════════════════════
"""

bl_info = {
    "name": "Arquera Tools",
    "author": "Arrow of Anathema Team",
    "version": (1, 0, 0),
    "blender": (4, 0, 0),
    "location": "View3D > Sidebar > ARQUERA",
    "description": "Herramientas de pipeline para Arrow of Anathema (Godot 4.6)",
    "category": "3D View",
}


import bpy
import os
from pathlib import Path
from bpy_extras.io_utils import ImportHelper, ExportHelper
from bpy.props import CollectionProperty, StringProperty
from bpy.types import Panel, Operator, OperatorFileListElement


# ═══════════════════════════════════════════════════════════════════════════
# OPERADOR: Limpiar FBX (Eliminar Luces y Cámaras)
# ═══════════════════════════════════════════════════════════════════════════

class ARQUERA_OT_clean_fbx(Operator, ImportHelper):
    """Limpia archivos FBX eliminando cámaras y luces"""
    
    bl_idname = "arquera.clean_fbx"
    bl_label = "Limpiar FBX"
    bl_options = {'PRESET'}
    
    files: CollectionProperty(
        type=OperatorFileListElement,
        options={'HIDDEN', 'SKIP_SAVE'}
    )
    
    directory: StringProperty(subtype='DIR_PATH')
    
    filter_glob: StringProperty(
        default="*.fbx",
        options={'HIDDEN'}
    )
    
    def execute(self, context):
        if not self.files:
            self.report({'ERROR'}, "No se seleccionaron archivos")
            return {'CANCELLED'}
        
        processed = 0
        errors = []
        
        print("\n" + "="*60)
        print("LIMPIANDO FBX")
        print(f"Archivos: {len(self.files)}")
        print("="*60)
        
        for file_elem in self.files:
            filepath = os.path.join(self.directory, file_elem.name)
            
            print(f"\n── {file_elem.name} ──")
            
            try:
                # Backup
                import shutil
                backup = filepath + ".bak"
                shutil.copy2(filepath, backup)
                print(f"  ✓ Backup: {file_elem.name}.bak")
                
                # Limpiar escena
                bpy.ops.object.select_all(action='SELECT')
                bpy.ops.object.delete(use_global=False, confirm=False)
                
                # Importar
                try:
                    bpy.ops.import_scene.fbx(filepath=filepath, use_anim=True)
                except:
                    bpy.ops.import_scene.fbx(
                        filepath=filepath,
                        use_anim=True,
                        ignore_leaf_bones=True,
                        use_custom_props=False
                    )
                
                # Eliminar cámaras y luces
                removed = 0
                for obj in list(bpy.data.objects):
                    if obj.type in {'CAMERA', 'LIGHT'}:
                        bpy.data.objects.remove(obj, do_unlink=True)
                        removed += 1
                
                for cam in list(bpy.data.cameras):
                    bpy.data.cameras.remove(cam)
                
                for light in list(bpy.data.lights):
                    bpy.data.lights.remove(light)
                
                print(f"  ✓ Eliminados: {removed}")
                
                # Exportar limpio
                bpy.ops.object.select_all(action='SELECT')
                bpy.ops.export_scene.fbx(
                    filepath=filepath,
                    use_selection=False,
                    object_types={'ARMATURE', 'MESH', 'EMPTY'},
                    bake_anim=True,
                    axis_forward='-Z',
                    axis_up='Y'
                )
                
                print(f"  ✓ Exportado limpio")
                
                # Limpiar
                bpy.ops.object.select_all(action='SELECT')
                bpy.ops.object.delete(use_global=False, confirm=False)
                
                processed += 1
                
            except Exception as e:
                print(f"  ✗ Error: {str(e)}")
                errors.append(file_elem.name)
                continue
        
        print(f"\n{'='*60}")
        print(f"✅ Procesados: {processed}/{len(self.files)}")
        print(f"{'='*60}\n")
        
        if processed > 0:
            self.report({'INFO'}, f"{processed} FBX limpiados")
        else:
            self.report({'ERROR'}, "No se procesaron archivos")
        
        return {'FINISHED'}


# ═══════════════════════════════════════════════════════════════════════════
# OPERADOR: Importar FBX Actions
# ═══════════════════════════════════════════════════════════════════════════

class ARQUERA_OT_import_fbx_actions(Operator, ImportHelper):
    """Importa múltiples FBX y extrae sus animaciones como Actions"""
    
    bl_idname = "arquera.import_fbx_actions"
    bl_label = "Importar Animaciones FBX"
    bl_options = {'PRESET', 'UNDO'}
    
    # Propiedades del selector de archivos
    files: CollectionProperty(
        type=OperatorFileListElement,
        options={'HIDDEN', 'SKIP_SAVE'}
    )
    
    directory: StringProperty(
        subtype='DIR_PATH'
    )
    
    filter_glob: StringProperty(
        default="*.fbx",
        options={'HIDDEN'}
    )
    
    def execute(self, context):
        if not self.files:
            self.report({'ERROR'}, "No se seleccionaron archivos")
            return {'CANCELLED'}
        
        imported_count = 0
        errors = []
        
        # WORKAROUND: Parchear el bug de Blender 5.1 con luces FBX
        try:
            import sys
            from types import ModuleType
            
            # Intentar parchear el importador FBX
            if 'io_scene_fbx.import_fbx' in sys.modules:
                fbx_module = sys.modules['io_scene_fbx.import_fbx']
                original_blen_read_light = getattr(fbx_module, 'blen_read_light', None)
                
                if original_blen_read_light:
                    def patched_blen_read_light(*args, **kwargs):
                        try:
                            return original_blen_read_light(*args, **kwargs)
                        except AttributeError as e:
                            if 'cast_shadow' in str(e):
                                print(f"  ⚠ Luz ignorada (bug Blender 5.1)")
                                return None
                            raise
                    
                    fbx_module.blen_read_light = patched_blen_read_light
                    print("✓ Parche temporal aplicado para luces FBX")
        except Exception as patch_error:
            print(f"⚠ No se pudo aplicar parche: {patch_error}")
        
        for file_elem in self.files:
            filepath = os.path.join(self.directory, file_elem.name)
            filename = Path(filepath).stem
            
            print(f"\n{'─'*60}")
            print(f"Importando: {filename}")
            print(f"{'─'*60}")
            
            try:
                # Importar FBX (ignorar errores de luces/cámaras)
                bpy.ops.import_scene.fbx(
                    filepath=filepath,
                    ignore_leaf_bones=True,
                    force_connect_children=False,
                    automatic_bone_orientation=True,
                    use_anim=True,
                    use_custom_props=False,
                    # Ignorar elementos problemáticos
                    use_image_search=False,
                    use_manual_orientation=False,
                    global_scale=1.0,
                    axis_forward='-Z',
                    axis_up='Y'
                )
                
                # Buscar el armature recién importado
                imported_armature = None
                for obj in context.selected_objects:
                    if obj.type == 'ARMATURE':
                        imported_armature = obj
                        break
                
                # Si no encontramos armature en seleccionados, buscar en todos los objetos
                if not imported_armature:
                    for obj in bpy.data.objects:
                        if obj.type == 'ARMATURE' and obj.select_get():
                            imported_armature = obj
                            break
                
                if imported_armature and imported_armature.animation_data:
                    action = imported_armature.animation_data.action
                    if action:
                        # Renombrar action
                        action.name = filename
                        print(f"✓ Action renombrada: {action.name}")
                        
                        # Hacer la action "fake user"
                        action.use_fake_user = True
                        
                        imported_count += 1
                else:
                    print(f"⚠ No se encontró animación en {filename}")
                
                # Eliminar TODOS los objetos importados (mesh, armature, luces, cámaras)
                objects_to_delete = []
                for obj in list(bpy.data.objects):
                    if obj.select_get():
                        objects_to_delete.append(obj)
                
                for obj in objects_to_delete:
                    bpy.data.objects.remove(obj, do_unlink=True)
                
                # Limpiar cámaras y luces huérfanas
                for cam in list(bpy.data.cameras):
                    if cam.users == 0:
                        bpy.data.cameras.remove(cam)
                
                for light in list(bpy.data.lights):
                    if light.users == 0:
                        bpy.data.lights.remove(light)
                
                print(f"✓ Limpieza completada")
                
            except Exception as e:
                error_msg = f"Error en {filename}: {str(e)}"
                print(f"✗ {error_msg}")
                errors.append(filename)
                
                # Intentar limpiar objetos parcialmente importados
                try:
                    for obj in list(context.selected_objects):
                        bpy.data.objects.remove(obj, do_unlink=True)
                except:
                    pass
                
                continue
        
        # Reporte final
        if imported_count > 0:
            msg = f"{imported_count} animaciones importadas"
            if errors:
                msg += f" ({len(errors)} con errores)"
            self.report({'INFO'}, msg)
        else:
            self.report({'ERROR'}, "No se importaron animaciones")
        
        return {'FINISHED'}


# ═══════════════════════════════════════════════════════════════════════════
# OPERADOR: Centrar Pivote y Modelo
# ═══════════════════════════════════════════════════════════════════════════

class ARQUERA_OT_center_pivot(Operator):
    """Centra el pivote en la base del modelo y lo posiciona en el origen"""
    
    bl_idname = "arquera.center_pivot"
    bl_label = "Centrar Pivote y Modelo"
    bl_options = {'REGISTER', 'UNDO'}
    
    def execute(self, context):
        # Verificar objeto seleccionado
        if not context.active_object or context.active_object.type != 'MESH':
            self.report({'ERROR'}, "Debes seleccionar un objeto MESH")
            return {'CANCELLED'}
        
        obj = context.active_object
        
        # Verificar si tiene armature
        tiene_armature = False
        for modifier in obj.modifiers:
            if modifier.type == 'ARMATURE':
                tiene_armature = True
                break
        
        if tiene_armature:
            self.report({'WARNING'}, "El objeto tiene esqueleto. No se modifica pivote ni posición")
            print(f"\n⚠ {obj.name} tiene Armature - Sin cambios\n")
            return {'FINISHED'}
        
        print(f"\n{'='*60}")
        print(f"CENTRANDO: {obj.name}")
        print(f"{'='*60}")
        
        # ═══════════════════════════════════════════════════════════════════
        # PASO 1: Calcular bounding box
        # ═══════════════════════════════════════════════════════════════════
        bbox_min = [float('inf')] * 3
        bbox_max = [float('-inf')] * 3
        
        for vertex in obj.data.vertices:
            world_co = obj.matrix_world @ vertex.co
            for i in range(3):
                bbox_min[i] = min(bbox_min[i], world_co[i])
                bbox_max[i] = max(bbox_max[i], world_co[i])
        
        # ═══════════════════════════════════════════════════════════════════
        # PASO 2: Colocar pivote en la base (centro X,Y + mínimo Z)
        # ═══════════════════════════════════════════════════════════════════
        pivot_x = (bbox_min[0] + bbox_max[0]) / 2.0
        pivot_y = (bbox_min[1] + bbox_max[1]) / 2.0
        pivot_z = bbox_min[2]  # Base del modelo
        
        # Guardar posición original del cursor
        cursor_orig = context.scene.cursor.location.copy()
        
        # Mover cursor al nuevo pivote
        context.scene.cursor.location = (pivot_x, pivot_y, pivot_z)
        
        # Cambiar origen del objeto al cursor
        bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
        
        # Restaurar cursor
        context.scene.cursor.location = cursor_orig
        
        print(f"✓ Pivote ajustado: ({pivot_x:.3f}, {pivot_y:.3f}, {pivot_z:.3f})")
        
        # ═══════════════════════════════════════════════════════════════════
        # PASO 3: Centrar modelo en el origen del mundo
        # ═══════════════════════════════════════════════════════════════════
        obj.location = (0, 0, 0)
        print(f"✓ Modelo centrado en: (0, 0, 0)")
        
        print(f"{'='*60}\n")
        
        self.report({'INFO'}, f"Pivote centrado: {obj.name}")
        return {'FINISHED'}


# ═══════════════════════════════════════════════════════════════════════════
# OPERADOR: Solicitar Nombre del Modelo
# ═══════════════════════════════════════════════════════════════════════════

class ARQUERA_OT_ask_model_name(Operator):
    """Solicita el nombre del modelo antes de exportar"""
    
    bl_idname = "arquera.ask_model_name"
    bl_label = "Nombre del Modelo"
    bl_options = {'INTERNAL'}
    
    model_name: StringProperty(
        name="Nombre",
        description="Nombre para el modelo, material y textura",
        default=""
    )
    
    def execute(self, context):
        if not self.model_name or not self.model_name.strip():
            self.report({'ERROR'}, "Debes ingresar un nombre")
            return {'CANCELLED'}
        
        # Guardar nombre en la escena para el siguiente operador
        context.scene['arquera_model_name'] = self.model_name.strip()
        
        # Llamar al exportador
        bpy.ops.arquera.prepare_model_export('INVOKE_DEFAULT')
        return {'FINISHED'}
    
    def invoke(self, context, event):
        # Pre-rellenar con el nombre del objeto activo
        if context.active_object:
            self.model_name = context.active_object.name
        
        return context.window_manager.invoke_props_dialog(self, width=400)
    
    def draw(self, context):
        layout = self.layout
        
        box = layout.box()
        box.label(text="📝 Configuración de Exportación", icon='EXPORT')
        
        col = box.column(align=True)
        col.prop(self, "model_name", text="Nombre del Modelo")
        
        layout.separator()
        
        info_box = layout.box()
        info_box.label(text="Este nombre se aplicará a:", icon='INFO')
        col = info_box.column(align=True)
        col.label(text="  • Geometría del objeto")
        col.label(text="  • Material (sufijo _M)")
        col.label(text="  • Textura difusa (sufijo _D)")
        
        layout.separator()
        layout.label(text="✓ Las animaciones conservan sus nombres", icon='ANIM')


# ═══════════════════════════════════════════════════════════════════════════
# OPERADOR: Preparar Modelo para Exportar
# ═══════════════════════════════════════════════════════════════════════════

class ARQUERA_OT_prepare_model_export(Operator, ExportHelper):
    """Exporta el modelo preparado para Godot"""
    
    bl_idname = "arquera.prepare_model_export"
    bl_label = "Seleccionar Carpeta de Exportación"
    bl_options = {'INTERNAL'}
    
    filename_ext = ""
    filter_folder = True
    
    directory: StringProperty(
        name="Directorio",
        description="Carpeta donde se exportarán los archivos",
        subtype='DIR_PATH'
    )
    
    def execute(self, context):
        # Verificar que hay un objeto seleccionado
        if not context.active_object or context.active_object.type != 'MESH':
            self.report({'ERROR'}, "Debes seleccionar un objeto MESH")
            return {'CANCELLED'}
        
        # Obtener el nombre guardado
        nombre_base = context.scene.get('arquera_model_name', context.active_object.name)
        obj = context.active_object
        
        # Crear directorio si no existe
        output_dir = Path(self.directory)
        output_dir.mkdir(parents=True, exist_ok=True)
        
        print(f"\n{'='*70}")
        print(f"PREPARANDO MODELO: {nombre_base}")
        print(f"{'='*70}")
        
        # ═══════════════════════════════════════════════════════════════════
        # PASO 0: Renombrar el objeto/geometría
        # ═══════════════════════════════════════════════════════════════════
        print(f"\n[0/7] Renombrando geometría...")
        obj.name = nombre_base
        obj.data.name = nombre_base
        print(f"  ✓ Objeto renombrado: {obj.name}")
        print(f"  ✓ Mesh renombrada: {obj.data.name}")
        
        # ═══════════════════════════════════════════════════════════════════
        # PASO 1: Renombrar materiales y limpiar texturas
        # ═══════════════════════════════════════════════════════════════════
        print("\n[1/7] Procesando materiales y texturas...")
        textura_difusa_imagen = None
        
        if obj.data.materials:
            for mat_slot in obj.data.materials:
                mat = mat_slot
                if mat and mat.node_tree:
                    # Renombrar material
                    mat.name = f"{nombre_base}_M"
                    print(f"  ✓ Material renombrado: {mat.name}")
                    
                    nodes = mat.node_tree.nodes
                    principled = None
                    image_node = None
                    
                    # Encontrar Principled BSDF
                    for node in nodes:
                        if node.type == 'BSDF_PRINCIPLED':
                            principled = node
                            break
                    
                    if principled:
                        base_color_input = principled.inputs.get('Base Color')
                        if base_color_input and base_color_input.links:
                            connected_node = base_color_input.links[0].from_node
                            if connected_node.type == 'TEX_IMAGE':
                                image_node = connected_node
                    
                    if image_node and image_node.image:
                        image_name = f"{nombre_base}_D"
                        textura_difusa_imagen = image_node.image
                        textura_difusa_imagen.name = image_name
                        print(f"  ✓ Textura difusa: {image_name}")
                        
                        # Eliminar otros nodos de textura
                        nodos_a_eliminar = [n for n in nodes if n.type == 'TEX_IMAGE' and n != image_node]
                        for node in nodos_a_eliminar:
                            nodes.remove(node)
                            print(f"  ✓ Eliminada: {node.name}")
        
        # ═══════════════════════════════════════════════════════════════════
        # PASO 2: Ajustar pivote a la base (solo si NO tiene armature)
        # ═══════════════════════════════════════════════════════════════════
        
        # Verificar si tiene armature
        tiene_armature = False
        for modifier in obj.modifiers:
            if modifier.type == 'ARMATURE':
                tiene_armature = True
                break
        
        if tiene_armature:
            print("\n[2/7] Pivote y posición...")
            print("  ⚠ Objeto con Armature - No se modifica pivote ni posición")
        else:
            print("\n[2/7] Ajustando pivote...")
            bbox_min = [float('inf')] * 3
            bbox_max = [float('-inf')] * 3
            
            for vertex in obj.data.vertices:
                world_co = obj.matrix_world @ vertex.co
                for i in range(3):
                    bbox_min[i] = min(bbox_min[i], world_co[i])
                    bbox_max[i] = max(bbox_max[i], world_co[i])
            
            pivot_x = (bbox_min[0] + bbox_max[0]) / 2.0
            pivot_y = (bbox_min[1] + bbox_max[1]) / 2.0
            pivot_z = bbox_min[2]
            
            cursor_orig = context.scene.cursor.location.copy()
            context.scene.cursor.location = (pivot_x, pivot_y, pivot_z)
            bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
            context.scene.cursor.location = cursor_orig
            
            print(f"  ✓ Pivote en base: ({pivot_x:.3f}, {pivot_y:.3f}, {pivot_z:.3f})")
            
            # ═══════════════════════════════════════════════════════════════════
            # PASO 3: Centrar en el mundo
            # ═══════════════════════════════════════════════════════════════════
            print("\n[3/7] Centrando modelo...")
            obj.location = (0, 0, 0)
            print("  ✓ Modelo en (0, 0, 0)")
        
        # ═══════════════════════════════════════════════════════════════════
        # PASO 4: Exportar GLB
        # ═══════════════════════════════════════════════════════════════════
        print("\n[4/7] Exportando GLB...")
        glb_path = output_dir / f"{nombre_base}.glb"
        
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        context.view_layer.objects.active = obj
        
        bpy.ops.export_scene.gltf(
            filepath=str(glb_path),
            use_selection=True,
            export_format='GLB',
            export_texcoords=True,
            export_normals=True,
            export_materials='EXPORT',
            export_image_format='NONE',
            export_apply=True
        )
        print(f"  ✓ GLB: {glb_path.name}")
        
        # ═══════════════════════════════════════════════════════════════════
        # PASO 5: Exportar textura
        # ═══════════════════════════════════════════════════════════════════
        print("\n[5/7] Exportando textura...")
        
        if textura_difusa_imagen:
            texture_out = output_dir / f"{nombre_base}_D.jpg"
            textura_difusa_imagen.filepath_raw = str(texture_out)
            textura_difusa_imagen.file_format = 'JPEG'
            textura_difusa_imagen.save()
            print(f"  ✓ Textura: {texture_out.name}")
        else:
            print("  ⚠ Sin textura difusa")
        
        print(f"\n{'='*70}")
        print("✅ EXPORTACIÓN COMPLETADA")
        print(f"{'='*70}\n")
        
        self.report({'INFO'}, f"Exportado: {nombre_base}")
        return {'FINISHED'}
    
    def invoke(self, context, event):
        if not context.active_object or context.active_object.type != 'MESH':
            self.report({'ERROR'}, "Selecciona un objeto MESH")
            return {'CANCELLED'}
        
        # Abrir selector de carpeta
        context.window_manager.fileselect_add(self)
        return {'RUNNING_MODAL'}





# ═══════════════════════════════════════════════════════════════════════════
# PANEL: Sidebar de Arquera Tools
# ═══════════════════════════════════════════════════════════════════════════

class ARQUERA_PT_tools_panel(Panel):
    """Panel principal de herramientas Arquera"""
    
    bl_label = "Arquera Tools"
    bl_idname = "ARQUERA_PT_tools"
    bl_space_type = 'VIEW_3D'
    bl_region_type = 'UI'
    bl_category = 'ARQUERA'  # Nombre de la pestaña
    
    def draw(self, context):
        layout = self.layout
        
        # ══════════════════════════════════════════════════════════════════
        # Sección: Animaciones
        # ══════════════════════════════════════════════════════════════════
        box = layout.box()
        box.label(text="🎬 Animaciones", icon='ANIM')
        
        col = box.column(align=True)
        col.operator(
            "arquera.clean_fbx",
            text="Limpiar FBX",
            icon='BRUSH_DATA'
        )
        col.operator(
            "arquera.import_fbx_actions",
            text="Importar FBX Actions",
            icon='IMPORT'
        )
        
        # ══════════════════════════════════════════════════════════════════
        # Sección: Exportación
        # ══════════════════════════════════════════════════════════════════
        box = layout.box()
        box.label(text="📦 Exportación", icon='EXPORT')
        
        col = box.column(align=True)
        
        # Mostrar objeto activo
        if context.active_object:
            obj = context.active_object
            if obj.type == 'MESH':
                col.label(text=f"Objeto: {obj.name}", icon='MESH_DATA')
                
                # Botón de centrar pivote
                col.operator(
                    "arquera.center_pivot",
                    text="Centrar Pivote",
                    icon='PIVOT_MEDIAN'
                )
                
                # Separador
                col.separator()
                
                # Botón de preparar y exportar
                col.operator(
                    "arquera.ask_model_name",
                    text="Preparar y Exportar",
                    icon='MESH_CUBE'
                )
            else:
                col.label(text="⚠ Selecciona un MESH", icon='ERROR')
        else:
            col.label(text="⚠ Sin objeto activo", icon='ERROR')
        
        # ══════════════════════════════════════════════════════════════════
        # Sección: Info
        # ══════════════════════════════════════════════════════════════════
        box = layout.box()
        box.label(text="ℹ️ Info del Proyecto", icon='INFO')
        
        col = box.column(align=True)
        col.label(text="Arrow of Anathema")
        col.label(text="Godot 4.6 • Jolt Physics")
        col.label(text="v1.0.0")


# ═══════════════════════════════════════════════════════════════════════════
# Registro del Addon
# ═══════════════════════════════════════════════════════════════════════════

classes = (
    ARQUERA_OT_clean_fbx,
    ARQUERA_OT_import_fbx_actions,
    ARQUERA_OT_center_pivot,
    ARQUERA_OT_ask_model_name,
    ARQUERA_OT_prepare_model_export,
    ARQUERA_PT_tools_panel,
)


def register():
    """Registrar todas las clases"""
    for cls in classes:
        bpy.utils.register_class(cls)
    print("✓ Arquera Tools registrado")


def unregister():
    """Desregistrar todas las clases"""
    for cls in reversed(classes):
        bpy.utils.unregister_class(cls)
    print("✗ Arquera Tools desregistrado")


if __name__ == "__main__":
    register()
