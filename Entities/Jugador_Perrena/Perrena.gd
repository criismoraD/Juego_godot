class_name Perrena
extends "res://Entities/Jugador_Arquera/Player.gd"

## Perrena — defensora controlable (variante arquera de la protagonista):
## - Movimientos completos de la protagonista (correr, saltar, agacharse, escaleras).
## - Disparo con arco animado y mecánicas completas de proyectiles (normales, explosivas, múltiples).
## - Mantiene el HUD y sistema de corazones de la protagonista.
## - Como defensora controlable tiene 3 de vida (vida_maxima).

const MAT_PERRENA: Material = preload("res://Entities/Jugador_Perrena/PERRENA_MAT.tres")
const ARCO_SCENE: PackedScene = preload("res://Entities/Jugador_Arquera/GEO_ARCO_ANIMADO.fbx")
const FLECHA_SCENE: PackedScene = preload("res://Entities/Jugador_Arquera/FLECHA.fbx")
const FLECHA_EXPLOSIVA_SCENE: PackedScene = preload("res://Entities/Flecha_Explosiva/Flecha_Explosiva.glb")

## Mapeo de clips del GLB de Perrena -> nombres que el AnimationTree del Player espera.
## Debe registrarse ANTES de que el Player construya su árbol dinámico.
const MAPEO_ANIMS: Dictionary = {
	"Idle": "Armature|Armature|IDLE",
	"Caminar": "Armature|Armature|CAMINAR_ADELANTE",
	"Correr": "Armature|Armature|CORRER_ADELANTE",
	"Disparo arco": "Armature|Armature|DISPARAR",
	"Aterrizar": "Armature|Armature|ATERRIZAJE",
	"Saltar": "Armature|Armature|CAER_SALTAR",
	"agacharse": "Armature|Armature|CAER_SALTAR",
	"pararse": "Armature|Armature|IDLE",
	"impacto": "Armature|Armature|HIT",
	"Muerte 1": "Armature|Armature|MUERTE",
	# Equivalentes aproximados para los estados restantes del árbol del Player
	"@caminar_atras": "Armature|Armature|CAMINAR_ATRAS",
	"@apuntar": "Armature|Armature|APUNTAR_IDLE",
	"@tomar_flecha": "Armature|Armature|TOMAR_FLECHA",
	"@escalar": "Armature|Armature|SUBIR_ESCALERA",
}
const SUBSTITUCIONES_ANIMS: Dictionary = {
	"@caminar_atras": "Caminar",
	"@apuntar": "Disparo arco",
	"@tomar_flecha": "Disparo arco",
	"@escalar": "Caminar",
}


func _init() -> void:
	vida_maxima = 3
	duracion_maxima_disparo = 0.20


func _ready() -> void:
	# 1. Conectar el AnimationTree al AnimationPlayer del GLB de Perrena
	var tree := find_child("AnimationTree", true, false) as AnimationTree
	var anim_p := find_child("AnimationPlayer", true, false) as AnimationPlayer
	if tree and anim_p:
		tree.anim_player = tree.get_path_to(anim_p)

	# 2. Aplicar textura personalizada de Perrena
	var modelo := find_child("PerrenaModel", true, false) as Node3D
	if not modelo:
		modelo = find_child("Perrena", true, false) as Node3D
	if modelo:
		for mesh in modelo.find_children("*", "MeshInstance3D", true, false):
			(mesh as MeshInstance3D).material_override = MAT_PERRENA

	# 3. Equipar arco animado y flechas en el esqueleto antes del setup del Player
	_setup_equipamiento_arco()

	# 4. Registrar los alias de animación ANTES de que el Player construya su árbol
	if anim_p:
		_remapear_animaciones_perrena(anim_p)

	# 5. Inicialización completa heredada del Player (árbol dinámico, hitbox, sombra, etc.)
	super._ready()


## Instancia los attachments de huesos para el arco animado y las flechas en las manos de Perrena
func _setup_equipamiento_arco() -> void:
	var skel: Skeleton3D = find_child("Skeleton3D", true, false) as Skeleton3D
	if not skel:
		return

	# Mano Izquierda: Arco animado y punto de spawn de flechas explosivas
	var idx_mano_izq: int = skel.find_bone("mixamorig_LeftHand")
	if idx_mano_izq != -1 and not skel.has_node("BoneAttach_Arco"):
		var attach_arco := BoneAttachment3D.new()
		attach_arco.name = "BoneAttach_Arco"
		attach_arco.bone_name = "mixamorig_LeftHand"
		attach_arco.bone_idx = idx_mano_izq
		skel.add_child(attach_arco)

		var arco: Node3D = ARCO_SCENE.instantiate() as Node3D
		arco.name = "ARCO_ANIMADO"
		arco.transform = Transform3D(
			Vector3(-5.398, -38.306, 10.174),
			Vector3(34.926, 0.257, 19.496),
			Vector3(-18.735, 11.514, 33.413),
			Vector3(-0.73, 4.909, 1.21)
		)
		attach_arco.add_child(arco)

		var spawn_exp := Marker3D.new()
		spawn_exp.name = "SpawnPosition_FlechaExplosiva"
		spawn_exp.transform = Transform3D(
			Vector3(4.498, 31.18, -6.942),
			Vector3(-30.294, 1.941, -10.912),
			Vector3(-10.129, 8.041, 29.552),
			Vector3(-10.05, -18.27, 7.743)
		)
		attach_arco.add_child(spawn_exp)

	# Mano Derecha: Flecha regular y Flecha explosiva
	var idx_mano_der: int = skel.find_bone("mixamorig_RightHand")
	if idx_mano_der != -1 and not skel.has_node("BoneAttach_Flecha"):
		var attach_flecha := BoneAttachment3D.new()
		attach_flecha.name = "BoneAttach_Flecha"
		attach_flecha.bone_name = "mixamorig_RightHand"
		attach_flecha.bone_idx = idx_mano_der
		skel.add_child(attach_flecha)

		var flecha: Node3D = FLECHA_SCENE.instantiate() as Node3D
		flecha.name = "FLECHA"
		flecha.transform = Transform3D(
			Vector3(-8.404, -23.576, -19.938),
			Vector3(30.812, -7.737, -3.839),
			Vector3(-1.992, -20.207, 24.733),
			Vector3(-0.497, 3.163, -0.089)
		)
		flecha.visible = false
		attach_flecha.add_child(flecha)

		var flecha_exp: Node3D = FLECHA_EXPLOSIVA_SCENE.instantiate() as Node3D
		flecha_exp.name = "FlechaExplosiva"
		flecha_exp.transform = Transform3D(
			Vector3(8.055, -24.329, 28.643),
			Vector3(-36.252, 2.692, 12.481),
			Vector3(-9.907, -29.632, -22.383),
			Vector3(5.39, 15.488, 7.723)
		)
		flecha_exp.visible = false
		attach_flecha.add_child(flecha_exp)


## Registra alias de animación en la librería para que el AnimationTree dinámico los reconozca
func _remapear_animaciones_perrena(anim_p: AnimationPlayer) -> void:
	var lib := anim_p.get_animation_library("")
	if not lib:
		return
	for clip_origen in MAPEO_ANIMS.keys():
		var clip_destino: String = MAPEO_ANIMS[clip_origen]
		if anim_p.has_animation(clip_destino):
			continue
		var buscar: String = SUBSTITUCIONES_ANIMS.get(clip_origen, clip_origen)
		for candidato in anim_p.get_animation_list():
			if candidato.ends_with(buscar) and not lib.has_animation(clip_destino):
				lib.add_animation(clip_destino, anim_p.get_animation(candidato))
				break
