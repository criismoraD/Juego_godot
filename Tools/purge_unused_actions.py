"""
Blender Script: Purge Unused Actions (remap)
=============================================
1. Desactiva el "Fake User" (escudo) SOLO de las Actions cuyo nombre
   contenga "remap" (case-insensitive).
2. Ejecuta un Purge de datos no usados (recursivo).
3. Reactiva el "Fake User" (escudo) en todas las Actions que sobrevivieron.

Uso: Abrir en Blender > Text Editor > Run Script  (o arrastrar al viewport)
"""

import bpy

# Palabra clave para filtrar — solo se purgaran actions con esto en el nombre
FILTER_KEYWORD = "remap"


def main():
    # ------------------------------------------------------------------ #
    # PASO 1 – Quitar el escudo (fake_user) solo de Actions con "remap"
    # ------------------------------------------------------------------ #
    total_before = len(bpy.data.actions)
    disabled_count = 0
    for action in bpy.data.actions:
        if FILTER_KEYWORD.lower() in action.name.lower():
            action.use_fake_user = False
            disabled_count += 1
            print(f"  ✗ Escudo quitado: {action.name}")
    print(f"[Paso 1] Escudo desactivado en {disabled_count} de {total_before} action(s) (filtro: '{FILTER_KEYWORD}').")

    # ------------------------------------------------------------------ #
    # PASO 2 – Purge Unused Data (recursivo)
    # ------------------------------------------------------------------ #
    # bpy.ops.outliner.orphans_purge requiere contexto de outliner,
    # así que usamos la API directa disponible desde Blender 3.x:
    # bpy.data.orphans_purge() devuelve el número de bloques eliminados.
    purged_total = 0
    # Purge recursivo: repetir hasta que ya no quede nada por limpiar.
    while True:
        purged = bpy.data.orphans_purge(
            do_local_ids=True,
            do_linked_ids=True,
            do_recursive=True,
        )
        purged_total += purged
        if purged == 0:
            break

    remaining = len(bpy.data.actions)
    removed = total_before - remaining
    print(f"[Paso 2] Purge completado — {purged_total} data-block(s) eliminado(s) en total.")
    print(f"         Actions eliminadas: {removed}  |  Actions restantes: {remaining}")

    # ------------------------------------------------------------------ #
    # PASO 3 – Reactivar el escudo en las Actions sobrevivientes
    # ------------------------------------------------------------------ #
    for action in bpy.data.actions:
        action.use_fake_user = True
    print(f"[Paso 3] Escudo reactivado en {remaining} action(s) restante(s).")

    print("--- Proceso terminado ---")


if __name__ == "__main__":
    main()
