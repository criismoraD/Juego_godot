"""
===========================================================================
EXPORT MODEL GLB JPG - Script para Blender
===========================================================================
Exporta el modelo ya preparado a Godot con estos pasos:
  6. Exporta GLB sin texturas embebidas
         - Incluye armature y animaciones si existen
  7. Exporta la textura difusa como JPG separado

REQUISITO: Seleccionar el mesh o el armature del modelo antes de ejecutar.

USO:
  1. Abrir Blender con el modelo ya preparado
    2. Seleccionar el objeto (mesh o armature)
  3. Ir a Scripting -> Abrir este archivo
  4. Ejecutar (Alt+P) -> Se abre un dialogo para elegir carpeta de destino
    5. Se exportan: [nombre].glb y [nombre]_D.jpg
===========================================================================
"""

import bpy
from pathlib import Path
from bpy_extras.io_utils import ExportHelper
from bpy.props import StringProperty
from bpy.types import Operator


class EXPORT_OT_model_glb_jpg(Operator, ExportHelper):
    """Exporta GLB con rig/animaciones y textura difusa en JPG separado"""

    bl_idname = "export_scene.model_glb_jpg"
    bl_label = "Exportar Modelo (GLB + JPG, pasos 6-7)"
    bl_options = {'PRESET', 'UNDO'}

    filename_ext = ""
    filter_folder = True

    directory: StringProperty(
        name="Directorio",
        description="Carpeta donde se exportaran los archivos",
        subtype='DIR_PATH'
    )

    @staticmethod
    def buscar_textura_difusa(obj):
        if not obj.data.materials:
            return None

        for mat in obj.data.materials:
            if not mat or not mat.node_tree:
                continue

            nodes = mat.node_tree.nodes
            principled = None

            for node in nodes:
                if node.type == 'BSDF_PRINCIPLED':
                    principled = node
                    break

            if not principled:
                continue

            base_color_input = principled.inputs.get('Base Color')
            if not base_color_input or not base_color_input.links:
                continue

            connected_node = base_color_input.links[0].from_node
            if connected_node.type == 'TEX_IMAGE' and connected_node.image:
                return connected_node.image

        return None

    @staticmethod
    def buscar_armature_vinculado(obj_mesh):
        if not obj_mesh or obj_mesh.type != 'MESH':
            return None

        armature = obj_mesh.find_armature()
        if armature and armature.type == 'ARMATURE':
            return armature

        for mod in obj_mesh.modifiers:
            if mod.type == 'ARMATURE' and mod.object and mod.object.type == 'ARMATURE':
                return mod.object

        if obj_mesh.parent and obj_mesh.parent.type == 'ARMATURE':
            return obj_mesh.parent

        return None

    @staticmethod
    def resolver_mesh_objetivo(context):
        obj_activo = context.active_object
        if not obj_activo:
            return None

        if obj_activo.type == 'MESH':
            return obj_activo

        if obj_activo.type == 'ARMATURE':
            for obj in context.selected_objects:
                if obj.type == 'MESH' and obj.find_armature() == obj_activo:
                    return obj

            for obj in context.scene.objects:
                if obj.type == 'MESH' and obj.find_armature() == obj_activo:
                    return obj

        return None

    @staticmethod
    def construir_opciones_animacion():
        propiedades = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
        opciones = {}

        if 'export_animations' in propiedades:
            opciones['export_animations'] = True
        if 'export_anim_mode' in propiedades:
            opciones['export_anim_mode'] = 'ACTIONS'
        if 'export_nla_strips' in propiedades:
            opciones['export_nla_strips'] = True
        if 'export_force_sampling' in propiedades:
            opciones['export_force_sampling'] = True
        if 'export_anim_single_armature' in propiedades:
            opciones['export_anim_single_armature'] = True
        if 'export_skins' in propiedades:
            opciones['export_skins'] = True

        return opciones

    def execute(self, context):
        obj = self.resolver_mesh_objetivo(context)
        if not obj:
            self.report({'ERROR'}, "Debes seleccionar un MESH o un ARMATURE con MESH vinculado")
            return {'CANCELLED'}

        nombre_base = obj.name
        armature_obj = self.buscar_armature_vinculado(obj)

        output_dir = Path(self.directory)
        output_dir.mkdir(parents=True, exist_ok=True)

        print(f"\n{'='*70}")
        print(f"EXPORTANDO MODELO: {nombre_base}")
        print(f"{'='*70}")

        if armature_obj:
            print(f"Rig detectado: {armature_obj.name}")
            print("Animaciones: habilitadas para exportacion GLB")
        else:
            print("ADVERTENCIA No se detecto armature vinculado")
            print("Se exportara solo la malla y materiales")
            self.report({'WARNING'}, "No se detecto armature; no se incluiran animaciones de rig")

        print("\n[1/2] Exportando GLB sin texturas embebidas (con animaciones si existen)...")
        glb_path = output_dir / f"{nombre_base}.glb"

        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        if armature_obj:
            armature_obj.select_set(True)
        context.view_layer.objects.active = obj

        opciones_exportacion = {
            'filepath': str(glb_path),
            'use_selection': True,
            'export_format': 'GLB',
            'export_texcoords': True,
            'export_normals': True,
            'export_materials': 'EXPORT',
            'export_image_format': 'NONE',
            'export_apply': True,
        }
        opciones_exportacion.update(self.construir_opciones_animacion())

        bpy.ops.export_scene.gltf(**opciones_exportacion)
        print(f"  OK GLB exportado: {glb_path.name}")

        print("\n[2/2] Exportando textura difusa en JPG...")
        textura_difusa_imagen = self.buscar_textura_difusa(obj)

        if textura_difusa_imagen:
            texture_out_path = output_dir / f"{nombre_base}_D.jpg"
            formato_original = textura_difusa_imagen.file_format
            ruta_original = textura_difusa_imagen.filepath_raw

            try:
                textura_difusa_imagen.filepath_raw = str(texture_out_path)
                textura_difusa_imagen.file_format = 'JPEG'
                textura_difusa_imagen.save()
                print(f"  OK Textura exportada: {texture_out_path.name}")
            except RuntimeError as error:
                print(f"  ADVERTENCIA No se pudo exportar la textura: {error}")
                self.report({'WARNING'}, f"No se pudo exportar la textura JPG: {error}")
            finally:
                textura_difusa_imagen.filepath_raw = ruta_original
                textura_difusa_imagen.file_format = formato_original
        else:
            print("  ADVERTENCIA No se encontro textura difusa conectada a Base Color")
            self.report({'WARNING'}, "No se encontro textura difusa para exportar")

        print(f"\n{'='*70}")
        print("EXPORTACION COMPLETADA")
        print(f"{'='*70}")
        print(f"Archivos generados en: {output_dir}")
        print(f"  - {nombre_base}.glb")
        print(f"  - {nombre_base}_D.jpg")
        print(f"{'='*70}\n")

        self.report({'INFO'}, f"Exportacion completada: {nombre_base}.glb")
        return {'FINISHED'}

    def invoke(self, context, event):
        if not self.resolver_mesh_objetivo(context):
            self.report({'ERROR'}, "Debes seleccionar un MESH o ARMATURE con MESH vinculado antes de ejecutar")
            return {'CANCELLED'}

        context.window_manager.fileselect_add(self)
        return {'RUNNING_MODAL'}


def menu_func_export(self, context):
    """Agregar al menu File > Export"""
    self.layout.operator(EXPORT_OT_model_glb_jpg.bl_idname, text="Modelo GLB + JPG (Pasos 6-7)")


def register():
    """Registrar el operador"""
    bpy.utils.register_class(EXPORT_OT_model_glb_jpg)
    bpy.types.TOPBAR_MT_file_export.append(menu_func_export)


def unregister():
    """Desregistrar el operador"""
    bpy.types.TOPBAR_MT_file_export.remove(menu_func_export)
    bpy.utils.unregister_class(EXPORT_OT_model_glb_jpg)


if __name__ == "__main__":
    register()
    bpy.ops.export_scene.model_glb_jpg('INVOKE_DEFAULT')
