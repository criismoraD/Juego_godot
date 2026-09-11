class_name TripulanteBarcoFondoAllyArcher
extends Node3D
## Tripulante arquera aliada de fondo para la Canoa Aliada.
##
## Características principales:
## - Permanece en la Capa Visual 2 (layers = 2).
## - No se desplaza a pie (fija en la embarcación).
## - Dispone únicamente de animaciones de IDLE y DISPARO.
## - Al activarse el combate, dispara flechas estéticas hacia la derecha (+X).

# === CONSTANTES ===
const ESCENA_FLECHA_ESTETICA: PackedScene = preload("res://System/Ambiente/FlechaFondoEstetica.tscn")
const SFX_DISPARO: AudioStream = preload("res://TEST_/disparo 100%.mp3")

# === ENUMS ===
enum EstadoTripulante { IDLE, PREPARANDO, APUNTANDO, DISPARANDO }

# === CONFIGURACIÓN ===
@export_category("Visual")
@export var capa_visual: int = 2  ## Capa de renderizado (Fondo = 2)
@export var esta_sentada: bool = false  ## Si es true, permanece sentada y ataca con split-body blend

@export_category("Combate Estético")
@export var auto_iniciar_combate: bool = false
@export var intervalo_disparo_min: float = 2.4
@export var intervalo_disparo_max: float = 4.2
@export var velocidad_flecha_min: float = 5.5
@export var velocidad_flecha_max: float = 7.5
@export var elevacion_flecha_min: float = 1.4
@export var elevacion_flecha_max: float = 2.8
@export var gravedad_flecha: float = 3.6

# === ESTADO PRIVADO ===
var _estado_actual: EstadoTripulante = EstadoTripulante.IDLE
var _en_combate: bool = false
var _temporizador_disparo: float = 0.0
var _temporizador_fase: float = 0.0

var _anim_player: AnimationPlayer = null
var _bow_anim_player: AnimationPlayer = null
var _anim_tree: AnimationTree = null
var _node_shoot: AnimationNodeAnimation = null
var _skeleton: Skeleton3D = null
var _arrow_in_hand: Node3D = null
var _punto_disparo: Node3D = null


# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	_buscar_componentes()
	_aplicar_capa_visual_recursiva(self)

	if esta_sentada:
		_setup_animation_tree()

	_ir_a_idle()

	if auto_iniciar_combate:
		iniciar_combate()


func _process(delta: float) -> void:
	if delta <= 0.0:
		return

	if not _en_combate:
		return

	match _estado_actual:
		EstadoTripulante.IDLE:
			_temporizador_disparo -= delta
			if _temporizador_disparo <= 0.0:
				_iniciar_ciclo_disparo()

		EstadoTripulante.PREPARANDO:
			_temporizador_fase -= delta
			if _temporizador_fase <= 0.0:
				_pasar_a_apuntando()

		EstadoTripulante.APUNTANDO:
			_temporizador_fase -= delta
			if _temporizador_fase <= 0.0:
				_soltar_flecha()

		EstadoTripulante.DISPARANDO:
			_temporizador_fase -= delta
			if _temporizador_fase <= 0.0:
				_ir_a_idle()


# === FUNCIONES PÚBLICAS ===
## Activa el combate estético de la arquera.
func iniciar_combate(retraso_inicial: float = -1.0) -> void:
	_en_combate = true
	if retraso_inicial >= 0.0:
		_temporizador_disparo = retraso_inicial
	else:
		_temporizador_disparo = randf_range(0.2, 1.8)


## Detiene el combate y regresa a animación IDLE constante.
func detener_combate() -> void:
	_en_combate = false
	_ir_a_idle()


## Retorna true si está actualmente en estado de combate.
func esta_en_combate() -> bool:
	return _en_combate


## Retorna el estado actual del tripulante.
func obtener_estado() -> EstadoTripulante:
	return _estado_actual


# === FUNCIONES PRIVADAS DE ANIMACIÓN Y DISPARO ===
func _ir_a_idle() -> void:
	_estado_actual = EstadoTripulante.IDLE
	_temporizador_disparo = randf_range(intervalo_disparo_min, intervalo_disparo_max)
	_ocultar_flecha_mano()

	if esta_sentada and _anim_tree:
		_anim_tree.set("parameters/UpperBlend/blend_amount", 0.0)
	else:
		_reproducir_anim_personaje(["IDE", "IDLE_001", "IDLE"], 0.3)

	_reproducir_anim_arco("ARCO_IDLE", 0.3)


func _iniciar_ciclo_disparo() -> void:
	_estado_actual = EstadoTripulante.PREPARANDO
	_temporizador_fase = 0.55
	_mostrar_flecha_mano()

	if esta_sentada and _anim_tree:
		if _node_shoot:
			_node_shoot.animation = _buscar_nombre_animacion(["TOMAR_FLECHA", "TOMAR_FLEHCA", "TOMA_FLECHA"])
		_anim_tree.set("parameters/Seek/seek_request", 0.0)
		_anim_tree.set("parameters/UpperBlend/blend_amount", 1.0)
	else:
		_reproducir_anim_personaje(["TOMAR_FLECHA", "TOMAR_FLEHCA", "TOMA_FLECHA"], 0.15)

	_reproducir_anim_arco("ARCO_TENSAR", 0.15)


func _pasar_a_apuntando() -> void:
	_estado_actual = EstadoTripulante.APUNTANDO
	_temporizador_fase = randf_range(0.4, 0.8)

	if esta_sentada and _anim_tree:
		if _node_shoot:
			_node_shoot.animation = _buscar_nombre_animacion(["IDLE_APUNTANDO", "APUNTAR_IDLE"])
		_anim_tree.set("parameters/Seek/seek_request", 0.0)
		_anim_tree.set("parameters/UpperBlend/blend_amount", 1.0)
	else:
		_reproducir_anim_personaje(["IDLE_APUNTANDO", "APUNTAR_IDLE"], 0.15)

	_reproducir_anim_arco("ARCO_TENSAR", 0.15)


func _soltar_flecha() -> void:
	_estado_actual = EstadoTripulante.DISPARANDO
	_temporizador_fase = 0.5
	_ocultar_flecha_mano()

	if esta_sentada and _anim_tree:
		if _node_shoot:
			_node_shoot.animation = _buscar_nombre_animacion(["DISPARAR_FLECHA", "SOLTAR_FLECHA", "DISPARAR"])
		_anim_tree.set("parameters/Seek/seek_request", 0.0)
		_anim_tree.set("parameters/UpperBlend/blend_amount", 1.0)
	else:
		_reproducir_anim_personaje(["DISPARAR_FLECHA", "SOLTAR_FLECHA", "DISPARAR"], 0.1)

	_reproducir_anim_arco("ARCO_DISPARO", 0.1)
	_spawnear_flecha_estetica()


func _spawnear_flecha_estetica() -> void:
	if not ESCENA_FLECHA_ESTETICA:
		return

	var flecha := ESCENA_FLECHA_ESTETICA.instantiate() as FlechaFondoEstetica
	if not flecha:
		return

	var root_scene: Node = get_tree().current_scene
	if not root_scene:
		root_scene = get_tree().root

	root_scene.add_child(flecha)

	# Posición de spawn: preferir mano (sigue al hueso tanto de pie como sentada) o punto de disparo
	var pos_spawn: Vector3 = global_position + Vector3(0.15, 0.32 if esta_sentada else 0.45, 0.0)
	if is_instance_valid(_arrow_in_hand):
		pos_spawn = _arrow_in_hand.global_position
	elif is_instance_valid(_punto_disparo):
		pos_spawn = _punto_disparo.global_position

	# Velocidad hacia la derecha (+X) con arco parabólico y ligera dispersión
	var vx: float = randf_range(velocidad_flecha_min, velocidad_flecha_max)
	var vy: float = randf_range(elevacion_flecha_min, elevacion_flecha_max)
	var vz: float = randf_range(-0.15, 0.15)
	var vel: Vector3 = Vector3(vx, vy, vz)

	flecha.iniciar(pos_spawn, vel, false, gravedad_flecha)


func _mostrar_flecha_mano() -> void:
	if is_instance_valid(_arrow_in_hand):
		_arrow_in_hand.visible = true


func _ocultar_flecha_mano() -> void:
	if is_instance_valid(_arrow_in_hand):
		_arrow_in_hand.visible = false


func _reproducir_anim_personaje(nombres: Array, blend: float = 0.2) -> void:
	if not _anim_player:
		return
	var lista_anims: PackedStringArray = _anim_player.get_animation_list()
	for cand in nombres:
		var c_str: String = str(cand).to_lower()
		for a in lista_anims:
			var a_str: String = a.to_lower()
			if a_str == c_str or a_str.ends_with("/" + c_str) or c_str in a_str:
				if _anim_player.current_animation != a:
					_anim_player.play(a, blend)
				return


func _reproducir_anim_arco(nombre: String, blend: float = 0.2) -> void:
	if not _bow_anim_player:
		return
	var lista_anims: PackedStringArray = _bow_anim_player.get_animation_list()
	var target_lower: String = nombre.to_lower()
	for a in lista_anims:
		var a_lower: String = a.to_lower()
		if a_lower == target_lower or target_lower in a_lower:
			_bow_anim_player.play(a, blend)
			return


func _buscar_nombre_animacion(candidatos: Array) -> StringName:
	if not _anim_player:
		return &""
	var lista_anims: PackedStringArray = _anim_player.get_animation_list()
	for cand in candidatos:
		var c_str: String = str(cand).to_lower()
		for a in lista_anims:
			var a_str: String = a.to_lower()
			if a_str == c_str or a_str.ends_with("/" + c_str) or c_str in a_str:
				return StringName(a)
	return &""


func _setup_animation_tree() -> void:
	if not _anim_player or not _skeleton:
		return

	_anim_tree = AnimationTree.new()
	_anim_tree.name = "AllyTripulanteAnimTree"
	add_child(_anim_tree)

	_anim_tree.anim_player = _anim_tree.get_path_to(_anim_player)
	var ap_root: Node = _anim_player.get_node(_anim_player.root_node)
	_anim_tree.root_node = _anim_tree.get_path_to(ap_root)

	var root := AnimationNodeBlendTree.new()

	# Animación base agachada / sentada (cuerpo completo / piernas)
	var anim_crouch: StringName = _buscar_nombre_animacion(["AGACHARSE", "AGACHADA"])
	if _anim_player.has_animation(anim_crouch):
		var a := _anim_player.get_animation(anim_crouch)
		if a:
			a.loop_mode = Animation.LOOP_LINEAR

	var node_crouch := AnimationNodeAnimation.new()
	node_crouch.animation = anim_crouch
	root.add_node("CrouchAnim", node_crouch)

	# Animación de disparo / ataque para torso superior
	var anim_shoot: StringName = _buscar_nombre_animacion(["DISPARAR_FLECHA", "TOMAR_FLECHA"])
	_node_shoot = AnimationNodeAnimation.new()
	_node_shoot.animation = anim_shoot
	root.add_node("ShootAnim", _node_shoot)

	# Blend2 con filtrado de huesos superiores
	var blend := AnimationNodeBlend2.new()
	blend.filter_enabled = true

	var skel_path: String = str(ap_root.get_path_to(_skeleton))
	var upper_bones: Array[String] = [
		"mixamorig_Spine",
		"mixamorig_Spine1",
		"mixamorig_Spine2",
		"mixamorig_Neck",
		"mixamorig_Head",
		"mixamorig_HeadTop_End",
		"mixamorig_LeftShoulder",
		"mixamorig_RightShoulder",
		"mixamorig_LeftArm",
		"mixamorig_RightArm",
		"mixamorig_LeftForeArm",
		"mixamorig_RightForeArm",
		"mixamorig_LeftHand",
		"mixamorig_RightHand",
	]
	for side in ["Left", "Right"]:
		for finger in ["Index", "Middle", "Ring", "Pinky", "Thumb"]:
			for idx in ["1", "2", "3"]:
				upper_bones.append("mixamorig_%sHand%s%s" % [side, finger, idx])

	for bone in upper_bones:
		if _skeleton.find_bone(bone) != -1:
			blend.set_filter_path(NodePath("%s:%s" % [skel_path, bone]), true)

	root.add_node("UpperBlend", blend)
	root.connect_node("UpperBlend", 0, "CrouchAnim")
	root.connect_node("UpperBlend", 1, "ShootAnim")

	var seek := AnimationNodeTimeSeek.new()
	root.add_node("Seek", seek)
	root.connect_node("Seek", 0, "UpperBlend")

	root.connect_node("output", 0, "Seek")

	_anim_tree.tree_root = root
	_anim_tree.set("parameters/UpperBlend/blend_amount", 0.0)
	_anim_tree.active = true


func _buscar_componentes() -> void:
	# Desactivar AnimationTree previos que secuestren el esqueleto
	for tree in find_children("*", "AnimationTree", true, false):
		tree.active = false

	# Buscar AnimationPlayers: separar personaje de arco
	var players: Array[Node] = find_children("*", "AnimationPlayer", true, false)
	for p in players:
		var ap := p as AnimationPlayer
		if not ap:
			continue
		var anims := ap.get_animation_list()
		var es_arco: bool = false
		for a in anims:
			if "ARCO" in a.to_upper() or "RECURVE" in a.to_upper():
				es_arco = true
				break
		if es_arco and not _bow_anim_player:
			_bow_anim_player = ap
		elif not es_arco and not _anim_player:
			_anim_player = ap

	_skeleton = find_child("Skeleton3D", true, false) as Skeleton3D
	_arrow_in_hand = find_child("FLECHA", true, false) as Node3D
	_punto_disparo = find_child("PuntoDisparo", true, false) as Node3D


func _aplicar_capa_visual_recursiva(nodo: Node) -> void:
	if nodo is VisualInstance3D:
		nodo.layers = capa_visual
	for hijo in nodo.get_children():
		_aplicar_capa_visual_recursiva(hijo)

