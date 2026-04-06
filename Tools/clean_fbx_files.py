"""
═══════════════════════════════════════════════════════════════════════════════
CLEAN FBX — Limpieza de archivos FBX
═══════════════════════════════════════════════════════════════════════════════
Elimina cámaras y luces de archivos FBX para evitar problemas de importación.

Soluciona el bug de Blender 5.1 con: AttributeError: 'CyclesLightSettings' 
object has no attribute 'cast_shadow'

PROCESO:
  1. Importa cada FBX seleccionado
  2. Elimina todas las cámaras y luces
  3. Re-exporta el FBX limpio (sobrescribe el original)
  4. Limpia la escena

USO:
  1. Abrir Blender (escena vacía o con tu modelo)
  2. Ir a Scripting → Abrir este archivo
  3. Ejecutar (Alt+P)
  4. Seleccionar los FBX a limpiar
  5. Los archivos se sobrescriben limpios

⚠️ ADVERTENCIA: Este script sobrescribe los archivos originales.
   Haz un backup antes de ejecutarlo.
═══════════════════════════════════════════════════════════════════════════════
"""

import bpy
import os
from pathlib import Path
from bpy_extras.io_utils import ImportHelper
from bpy.props import CollectionProperty, StringProperty, BoolProperty
from bpy.types import Operator, OperatorFileListElement


class CLEAN_OT_fbx_files(Operator, ImportHelper):
    """Limpia archivos FBX eliminando cámaras y luces"""
    
    bl_idname = "clean.fbx_files"
    bl_label = "Limpiar FBX (Eliminar Luces/Cámaras)"
    bl_options = {'PRESET'}
    
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
    
    create_backup: BoolProperty(
        name="Crear Backup",
        description="Crear copia de seguridad (.fbx.bak) antes de sobrescribir",
        default=True
    )
    
    def execute(self, context):
        if not self.files:
            self.report({'ERROR'}, "No se seleccionaron archivos")
            return {'CANCELLED'}
        
        processed = 0
        errors = []
        
        print("\n" + "="*70)
        print("LIMPIANDO ARCHIVOS FBX")
        print(f"Archivos seleccionados: {len(self.files)}")
        print(f"Crear backup: {'SÍ' if self.create_backup else 'NO'}")
        print("="*70)
        
        # Guardar estado original de la escena
        original_objects = set(bpy.data.objects)
        
        for file_elem in self.files:
            filepath = os.path.join(self.directory, file_elem.name)
            filename = Path(filepath).stem
            
            print(f"\n{'─'*60}")
            print(f"Procesando: {file_elem.name}")
            print(f"{'─'*60}")
            
            try:
                # 1) Crear backup si está habilitado
                if self.create_backup:
                    backup_path = filepath + ".bak"
                    import shutil
                    shutil.copy2(filepath, backup_path)
                    print(f"  ✓ Backup creado: {file_elem.name}.bak")
                
                # 2) Importar FBX (forzar importación ignorando errores)
                # Limpiar escena antes de importar
                bpy.ops.object.select_all(action='SELECT')
                bpy.ops.object.delete(use_global=False, confirm=False)
                
                try:
                    bpy.ops.import_scene.fbx(
                        filepath=filepath,
                        use_anim=True,
                        ignore_leaf_bones=False,
                        automatic_bone_orientation=True,
                        use_custom_props=True,
                        use_image_search=True
                    )
                except Exception as import_error:
                    # Si falla, intentar importación más permisiva
                    print(f"  ⚠ Error en importación normal, intentando modo seguro...")
                    bpy.ops.import_scene.fbx(
                        filepath=filepath,
                        use_anim=True,
                        ignore_leaf_bones=True,
                        use_custom_props=False,
                        use_image_search=False
                    )
                
                print(f"  ✓ FBX importado")
                
                # 3) Contar y eliminar cámaras
                cameras_removed = 0
                for obj in list(bpy.data.objects):
                    if obj.type == 'CAMERA':
                        bpy.data.objects.remove(obj, do_unlink=True)
                        cameras_removed += 1
                
                # Eliminar datos de cámaras huérfanas
                for cam_data in list(bpy.data.cameras):
                    bpy.data.cameras.remove(cam_data)
                
                if cameras_removed > 0:
                    print(f"  ✓ Cámaras eliminadas: {cameras_removed}")
                
                # 4) Contar y eliminar luces
                lights_removed = 0
                for obj in list(bpy.data.objects):
                    if obj.type == 'LIGHT':
                        bpy.data.objects.remove(obj, do_unlink=True)
                        lights_removed += 1
                
                # Eliminar datos de luces huérfanas
                for light_data in list(bpy.data.lights):
                    bpy.data.lights.remove(light_data)
                
                if lights_removed > 0:
                    print(f"  ✓ Luces eliminadas: {lights_removed}")
                
                if cameras_removed == 0 and lights_removed == 0:
                    print(f"  • Ya estaba limpio (sin cámaras ni luces)")
                
                # 5) Seleccionar todo para exportar
                bpy.ops.object.select_all(action='SELECT')
                
                # 6) Exportar FBX limpio (sobrescribir)
                bpy.ops.export_scene.fbx(
                    filepath=filepath,
                    use_selection=False,
                    use_active_collection=False,
                    global_scale=1.0,
                    apply_unit_scale=True,
                    apply_scale_options='FBX_SCALE_NONE',
                    bake_space_transform=False,
                    object_types={'ARMATURE', 'MESH', 'EMPTY'},
                    use_mesh_modifiers=True,
                    use_mesh_modifiers_render=True,
                    mesh_smooth_type='OFF',
                    use_tspace=False,
                    use_custom_props=True,
                    add_leaf_bones=True,
                    primary_bone_axis='Y',
                    secondary_bone_axis='X',
                    bake_anim=True,
                    bake_anim_use_all_actions=True,
                    bake_anim_use_nla_strips=True,
                    bake_anim_step=1.0,
                    bake_anim_simplify_factor=1.0,
                    path_mode='AUTO',
                    embed_textures=False,
                    batch_mode='OFF',
                    axis_forward='-Z',
                    axis_up='Y'
                )
                
                print(f"  ✓ FBX limpio exportado")
                
                # 7) Limpiar escena para el siguiente archivo
                bpy.ops.object.select_all(action='SELECT')
                bpy.ops.object.delete(use_global=False, confirm=False)
                
                processed += 1
                
            except Exception as e:
                error_msg = f"Error procesando {file_elem.name}: {str(e)}"
                print(f"  ✗ {error_msg}")
                errors.append(file_elem.name)
                
                # Intentar limpiar
                try:
                    bpy.ops.object.select_all(action='SELECT')
                    bpy.ops.object.delete(use_global=False, confirm=False)
                except:
                    pass
                
                continue
        
        # Reporte final
        print(f"\n{'='*70}")
        print("✅ LIMPIEZA COMPLETADA")
        print(f"{'='*70}")
        print(f"Archivos procesados: {processed}/{len(self.files)}")
        if errors:
            print(f"Errores: {len(errors)}")
            for err_file in errors:
                print(f"  • {err_file}")
        print(f"{'='*70}\n")
        
        if processed > 0:
            msg = f"{processed} archivos FBX limpiados"
            if errors:
                msg += f" ({len(errors)} con errores)"
            self.report({'INFO'}, msg)
        else:
            self.report({'ERROR'}, "No se procesaron archivos")
        
        return {'FINISHED'}


def register():
    """Registrar el operador"""
    bpy.utils.register_class(CLEAN_OT_fbx_files)
    print("✓ Clean FBX registrado")


def unregister():
    """Desregistrar el operador"""
    bpy.utils.unregister_class(CLEAN_OT_fbx_files)
    print("✗ Clean FBX desregistrado")


if __name__ == "__main__":
    register()
    # Ejecutar directamente desde el editor
    bpy.ops.clean.fbx_files('INVOKE_DEFAULT')
