"""
═══════════════════════════════════════════════════════════════════════════════
IMPORT FBX ACTIONS — Script para Blender
═══════════════════════════════════════════════════════════════════════════════
Importa múltiples FBX de animación a la escena actual.
Para cada FBX:
  1. Importa el FBX (crea armature + mesh temporales)
  2. Renombra la Action con el nombre del archivo
  3. Elimina el modelo/armature importado (conserva solo la Action)

REQUISITO: Tener el modelo principal + armature ya abierto en Blender.

USO:
  1. Abrir Blender con tu modelo y armature
  2. Ir a Scripting → Abrir este archivo
  3. Ejecutar (Alt+P) → Se abrirá un diálogo para seleccionar los FBX
  4. Seleccionar los FBX de animación → las Actions se añaden automáticamente
═══════════════════════════════════════════════════════════════════════════════
"""

import bpy
import os
from pathlib import Path
from bpy_extras.io_utils import ImportHelper
from bpy.props import CollectionProperty, StringProperty
from bpy.types import Operator, OperatorFileListElement


class IMPORT_OT_fbx_actions(Operator, ImportHelper):
    """Importa FBX y extrae sus animaciones como Actions"""
    bl_idname = "import_anim.fbx_actions"
    bl_label = "Importar Animaciones FBX"
    bl_options = {'REGISTER', 'UNDO'}
    
    # Filtrar solo archivos FBX
    filter_glob: StringProperty(default="*.fbx", options={'HIDDEN'})
    
    # Permitir seleccionar múltiples archivos
    files: CollectionProperty(type=OperatorFileListElement)
    directory: StringProperty(subtype='DIR_PATH')
    
    def execute(self, context):
        # Verificar que hay un Armature en la escena
        armature_principal = None
        for obj in bpy.data.objects:
            if obj.type == 'ARMATURE':
                armature_principal = obj
                break
        
        if not armature_principal:
            self.report({'ERROR'}, "No se encontró un Armature en la escena. Abre tu modelo primero.")
            return {'CANCELLED'}
        
        print("\n" + "=" * 60)
        print("IMPORTANDO ANIMACIONES FBX")
        print(f"Armature principal: {armature_principal.name}")
        print(f"Archivos seleccionados: {len(self.files)}")
        print("=" * 60)
        
        # Guardar los objetos que ya existen (no eliminarlos)
        objetos_originales = set(bpy.data.objects)
        actions_importadas = []
        
        for file_elem in self.files:
            fbx_path = os.path.join(self.directory, file_elem.name)
            nombre_action = Path(file_elem.name).stem
            
            print(f"\n── Procesando: {file_elem.name} ──")
            
            # 1) Recordar las Actions que existen ANTES de importar
            actions_antes = set(bpy.data.actions)
            
            # 2) Importar el FBX con manejo de errores
            try:
                bpy.ops.import_scene.fbx(
                    filepath=fbx_path,
                    use_anim=True,
                    ignore_leaf_bones=True,
                    automatic_bone_orientation=True,
                    force_connect_children=False,
                    use_custom_props=False,
                    use_image_search=False,
                    use_manual_orientation=False,
                    global_scale=1.0,
                    axis_forward='-Z',
                    axis_up='Y'
                )
                print(f"   Importado OK")
            except Exception as e:
                print(f"   ⚠ Error al importar: {str(e)}")
                print(f"   Continuando con siguiente archivo...")
                continue
            
            # 3) Encontrar la Action NUEVA (la que no existía antes)
            actions_despues = set(bpy.data.actions)
            nuevas_actions = actions_despues - actions_antes
            
            action_nueva = None
            
            if nuevas_actions:
                # Hay una action nueva (nombre no existía antes)
                action_nueva = list(nuevas_actions)[0]
                print(f"   Action encontrada (nueva): {action_nueva.name}")
            else:
                # Blender reutilizó una action existente (mismo nombre interno)
                # Buscar en los armatures temporales recién importados
                objetos_actuales = set(bpy.data.objects)
                objetos_nuevos = objetos_actuales - objetos_originales
                
                for obj in objetos_nuevos:
                    if obj.type == 'ARMATURE' and obj.animation_data:
                        if obj.animation_data.action:
                            action_nueva = obj.animation_data.action
                            print(f"   Action encontrada (en armature temporal): {action_nueva.name}")
                            break
                        # Buscar en NLA
                        if obj.animation_data.nla_tracks:
                            for track in obj.animation_data.nla_tracks:
                                for strip in track.strips:
                                    if strip.action:
                                        action_nueva = strip.action
                                        print(f"   Action encontrada (en NLA): {action_nueva.name}")
                                        break
                                if action_nueva:
                                    break
                    if action_nueva:
                        break
            
            if not action_nueva:
                print(f"   [AVISO] No se encontró animación, omitiendo")
                # Aún así, eliminar los objetos importados
            else:
                # 4) RENOMBRAR la Action al nombre del archivo
                old_name = action_nueva.name
                action_nueva.name = nombre_action
                action_nueva.use_fake_user = True
                actions_importadas.append(action_nueva)
                print(f"   Action renombrada: '{old_name}' → '{nombre_action}'")
                
                # 5) ASIGNAR SLOT al Armature principal (Blender 4.x)
                if hasattr(action_nueva, 'slots'):
                    for slot in action_nueva.slots:
                        slot.name_display = armature_principal.name
                        print(f"   Slot '{slot.identifier}' → name_display = '{armature_principal.name}'")
            
            # 5) ELIMINAR los objetos importados (mesh + armature temporales)
            objetos_actuales = set(bpy.data.objects)
            objetos_a_borrar = objetos_actuales - objetos_originales
            
            if objetos_a_borrar:
                bpy.ops.object.select_all(action='DESELECT')
                for obj in objetos_a_borrar:
                    if obj.name in bpy.data.objects:
                        obj.select_set(True)
                bpy.ops.object.delete(use_global=False, confirm=False)
                print(f"   Objetos temporales eliminados ({len(objetos_a_borrar)})")
        
        # ── Limpiar datos huérfanos ──
        print("\n── Limpiando datos huérfanos ──")
        
        # Limpiar cámaras
        for cam in list(bpy.data.cameras):
            if cam.users == 0:
                bpy.data.cameras.remove(cam)
                print(f"   Cámara eliminada: {cam.name}")
        
        # Limpiar luces
        for light in list(bpy.data.lights):
            if light.users == 0:
                bpy.data.lights.remove(light)
                print(f"   Luz eliminada: {light.name}")
        
        # Limpiar armatures
        for arm_data in list(bpy.data.armatures):
            if arm_data.users == 0:
                bpy.data.armatures.remove(arm_data)
        for mesh_data in list(bpy.data.meshes):
            if mesh_data.users == 0:
                bpy.data.meshes.remove(mesh_data)
        
        # ── Resumen ──
        print("\n" + "=" * 60)
        print("RESULTADO:")
        print(f"  Actions importadas: {len(actions_importadas)}")
        for a in actions_importadas:
            frames = int(a.frame_range[1] - a.frame_range[0])
            print(f"    • {a.name}  ({frames} frames)")
        
        # Mostrar todas las Actions disponibles
        print(f"\n  Total Actions en Blender: {len(bpy.data.actions)}")
        for a in sorted(bpy.data.actions, key=lambda x: x.name):
            marker = " ★" if a in actions_importadas else ""
            print(f"    • {a.name}{marker}")
        print("=" * 60)
        
        self.report({'INFO'}, f"Importadas {len(actions_importadas)} animaciones")
        return {'FINISHED'}


# ═══════════════════════════════════════════════════════════════════════════════
# REGISTRO
# ═══════════════════════════════════════════════════════════════════════════════

def menu_func_import(self, context):
    self.layout.operator(IMPORT_OT_fbx_actions.bl_idname, text="FBX Actions (.fbx)")


def register():
    bpy.utils.register_class(IMPORT_OT_fbx_actions)
    bpy.types.TOPBAR_MT_file_import.append(menu_func_import)


def unregister():
    bpy.utils.unregister_class(IMPORT_OT_fbx_actions)
    bpy.types.TOPBAR_MT_file_import.remove(menu_func_import)


# ═══════════════════════════════════════════════════════════════════════════════
# EJECUTAR — Al correr el script, se registra y abre el diálogo automáticamente
# ═══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    register()
    # Abrir el diálogo de selección de archivos automáticamente
    bpy.ops.import_anim.fbx_actions('INVOKE_DEFAULT')
