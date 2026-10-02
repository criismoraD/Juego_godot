class_name ImperioGirl
extends "res://Entities/Jugador_Arquera/Player.gd"

## Imperio Girl — nuevo personaje jugable para el nivel tutorial,
## idéntica en comportamiento y mecánicas a la protagonista Eryn:
## - Mismo set de movimientos (caminar, correr, saltar, agacharse, escaleras).
## - Disparo con arco animado y mecánicas completas (normales, explosivas, múltiples).
## - Sistema de vida, daño y HUD idéntico.
## - Paridad total de colisión y física.

const MAT_IMPERIO_GIRL: Material = preload("res://Entities/Jugador_ImperioGirl/IMPERIO_GIRL_MAT.tres")
const ARCO_SCENE: PackedScene = preload("res://Entities/Jugador_Arquera/GEO_ARCO_ANIMADO.fbx")
const FLECHA_SCENE: PackedScene = preload("res://Entities/Jugador_Arquera/FLECHA.fbx")
const FLECHA_EXPLOSIVA_SCENE: PackedScene = preload("res://Entities/Flecha_Explosiva/Flecha_Explosiva.glb")

## Mapeo de clips del GLB de Imperio Girl -> nombres que el AnimationTree del Player espera.
const MAPEO_ANIMS: Dictionary = {
	"Idle espera": "Armature|Armature|IDLE",
	"Caminar": "Armature|Armature|CAMINAR_ADELANTE",
	"Correr": "Armature|Armature|CORRER_ADELANTE",
	"Disparo arco": "Armature|Armature|DISPARAR",
	"Aterrizaje": "Armature|Armature|ATERRIZAJE",
	"Caida": "Armature|Armature|CAER_SALTAR",
	"Agacharse": "Armature|Armature|CAER_SALTAR",
	"Standing Up": "Armature|Armature|IDLE",
	"Hit": "Armature|Armature|HIT",
	"Muerte1": "Armature|Armature|MUERTE",
	"Apuntar idle": "Armature|Armature|APUNTAR_IDLE",
	"Climbing Ladder": "Armature|Armature|SUBIR_ESCALERA",
	"@caminar_atras": "Armature|Armature|CAMINAR_ATRAS",
	"@tomar_flecha": "Armature|Armature|TOMAR_FLECHA",
}

const SUBSTITUCIONES_ANIMS: Dictionary = {
	"@caminar_atras": "Caminar",
	"@tomar_flecha": "Disparo arco",
}


func _init() -> void:
	vida_maxima = 4
	duracion_maxima_disparo = 0.20
	# Paridad con Eryn (vista 2.5D lateral):
	# - eje_rotacion = 2 (Z / FORWARD): el pitch del torso inclina arriba/abajo
	#   manteniéndose de lado. Con 0 (X) el torso gira hacia cámara y no se
	#   ve apuntar hacia arriba.
	# - rotacion_personaje_escalera = 180 como Eryn/Perrena para que al apuntar
	#   en escalera vuelva a perfil lateral igual que la protagonista.
	rotacion_personaje_escalera = 180.0
	eje_rotacion = 2


func _ready() -> void:
	# 1. Conectar el AnimationTree al AnimationPlayer CORPORAL del GLB
	var tree := find_child("AnimationTree", true, false) as AnimationTree
	var anim_p := _player_corporal()
	if tree and anim_p:
		tree.anim_player = tree.get_path_to(anim_p)

	# 2. Aplicar textura/material personalizado de Imperio Girl
	var modelo := find_child("ImperioGirlModel", true, false) as Node3D
	if not modelo:
		modelo = find_child("ImperioGirl", true, false) as Node3D
	if not modelo:
		modelo = find_child("Imperio Girl2", true, false) as Node3D
	if modelo:
		for mesh in modelo.find_children("*", "MeshInstance3D", true, false):
			(mesh as MeshInstance3D).material_override = MAT_IMPERIO_GIRL

	# 3. Equipar arco animado y flechas en el esqueleto antes del setup del Player
	_setup_equipamiento_arco()

	# 4. Registrar los alias de animación ANTES de que el Player construya su árbol dinámico
	if anim_p:
		_remapear_animaciones_imperio(anim_p)

	# 5. Inicialización completa heredada del Player (árbol dinámico, hitbox, sombra, etc.)
	super._ready()

	# 6. Paridad física con la protagonista: colisiones y máscaras idénticas
	_aplicar_colision_jugador()

	# 7. Alinear la base de tracks del árbol con la del AnimationPlayer
	_alinear_base_tracks_arbol()

	# 8. Limpiar cualquier pose residual en los huesos del Skeleton3D
	var skel: Skeleton3D = find_child("Skeleton3D", true, false) as Skeleton3D
	if skel:
		skel.clear_bones_global_pose_override()


## Configura attachments de huesos para arco animado y flechas en las manos de Imperio Girl.
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
			Vector3(-11.243897, -37.815845, 6.5981526),
			Vector3(36.878456, -8.732639, 12.795336),
			Vector3(-10.656186, 9.6799755, 37.319485),
			Vector3(-0.96935654, 5.0990295, 1.9075756)
		)
		attach_arco.add_child(arco)

		var spawn_exp := Marker3D.new()
		spawn_exp.name = "SpawnPosition_FlechaExplosiva"
		spawn_exp.transform = Transform3D(
			Vector3(4.4982424, 31.179523, -6.9416704),
			Vector3(-30.294294, 1.941139, -10.91199),
			Vector3(-10.129435, 8.04071, 29.552084),
			Vector3(-10.049694, -18.270287, 7.7429447)
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
			Vector3(-8.403967, -23.576057, -19.938494),
			Vector3(30.81243, -7.736585, -3.839222),
			Vector3(-1.99194, -20.206808, 24.732906),
			Vector3(-0.49650955, 3.162592, -0.08917618)
		)
		flecha.visible = false
		attach_flecha.add_child(flecha)

		var flecha_exp: Node3D = FLECHA_EXPLOSIVA_SCENE.instantiate() as Node3D
		flecha_exp.name = "FlechaExplosiva"
		flecha_exp.transform = Transform3D(
			Vector3(8.05503, -24.329357, 28.643463),
			Vector3(-36.252083, 2.6922657, 12.48148),
			Vector3(-9.907173, -29.632471, -22.383343),
			Vector3(5.3902016, 15.487649, 7.723442)
		)
		flecha_exp.visible = false
		attach_flecha.add_child(flecha_exp)


func _resolver_attachment_existente(skel: Skeleton3D, nombre: String) -> void:
	var att := skel.get_node_or_null(nombre) as BoneAttachment3D
	if att == null or String(att.bone_name).is_empty():
		return
	var idx: int = skel.find_bone(String(att.bone_name))
	if idx != -1:
		att.bone_idx = idx


## Devuelve el AnimationPlayer corporal de Imperio Girl (evita los del arco/flecha).
static func _player_corporal_en(nodo: Node) -> AnimationPlayer:
	var modelo := nodo.find_child("ImperioGirlModel", true, false) as Node3D
	if not modelo:
		modelo = nodo.find_child("ImperioGirl", true, false) as Node3D
	if not modelo:
		modelo = nodo.find_child("Imperio Girl2", true, false) as Node3D
	if modelo:
		var directo := modelo.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if directo:
			return directo
	for n in nodo.find_children("*", "AnimationPlayer", true, false):
		var ap := n as AnimationPlayer
		if ap and (ap.has_animation("Idle espera") or ap.has_animation("Climbing Ladder") or ap.has_animation("Caminar")):
			return ap
	return nodo.find_child("AnimationPlayer", true, false) as AnimationPlayer


func _player_corporal() -> AnimationPlayer:
	return _player_corporal_en(self)


func _alinear_base_tracks_arbol() -> void:
	var tree := find_child("AnimationTree", true, false) as AnimationTree
	var anim_p := _player_corporal()
	if tree == null or anim_p == null:
		return
	var base_jugador := anim_p.get_node_or_null(anim_p.root_node) as Node
	if base_jugador == null:
		return
	var base_arbol := tree.get_node_or_null(tree.root_node) as Node
	if base_arbol == base_jugador:
		return
	var estaba_activo: bool = tree.active
	tree.active = false
	tree.root_node = tree.get_path_to(base_jugador)
	if estaba_activo:
		tree.active = true


func _remapear_animaciones_imperio(anim_p: AnimationPlayer) -> void:
	for clip_origen in MAPEO_ANIMS.keys():
		var clip_destino: String = MAPEO_ANIMS[clip_origen]
		if anim_p.has_animation(clip_destino):
			continue
		var buscar: String = SUBSTITUCIONES_ANIMS.get(clip_origen, clip_origen)
		var fuente := _buscar_animacion_nativa(anim_p, buscar)
		if fuente == null:
			push_warning("[ImperioGirl] Sin clip nativo para '%s' (buscaba '%s')" % [clip_destino, buscar])
			continue
		if clip_destino in [
			"Armature|Armature|IDLE",
			"Armature|Armature|CAMINAR_ADELANTE",
			"Armature|Armature|CAMINAR_ATRAS",
			"Armature|Armature|APUNTAR_IDLE",
			"Armature|Armature|CORRER_ADELANTE",
			"Armature|Armature|SUBIR_ESCALERA",
			"Armature|Armature|APUNTAR_CAMINAR_ADELANTE"
		]:
			fuente.loop_mode = Animation.LOOP_LINEAR
		_registrar_alias(anim_p, clip_destino, fuente)
		# Registrar también alias de una sola barra si no existe
		if clip_destino.begins_with("Armature|Armature|"):
			var alias_corto: String = clip_destino.replace("Armature|Armature|", "Armature|")
			_registrar_alias(anim_p, alias_corto, fuente)


func _buscar_animacion_nativa(anim_p: AnimationPlayer, buscar: String) -> Animation:
	var buscar_bajo: String = buscar.to_lower()
	for lib_nombre in anim_p.get_animation_library_list():
		var lib := anim_p.get_animation_library(lib_nombre)
		if lib == null:
			continue
		for anim_nombre in lib.get_animation_list():
			if String(anim_nombre).to_lower().ends_with(buscar_bajo) or String(anim_nombre).to_lower() == buscar_bajo:
				return lib.get_animation(anim_nombre)
	return null


func _registrar_alias(anim_p: AnimationPlayer, destino: String, fuente: Animation) -> void:
	var lib_nombre: String = ""
	var anim_nombre: String = destino
	if destino.contains("/"):
		var partes := destino.split("/", true, 1)
		lib_nombre = partes[0]
		anim_nombre = partes[1]
	if not anim_p.has_animation_library(lib_nombre):
		anim_p.add_animation_library(lib_nombre, AnimationLibrary.new())
	var lib := anim_p.get_animation_library(lib_nombre)
	if lib and not lib.has_animation(anim_nombre):
		lib.add_animation(anim_nombre, fuente)
