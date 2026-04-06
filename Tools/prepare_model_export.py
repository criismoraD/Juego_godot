"""
═══════════════════════════════════════════════════════════════════════════════
PREPARE MODEL EXPORT — Script para Blender
═══════════════════════════════════════════════════════════════════════════════
Prepara modelos 3D para exportar a Godot con convenciones específicas:
  1. Renombra Material → [nombre]_M
  2. Renombra Textura difusa → [nombre]_D
  3. Limpia texturas (solo mantiene difusa/color)
  4. Coloca el pivote en la base del modelo (centro inferior)
  5. Centra el modelo en el mundo (0,0,0)
  6. Exporta GLB sin texturas embebidas
  7. Exporta la textura difusa como PNG separado

REQUISITO: Seleccionar el objeto a procesar antes de ejecutar.

USO:
  1. Abrir Blender con tu modelo
  2. Seleccionar el objeto (mesh)
  3. Ir a Scripting → Abrir este archivo
  4. Ejecutar (Alt+P) → Se abrirá un diálogo para elegir carpeta de destino
  5. Los archivos se exportan: [nombre].glb y [nombre]_D.png
═══════════════════════════════════════════════════════════════════════════════
"""

import bpy
import os
import shutil
from pathlib import Path
from bpy_extras.io_utils import ExportHelper
from bpy.props import StringProperty
from bpy.types import Operator


class EXPORT_OT_prepare_model(Operator, ExportHelper):
    """Prepara y exporta modelo para Godot (GLB + Textura)"""
    
    bl_idname = "export_scene.prepare_model"
    bl_label = "Preparar y Exportar Modelo"
    bl_options = {'PRESET', 'UNDO'}
    
    # Propiedades del selector de archivos
    filename_ext = ""  # No usamos extensión porque exportamos múltiples archivos
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
        
        obj = context.active_object
        nombre_base = obj.name
        
        # Crear directorio si no existe
        output_dir = Path(self.directory)
        output_dir.mkdir(parents=True, exist_ok=True)
        
        print(f"\n{'='*70}")
        print(f"PREPARANDO MODELO: {nombre_base}")
        print(f"{'='*70}")
        
        # ═══════════════════════════════════════════════════════════════════
        # PASO 1: Renombrar materiales y limpiar texturas
        # ═══════════════════════════════════════════════════════════════════
        print("\n[1/6] Procesando materiales y texturas...")
        textura_difusa_imagen = None
        textura_difusa_node = None
        
        if obj.data.materials:
            for mat_slot in obj.data.materials:
                mat = mat_slot
                if mat and mat.node_tree:
                    # Renombrar material
                    mat.name = f"{nombre_base}_M"
                    print(f"  ✓ Material renombrado: {mat.name}")
                    
                    # Buscar nodo de imagen (Base Color / Diffuse)
                    nodes = mat.node_tree.nodes
                    principled = None
                    image_node = None
                    
                    # Encontrar nodo Principled BSDF
                    for node in nodes:
                        if node.type == 'BSDF_PRINCIPLED':
                            principled = node
                            break
                    
                    if principled:
                        # Buscar textura conectada a Base Color
                        base_color_input = principled.inputs.get('Base Color')
                        if base_color_input and base_color_input.links:
                            connected_node = base_color_input.links[0].from_node
                            if connected_node.type == 'TEX_IMAGE':
                                image_node = connected_node
                    
                    # Si encontramos textura difusa, guardar referencia a la imagen
                    if image_node and image_node.image:
                        # Renombrar imagen
                        image_name = f"{nombre_base}_D"
                        textura_difusa_imagen = image_node.image  # Guardar referencia
                        textura_difusa_imagen.name = image_name
                        textura_difusa_node = image_node
                        print(f"  ✓ Textura difusa encontrada: {image_name}")
                        
                        # Crear lista de nodos a eliminar (evitar modificar durante iteración)
                        nodos_a_eliminar = []
                        for node in nodes:
                            if node.type == 'TEX_IMAGE' and node != image_node:
                                nodos_a_eliminar.append(node)
                        
                        # Eliminar otros nodos de textura
                        for node in nodos_a_eliminar:
                            print(f"  ✓ Textura extra eliminada: {node.name}")
                            nodes.remove(node)
        else:
            print("  ⚠ Objeto sin materiales")
        
        # ═══════════════════════════════════════════════════════════════════
        # PASO 2: Colocar pivote en la base del modelo
        # ═══════════════════════════════════════════════════════════════════
        print("\n[2/6] Ajustando pivote...")
        
        # Obtener bounding box del objeto
        bbox_min = [float('inf')] * 3
        bbox_max = [float('-inf')] * 3
        
        for vertex in obj.data.vertices:
            world_co = obj.matrix_world @ vertex.co
            for i in range(3):
                bbox_min[i] = min(bbox_min[i], world_co[i])
                bbox_max[i] = max(bbox_max[i], world_co[i])
        
        # Calcular centro en X e Y, pero mínimo en Z (base)
        pivot_x = (bbox_min[0] + bbox_max[0]) / 2.0
        pivot_y = (bbox_min[1] + bbox_max[1]) / 2.0
        pivot_z = bbox_min[2]  # Base del modelo
        
        # Guardar posición original del cursor
        cursor_location_original = context.scene.cursor.location.copy()
        
        # Mover cursor 3D al nuevo pivote
        context.scene.cursor.location = (pivot_x, pivot_y, pivot_z)
        
        # Cambiar origen al cursor
        bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
        print(f"  ✓ Pivote ajustado a base: ({pivot_x:.3f}, {pivot_y:.3f}, {pivot_z:.3f})")
        
        # Restaurar cursor
        context.scene.cursor.location = cursor_location_original
        
        # ═══════════════════════════════════════════════════════════════════
        # PASO 3: Centrar modelo en el mundo
        # ═══════════════════════════════════════════════════════════════════
        print("\n[3/6] Centrando modelo en el mundo...")
        obj.location = (0, 0, 0)
        print(f"  ✓ Modelo centrado en (0, 0, 0)")
        
        # ═══════════════════════════════════════════════════════════════════
        # PASO 4: Exportar GLB sin texturas embebidas
        # ═══════════════════════════════════════════════════════════════════
        print("\n[4/6] Exportando GLB...")
        glb_path = output_dir / f"{nombre_base}.glb"
        
        # Deseleccionar todo y seleccionar solo el objeto actual
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
            export_image_format='NONE',  # NO embeber texturas
            export_apply=True
        )
        print(f"  ✓ GLB exportado: {glb_path.name}")
        
        # ═══════════════════════════════════════════════════════════════════
        # PASO 5: Exportar textura difusa
        # ═══════════════════════════════════════════════════════════════════
        print("\n[5/6] Exportando textura difusa...")
        
        if textura_difusa_imagen:
            texture_out_path = output_dir / f"{nombre_base}_D.jpg"
            
            # Guardar imagen
            textura_difusa_imagen.filepath_raw = str(texture_out_path)
            textura_difusa_imagen.file_format = 'JPEG'
            textura_difusa_imagen.save()
            
            print(f"  ✓ Textura exportada: {texture_out_path.name}")
        else:
            print("  ⚠ No se encontró textura difusa para exportar")
        
        # ═══════════════════════════════════════════════════════════════════
        # PASO 6: Resumen final
        # ═══════════════════════════════════════════════════════════════════
        print(f"\n{'='*70}")
        print("✅ EXPORTACIÓN COMPLETADA")
        print(f"{'='*70}")
        print(f"Archivos generados en: {output_dir}")
        print(f"  • {nombre_base}.glb (modelo sin texturas embebidas)")
        print(f"  • {nombre_base}_D.jpg (textura difusa)")
        print(f"{'='*70}\n")
        
        self.report({'INFO'}, f"Modelo exportado: {nombre_base}.glb")
        return {'FINISHED'}
    
    def invoke(self, context, event):
        # Verificar objeto seleccionado antes de abrir el diálogo
        if not context.active_object or context.active_object.type != 'MESH':
            self.report({'ERROR'}, "Debes seleccionar un objeto MESH antes de ejecutar")
            return {'CANCELLED'}
        
        # Abrir selector de carpeta
        context.window_manager.fileselect_add(self)
        return {'RUNNING_MODAL'}


def menu_func_export(self, context):
    """Añadir al menú File > Export"""
    self.layout.operator(EXPORT_OT_prepare_model.bl_idname, text="Modelo Preparado (GLB + Textura)")


def register():
    """Registrar el operador"""
    bpy.utils.register_class(EXPORT_OT_prepare_model)
    bpy.types.TOPBAR_MT_file_export.append(menu_func_export)


def unregister():
    """Desregistrar el operador"""
    bpy.types.TOPBAR_MT_file_export.remove(menu_func_export)
    bpy.utils.unregister_class(EXPORT_OT_prepare_model)


# ═══════════════════════════════════════════════════════════════════════════
# Ejecutar directamente desde el editor de scripts
# ═══════════════════════════════════════════════════════════════════════════
if __name__ == "__main__":
    register()
    
    # Si se ejecuta desde el editor, invocar directamente
    bpy.ops.export_scene.prepare_model('INVOKE_DEFAULT')
