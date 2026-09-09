class_name Perrena
extends "res://Entities/Jugador_Arquera/Player.gd"

## Perrena — segundo player jugable, idéntica a la protagonista Eryn:
## - Mismos movimientos (correr, saltar, agacharse, escaleras), animaciones y vida (4).
## - Disparo con arco animado de 1 proyectil y mecánicas completas (normales, explosivas, múltiples).
## - Mantiene el HUD y sistema de corazones de la protagonista.
## - Misma escala de modelo (3.1) y cápsula que Eryn: el arco queda del mismo tamaño.

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
	vida_maxima = 4
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

	# 6. Paridad física con la protagonista: misma capa/máscara para que
	# Perrena pase por el costado de las defensoras sin chocar (capa 2 excluida).
	_aplicar_colision_jugador()

	# 7. Alinear la base de tracks del árbol con la del AnimationPlayer.
	_alinear_base_tracks_arbol()


## Instancia los attachments de huesos para el arco animado y las flechas en las manos de Perrena.
## Si ya existen en el .tscn (colocados a mano en el editor), se reutilizan y
## solo se asegura que apunten al hueso correcto: la edición manual se respeta en juego.
func _setup_equipamiento_arco() -> void:
	var skel: Skeleton3D = find_child("Skeleton3D", true, false) as Skeleton3D
	if not skel:
		return

	_resolver_attachment_existente(skel, "BoneAttach_Arco")
	_resolver_attachment_existente(skel, "BoneAttach_Flecha")

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


## Si el attachment ya viene en la escena (edición manual en el .tscn),
## resuelve su índice desde el nombre para que siga al hueso correcto.
## No toca su transform: la colocación manual del editor se respeta en juego.
func _resolver_attachment_existente(skel: Skeleton3D, nombre: String) -> void:
	var att := skel.get_node_or_null(nombre) as BoneAttachment3D
	if att == null or String(att.bone_name).is_empty():
		return
	var idx: int = skel.find_bone(String(att.bone_name))
	if idx != -1:
		att.bone_idx = idx


## El AnimationTree resuelve los tracks de los clips desde su root_node,
## pero los clips importados están escritos para la base del AnimationPlayer
## (en este GLB el player cuelga del Skeleton3D, no de la raíz del modelo).
## Si ambas bases no coinciden, el árbol no mueve ningún hueso: Perrena se
## desplaza estática aunque los clips se vean bien en el editor (ahí
## reproduce el player directo, con su propia base). Se igualan en runtime.
func _alinear_base_tracks_arbol() -> void:
	var tree := find_child("AnimationTree", true, false) as AnimationTree
	var anim_p := find_child("AnimationPlayer", true, false) as AnimationPlayer
	if tree == null or anim_p == null:
		return
	var base_jugador := anim_p.get_node_or_null(anim_p.root_node) as Node
	if base_jugador == null:
		return
	var base_arbol := get_node_or_null(tree.root_node) as Node
	if base_arbol == base_jugador:
		return
	tree.root_node = get_path_to(base_jugador)


## Registra alias de animación para que el AnimationTree dinámico (que pide
## nombres estilo Eryn "Armature|Armature|X", o sea librería "Armature") los
## reconozca. Busca el clip nativo del GLB ("Idle", "Caminar", ...) en TODAS
## las librerías y registra el alias en la librería que el destino indica.
## Sin esto el árbol no resuelve ninguna animación y Perrena queda estática.
func _remapear_animaciones_perrena(anim_p: AnimationPlayer) -> void:
	for clip_origen in MAPEO_ANIMS.keys():
		var clip_destino: String = MAPEO_ANIMS[clip_origen]
		if anim_p.has_animation(clip_destino):
			continue
		var buscar: String = SUBSTITUCIONES_ANIMS.get(clip_origen, clip_origen)
		var fuente := _buscar_animacion_nativa(anim_p, buscar)
		if fuente == null:
			push_warning("[Perrena] Sin clip nativo para '%s' (buscaba '*%s')" % [clip_destino, buscar])
			continue
		_registrar_alias(anim_p, clip_destino, fuente)


## Busca en todas las librerías del AnimationPlayer un clip cuyo nombre
## termine con el fragmento buscado (p. ej. "Disparo arco", "Caminar").
func _buscar_animacion_nativa(anim_p: AnimationPlayer, buscar: String) -> Animation:
	for lib_nombre in anim_p.get_animation_library_list():
		var lib := anim_p.get_animation_library(lib_nombre)
		if lib == null:
			continue
		for anim_nombre in lib.get_animation_list():
			if String(anim_nombre).ends_with(buscar):
				return lib.get_animation(anim_nombre)
	return null


## Registra el alias en la librería que el nombre destino indica
## ("Armature|Armature|IDLE" -> librería "Armature", clip "Armature|IDLE"),
## creándola si no existe. Así has_animation()/play() del árbol lo resuelven.
func _registrar_alias(anim_p: AnimationPlayer, destino: String, fuente: Animation) -> void:
	var partes := destino.split("|")
	if partes.size() < 2:
		return
	var lib_nombre: String = partes[0]
	var anim_nombre: String = "|".join(partes.slice(1))
	if not anim_p.has_animation_library(lib_nombre):
		anim_p.add_animation_library(lib_nombre, AnimationLibrary.new())
	var lib := anim_p.get_animation_library(lib_nombre)
	if lib and not lib.has_animation(anim_nombre):
		lib.add_animation(anim_nombre, fuente)
