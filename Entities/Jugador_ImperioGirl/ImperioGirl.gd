class_name ImperioGirl
extends "res://Entities/Jugador_Arquera/Player.gd"

## Imperio Girl — personaje jugable para el nivel tutorial,
## con paridad visual y mecánica exacta a la protagonista principal Eryn:
## - Mismo comportamiento de disparo: tensado fluido hacia la mejilla (TOMAR_FLECHA -> APUNTAR_IDLE),
##   rotación de torso pitch con el ratón y disparo ágil (DISPARAR).
## - Mismo comportamiento de escaleras: orientación natural de cara a los peldaños / espalda a cámara
##   (rotacion_personaje_escalera = 180°, idéntico a Eryn), y giro lateral de perfil al apuntar/disparar en escalera.
## - Locomoción idéntica al apuntar: caminar adelante de frente y caminar hacia atrás retrocediendo
##   con animación invertida fluida (CAMINAR_ATRAS).
## - Mismo sistema de daño, vida (4), flechas explosivas/múltiples y HUD.

const MAT_IMPERIO_GIRL: Material = preload("res://Entities/Jugador_ImperioGirl/IMPERIO_GIRL_MAT.tres")
const ARCO_SCENE: PackedScene = preload("res://Entities/Jugador_Arquera/GEO_ARCO_ANIMADO.fbx")
const FLECHA_SCENE: PackedScene = preload("res://Entities/Jugador_Arquera/FLECHA.fbx")
const FLECHA_EXPLOSIVA_SCENE: PackedScene = preload("res://Entities/Flecha_Explosiva/Flecha_Explosiva.glb")

## Mapeo de clips del GLB de Imperio Girl -> nombres esperados por el Player/AnimationTree.
const MAPEO_ANIMS: Dictionary = {
	"Idle espera": "Armature|Armature|IDLE",
	"Caminar": "Armature|Armature|CAMINAR_ADELANTE",
	"Caminar hacia atras": "Armature|Armature|CAMINAR_ATRAS",
	"Correr": "Armature|Armature|CORRER_ADELANTE",
	"Disparo arco": "Armature|Armature|DISPARAR",
	"Aterrizaje": "Armature|Armature|ATERRIZAJE",
	"Caida": "Armature|Armature|CAER_SALTAR",
	"Agacharse": "Armature|Armature|AGANCHARSE",
	"Standing Up": "Armature|Armature|PARARSE",
	"Hit": "Armature|Armature|HIT",
	"Muerte1": "Armature|Armature|MUERTE",
	"Muerte2": "Armature|Armature|MUERTE_2",
	"Apuntar idle": "Armature|Armature|APUNTAR_IDLE",
	"Subir escalera": "Armature|Armature|SUBIR_ESCALERA",
	"Climbing Ladder": "Armature|Armature|SUBIR_ESCALERA",
	"Standing Aim Walk Forward": "Armature|Armature|APUNTAR_CAMINAR_ADELANTE",
	"@tomar_flecha": "Armature|Armature|TOMAR_FLECHA",
}

const SUBSTITUCIONES_ANIMS: Dictionary = {
	"@tomar_flecha": "Apuntar idle",
}

## Mismo loop de armadura que la ballestera aliada: suena natural como armadura.
const STREAM_CORRER_ARMADURA: AudioStream = preload("res://Entities/Aliada_Ballestera/Audio/sonido_correr_armadura.wav")
const VOLUMEN_CORRER_DB: float = 8.0
const UMBRAL_VELOCIDAD_CORRER: float = 0.15
const UMBRAL_INPUT_CORRER: float = 0.1

var _sfx_correr: AudioStreamPlayer = null
var _forzar_sonido_correr: bool = false
var _entrada_aim_full_lista: bool = false


func _init() -> void:
	vida_maxima = 4
	duracion_maxima_disparo = 0.20
	# Paridad visual y mecánica exacta con Eryn (vista 2.5D lateral):
	# - rotacion_personaje_escalera = 180.0: con el nuevo clip de Subir escalera orientado de forma estándar,
	#   180° orienta su espalda a la cámara y cara a los peldaños, idéntico a Eryn (180°).
	# - rotacion_torso_escalera = 0.0: alineación neutral del torso al apuntar en escalera.
	# - eje_rotacion = 2 (Z / FORWARD): el pitch del torso inclina arriba/abajo en el plano 2.5D.
	rotacion_personaje_escalera = 180.0
	rotacion_torso_escalera = 0.0
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

	# 5b. Entrada "aim_full": apuntar quieta con pose de cuerpo completo
	_agregar_entrada_aim_full()

	# 6. Paridad física con la protagonista: colisiones y máscaras idénticas
	_aplicar_colision_jugador()

	# 7. Alinear la base de tracks del árbol con la del AnimationPlayer
	_alinear_base_tracks_arbol()

	# 8. Limpiar cualquier pose residual en los huesos del Skeleton3D
	var skel: Skeleton3D = find_child("Skeleton3D", true, false) as Skeleton3D
	if skel:
		skel.clear_bones_global_pose_override()

	# 9. Loop de armadura al correr (igual que la ballestera aliada)
	_configurar_sonido_correr()


func _process(delta: float) -> void:
	super._process(delta)
	_actualizar_sonido_correr()


func _exit_tree() -> void:
	if _sfx_correr and is_instance_valid(_sfx_correr):
		if _sfx_correr.finished.is_connected(_sfx_correr.play):
			_sfx_correr.finished.disconnect(_sfx_correr.play)
		if _sfx_correr.playing:
			_sfx_correr.stop()
	super._exit_tree()


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
		if ap and (ap.has_animation("Idle espera") or ap.has_animation("Subir escalera") or ap.has_animation("Climbing Ladder") or ap.has_animation("Caminar")):
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


## Entrada "aim_full" en Locomotion con el APUNTAR_IDLE de cuerpo completo.
## Solo existe en su árbol (construido por instancia): Eryn no se toca.
func _agregar_entrada_aim_full() -> void:
	if _entrada_aim_full_lista:
		return
	if anim_tree == null:
		return
	var root := anim_tree.tree_root as AnimationNodeBlendTree
	if root == null:
		return
	var nodo_aim := AnimationNodeAnimation.new()
	nodo_aim.animation = "Armature|Armature|APUNTAR_IDLE"
	root.add_node("AimFull", nodo_aim)
	var loco := root.get_node("Locomotion") as AnimationNodeTransition
	if loco == null:
		return
	loco.input_count = 5
	loco.set_input_name(4, "aim_full")
	root.connect_node("Locomotion", 4, "AimFull")
	_entrada_aim_full_lista = true


func _remapear_animaciones_imperio(anim_p: AnimationPlayer) -> void:
	# 1. Registrar alias base desde MAPEO_ANIMS
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
			"Armature|Armature|APUNTAR_CAMINAR_ADELANTE",
			"Armature|Armature|CAER_SALTAR"
		]:
			fuente.loop_mode = Animation.LOOP_LINEAR
		elif clip_destino in [
			"Armature|Armature|DISPARAR",
			"Armature|Armature|ATERRIZAJE",
			"Armature|Armature|HIT",
			"Armature|Armature|MUERTE",
			"Armature|Armature|MUERTE_2"
		]:
			fuente.loop_mode = Animation.LOOP_NONE

		_registrar_alias(anim_p, clip_destino, fuente)
		if clip_destino.begins_with("Armature|Armature|"):
			var alias_corto: String = clip_destino.replace("Armature|Armature|", "Armature|")
			_registrar_alias(anim_p, alias_corto, fuente)


	# 2. Generar clip invertido en tiempo para CAMINAR_ATRAS a partir de Caminar
	# Esto permite que al retroceder cargando el arco o apuntando, las piernas den pasos hacia atras reales
	if not anim_p.has_animation("Armature|Armature|CAMINAR_ATRAS"):
		var fuente_caminar := _buscar_animacion_nativa(anim_p, "Caminar")
		if fuente_caminar:
			var anim_atras := _crear_animacion_invertida(fuente_caminar)
			_registrar_alias(anim_p, "Armature|Armature|CAMINAR_ATRAS", anim_atras)
			_registrar_alias(anim_p, "Armature|CAMINAR_ATRAS", anim_atras)


## Clona una animación invirtiendo los keyframes en el tiempo para retroceso natural
func _crear_animacion_invertida(fuente: Animation) -> Animation:
	var anim_rev := Animation.new()
	anim_rev.length = fuente.length
	anim_rev.loop_mode = Animation.LOOP_LINEAR
	for t in range(fuente.get_track_count()):
		var track_type := fuente.track_get_type(t)
		var track_path := fuente.track_get_path(t)
		var new_t := anim_rev.add_track(track_type)
		anim_rev.track_set_path(new_t, track_path)
		anim_rev.track_set_interpolation_type(new_t, fuente.track_get_interpolation_type(t))
		var key_count := fuente.track_get_key_count(t)
		for k in range(key_count):
			var orig_time := fuente.track_get_key_time(t, k)
			var rev_time: float = fuente.length - orig_time
			var val = fuente.track_get_key_value(t, k)
			var trans := fuente.track_get_key_transition(t, k)
			anim_rev.track_insert_key(new_t, rev_time, val, trans)
	return anim_rev


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


## Helper de compatibilidad: indica que Imperio Girl cuenta con el clip de aim walk dedicado registrado
func _tiene_clip_aim_walk_dedicado() -> bool:
	return true


## Crea el reproductor del loop de armadura (mismo clip que AllyBallestera).
func _configurar_sonido_correr() -> void:
	if _sfx_correr and is_instance_valid(_sfx_correr):
		return
	if STREAM_CORRER_ARMADURA == null:
		return
	_sfx_correr = AudioStreamPlayer.new()
	_sfx_correr.name = "SfxCorrerArmadura"
	_sfx_correr.stream = STREAM_CORRER_ARMADURA
	_sfx_correr.volume_db = VOLUMEN_CORRER_DB
	_sfx_correr.bus = "Master"
	_sfx_correr.add_to_group("pausable_audio")
	add_child(_sfx_correr)
	# Loop por re-encadenado: fiable con WAV importado sin loop
	_sfx_correr.finished.connect(_sfx_correr.play)


## True cuando la locomoción está en carrera en suelo (o la cinemática la fuerza).
## Espeja a Player.update_locomotion_anim: run_fwd <=> en suelo, sin apuntar y en
## movimiento. Con arco tensado la locomoción es walk_fwd y no suena armadura.
func _esta_corriendo() -> bool:
	if is_dead:
		return false
	if _forzar_sonido_correr:
		return true
	if current_move_state != MoveState.GROUND:
		return false
	if not is_on_floor():
		return false
	if current_aim_state == AimState.AIMING or current_aim_state == AimState.DRAWING:
		return false
	return absf(velocity.x) >= UMBRAL_VELOCIDAD_CORRER


## Enciende o apaga el loop según si está corriendo (respaldo por si algún flujo
## no pasa por update_locomotion_anim).
func _actualizar_sonido_correr() -> void:
	_fijar_sonido_correr(_esta_corriendo())


func _fijar_sonido_correr(activo: bool) -> void:
	if not _sfx_correr or not is_instance_valid(_sfx_correr):
		return
	if activo:
		if not _sfx_correr.playing:
			_sfx_correr.play()
	elif _sfx_correr.playing:
		_sfx_correr.stop()


## Controla locomotion, animación aim_full y sonido de correr en un solo lugar.
## - Si está quieta en suelo apuntando/tensando: activa pose "aim_full" de cuerpo completo.
## - En cualquier otro caso delega a super (sistema Eryn: piernas + torso superpuesto).
## - Siempre sincroniza el sonido de correr con el input_dir real.
func update_locomotion_anim(input_dir) -> void:
	# ── Animación aim_full (quieta apuntando en suelo) ───────────────────────
	if _entrada_aim_full_lista and not is_dead \
	and current_move_state == MoveState.GROUND \
	and (current_aim_state == AimState.AIMING
			or current_aim_state == AimState.DRAWING
			or current_aim_state == AimState.SHOOTING) \
	and absf(float(input_dir)) <= UMBRAL_INPUT_CORRER:
		if anim_tree:
			anim_tree.set("parameters/Locomotion/transition_request", "aim_full")
		_fijar_sonido_correr(false)
		return

	# ── Locomotion normal (correr / caminar / idle) ───────────────────────────
	super.update_locomotion_anim(input_dir)
	var corriendo: bool = (
		not is_dead
		and current_move_state == MoveState.GROUND
		and current_aim_state != AimState.AIMING
		and current_aim_state != AimState.DRAWING
		and absf(float(input_dir)) > UMBRAL_INPUT_CORRER
		and is_on_floor()
	)
	_fijar_sonido_correr(corriendo or _forzar_sonido_correr)


## Al salir del suelo (aire, trepe, aterrizaje, muerte) se corta el loop.
func set_motion_anim(state_name: String):
	super.set_motion_anim(state_name)
	if state_name != "ground" and not _forzar_sonido_correr:
		_fijar_sonido_correr(false)


## Fuerza el sonido (cinemática de entrada del tutorial: el tween mueve el
## global_position con velocity a cero, así que la detección normal no lo oye).
func iniciar_sonido_correr_forzado() -> void:
	_forzar_sonido_correr = true
	_actualizar_sonido_correr()


## Libera el forzado y deja que la detección normal tome el mando.
func detener_sonido_correr_forzado() -> void:
	_forzar_sonido_correr = false
	_actualizar_sonido_correr()
