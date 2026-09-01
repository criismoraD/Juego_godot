"""
===============================================================================
ARQUERA TOOLS - Addon para Blender
===============================================================================
Panel de herramientas para el proyecto Arrow of Anathema.

CARACTERISTICAS:
  - Importar animaciones FBX en batch
    - Preparar modelos (pasos 1-6)
    - Exportar GLB + JPG (pasos 7-8)
    - Exportar Solo Textura (JPG)
    - Pipeline completo preparar + exportar (pasos 1-8)

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
    "version": (1, 3, 0),
    "blender": (4, 0, 0),
    "location": "View3D > Sidebar > ARQUERA",
    "description": "Herramientas de pipeline para Arrow of Anathema (Godot 4.6)",
    "category": "3D View",
}


import bpy
import os
import re
from pathlib import Path
from bpy_extras.io_utils import ImportHelper, ExportHelper
from bpy.props import CollectionProperty, StringProperty, EnumProperty, BoolProperty, FloatProperty, IntProperty
from bpy.types import Operator, OperatorFileListElement, Panel


def ejecutar_op_viewport(context, op, **kwargs):
    """Ejecuta un operador garantizando un contexto de 3D Viewport para evitar errores de area/contexto."""
    view3d_area = None
    for window in context.window_manager.windows:
        for area in window.screen.areas:
            if area.type == 'VIEW_3D':
                view3d_area = area
                break
        if view3d_area:
            break

    if view3d_area:
        try:
            with context.temp_override(area=view3d_area):
                op(**kwargs)
                return True
        except Exception as e:
            print(f"[Arquera Tools] Fallo temp_override en {op}: {e}")

    try:
        op(**kwargs)
        return True
    except Exception as e:
        print(f"[Arquera Tools] Fallo sin override en {op}: {e}")
        return False


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

        # Comprobar si ya existe un Armature en la escena
        armature_principal = None
        for obj in bpy.data.objects:
            if obj.type == 'ARMATURE':
                armature_principal = obj
                break

        escena_vacia = (armature_principal is None)

        print("\n" + "=" * 60)
        print("IMPORTANDO ANIMACIONES FBX")
        if armature_principal:
            print(f"Armature existente en escena: {armature_principal.name}")
        else:
            print("Escena sin esqueleto: El primer FBX se importara como modelo base (geometria + esqueleto)")
        print(f"Archivos seleccionados: {len(self.files)}")
        print("=" * 60)

        objetos_originales = set(bpy.data.objects)
        actions_importadas = []

        for idx, file_elem in enumerate(self.files):
            fbx_path = os.path.join(self.directory, file_elem.name)
            nombre_action = Path(file_elem.name).stem

            print(f"\n-- [{idx + 1}/{len(self.files)}] Procesando: {file_elem.name} --")

            actions_antes = set(bpy.data.actions)
            objetos_antes = set(bpy.data.objects)

            bpy.ops.import_scene.fbx(
                filepath=fbx_path,
                use_anim=True,
            )
            print("   Importado OK")

            actions_despues = set(bpy.data.actions)
            nuevas_actions = actions_despues - actions_antes
            objetos_despues = set(bpy.data.objects)
            objetos_nuevos = objetos_despues - objetos_antes

            action_nueva = None
            if nuevas_actions:
                action_nueva = list(nuevas_actions)[0]
                print(f"   Action encontrada (nueva): {action_nueva.name}")
            else:
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

            # Si la escena estaba vacia y es el PRIMER FBX, conservamos su modelo y esqueleto nativo
            if escena_vacia and idx == 0:
                for obj in objetos_nuevos:
                    if obj.type == 'ARMATURE':
                        armature_principal = obj
                
                # Actualizar conjunto original para no eliminar el modelo base en los siguientes FBX
                objetos_originales = set(bpy.data.objects)

                # Visualizacion limpia sin tocar matrices ni edit_bones
                if armature_principal:
                    if hasattr(armature_principal.data, "display_type"):
                        armature_principal.data.display_type = 'STICK'
                    armature_principal.show_in_front = True
                print(f"   Modelo base conservado: Armature='{armature_principal.name if armature_principal else 'Desconocido'}'")
            else:
                # Si ya existía un modelo o es un archivo posterior, borramos los objetos duplicados importados
                for obj in objetos_nuevos:
                    if obj.name in bpy.data.objects:
                        bpy.data.objects.remove(obj, do_unlink=True)
                print(f"   Objetos duplicados eliminados ({len(objetos_nuevos)})")

            if action_nueva and armature_principal:
                old_name = action_nueva.name
                action_nueva.name = nombre_action
                action_nueva.use_fake_user = True
                actions_importadas.append(action_nueva)
                print(f"   Action registrada: '{old_name}' -> '{nombre_action}'")

                if hasattr(action_nueva, 'slots'):
                    for slot in action_nueva.slots:
                        slot.name_display = armature_principal.name

        # Limpiar bloques huérfanos y actions corruptas/basura
        for arm_data in list(bpy.data.armatures):
            if arm_data.users == 0:
                bpy.data.armatures.remove(arm_data)
        for mesh_data in list(bpy.data.meshes):
            if mesh_data.users == 0:
                bpy.data.meshes.remove(mesh_data)
        for act in list(bpy.data.actions):
            if not es_nombre_action_valido(act.name) or len(obtener_todas_las_fcurves(act)) == 0:
                if act not in actions_importadas:
                    try:
                        bpy.data.actions.remove(act)
                    except Exception:
                        pass

        # Asignar la primera animación al esqueleto y actualizar el visualizador
        if armature_principal and actions_importadas:
            if not armature_principal.animation_data:
                armature_principal.animation_data_create()
            armature_principal.animation_data.action = actions_importadas[0]
            context.scene.arquera_active_action = actions_importadas[0].name

        print("\n" + "=" * 60)
        print("RESULTADO:")
        print(f"  Actions importadas: {len(actions_importadas)}")
        for action in actions_importadas:
            frames = int(action.frame_range[1] - action.frame_range[0])
            print(f"    - {action.name} ({frames} frames)")
        print("=" * 60)

        self.report({'INFO'}, f"Importadas {len(actions_importadas)} animaciones")
        return {'FINISHED'}


def obtener_todas_las_fcurves(action, arm=None):
    """
    Recopila todas las FCurves de un Action de forma 100% compatible
    tanto con Blender 4.x/clasico como con el nuevo sistema de animaciones de Blender 5.x
    (Layers -> Strips -> ChannelBags -> FCurves y Slotted Actions).
    """
    curvas_encontradas = []
    vistos = set()

    def registrar_fc(fc):
        if fc and hasattr(fc, "data_path") and hasattr(fc, "keyframe_points"):
            ptr = fc.as_pointer() if hasattr(fc, "as_pointer") else id(fc)
            if ptr not in vistos:
                vistos.add(ptr)
                curvas_encontradas.append(fc)

    def explorar_objeto(obj, depth=0):
        if not obj or depth > 6:
            return
        
        # 1. Atributos directos de curvas
        for fc_attr in ("fcurves", "curves"):
            if hasattr(obj, fc_attr):
                try:
                    col = getattr(obj, fc_attr)
                    if col:
                        for fc in col:
                            registrar_fc(fc)
                except Exception:
                    pass

        # 2. Contenedores anidados (Layers, Strips, ChannelBags, Slots)
        for sub_name in ("layers", "strips", "channel_bags", "channelbags", "all_channel_bags", "slots"):
            if hasattr(obj, sub_name):
                try:
                    col = getattr(obj, sub_name)
                    if col:
                        for sub_obj in col:
                            explorar_objeto(sub_obj, depth + 1)
                except Exception:
                    pass

    if action:
        explorar_objeto(action)

    if arm and arm.animation_data:
        if arm.animation_data.action and arm.animation_data.action != action:
            explorar_objeto(arm.animation_data.action)

    return curvas_encontradas


def es_curva_hips_y(fc) -> bool:
    """Identifica con precisión si una curva FCurve pertenece EXCLUSIVAMENTE a la traslación Y del hueso Hips/Pelvis/Root."""
    if not fc or not hasattr(fc, "array_index"):
        return False
    if fc.array_index != 1:  # Eje Y (vertical en Mixamo bone space)
        return False

    dp = getattr(fc, "data_path", "").lower()
    group_name = fc.group.name.lower() if (hasattr(fc, "group") and fc.group) else ""

    # Excluir cualquier otro hueso (Spine, Legs, Arms, Head, etc.) para que no se deforme el cuerpo
    huesos_no_hips = ("spine", "leg", "arm", "shoulder", "head", "neck", "hand", "foot", "toe", "finger", "clavicle")
    if any(h in dp for h in huesos_no_hips) or any(h in group_name for h in huesos_no_hips):
        return False

    # Debe ser explícitamente el hueso de la cadera (Hips, Pelvis o Root)
    es_hips = any(kw in dp for kw in ("hips", "pelvis", "root")) or any(kw in group_name for kw in ("hips", "pelvis", "root"))
    if not es_hips:
        return False

    if "location" not in dp and "location" not in group_name:
        return False

    return True


def es_curva_hips_xz(fc) -> bool:
    """Identifica con precisión si una curva FCurve pertenece EXCLUSIVAMENTE a la traslación X o Z del hueso Hips/Pelvis/Root."""
    if not fc or not hasattr(fc, "array_index"):
        return False
    if fc.array_index not in (0, 2):  # Ejes X y Z (Laterales y Profundidad)
        return False

    dp = getattr(fc, "data_path", "").lower()
    group_name = fc.group.name.lower() if (hasattr(fc, "group") and fc.group) else ""

    huesos_no_hips = ("spine", "leg", "arm", "shoulder", "head", "neck", "hand", "foot", "toe", "finger", "clavicle")
    if any(h in dp for h in huesos_no_hips) or any(h in group_name for h in huesos_no_hips):
        return False

    es_hips = any(kw in dp for kw in ("hips", "pelvis", "root")) or any(kw in group_name for kw in ("hips", "pelvis", "root"))
    if not es_hips:
        return False

    if "location" not in dp and "location" not in group_name:
        return False

    return True


def es_nombre_action_valido(nombre: str) -> bool:
    """Verifica si el nombre de una acción es válido y legible, descartando bytes o símbolos corruptos."""
    if not nombre:
        return False
    nombre_clean = nombre.strip()
    if not nombre_clean:
        return False
    # Descartar temporales o prefijos de basura
    if nombre_clean.startswith(('@', '.')):
        return False
    # Descartar caracteres de control no imprimibles o decodificaciones binarias corruptas
    caracteres_corruptos = {'Æ', 'Ð', 'Đ', 'º', 'Ý', 'È', 'ú', 'Ø', 'Þ', 'ÿ', 'Ç', '¢'}
    for ch in nombre_clean:
        code = ord(ch)
        if code < 32 or code == 127:
            return False
        if ch in caracteres_corruptos:
            return False
    return True


def fijar_fcurve_un_fotograma(fc, frame: float, valor: float) -> None:
    """Deja la curva con exactamente 1 fotograma en el frame inicial y el valor especificado."""
    while len(fc.keyframe_points) > 1:
        fc.keyframe_points.remove(fc.keyframe_points[-1])

    if len(fc.keyframe_points) == 1:
        fc.keyframe_points[0].co = (frame, valor)
        fc.keyframe_points[0].handle_left = (frame, valor)
        fc.keyframe_points[0].handle_right = (frame, valor)
    else:
        fc.keyframe_points.insert(frame=frame, value=valor)

    fc.update()


def centrar_eje_xz_de_action(action, frame_inicio=1) -> int:
    """
    Fija los ejes horizontales X (0) y Z (2) del Hips a 1 solo fotograma inicial con valor 0.0.
    Elimina la traslacion horizontal sin alterar la altura ni rotaciones ni mover el Armature Object.
    """
    if not action:
        return 0

    todas_fcurves = obtener_todas_las_fcurves(action)
    modificadas = 0

    for fc in todas_fcurves:
        if es_curva_hips_xz(fc):
            fijar_fcurve_un_fotograma(fc, frame_inicio, 0.0)
            modificadas += 1

    return modificadas


def procesar_transformacion_action(context, action, modo="XZ", armature=None) -> int:
    """
    modo: 'XZ', 'ALTURA'
    """
    if not action:
        return 0

    frame_inicio = int(action.frame_range[0]) if action.frame_range else 1
    curvas_modificadas = 0

    if modo == "XZ":
        curvas_modificadas = centrar_eje_xz_de_action(action, frame_inicio)
    elif modo == "ALTURA":
        curvas_modificadas = centrar_altura_de_action(action)

    if armature:
        if not armature.animation_data:
            armature.animation_data_create()
        armature.animation_data.action = action
        armature.update_tag()

    context.view_layer.update()
    context.scene.frame_set(context.scene.frame_current)
    return curvas_modificadas


def centrar_animacion_in_place(context, action, armature=None, alinear_altura_reposo=True) -> int:
    return procesar_transformacion_action(context, action, "XZ", armature)


def _ejecutar_centrado_generico(self, context, modo: str, descripcion_eje: str) -> set:
    arm = None
    if context.active_object and context.active_object.type == 'ARMATURE':
        arm = context.active_object
    elif context.active_object and context.active_object.type == 'MESH':
        arm = buscar_armature_vinculado(context.active_object)

    if not arm:
        for obj in context.scene.objects:
            if obj.type == 'ARMATURE':
                arm = obj
                break

    acciones_a_procesar = set()
    act_name = context.scene.arquera_active_action
    if act_name and act_name != 'NONE':
        a = bpy.data.actions.get(act_name)
        if a:
            acciones_a_procesar.add(a)

    if arm and arm.animation_data and arm.animation_data.action:
        acciones_a_procesar.add(arm.animation_data.action)

    if not acciones_a_procesar:
        for a in bpy.data.actions:
            acciones_a_procesar.add(a)

    if not acciones_a_procesar:
        self.report({'ERROR'}, "No se encontro ninguna animacion activa")
        return {'CANCELLED'}

    total_curvas = 0
    ultima_act = None
    for act in acciones_a_procesar:
        curvas = procesar_transformacion_action(context, act, modo, arm)
        total_curvas += curvas
        ultima_act = act

    if arm and ultima_act:
        if not arm.animation_data:
            arm.animation_data_create()
        arm.animation_data.action = ultima_act
        arm.update_tag()

    if ultima_act:
        context.scene.arquera_active_action = ultima_act.name

    context.view_layer.update()
    context.scene.frame_set(context.scene.frame_current)

    nombre_rep = ultima_act.name if ultima_act else "Activa"
    if total_curvas > 0:
        self.report({'INFO'}, f"Centrado {descripcion_eje}: '{nombre_rep}' ({total_curvas} curvas ajustadas)")
    else:
        self.report({'WARNING'}, f"Action '{nombre_rep}': no se encontraron curvas de traslacion para {descripcion_eje}")
    return {'FINISHED'}


class ARQUERA_OT_center_xz(Operator):
    """Centra la animacion en el plano horizontal (Ejes X y Z) fijando la traslacion en 0 (1 fotograma)"""

    bl_idname = "arquera.center_xz"
    bl_label = "CENTRAR X y Z (SUELO)"
    bl_options = {'REGISTER', 'UNDO'}

    def execute(self, context):
        return _ejecutar_centrado_generico(self, context, "XZ", "X y Z (Suelo)")




class ARQUERA_OT_clean_garbage_actions(Operator):
    """Elimina acciones invalidas, corruptas, temporales (@...) o sin curvas de animacion"""

    bl_idname = "arquera.clean_garbage_actions"
    bl_label = "LIMPIAR ACTIONS BASURA"
    bl_options = {'REGISTER', 'UNDO'}

    def execute(self, context):
        borradas = 0
        for act in list(bpy.data.actions):
            curvas = obtener_todas_las_fcurves(act)
            es_basura = (
                not es_nombre_action_valido(act.name)
                or len(curvas) == 0
            )
            if es_basura:
                try:
                    for obj in bpy.data.objects:
                        if obj.animation_data and obj.animation_data.action == act:
                            obj.animation_data.action = None
                    bpy.data.actions.remove(act)
                    borradas += 1
                except Exception:
                    pass

        curr = context.scene.arquera_active_action
        if curr and curr != 'NONE' and curr not in bpy.data.actions:
            validas = [a.name for a in bpy.data.actions if es_nombre_action_valido(a.name) and len(obtener_todas_las_fcurves(a)) > 0]
            context.scene.arquera_active_action = validas[0] if validas else 'NONE'

        context.view_layer.update()
        self.report({'INFO'}, f"Limpieza completada: {borradas} action(s) basura eliminada(s)")
        return {'FINISHED'}


class ARQUERA_OT_delete_active_action(Operator):
    """Elimina el Action / Animacion actualmente seleccionada del archivo de Blender"""

    bl_idname = "arquera.delete_active_action"
    bl_label = "ELIMINAR ACTION"
    bl_options = {'REGISTER', 'UNDO'}

    def execute(self, context):
        act_name = context.scene.arquera_active_action
        if not act_name or act_name == 'NONE':
            self.report({'WARNING'}, "No hay ninguna animacion seleccionada para eliminar")
            return {'CANCELLED'}

        action = bpy.data.actions.get(act_name)
        if not action:
            self.report({'ERROR'}, f"Action '{act_name}' no encontrada")
            return {'CANCELLED'}

        # Desvincular de todos los objetos en la escena
        for obj in bpy.data.objects:
            if obj.animation_data and obj.animation_data.action == action:
                obj.animation_data.action = None

        nombre_borrado = action.name
        bpy.data.actions.remove(action)

        # Actualizar selector con las acciones restantes
        if len(bpy.data.actions) > 0:
            nueva_act = bpy.data.actions[0]
            context.scene.arquera_active_action = nueva_act.name
            arm = None
            if context.active_object and context.active_object.type == 'ARMATURE':
                arm = context.active_object
            elif context.active_object and context.active_object.type == 'MESH':
                arm = buscar_armature_vinculado(context.active_object)
            if not arm:
                for obj in context.scene.objects:
                    if obj.type == 'ARMATURE':
                        arm = obj
                        break
            if arm:
                if not arm.animation_data:
                    arm.animation_data_create()
                arm.animation_data.action = nueva_act
                arm.update_tag()
        else:
            context.scene.arquera_active_action = 'NONE'

        context.view_layer.update()
        self.report({'INFO'}, f"Action '{nombre_borrado}' eliminada exitosamente")
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
    if not obj_activo and context.selected_objects:
        obj_activo = context.selected_objects[0]

    if not obj_activo:
        meshes = [o for o in context.scene.objects if o.type == 'MESH']
        if len(meshes) == 1:
            return meshes[0]
        return None

    if obj_activo.type == 'MESH':
        return obj_activo

    if obj_activo.type == 'ARMATURE':
        # 1. Buscar en hijos directos o recursivos
        for child in obj_activo.children_recursive:
            if child.type == 'MESH':
                return child

        # 2. Buscar en objetos seleccionados
        for obj in context.selected_objects:
            if obj.type == 'MESH' and (obj.parent == obj_activo or buscar_armature_vinculado(obj) == obj_activo):
                return obj

        # 3. Buscar en la escena objetos vinculados
        for obj in context.scene.objects:
            if obj.type == 'MESH' and (obj.parent == obj_activo or buscar_armature_vinculado(obj) == obj_activo):
                return obj

        # 4. Cualquier malla en la escena si solo hay una o principal
        meshes = [o for o in context.scene.objects if o.type == 'MESH']
        if meshes:
            return meshes[0]

    for obj in context.selected_objects:
        if obj.type == 'MESH':
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

    print("\n[1/4] Procesando materiales y texturas...")
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

    print("\n[2/4] Unificando vertices duplicados (Merge by Distance)...")
    if getattr(context.scene, "arquera_merge_enabled", True):
        # Asegurar modo objeto para manipulacion limpia
        bpy.ops.object.mode_set(mode='OBJECT')
        context.view_layer.objects.active = obj
        obj.select_set(True)

        # Cambiar a modo edicion, seleccionar todo y remover doubles
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.mesh.remove_doubles(threshold=0.0001)

        # Regresar a modo objeto para continuar preparacion
        bpy.ops.object.mode_set(mode='OBJECT')
        print("  OK Vertices duplicados unificados con umbral 0.0001")
    else:
        print("  SKIP Merge by Distance desactivado por el usuario")

    print("\n[3/4] Ajustando pivote...")
    bbox_min = [float('inf')] * 3
    bbox_max = [float('-inf')] * 3

    for vertex in obj.data.vertices:
        world_co = obj.matrix_world @ vertex.co
        for i in range(3):
            bbox_min[i] = min(bbox_min[i], world_co[i])
            bbox_max[i] = max(bbox_max[i], world_co[i])

    pivot_x = (bbox_min[0] + bbox_max[0]) / 2.0
    pivot_y = (bbox_min[1] + bbox_max[1]) / 2.0
    
    pivot_mode = getattr(context.scene, "arquera_pivot_mode", 'BOTTOM')
    if pivot_mode == 'CENTER':
        pivot_z = (bbox_min[2] + bbox_max[2]) / 2.0
        print("  Alineando pivote al centro geometrico (CENTER)")
    else:
        pivot_z = bbox_min[2]
        print("  Alineando pivote a la base del objeto (BOTTOM)")

    cursor_location_original = context.scene.cursor.location.copy()
    context.scene.cursor.location = (pivot_x, pivot_y, pivot_z)
    ejecutar_op_viewport(context, bpy.ops.object.origin_set, type='ORIGIN_CURSOR')
    context.scene.cursor.location = cursor_location_original

    print(f"  OK Pivote ajustado a base: ({pivot_x:.3f}, {pivot_y:.3f}, {pivot_z:.3f})")

    print("\n[4/4] Centrando modelo en el mundo y aplicando transformaciones...")
    obj.location = (0, 0, 0)

    # Asegurar modo objeto y aplicar todas las transformaciones para dejar Loc=0, Rot=0, Scale=1
    if context.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')

    context.view_layer.objects.active = obj
    obj.select_set(True)
    ejecutar_op_viewport(context, bpy.ops.object.transform_apply, location=True, rotation=True, scale=True)

    arm = buscar_armature_vinculado(obj)
    if arm:
        arm.location = (0, 0, 0)
        context.view_layer.objects.active = arm
        arm.select_set(True)
        ejecutar_op_viewport(context, bpy.ops.object.transform_apply, location=True, rotation=True, scale=True)
        context.view_layer.objects.active = obj
        # Limpiar formas gigantes y calibrar huesos al preparar
        ajustar_huesos_de_armature(context, arm, obj)

    print("  OK Modelo centrado y transformaciones aplicadas (Loc=0, Rot=0, Scale=1)")

    print(f"\n{'=' * 70}")
    print("PREPARACION COMPLETADA")
    print(f"{'=' * 70}\n")


def exportar_solo_textura(context, obj, output_dir):
    # Siempre usar el nombre de la malla principal, incluso si está seleccionada la Armature
    mesh_principal = resolver_mesh_objetivo(context)
    if mesh_principal:
        nombre_base = mesh_principal.name
    elif obj.type == 'MESH':
        nombre_base = obj.name
    else:
        nombre_base = obj.name

    print(f"\n{'=' * 70}")
    print(f"EXPORTANDO SOLO TEXTURA: {nombre_base}")
    print(f"{'=' * 70}")

    objetos_seleccionados = list(context.selected_objects)
    if not objetos_seleccionados:
        objetos_seleccionados = [obj]

    meshes_a_exportar = set()
    for o in objetos_seleccionados:
        if o.type == 'MESH':
            meshes_a_exportar.add(o)
        elif o.type == 'ARMATURE':
            for scene_obj in context.scene.objects:
                if scene_obj.type == 'MESH' and (scene_obj.parent == o or buscar_armature_vinculado(scene_obj) == o):
                    meshes_a_exportar.add(scene_obj)

        for child in o.children_recursive:
            if child.type == 'MESH':
                meshes_a_exportar.add(child)

    res_mode = getattr(context.scene, "arquera_texture_res", '1K')
    target_dim = 1024 if res_mode == '1K' else 2048

    texturas_exportadas = 0
    for o in meshes_a_exportar:
        textura_difusa_imagen = buscar_textura_difusa(o)
        if textura_difusa_imagen:
            texture_out_path = output_dir / f"{o.name}_D.jpg"

            # Crear copia temporal para escalar sin alterar la imagen original del proyecto
            img_temp = textura_difusa_imagen.copy()
            try:
                orig_w, orig_h = img_temp.size
                if orig_w > 0 and orig_h > 0:
                    if orig_w >= orig_h:
                        new_w = target_dim
                        new_h = max(1, int(orig_h * (target_dim / orig_w)))
                    else:
                        new_h = target_dim
                        new_w = max(1, int(orig_w * (target_dim / orig_h)))
                    img_temp.scale(new_w, new_h)
                    print(f"  Escalando textura de {orig_w}x{orig_h} a {new_w}x{new_h} ({res_mode})")

                img_temp.filepath_raw = str(texture_out_path)
                img_temp.file_format = 'JPEG'
                img_temp.save()
                print(f"  OK Textura exportada para {o.name}: {texture_out_path.name}")
                texturas_exportadas += 1
            except Exception as e:
                print(f"  ADVERTENCIA No se pudo exportar la textura de {o.name}: {e}")
            finally:
                if img_temp and img_temp.name in bpy.data.images:
                    bpy.data.images.remove(img_temp)

    if texturas_exportadas == 0:
        print("  AVISO No se encontraron texturas difusas para exportar")

    print(f"\n{'=' * 70}")
    print("EXPORTACION DE TEXTURA COMPLETADA")
    print(f"{'=' * 70}\n")
    return texturas_exportadas


def exportar_modelo(context, obj, output_dir):
    # Siempre usar el nombre de la malla principal para el archivo GLB
    mesh_principal = resolver_mesh_objetivo(context)
    if mesh_principal:
        nombre_base = mesh_principal.name
    elif obj.type == 'MESH':
        nombre_base = obj.name
    else:
        nombre_base = obj.name

    print(f"\n{'=' * 70}")
    print(f"EXPORTANDO MODELO: {nombre_base}")
    print(f"{'=' * 70}")

    # Guardamos todos los objetos que el usuario tenía seleccionados inicialmente
    objetos_seleccionados = list(context.selected_objects)
    if not objetos_seleccionados:
        objetos_seleccionados = [obj]

    armatures_a_exportar = set()
    meshes_a_exportar = set()

    # 1. Procesar objetos seleccionados directamente e identificar sus armatures y jerarquías
    for o in objetos_seleccionados:
        if o.type == 'ARMATURE':
            armatures_a_exportar.add(o)
        elif o.type == 'MESH':
            meshes_a_exportar.add(o)
            arm = buscar_armature_vinculado(o)
            if arm:
                armatures_a_exportar.add(arm)

        # 2. Procesar hijos recursivos (por si seleccionó un Empty, un grupo o un nodo padre)
        for child in o.children_recursive:
            if child.type == 'MESH':
                meshes_a_exportar.add(child)
                arm = buscar_armature_vinculado(child)
                if arm:
                    armatures_a_exportar.add(arm)
            elif child.type == 'ARMATURE':
                armatures_a_exportar.add(child)

    # 3. Para cada armature que se va a exportar, buscar todos los meshes asociados en toda la escena
    for arm in list(armatures_a_exportar):
        for scene_obj in context.scene.objects:
            if scene_obj.type == 'MESH':
                if scene_obj.parent == arm or buscar_armature_vinculado(scene_obj) == arm:
                    meshes_a_exportar.add(scene_obj)

    # Combinamos todos los objetos que deben ser seleccionados en la exportación
    todos_los_objetos = list(armatures_a_exportar) + list(meshes_a_exportar)

    print(f"Objetos seleccionados por usuario: {[o.name for o in objetos_seleccionados]}")
    print(f"Objetos finales a exportar en el GLB: {[o.name for o in todos_los_objetos]}")

    print("\n[1/2] Exportando GLB sin texturas embebidas (con animaciones si existen)...")
    glb_path = output_dir / f"{nombre_base}.glb"

    # Seleccionar todos los objetos de la exportación (meshes + armatures)
    for o_scene in context.scene.objects:
        o_scene.select_set(False)
    for o in todos_los_objetos:
        o.select_set(True)

    # Establecer un objeto activo válido para evitar problemas en el exportador
    if context.active_object in todos_los_objetos:
        context.view_layer.objects.active = context.active_object
    elif todos_los_objetos:
        context.view_layer.objects.active = todos_los_objetos[0]

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

    print("\n[2/2] Exportando texturas difusas en JPG...")
    texturas_exportadas = exportar_solo_textura(context, obj, output_dir)

    print(f"\n{'=' * 70}")
    print("EXPORTACION COMPLETADA")
    print(f"{'=' * 70}")
    print(f"Archivos generados en: {output_dir}")
    print(f"  - {nombre_base}.glb")
    if texturas_exportadas > 0:
        print(f"  - Texturas JPG correspondientes a cada mesh")
    print(f"{'=' * 70}\n")


def exportar_fbx_sin_animaciones(context, obj, output_dir):
    mesh_principal = resolver_mesh_objetivo(context)
    if mesh_principal:
        nombre_base = mesh_principal.name
    elif obj.type == 'MESH':
        nombre_base = obj.name
    else:
        nombre_base = obj.name

    print(f"\n{'=' * 70}")
    print(f"EXPORTANDO FBX MIXAMO (POSTURA DE REPOSO): {nombre_base}")
    print(f"{'=' * 70}")

    objetos_seleccionados = list(context.selected_objects)
    if not objetos_seleccionados:
        objetos_seleccionados = [obj]

    armatures_a_exportar = set()
    meshes_a_exportar = set()

    for o in objetos_seleccionados:
        if o.type == 'ARMATURE':
            armatures_a_exportar.add(o)
        elif o.type == 'MESH':
            meshes_a_exportar.add(o)
            arm = buscar_armature_vinculado(o)
            if arm:
                armatures_a_exportar.add(arm)

        for child in o.children_recursive:
            if child.type == 'MESH':
                meshes_a_exportar.add(child)
                arm = buscar_armature_vinculado(child)
                if arm:
                    armatures_a_exportar.add(arm)
            elif child.type == 'ARMATURE':
                armatures_a_exportar.add(child)

    for arm in list(armatures_a_exportar):
        for scene_obj in context.scene.objects:
            if scene_obj.type == 'MESH':
                if scene_obj.parent == arm or buscar_armature_vinculado(scene_obj) == arm:
                    meshes_a_exportar.add(scene_obj)

    todos_los_objetos = list(armatures_a_exportar) + list(meshes_a_exportar)

    # 1. Guardar estado original de animaciones y forzar postura de reposo (T-Pose / Bind Pose)
    action_originales = {}
    pose_positions_originales = {}
    for arm in armatures_a_exportar:
        if arm.animation_data and arm.animation_data.action:
            action_originales[arm] = arm.animation_data.action
            arm.animation_data.action = None
        if hasattr(arm.data, "pose_position"):
            pose_positions_originales[arm] = arm.data.pose_position
            # Forzar REST POSE puro para que la malla no se distorsione en Mixamo
            arm.data.pose_position = 'REST'

    fbx_path = output_dir / f"{nombre_base}.fbx"

    for o_scene in context.scene.objects:
        o_scene.select_set(False)
    for o in todos_los_objetos:
        o.select_set(True)

    if context.active_object in todos_los_objetos:
        context.view_layer.objects.active = context.active_object
    elif todos_los_objetos:
        context.view_layer.objects.active = todos_los_objetos[0]

    context.view_layer.update()

    try:
        bpy.ops.export_scene.fbx(
            filepath=str(fbx_path),
            use_selection=True,
            bake_anim=False,
            object_types={'ARMATURE', 'MESH'},
            mesh_smooth_type='FACE',
            add_leaf_bones=False,
            primary_bone_axis='Y',
            secondary_bone_axis='X',
            axis_forward='-Z',
            axis_up='Y',
            armature_nodetype='NULL',
            bake_space_transform=False,
            apply_unit_scale=True,
            apply_scale_options='FBX_SCALE_NONE'
        )
        print(f"  OK FBX exportado para Mixamo: {fbx_path.name}")
    except Exception as e:
        print(f"  ERROR al exportar FBX: {e}")
    finally:
        # Restaurar animaciones y estado de pose en las armatures de la escena
        for arm, act in action_originales.items():
            if arm.animation_data:
                arm.animation_data.action = act
        for arm, pos_orig in pose_positions_originales.items():
            if hasattr(arm.data, "pose_position"):
                arm.data.pose_position = pos_orig
        context.view_layer.update()
        if context.scene:
            context.scene.frame_set(context.scene.frame_current)

    print(f"\n{'=' * 70}")
    print("EXPORTACION FBX MIXAMO COMPLETADA")
    print(f"Archivo generado: {fbx_path}")
    print(f"{'=' * 70}\n")


class ARQUERA_OT_prepare_model(Operator):
    """Ejecuta Paso 1: Preparar Modelo (limpieza, merge, pivote y centrado)"""

    bl_idname = "arquera.prepare_model"
    bl_label = "Preparar Modelo - Paso 1"
    bl_options = {'REGISTER', 'UNDO'}

    nombre_modelo: StringProperty(
        name="Nombre del Modelo",
        description="Nombre que se asignara al objeto/modelo y sus recursos",
        default=""
    )

    def invoke(self, context, event):
        obj = resolver_mesh_objetivo(context)
        if not obj:
            self.report({'ERROR'}, "Debes seleccionar un MESH o ARMATURE con MESH vinculado")
            return {'CANCELLED'}

        # Prellenar con el nombre actual
        self.nombre_modelo = obj.name
        return context.window_manager.invoke_props_dialog(self, width=320)

    def draw(self, context):
        layout = self.layout
        layout.label(text="Ingresa el nombre del modelo:", icon='OBJECT_DATAMODE')
        layout.prop(self, "nombre_modelo", text="")

    def execute(self, context):
        obj = resolver_mesh_objetivo(context)
        if not obj:
            self.report({'ERROR'}, "Debes seleccionar un MESH o ARMATURE con MESH vinculado")
            return {'CANCELLED'}

        nuevo_nombre = self.nombre_modelo.strip()
        if nuevo_nombre:
            obj.name = nuevo_nombre
            if context.active_object and context.active_object != obj:
                context.active_object.name = nuevo_nombre

        preparar_modelo(context, obj)
        self.report({'INFO'}, f"Preparacion completada: {obj.name}")
        return {'FINISHED'}


class ARQUERA_OT_export_model(Operator, ExportHelper):
    """Ejecuta pasos 7-8 de exportacion"""

    bl_idname = "arquera.export_model"
    bl_label = "Exportar GLB + JPG (pasos 7-8)"
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


class ARQUERA_OT_export_fbx_no_anim(Operator, ExportHelper):
    """Exporta el modelo y esqueleto en postura de reposo optimizado para Mixamo (sin animaciones)"""

    bl_idname = "arquera.export_fbx_no_anim"
    bl_label = "Exportar FBX MIXAMO"
    bl_options = {'PRESET', 'UNDO'}

    filename_ext = ""
    filter_folder = True

    directory: StringProperty(
        name="Directorio",
        description="Carpeta donde se exportara el archivo FBX",
        subtype='DIR_PATH'
    )

    def execute(self, context):
        obj = resolver_mesh_objetivo(context)
        if not obj:
            self.report({'ERROR'}, "Debes seleccionar un MESH o ARMATURE con MESH vinculado")
            return {'CANCELLED'}

        output_dir = Path(self.directory)
        output_dir.mkdir(parents=True, exist_ok=True)

        exportar_fbx_sin_animaciones(context, obj, output_dir)
        self.report({'INFO'}, f"FBX exportado sin animaciones: {obj.name}.fbx")
        return {'FINISHED'}

    def invoke(self, context, event):
        if not resolver_mesh_objetivo(context):
            self.report({'ERROR'}, "Debes seleccionar un MESH o ARMATURE con MESH vinculado antes de ejecutar")
            return {'CANCELLED'}

        context.window_manager.fileselect_add(self)
        return {'RUNNING_MODAL'}


class ARQUERA_OT_export_texture_only(Operator, ExportHelper):
    """Exporta solo las texturas difusas en JPG"""

    bl_idname = "arquera.export_texture_only"
    bl_label = "Exportar Solo Textura (JPG)"
    bl_options = {'PRESET', 'UNDO'}

    filename_ext = ""
    filter_folder = True

    directory: StringProperty(
        name="Directorio",
        description="Carpeta donde se exportara la textura",
        subtype='DIR_PATH'
    )

    def execute(self, context):
        obj = resolver_mesh_objetivo(context)
        if not obj:
            self.report({'ERROR'}, "Debes seleccionar un MESH o ARMATURE con MESH vinculado")
            return {'CANCELLED'}

        output_dir = Path(self.directory)
        output_dir.mkdir(parents=True, exist_ok=True)

        count = exportar_solo_textura(context, obj, output_dir)
        if count > 0:
            self.report({'INFO'}, f"Textura exportada ({count} archivo/s)")
        else:
            self.report({'WARNING'}, "No se encontraron texturas difusas para exportar")
        return {'FINISHED'}

    def invoke(self, context, event):
        if not resolver_mesh_objetivo(context):
            self.report({'ERROR'}, "Debes seleccionar un MESH o ARMATURE con MESH vinculado antes de ejecutar")
            return {'CANCELLED'}

        context.window_manager.fileselect_add(self)
        return {'RUNNING_MODAL'}


def obtener_nombres_huesos_con_peso(mesh_obj) -> set:
    huesos_con_peso = set()
    if not mesh_obj or mesh_obj.type != 'MESH' or not mesh_obj.data:
        return huesos_con_peso

    vg_map = {vg.index: vg.name for vg in mesh_obj.vertex_groups}
    for v in mesh_obj.data.vertices:
        for g in v.groups:
            if g.weight > 0.0001 and g.group in vg_map:
                huesos_con_peso.add(vg_map[g.group])
    return huesos_con_peso


def ajustar_huesos_de_armature(context, armature_obj=None, mesh_obj=None) -> bool:
    """
    Mide el modelo 3D y ajusta la escala visual de los huesos en la Armature:
    - Elimina todos los huesos terminales/nub bones sin influencia (HeadTop_End, Toe_End, Thumb4_end, etc.)
    - Elimina icósferas, aros y formas personalizadas
    - Ajusta la longitud de los huesos restantes a la proporción del cuerpo
    - Mantiene intactos el skinning, pesos y matrices de animación.
    """
    if not armature_obj:
        if context.active_object and context.active_object.type == 'ARMATURE':
            armature_obj = context.active_object
        else:
            m = resolver_mesh_objetivo(context)
            if m:
                mesh_obj = m
                armature_obj = buscar_armature_vinculado(m)

    if not armature_obj or armature_obj.type != 'ARMATURE':
        for o in context.scene.objects:
            if o.type == 'ARMATURE':
                armature_obj = o
                break

    if not armature_obj or armature_obj.type != 'ARMATURE':
        print("  AVISO No se encontro un Armature valido para ajustar huesos")
        return False

    if not mesh_obj:
        for o in context.scene.objects:
            if o.type == 'MESH' and (o.parent == armature_obj or buscar_armature_vinculado(o) == armature_obj):
                mesh_obj = o
                break

    # 1. Medir la altura real del modelo 3D
    altura_modelo = 1.0
    if mesh_obj and mesh_obj.data and len(mesh_obj.data.vertices) > 0:
        z_coords = [(mesh_obj.matrix_world @ v.co).z for v in mesh_obj.data.vertices]
        if z_coords:
            altura_modelo = max(0.1, max(z_coords) - min(z_coords))
    elif armature_obj.dimensions.z > 0:
        altura_modelo = max(0.1, armature_obj.dimensions.z)

    longitud_ideal_punta = max(0.02, altura_modelo * 0.04)

    # 2. Desactivar y LIMPIAR Custom Shapes (círculos e icósferas) de todos los Pose Bones
    if hasattr(armature_obj.data, "show_bone_custom_shapes"):
        armature_obj.data.show_bone_custom_shapes = False

    if armature_obj.pose:
        for pb in armature_obj.pose.bones:
            pb.custom_shape = None
            if hasattr(pb, "custom_shape_scale_xyz"):
                pb.custom_shape_scale_xyz = (1.0, 1.0, 1.0)

    # 3. Eliminar colecciones y objetos huérfanos de formas creadas por el importador glTF
    objetos_forma_a_borrar = []
    for o in list(bpy.data.objects):
        nombre_lower = o.name.lower()
        if "gltf_not_exported" in nombre_lower or "bone_shape" in nombre_lower or "icosphere" in nombre_lower or "circle" in nombre_lower:
            if o.type in {'MESH', 'CURVE', 'EMPTY'} and o != mesh_obj:
                objetos_forma_a_borrar.append(o)

    for o in objetos_forma_a_borrar:
        bpy.data.objects.remove(o, do_unlink=True)

    for col in list(bpy.data.collections):
        if "gltf_not_exported" in col.name.lower():
            bpy.data.collections.remove(col)

    # 4. Modo EDIT: Normalizar la longitud visual de las puntas y cabeza (sin borrar huesos para preservar animaciones)
    modo_original = context.mode
    if modo_original != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')

    context.view_layer.objects.active = armature_obj
    armature_obj.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')

    huesos_ajustados = 0
    for eb in armature_obj.data.edit_bones:
        dir_vec = eb.tail - eb.head
        if dir_vec.length == 0:
            continue

        # Si es hueso de punta/terminal (leaf bone) o hueso de cabeza
        if len(eb.children) == 0:
            eb.tail = eb.head + dir_vec.normalized() * longitud_ideal_punta
            huesos_ajustados += 1
        elif "head" in eb.name.lower() and len(eb.children) <= 1:
            max_head_len = max(0.04, altura_modelo * 0.08)
            if dir_vec.length > max_head_len:
                eb.tail = eb.head + dir_vec.normalized() * max_head_len
                huesos_ajustados += 1
        elif dir_vec.length > altura_modelo * 0.35:
            eb.tail = eb.head + dir_vec.normalized() * (altura_modelo * 0.15)
            huesos_ajustados += 1

    bpy.ops.object.mode_set(mode='OBJECT')

    # 5. Configurar visualización limpia como STICK (varillas finas)
    if hasattr(armature_obj.data, "display_type"):
        armature_obj.data.display_type = 'STICK'
    armature_obj.show_in_front = True

    print(f"  OK Huesos visualmente normalizados ({huesos_ajustados} huesos)")
    return True


class ARQUERA_OT_import_glb_clean(Operator, ImportHelper):
    """Importa un archivo GLB/glTF configurando automaticamente los huesos limpios y proporcionales"""

    bl_idname = "arquera.import_glb_clean"
    bl_label = "Importar GLB (Auto-Ajustar Huesos)"
    bl_options = {'REGISTER', 'UNDO'}

    filename_ext = ".glb"
    filter_glob: StringProperty(
        default="*.glb;*.gltf",
        options={'HIDDEN'}
    )

    def execute(self, context):
        try:
            bpy.ops.import_scene.gltf(
                filepath=self.filepath,
                bone_heuristic='TEMPERANCE',
                disable_bone_shape=True,
            )
        except Exception as e:
            self.report({'ERROR'}, f"Error al importar GLB: {e}")
            return {'CANCELLED'}

        # Auto-ajustar visualización de huesos recién importados
        ajustar_huesos_de_armature(context)
        self.report({'INFO'}, "GLB importado con huesos limpios y proporcionados")
        return {'FINISHED'}


class ARQUERA_OT_clean_scene(Operator):
    """Elimina el cubo, camaras y luces por defecto de la escena"""

    bl_idname = "arquera.clean_scene"
    bl_label = "Limpiar Escena"
    bl_options = {'REGISTER', 'UNDO'}

    def execute(self, context):
        objetos_a_borrar = []
        for obj in context.scene.objects:
            if obj.name.lower().startswith("cube") or obj.name.lower().startswith("cubo") or obj.type in {'CAMERA', 'LIGHT'}:
                objetos_a_borrar.append(obj)

        if objetos_a_borrar:
            for obj in objetos_a_borrar:
                bpy.data.objects.remove(obj, do_unlink=True)
            for mesh in list(bpy.data.meshes):
                if mesh.users == 0:
                    bpy.data.meshes.remove(mesh)
            self.report({'INFO'}, f"Escena limpia: {len(objetos_a_borrar)} objeto/s eliminados")
        else:
            self.report({'INFO'}, "La escena ya esta limpia")
        return {'FINISHED'}


def obtener_lista_actions(self, context):
    items = [('NONE', "-- Sin Animacion --", "No reproduce ninguna animacion")]
    acciones_validas = []

    for act in bpy.data.actions:
        if not act or not act.name:
            continue
        if not es_nombre_action_valido(act.name):
            continue
        acciones_validas.append(act)

    # Ordenar alfabeticamente para una lista limpia y facil de navegar
    acciones_validas.sort(key=lambda a: a.name.lower())

    for act in acciones_validas:
        items.append((act.name, act.name, f"Reproducir animacion: {act.name}"))
    return items


def al_ajustar_altura_hips_y(self, context):
    try:
        ctx = context if context else bpy.context
        scene = getattr(ctx, "scene", None)
        if not scene:
            scene = bpy.context.scene
        if not scene:
            return

        nuevo_val = getattr(scene, "arquera_hips_y_offset", 0.0)
        act_name = getattr(scene, "arquera_active_action", "NONE")
        action = bpy.data.actions.get(act_name) if act_name and act_name != 'NONE' else None
        
        arm = ctx.active_object if (ctx.active_object and ctx.active_object.type == 'ARMATURE') else None
        if not arm:
            for obj in scene.objects:
                if obj.type == 'ARMATURE':
                    arm = obj
                    break

        if not action and arm and arm.animation_data and arm.animation_data.action:
            action = arm.animation_data.action

        if not action:
            return

        frame_inicio = 1.0
        if action.frame_range:
            frame_inicio = float(action.frame_range[0])

        todas_curvas = obtener_todas_las_fcurves(action, arm)
        curvas_modificadas = 0

        for fc in todas_curvas:
            if es_curva_hips_y(fc):
                # Deja exactamente 1 solo fotograma en la curva Y y asigna el valor directo del Slider
                fijar_fcurve_un_fotograma(fc, frame_inicio, nuevo_val)
                curvas_modificadas += 1

        if hasattr(action, "tag_update"):
            action.tag_update()
        if hasattr(action, "update_tag"):
            action.update_tag()

        # Forzar redibujado de la animación y del Graph Editor
        if arm and arm.animation_data:
            arm.update_tag(refresh={'DATA', 'OBJECT', 'TIME'})

        for window in ctx.window_manager.windows:
            for area in window.screen.areas:
                if area.type in {'GRAPH_EDITOR', 'DOPESHEET_EDITOR', 'VIEW_3D'}:
                    area.tag_redraw()

        ctx.view_layer.update()
        scene.frame_set(scene.frame_current)
    except Exception as e:
        print(f"[Arquera Tools] Error al mover slider Hips Y: {e}")


def al_cambiar_action(self, context):
    selected_act_name = context.scene.arquera_active_action
    
    arm = None
    if context.active_object and context.active_object.type == 'ARMATURE':
        arm = context.active_object
    else:
        m = resolver_mesh_objetivo(context)
        if m:
            arm = buscar_armature_vinculado(m)

    if not arm:
        for o in context.scene.objects:
            if o.type == 'ARMATURE':
                arm = o
                break

    if arm:
        if not arm.animation_data:
            arm.animation_data_create()

        if selected_act_name == 'NONE':
            arm.animation_data.action = None
        else:
            act = bpy.data.actions.get(selected_act_name)
            if act:
                arm.animation_data.action = act
                if act.frame_range:
                    context.scene.frame_start = int(act.frame_range[0])
                    context.scene.frame_end = int(act.frame_range[1])
                    context.scene.frame_current = int(act.frame_range[0])

                # Leer el valor actual del fotograma de Y si existe
                todas = obtener_todas_las_fcurves(act, arm)
                valor_y = None
                for fc in todas:
                    if es_curva_hips_y(fc) and len(fc.keyframe_points) > 0:
                        valor_y = fc.keyframe_points[0].co[1]
                        break

                if valor_y is not None:
                    try:
                        context.scene["arquera_hips_y_offset"] = valor_y
                    except Exception:
                        pass

        arm.update_tag(refresh={'DATA', 'OBJECT'})
    context.view_layer.update()


class ARQUERA_PT_tools_panel(Panel):
    """Panel principal de herramientas Arquera"""

    bl_label = "Arquera Tools"
    bl_idname = "ARQUERA_PT_tools"
    bl_space_type = 'VIEW_3D'
    bl_region_type = 'UI'
    bl_category = 'Arquera Tools'

    def draw(self, context):
        layout = self.layout

        # Botón Limpiar Escena arriba de todo (Destacado en Rojo / Alert)
        box_clean = layout.box()
        col_clean = box_clean.column()
        col_clean.alert = True
        col_clean.scale_y = 1.25
        col_clean.operator(
            "arquera.clean_scene",
            text="LIMPIAR ESCENA",
            icon='TRASH',
        )

        # Sección de Animaciones y Rig
        box_anim = layout.box()
        box_anim.label(text="Animaciones / Rig", icon='ANIM')
        
        col_anim = box_anim.column(align=True)
        col_anim.scale_y = 1.15
        col_anim.operator(
            "arquera.import_glb_clean",
            text="IMPORTAR GLB PARA AÑADIR ANIMACION NUEVA",
            icon='IMPORT',
        )
        col_anim.operator(
            "arquera.import_fbx_actions",
            text="IMPORTAR ANIMACIONES NUEVAS",
            icon='ACTION',
        )

        # Selector de Actions / Animaciones
        if len(bpy.data.actions) > 0:
            box_anim.separator()
            row_act_lbl = box_anim.row()
            row_act_lbl.label(text="Visualizar Animacion:", icon='PLAY')
            box_anim.prop(context.scene, "arquera_active_action", text="")

            box_anim.separator()
            box_anim.label(text="Centrado de Animacion:", icon='CON_LOCLIKE')
            
            col_centrado = box_anim.column(align=True)
            col_centrado.scale_y = 1.25
            col_centrado.operator(
                "arquera.center_xz",
                text="CENTRAR X y Z (SUELO)",
                icon='SNAP_MIDPOINT',
            )

            # Slider para el eje Y del Hips (suma/resta a todos los cuadros)
            box_anim.separator()
            box_anim.label(text="Ajuste Altura Hips (Eje Y):", icon='ARROW_LEFTRIGHT')
            row_slider = box_anim.row(align=True)
            row_slider.scale_y = 1.25
            row_slider.prop(context.scene, "arquera_hips_y_offset", text="Altura Y (m)", slider=True)

            box_anim.separator()
            row_tools = box_anim.row(align=True)
            row_tools.scale_y = 1.15
            
            col_clean_act = row_tools.column()
            col_clean_act.operator(
                "arquera.clean_garbage_actions",
                text="LIMPIAR BASURA / @",
                icon='BRUSH_DATA',
            )
            
            col_del_act = row_tools.column()
            col_del_act.alert = True
            col_del_act.operator(
                "arquera.delete_active_action",
                text="ELIMINAR ACTION",
                icon='TRASH',
            )

        # Sección de Exportación
        box_exp = layout.box()
        box_exp.label(text="Exportacion de Modelos", icon='EXPORT')

        mesh_objetivo = resolver_mesh_objetivo(context)
        if mesh_objetivo:
            # Indicador de objeto activo
            row_obj = box_exp.row(align=True)
            row_obj.label(text=f"Objeto: {mesh_objetivo.name}", icon='CHECKMARK')
            
            # Selector de pivote en botones (Base / Centro)
            box_exp.label(text="Alineacion Pivote:")
            row_piv = box_exp.row(align=True)
            row_piv.scale_y = 1.1
            row_piv.prop(context.scene, "arquera_pivot_mode", expand=True)

            box_exp.prop(context.scene, "arquera_merge_enabled")
            
            # Selector de resolución de textura (1K / 2K)
            box_exp.label(text="Resolucion Textura:")
            row_res = box_exp.row(align=True)
            row_res.scale_y = 1.1
            row_res.prop(context.scene, "arquera_texture_res", expand=True)

            box_exp.separator()
            
            # Botón Paso 1 (Destacado en caja individual)
            box_p1 = box_exp.box()
            col_p1 = box_p1.column()
            col_p1.scale_y = 1.3
            col_p1.operator(
                "arquera.prepare_model",
                text="Preparar Modelo - Paso 1",
                icon='TOOL_SETTINGS',
            )

            # Botón Paso 2 GLB (Destacado en caja individual)
            box_p2 = box_exp.box()
            col_p2 = box_p2.column()
            col_p2.scale_y = 1.3
            col_p2.operator(
                "arquera.export_model",
                text="Exportar GLB + JPG - Paso 2",
                icon='FILE_TICK',
            )

            # Botón FBX Mixamo
            box_fbx = box_exp.box()
            col_fbx = box_fbx.column()
            col_fbx.scale_y = 1.15
            col_fbx.operator(
                "arquera.export_fbx_no_anim",
                text="Exportar FBX MIXAMO",
                icon='OUTLINER_OB_ARMATURE',
            )

            # Botón Solo Textura
            box_tex = box_exp.box()
            col_tex = box_tex.column()
            col_tex.scale_y = 1.1
            col_tex.operator(
                "arquera.export_texture_only",
                text="Exportar Solo Textura (JPG)",
                icon='IMAGE_DATA',
            )
        elif context.active_object:
            row_warn = box_exp.row()
            row_warn.alert = True
            row_warn.label(text="Selecciona un MESH o ARMATURE valido", icon='ERROR')
        else:
            row_info = box_exp.row()
            row_info.label(text="Sin objeto seleccionado en la escena", icon='INFO')

        box_info = layout.box()
        box_info.label(text="Info del Proyecto", icon='INFO')
        box_info.label(text="Arrow of Anathema")
        box_info.label(text="Godot 4.x Engine")


classes = (
    ARQUERA_OT_clean_scene,
    ARQUERA_OT_import_glb_clean,
    ARQUERA_OT_import_fbx_actions,
    ARQUERA_OT_center_xz,
    ARQUERA_OT_clean_garbage_actions,
    ARQUERA_OT_delete_active_action,
    ARQUERA_OT_prepare_model,
    ARQUERA_OT_export_model,
    ARQUERA_OT_export_fbx_no_anim,
    ARQUERA_OT_export_texture_only,
    ARQUERA_PT_tools_panel,
)


def register():
    for cls in classes:
        bpy.utils.register_class(cls)
    bpy.types.Scene.arquera_pivot_mode = EnumProperty(
        name="Alineacion Pivote",
        description="Elige como centrar el pivote del modelo",
        items=[
            ('BOTTOM', "Base", "Centra el pivote en el fondo del bounding box (ideal para personajes)"),
            ('CENTER', "Centro", "Centra el pivote en el centro del bounding box (ideal para proyectiles y objetos voladores)"),
        ],
        default='BOTTOM'
    )
    bpy.types.Scene.arquera_merge_enabled = BoolProperty(
        name="Merge by Distance",
        description="Activa/desactiva la fusion de vertices duplicados en Preparar Modelo",
        default=True,
    )
    bpy.types.Scene.arquera_texture_res = EnumProperty(
        name="Resolucion de Textura",
        description="Escala las texturas exportadas a 1K o 2K",
        items=[
            ('1K', "1K", "Escala la textura a 1024px"),
            ('2K', "2K", "Escala la textura a 2048px"),
        ],
        default='1K'
    )
    bpy.types.Scene.arquera_active_action = EnumProperty(
        name="Animacion",
        description="Selecciona una animacion para previsualizar en el modelo",
        items=obtener_lista_actions,
        update=al_cambiar_action
    )
    bpy.types.Scene.arquera_hips_y_offset = FloatProperty(
        name="Altura Hips (Y)",
        description="Suma o resta altura en metros a todos los fotogramas de la curva Y del Hips",
        default=0.0,
        min=-20.0,
        max=20.0,
        step=1.0,
        precision=3,
        update=al_ajustar_altura_hips_y,
    )
    print("OK Arquera Tools registrado")


def unregister():
    for cls in reversed(classes):
        bpy.utils.unregister_class(cls)
    if hasattr(bpy.types.Scene, "arquera_pivot_mode"):
        del bpy.types.Scene.arquera_pivot_mode
    if hasattr(bpy.types.Scene, "arquera_merge_enabled"):
        del bpy.types.Scene.arquera_merge_enabled
    if hasattr(bpy.types.Scene, "arquera_texture_res"):
        del bpy.types.Scene.arquera_texture_res
    if hasattr(bpy.types.Scene, "arquera_active_action"):
        del bpy.types.Scene.arquera_active_action
    if hasattr(bpy.types.Scene, "arquera_hips_y_offset"):
        del bpy.types.Scene.arquera_hips_y_offset
    print("OK Arquera Tools desregistrado")


if __name__ == "__main__":
    register()
