"""Utilidad de diagnóstico: imprime nodos, transformadas y bounds de modelos GLB.

Uso:
    python Tools/glb_bounds.py "ruta/al/modelo.glb" [...]
"""

import json
import struct
import sys


def glb_info(path: str) -> dict:
    with open(path, "rb") as f:
        data = f.read()

    magic, _ver, length = struct.unpack("<III", data[:12])
    if magic != 0x46546C67:  # "glTF"
        raise ValueError("No es un GLB válido: %s" % path)

    offset = 12
    json_chunk = None
    while offset < length:
        chunk_len, chunk_type = struct.unpack("<II", data[offset:offset + 8])
        chunk_data = data[offset + 8:offset + 8 + chunk_len]
        if chunk_type == 0x4E4F534A:  # "JSON"
            json_chunk = chunk_data
        offset += 8 + chunk_len

    gltf = json.loads(json_chunk.decode("utf-8"))

    nodes = []
    for node in gltf.get("nodes", []):
        nodes.append({
            "name": node.get("name"),
            "mesh": node.get("mesh"),
            "translation": node.get("translation"),
            "rotation": node.get("rotation"),
            "scale": node.get("scale"),
            "children": node.get("children"),
        })

    meshes = []
    for mesh in gltf.get("meshes", []):
        prims = []
        for prim in mesh.get("primitives", []):
            acc = gltf["accessors"][prim["attributes"]["POSITION"]]
            prims.append({"min": acc.get("min"), "max": acc.get("max")})
        meshes.append({"name": mesh.get("name"), "prims": prims})

    return {"nodes": nodes, "meshes": meshes, "animations": gltf.get("animations", [])}


def main() -> None:
    for path in sys.argv[1:]:
        print("===== %s" % path)
        try:
            info = glb_info(path)
            for node in info["nodes"]:
                print("  node:", json.dumps(node, ensure_ascii=False))
            for mesh in info["meshes"]:
                print("  mesh:", mesh["name"], mesh["prims"])
            print("  animations:", len(info["animations"]))
        except Exception as exc:  # noqa: BLE001 - utilidad de diagnóstico
            print("  ERROR:", exc)


if __name__ == "__main__":
    main()
