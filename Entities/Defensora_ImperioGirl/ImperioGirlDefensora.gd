class_name ImperioGirlDefensora
extends AllyArcher

## Defensora Imperio Girl: misma función que la defensora arquera
## (ciclo IDLE → TOMAR_FLECHA → IDLE_APUNTANDO → DISPARAR, diálogos con
## decir(), daño/muerte/revive, grupos allies/defensoras y registro en
## active_allies_cache) pero con el modelo de Imperio Girl.
## Hereda TODA la lógica de AllyArcher: solo adapta el nombre del modelo
## y registra alias de animación (el GLB trae clips nativos como
## "Disparo arco" o "Muerte1" y la base los pide como DISPARAR/MUERTE_01).

const PREFIJO_ARMATURE_COMPLETO: String = "Armature|Armature|"
const PREFIJO_ARMATURE_CORTO: String = "Armature|"

## Textura de Imperio Girl (la misma de la protagonista: sin ella el GLB se ve blanco).
const MAT_IMPERIO_GIRL: Material = preload("res://Entities/Jugador_ImperioGirl/IMPERIO_GIRL_MAT.tres")

## Destino (nombre que pide AllyArcher) -> clip nativo del GLB de Imperio Girl.
const MAPEO_ANIMS_IMPERIO: Dictionary = {
	"IDLE": "Idle espera",
	"IDLE_ESPERA": "Idle espera",
	"IDLE_EXAMINAR": "Idle espera",
	"VICTORIA": "Idle espera",
	"TOMAR_FLECHA": "Apuntar idle",
	"APUNTAR_IDLE": "Apuntar idle",
	"APUNTAR_CAMINAR_ADELANTE": "Standing Aim Walk Forward",
	"DISPARAR": "Disparo arco",
	"CAMINAR_ADELANTE": "Caminar",
	"CORRER_ADELANTE": "Correr",
	"SUBIR_ESCALERA": "Climbing Ladder",
	"ATERRIZAJE": "Aterrizaje",
	"ATERRIZAJE_POST_SALTO_O_CAIDA": "Aterrizaje",
	"CAER_SALTAR": "Caida",
	"HIT": "Hit",
	"DAÑO_01": "Hit",
	"DAÑO_02": "Hit",
	"ELECTROCUTAR": "Hit",
	"MUERTE": "Muerte1",
	"MUERTE_01": "Muerte1",
	"MUERTE_02": "Muerte1",
	"LEVANTARSE": "Agacharse",
}

## Alias que deben loopear (locomoción e idles).
const ALIAS_EN_LOOP: Array[String] = [
	"IDLE", "APUNTAR_IDLE", "APUNTAR_CAMINAR_ADELANTE",
	"CORRER_ADELANTE", "CAMINAR_ADELANTE", "SUBIR_ESCALERA",
]

const NOMBRES_ATTACHMENTS_ARCO: Array[String] = ["BoneAttach_Arco", "BoneAttach_Flecha"]

## Loop de pasos de locomoción más suave que la arquera (-10 dB frente a 0.5 dB).
const VOLUMEN_PASOS_DB: float = -10.0


func _ready() -> void:
	nombre_nodo_modelo = "ImperioGirlModel"
	volumen_pasos_db = VOLUMEN_PASOS_DB
	_aplicar_material_imperio()
	_resolver_attachments_huesos()
	_remapear_animaciones_imperio()
	super._ready()


## Aplica la textura de Imperio Girl a todas las mallas del modelo
## (igual que la protagonista en ImperioGirl.gd; sin esto se ve blanca).
func _aplicar_material_imperio() -> void:
	var modelo := find_child("ImperioGirlModel", true, false) as Node3D
	if not is_instance_valid(modelo):
		return
	for mesh in modelo.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_override = MAT_IMPERIO_GIRL


## Repara el bone_idx de los attachments del arco/flecha contra el hueso real
## (mismo GLB que la jugadora, por si el importador varió los índices).
func _resolver_attachments_huesos() -> void:
	var esqueleto := find_child("Skeleton3D", true, false) as Skeleton3D
	if not is_instance_valid(esqueleto):
		return
	for nombre_attach in NOMBRES_ATTACHMENTS_ARCO:
		var attach := esqueleto.get_node_or_null(nombre_attach) as BoneAttachment3D
		if attach == null:
			attach = find_child(nombre_attach, true, false) as BoneAttachment3D
		if attach == null or String(attach.bone_name).is_empty():
			continue
		var idx: int = esqueleto.find_bone(String(attach.bone_name))
		if idx != -1:
			attach.bone_idx = idx


## Registra en el AnimationPlayer del modelo los alias que AllyArcher pide
## (IDLE, TOMAR_FLECHA, DISPARAR, MUERTE_01...). Réplica del remapeo de ImperioGirl.
func _remapear_animaciones_imperio() -> void:
	var anim_p := _player_corporal_modelo()
	if anim_p == null:
		push_warning("[ImperioGirlDefensora] Sin AnimationPlayer corporal: sin alias de animación.")
		return
	for destino in MAPEO_ANIMS_IMPERIO.keys():
		var origen: String = MAPEO_ANIMS_IMPERIO[destino]
		var destino_completo: String = PREFIJO_ARMATURE_COMPLETO + destino
		if anim_p.has_animation(destino_completo):
			continue
		var fuente := _buscar_animacion_nativa(anim_p, origen)
		if fuente == null:
			push_warning("[ImperioGirlDefensora] Sin clip nativo para '%s' (buscaba '%s')" % [destino_completo, origen])
			continue
		if destino in ALIAS_EN_LOOP:
			fuente.loop_mode = Animation.LOOP_LINEAR
		_registrar_alias(anim_p, destino_completo, fuente)
		_registrar_alias(anim_p, PREFIJO_ARMATURE_CORTO + destino, fuente)


## AnimationPlayer corporal del modelo (evita los del arco/flecha).
func _player_corporal_modelo() -> AnimationPlayer:
	var modelo := find_child("ImperioGirlModel", true, false) as Node3D
	if is_instance_valid(modelo):
		var directo := modelo.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if directo:
			return directo
	for n in find_children("*", "AnimationPlayer", true, false):
		var ap := n as AnimationPlayer
		if ap and (ap.has_animation("Idle espera") or ap.has_animation("Caminar") or ap.has_animation("Muerte1")):
			return ap
	return find_child("AnimationPlayer", true, false) as AnimationPlayer


func _buscar_animacion_nativa(anim_p: AnimationPlayer, buscar: String) -> Animation:
	var buscar_bajo: String = buscar.to_lower()
	for lib_nombre in anim_p.get_animation_library_list():
		var lib := anim_p.get_animation_library(lib_nombre)
		if lib == null:
			continue
		for anim_nombre in lib.get_animation_list():
			var nombre_bajo: String = String(anim_nombre).to_lower()
			if nombre_bajo.ends_with(buscar_bajo) or nombre_bajo == buscar_bajo:
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
