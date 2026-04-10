"""
===============================================================================
ARQUERA TOOLS - Addon para Blender
===============================================================================
Panel de herramientas para el proyecto Arrow of Anathema.

CARACTERISTICAS:
  - Importar animaciones FBX en batch
    - Preparar modelos (pasos 1-5)
    - Exportar GLB + JPG (pasos 6-7)
    - Pipeline completo preparar + exportar (pasos 1-7)

INSTALACION:
  1. Editar -> Preferencias -> Add-ons
  2. Instalar -> Seleccionar este archivo .py
  3. Activar el checkbox "3D View: Arquera Tools"
  4. Presionar N en el viewport -> Pestana "ARQUERA"
===============================================================================
"""

bl_info = {
    "name": "Arquera Tools",
    "author": "Arrow of Anathema Team",
    "version": (1, 2, 0),
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
from bpy.types import Operator, OperatorFileListElement, Panel


class ARQUERA_OT_import_fbx_actions(Operator, ImportHelper):
    """Importa multiples FBX y extrae sus animaciones como Actions"""

    bl_idname = "arquera.import_fbx_actions"
    bl_label = "Importar Animaciones FBX"
    bl_options = {'REGISTER', 'UNDO'}

    filter_glob: StringProperty(default="*.fbx", options={'HIDDEN'})
    files: CollectionProperty(type=OperatorFileListElement)
    directory: StringProperty(subtype='DIR_PATH')

    def execute(self, context):
        if not self.files:
            self.report({'ERROR'}, "No se seleccionaron archivos")
            return {'CANCELLED'}

        armature_principal = None
        for obj in bpy.data.objects:
            if obj.type == 'ARMATURE':
                armature_principal = obj
                break

        if not armature_principal:
            self.report({'ERROR'}, "No se encontro un Armature en la escena. Abre tu modelo primero.")
            return {'CANCELLED'}

        print("\n" + "=" * 60)
        print("IMPORTANDO ANIMACIONES FBX")
        print(f"Armature principal: {armature_principal.name}")
        print(f"Archivos seleccionados: {len(self.files)}")
        print("=" * 60)

        objetos_originales = set(bpy.data.objects)
        actions_importadas = []

        for file_elem in self.files:
            fbx_path = os.path.join(self.directory, file_elem.name)
            nombre_action = Path(file_elem.name).stem

            print(f"\n-- Procesando: {file_elem.name} --")

            actions_antes = set(bpy.data.actions)

            bpy.ops.import_scene.fbx(
                filepath=fbx_path,
                use_anim=True,
                ignore_leaf_bones=True,
                automatic_bone_orientation=True,
            )
            print("   Importado OK")

            actions_despues = set(bpy.data.actions)
            nuevas_actions = actions_despues - actions_antes

            action_nueva = None

            if nuevas_actions:
                action_nueva = list(nuevas_actions)[0]
                print(f"   Action encontrada (nueva): {action_nueva.name}")
            else:
                objetos_actuales = set(bpy.data.objects)
                objetos_nuevos = objetos_actuales - objetos_originales

                for obj in objetos_nuevos:
                    if obj.type == 'ARMATURE' and obj.animation_data:
                        if obj.animation_data.action:
                            action_nueva = obj.animation_data.action
                            print(f"   Action encontrada (armature): {action_nueva.name}")
                            break
                        if obj.animation_data.nla_tracks:
                            for track in obj.animation_data.nla_tracks:
                                for strip in track.strips:
                                    if strip.action:
                                        action_nueva = strip.action
                                        print(f"   Action encontrada (NLA): {action_nueva.name}")
                                        break
                                if action_nueva:
                                    break
                    if action_nueva:
                        break

            if action_nueva:
                old_name = action_nueva.name
                action_nueva.name = nombre_action
                action_nueva.use_fake_user = True
                actions_importadas.append(action_nueva)
                print(f"   Action renombrada: '{old_name}' -> '{nombre_action}'")

                if hasattr(action_nueva, 'slots'):
                    for slot in action_nueva.slots:
                        slot.name_display = armature_principal.name
                        print(f"   Slot '{slot.identifier}' -> '{armature_principal.name}'")
            else:
                print("   [AVISO] No se encontro animacion")

            objetos_actuales = set(bpy.data.objects)
            objetos_a_borrar = objetos_actuales - objetos_originales

            if objetos_a_borrar:
                bpy.ops.object.select_all(action='DESELECT')
                for obj in objetos_a_borrar:
                    if obj.name in bpy.data.objects:
                        obj.select_set(True)
                bpy.ops.object.delete(use_global=False, confirm=False)
                print(f"   Objetos temporales eliminados ({len(objetos_a_borrar)})")

        for arm_data in list(bpy.data.armatures):
            if arm_data.users == 0:
                bpy.data.armatures.remove(arm_data)
        for mesh_data in list(bpy.data.meshes):
            if mesh_data.users == 0:
                bpy.data.meshes.remove(mesh_data)

        print("\n" + "=" * 60)
        print("RESULTADO:")
        print(f"  Actions importadas: {len(actions_importadas)}")
        for action in actions_importadas:
            frames = int(action.frame_range[1] - action.frame_range[0])
            print(f"    - {action.name} ({frames} frames)")
        print("=" * 60)

        self.report({'INFO'}, f"Importadas {len(actions_importadas)} animaciones")
        return {'FINISHED'}


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


def preparar_modelo(context, obj):
    nombre_base = obj.name

    print(f"\n{'=' * 70}")
    print(f"PREPARANDO MODELO: {nombre_base}")
    print(f"{'=' * 70}")

    print("\n[1/3] Procesando materiales y texturas...")
    if obj.data.materials:
        for mat in obj.data.materials:
            if mat and mat.node_tree:
                mat.name = f"{nombre_base}_M"
                print(f"  OK Material renombrado: {mat.name}")

                nodes = mat.node_tree.nodes
                links = mat.node_tree.links
                principled = None
                image_node = None

                for node in nodes:
                    if node.type == 'BSDF_PRINCIPLED':
                        principled = node
                        break

                if not principled:
                    print("  AVISO Material sin Principled BSDF, se omite limpieza")
                    continue

                base_color_input = principled.inputs.get('Base Color')
                if base_color_input and base_color_input.links:
                    for link in base_color_input.links:
                        if link.from_node.type == 'TEX_IMAGE' and link.from_node.image:
                            image_node = link.from_node
                            break

                if not image_node:
                    for node in nodes:
                        if node.type == 'TEX_IMAGE' and node.image:
                            image_node = node
                            break

                if image_node and image_node.image:
                    image_name = f"{nombre_base}_D"
                    image_node.image.name = image_name
                    print(f"  OK Textura difusa encontrada: {image_name}")

                    if base_color_input:
                        for link in list(base_color_input.links):
                            links.remove(link)
                        links.new(image_node.outputs.get('Color'), base_color_input)

                # Desconectar mapas no difusos del Principled
                for input_socket in principled.inputs:
                    if input_socket.name == 'Base Color':
                        continue
                    for link in list(input_socket.links):
                        links.remove(link)

                # Mantener solo Output, Principled y mapa difuso
                nodos_permitidos = {principled}
                if image_node:
                    nodos_permitidos.add(image_node)

                nodos_eliminados = 0
                for node in list(nodes):
                    if node in nodos_permitidos or node.type == 'OUTPUT_MATERIAL':
                        continue
                    nodes.remove(node)
                    nodos_eliminados += 1

                print(f"  OK Nodos no difusos eliminados: {nodos_eliminados}")
    else:
        print("  AVISO Objeto sin materiales")

    print("\n[2/3] Ajustando pivote...")
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

    cursor_location_original = context.scene.cursor.location.copy()
    context.scene.cursor.location = (pivot_x, pivot_y, pivot_z)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    context.scene.cursor.location = cursor_location_original

    print(f"  OK Pivote ajustado a base: ({pivot_x:.3f}, {pivot_y:.3f}, {pivot_z:.3f})")

    print("\n[3/3] Centrando modelo en el mundo...")
    obj.location = (0, 0, 0)
    print("  OK Modelo centrado en (0, 0, 0)")

    print(f"\n{'=' * 70}")
    print("PREPARACION COMPLETADA")
    print(f"{'=' * 70}\n")


def exportar_modelo(context, obj, output_dir):
    nombre_base = obj.name
    armature_obj = buscar_armature_vinculado(obj)

    print(f"\n{'=' * 70}")
    print(f"EXPORTANDO MODELO: {nombre_base}")
    print(f"{'=' * 70}")

    if armature_obj:
        print(f"Rig detectado: {armature_obj.name}")
        print("Animaciones: habilitadas para exportacion GLB")
    else:
        print("ADVERTENCIA No se detecto armature vinculado")
        print("Se exportara solo la malla y materiales")

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
    opciones_exportacion.update(construir_opciones_animacion())

    bpy.ops.export_scene.gltf(**opciones_exportacion)
    print(f"  OK GLB exportado: {glb_path.name}")

    print("\n[2/2] Exportando textura difusa en JPG...")
    textura_difusa_imagen = buscar_textura_difusa(obj)

    if textura_difusa_imagen:
        texture_out_path = output_dir / f"{nombre_base}_D.jpg"
        formato_original = textura_difusa_imagen.file_format
        ruta_original = textura_difusa_imagen.filepath_raw

        try:
            textura_difusa_imagen.filepath_raw = str(texture_out_path)
            textura_difusa_imagen.file_format = 'JPEG'
            textura_difusa_imagen.save()
            print(f"  OK Textura exportada: {texture_out_path.name}")
        finally:
            textura_difusa_imagen.filepath_raw = ruta_original
            textura_difusa_imagen.file_format = formato_original
    else:
        print("  AVISO No se encontro textura difusa para exportar")

    print(f"\n{'=' * 70}")
    print("EXPORTACION COMPLETADA")
    print(f"{'=' * 70}")
    print(f"Archivos generados en: {output_dir}")
    print(f"  - {nombre_base}.glb")
    print(f"  - {nombre_base}_D.jpg")
    print(f"{'=' * 70}\n")


class ARQUERA_OT_prepare_model(Operator):
    """Ejecuta pasos 1-5 de preparacion"""

    bl_idname = "arquera.prepare_model"
    bl_label = "Preparar Modelo (pasos 1-5)"
    bl_options = {'REGISTER', 'UNDO'}

    def execute(self, context):
        obj = resolver_mesh_objetivo(context)
        if not obj:
            self.report({'ERROR'}, "Debes seleccionar un MESH o ARMATURE con MESH vinculado")
            return {'CANCELLED'}

        preparar_modelo(context, obj)
        self.report({'INFO'}, f"Preparacion completada: {obj.name}")
        return {'FINISHED'}


class ARQUERA_OT_export_model(Operator, ExportHelper):
    """Ejecuta pasos 6-7 de exportacion"""

    bl_idname = "arquera.export_model"
    bl_label = "Exportar GLB + JPG (pasos 6-7)"
    bl_options = {'PRESET', 'UNDO'}

    filename_ext = ""
    filter_folder = True

    directory: StringProperty(
        name="Directorio",
        description="Carpeta donde se exportaran los archivos",
        subtype='DIR_PATH'
    )

    def execute(self, context):
        obj = resolver_mesh_objetivo(context)
        if not obj:
            self.report({'ERROR'}, "Debes seleccionar un MESH o ARMATURE con MESH vinculado")
            return {'CANCELLED'}

        output_dir = Path(self.directory)
        output_dir.mkdir(parents=True, exist_ok=True)

        exportar_modelo(context, obj, output_dir)
        self.report({'INFO'}, f"Exportacion completada: {obj.name}.glb")
        return {'FINISHED'}

    def invoke(self, context, event):
        if not resolver_mesh_objetivo(context):
            self.report({'ERROR'}, "Debes seleccionar un MESH o ARMATURE con MESH vinculado antes de ejecutar")
            return {'CANCELLED'}

        context.window_manager.fileselect_add(self)
        return {'RUNNING_MODAL'}


class ARQUERA_OT_prepare_and_export_model(Operator, ExportHelper):
    """Ejecuta pasos 1-7 de preparacion y exportacion"""

    bl_idname = "arquera.prepare_and_export_model"
    bl_label = "Preparar + Exportar (pasos 1-7)"
    bl_options = {'PRESET', 'UNDO'}

    filename_ext = ""
    filter_folder = True

    directory: StringProperty(
        name="Directorio",
        description="Carpeta donde se exportaran los archivos",
        subtype='DIR_PATH'
    )

    def execute(self, context):
        obj = resolver_mesh_objetivo(context)
        if not obj:
            self.report({'ERROR'}, "Debes seleccionar un MESH o ARMATURE con MESH vinculado")
            return {'CANCELLED'}

        output_dir = Path(self.directory)
        output_dir.mkdir(parents=True, exist_ok=True)

        preparar_modelo(context, obj)
        exportar_modelo(context, obj, output_dir)

        self.report({'INFO'}, f"Pipeline completado: {obj.name}.glb")
        return {'FINISHED'}

    def invoke(self, context, event):
        if not resolver_mesh_objetivo(context):
            self.report({'ERROR'}, "Debes seleccionar un MESH o ARMATURE con MESH vinculado antes de ejecutar")
            return {'CANCELLED'}

        context.window_manager.fileselect_add(self)
        return {'RUNNING_MODAL'}


class ARQUERA_PT_tools_panel(Panel):
    """Panel principal de herramientas Arquera"""

    bl_label = "Arquera Tools"
    bl_idname = "ARQUERA_PT_tools"
    bl_space_type = 'VIEW_3D'
    bl_region_type = 'UI'
    bl_category = 'ARQUERA'

    def draw(self, context):
        layout = self.layout

        box_anim = layout.box()
        box_anim.label(text="Animaciones", icon='ANIM')
        box_anim.operator(
            "arquera.import_fbx_actions",
            text="Importar FBX Actions",
            icon='IMPORT',
        )

        box_exp = layout.box()
        box_exp.label(text="Exportacion", icon='EXPORT')

        mesh_objetivo = resolver_mesh_objetivo(context)
        if mesh_objetivo:
            box_exp.label(text=f"Objeto: {mesh_objetivo.name}", icon='MESH_DATA')
            box_exp.operator(
                "arquera.prepare_model",
                text="Preparar Modelo (1-5)",
                icon='MODIFIER',
            )
            box_exp.operator(
                "arquera.export_model",
                text="Exportar GLB + JPG (6-7)",
                icon='EXPORT',
            )
            box_exp.operator(
                "arquera.prepare_and_export_model",
                text="Preparar + Exportar (1-7)",
                icon='FILE_TICK',
            )
        elif context.active_object:
            box_exp.label(text="Selecciona MESH o ARMATURE valido", icon='ERROR')
        else:
            box_exp.label(text="Sin objeto activo", icon='ERROR')

        box_info = layout.box()
        box_info.label(text="Info del Proyecto", icon='INFO')
        box_info.label(text="Arrow of Anathema")
        box_info.label(text="Godot 4.6")


classes = (
    ARQUERA_OT_import_fbx_actions,
    ARQUERA_OT_prepare_model,
    ARQUERA_OT_export_model,
    ARQUERA_OT_prepare_and_export_model,
    ARQUERA_PT_tools_panel,
)


def register():
    for cls in classes:
        bpy.utils.register_class(cls)
    print("OK Arquera Tools registrado")


def unregister():
    for cls in reversed(classes):
        bpy.utils.unregister_class(cls)
    print("OK Arquera Tools desregistrado")


if __name__ == "__main__":
    register()
