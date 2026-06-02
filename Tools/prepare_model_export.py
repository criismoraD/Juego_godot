"""
===========================================================================
PREPARE MODEL EXPORT - Preparacion de modelo para Blender
===========================================================================
Prepara modelos 3D para exportar a Godot con convenciones especificas:
    1. Renombra Material -> [nombre]_M
    2. Renombra Textura difusa -> [nombre]_D
    3. Limpia texturas (solo mantiene difusa/color)
    4. Coloca el pivote en la base del modelo (centro inferior)
    5. Centra el modelo en el mundo (0,0,0)

REQUISITO: Seleccionar el objeto a procesar antes de ejecutar.

USO:
    1. Abrir Blender con tu modelo
    2. Seleccionar el objeto (mesh)
    3. Ir a Scripting -> Abrir este archivo
    4. Ejecutar (Alt+P)
    5. El objeto quedara preparado para exportacion
===========================================================================
"""

import bpy
from bpy.types import Operator


class OBJECT_OT_prepare_model(Operator):
    """Prepara modelo para exportacion (pasos 1 a 5)"""
    
    bl_idname = "object.prepare_model"
    bl_label = "Preparar Modelo (Pasos 1-5)"
    bl_options = {'REGISTER', 'UNDO'}
    
    def execute(self, context):
        # Verificar que hay un objeto seleccionado
        if not context.active_object or context.active_object.type != 'MESH':
            self.report({'ERROR'}, "Debes seleccionar un objeto MESH")
            return {'CANCELLED'}
        
        obj = context.active_object
        nombre_base = obj.name
        
        print(f"\n{'='*70}")
        print(f"PREPARANDO MODELO: {nombre_base}")
        print(f"{'='*70}")
        
        # ═══════════════════════════════════════════════════════════════════
        # PASO 1: Renombrar materiales y limpiar texturas
        # ═══════════════════════════════════════════════════════════════════
        print("\n[1/3] Procesando materiales y texturas...")
        
        if obj.data.materials:
            for mat_slot in obj.data.materials:
                mat = mat_slot
                if mat and mat.node_tree:
                    mat.name = f"{nombre_base}_M"
                    print(f"  ✓ Material renombrado: {mat.name}")

                    nodes = mat.node_tree.nodes
                    links = mat.node_tree.links
                    principled = None
                    image_node = None

                    for node in nodes:
                        if node.type == 'BSDF_PRINCIPLED':
                            principled = node
                            break

                    if not principled:
                        print("  ⚠ Material sin Principled BSDF, se omite limpieza")
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
                        print(f"  ✓ Textura difusa encontrada: {image_name}")

                        if base_color_input:
                            for link in list(base_color_input.links):
                                links.remove(link)
                            links.new(image_node.outputs.get('Color'), base_color_input)

                    # Desconectar todos los mapas no difusos del Principled
                    for input_socket in principled.inputs:
                        if input_socket.name == 'Base Color':
                            continue
                        for link in list(input_socket.links):
                            links.remove(link)

                    # Mantener solo: Output, Principled y textura difusa
                    nodos_permitidos = {principled}
                    if image_node:
                        nodos_permitidos.add(image_node)

                    nodos_eliminados = 0
                    for node in list(nodes):
                        if node in nodos_permitidos or node.type == 'OUTPUT_MATERIAL':
                            continue
                        nodes.remove(node)
                        nodos_eliminados += 1

                    print(f"  ✓ Nodos no difusos eliminados: {nodos_eliminados}")
        else:
            print("  ⚠ Objeto sin materiales")
        
        # ═══════════════════════════════════════════════════════════════════
        # PASO 2: Colocar pivote en la base del modelo
        # ═══════════════════════════════════════════════════════════════════
        print("\n[2/3] Ajustando pivote...")
        
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
        print("\n[3/3] Centrando modelo en el mundo...")
        obj.location = (0, 0, 0)
        print(f"  ✓ Modelo centrado en (0, 0, 0)")

        print(f"\n{'='*70}")
        print("✅ PREPARACION COMPLETADA")
        print(f"{'='*70}")
        print("Tareas realizadas:")
        print("  • Material renombrado a [nombre]_M")
        print("  • Textura difusa renombrada a [nombre]_D")
        print("  • Texturas extra eliminadas")
        print("  • Pivote colocado en la base")
        print("  • Modelo centrado en el mundo")
        print("\nSiguiente paso: ejecutar el script de exportacion (pasos 6-7).")
        print(f"{'='*70}\n")
        
        self.report({'INFO'}, f"Preparacion completada para: {nombre_base}")
        return {'FINISHED'}


def menu_func_prepare(self, context):
    """Añadir al menu Object"""
    self.layout.operator(OBJECT_OT_prepare_model.bl_idname, text="Preparar Modelo (Pasos 1-5)")


def register():
    """Registrar el operador"""
    bpy.utils.register_class(OBJECT_OT_prepare_model)
    bpy.types.VIEW3D_MT_object.append(menu_func_prepare)


def unregister():
    """Desregistrar el operador"""
    bpy.types.VIEW3D_MT_object.remove(menu_func_prepare)
    bpy.utils.unregister_class(OBJECT_OT_prepare_model)


# ═══════════════════════════════════════════════════════════════════════════
# Ejecutar directamente desde el editor de scripts
# ═══════════════════════════════════════════════════════════════════════════
if __name__ == "__main__":
    register()
    
    # Si se ejecuta desde el editor, invocar directamente
    bpy.ops.object.prepare_model('INVOKE_DEFAULT')
