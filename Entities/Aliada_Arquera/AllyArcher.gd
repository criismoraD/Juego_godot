class_name AllyArcher
extends Node3D
static var active_allies_cache: Array[Node] = []
## NO rastrea enemigos — dispara en arco hacia la derecha.
## Empieza a disparar cuando hay 2+ enemigos en pantalla.
# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURACIÓN
# ═══════════════════════════════════════════════════════════════════════════════
enum State { IDLE, AIMING, SHOOTING, RELOADING, DYING, DEAD, GETTING_UP, CELEBRATING }
enum TipoDisparoAliada { NORMAL, EXPLOSIVO, MULTIPLE }
@export_category("Activación")
@export var enemigos_minimos: int = 1  ## Cantidad mínima de enemigos vivos para empezar a disparar
@export_category("Disparo")
@export var potencia_minima: float = 5.0
@export var potencia_maxima: float = 12.0
@export var altura_spawn_flecha: float = 1.2
@export var tiempo_suelta_flecha: float = 0.25  ## Segundos del inicio de SOLTAR_FLECHA hasta la suelta de la flecha
@export var tiempo_apuntado_min: float = 0.3  ## Segundos mínimos en IDLE_APUNTANDO (carga mínima)
@export var tiempo_apuntado_max: float = 1.2  ## Segundos máximos en IDLE_APUNTANDO (más tiempo = más potencia)
@export_range(0.0, 30.0, 1.0) var angulo_disparo_min: float = 5.0  ## Ángulo mínimo de elevación (grados)
@export_range(0.0, 60.0, 1.0) var angulo_disparo_max: float = 35.0  ## Ángulo máximo de elevación (grados)
@export_range(1.0, 3.0, 0.05) var multiplicador_potencia_volador: float = 1.6  ## Fuerza extra al disparar a enemigos voladores (trayectoria más plana)
@export_category("Tiempos")
@export var idle_min: float = 0.4  ## Segundos mínimos en idle entre ciclos
@export var idle_max: float = 0.9  ## Segundos máximos en idle entre ciclos
@export_category("Idle Fuera de Combate")
@export var tiempo_entre_examinar_min: float = 6.0  ## Segundos mínimos en IDLE antes de reproducir IDLE_EXAMINAR
@export var tiempo_entre_examinar_max: float = 14.0  ## Segundos máximos en IDLE antes de reproducir IDLE_EXAMINAR
@export_category("Celebración de Victoria")
@export var repeticiones_victoria_min: int = 3  ## Mínimo de loops de la animación de victoria tras oleada
@export_category("Celebración_max")
@export var repeticiones_victoria_max: int = 4  ## Máximo de loops de la animación de victoria tras oleada
@export var duracion_animacion_victoria: float = 1.0  ## Tiempo en segundos de cada loop de victoria
@export var rotacion_victoria_grados: float = 15.0  ## Grados de giro del personaje durante la celebración de victoria
@export var velocidad_giro_victoria: float = 4.5  ## Velocidad de rotación suave para la celebración
@export var probar_victoria: bool = false:  ## Botón para reproducir la animación de victoria desde el Inspector
	set(val):
		if val:
			probar_victoria = false
			celebrar_victoria()
@export_category("Vida")
@export var vida_maxima: int = 2
@export var plano_profundidad_z: float = -0.02  ## Plano Z retrasado (detrás de ballesteras y protagonista)
@export_category("Debug")
@export var debug_logs_enabled: bool = false
# ═══════════════════════════════════════════════════════════════════════════════
# REFERENCIAS
# ═══════════════════════════════════════════════════════════════════════════════
var arrow_scene = preload("res://Entities/Proyectil_Flecha_Aliada/AllyArrow.tscn")
var explosive_arrow_scene = preload("res://Entities/Flecha_Explosiva/FlechaExplosiva.tscn")
var dissolve_shader = preload("res://System/Shaders/dissolve.gdshader")
const TEXTURA_HUMO_PISADAS: Texture2D = preload("res://VFX/Textures/Smoke/Humo_Pisadas_1A-1.png")
const HUMO_PISADAS_FRAMES_H: int = 9
const HUMO_PISADAS_FRAMES_V: int = 1
var _particulas_pisada: GPUParticles3D = null
var anim_player: AnimationPlayer
var bow_anim_player: AnimationPlayer
var skeleton: Skeleton3D
var arrow_node: Node3D
var explosive_arrow_node: Node3D
var hitbox_body: StaticBody3D
var model_root: Node3D
var _original_model_y_rot: float = 0.0
var ultima_muerte_anim: String = ""
var _flecha_soltada: bool = false
var _tiempo_ataque_actual: float = 0.0
@onready var speech_bubble: SpeechBubbleComponent = get_node_or_null("SpeechBubbleComponent")
# ═══════════════════════════════════════════════════════════════════════════════
# ESTADO
# ═══════════════════════════════════════════════════════════════════════════════
var current_state: State = State.IDLE
var state_timer: float = 0.0
var _blink_timer: float = 0.0
var charge_duration: float = 0.0
var health: int = 1
var flechas_explosivas: int = 0  ## Contador interno de flechas explosivas
var flechas_multiples: int = 0  ## Contador interno de flechas múltiples
var _icono_aturdimiento: Sprite3D = null
var _icono_aturdimiento_tween: Tween = null
var paralisis_timer: float = 0.0  ## Tiempo restante de parálisis (4 segundos sin atacar)
var _paralisis_vfx_timer: float = 0.0
var is_dissolving: bool = false
var dissolve_materials: Array = []
static var _cached_wave_spawner: Node = null
var _spine_bone_idx: int = -1  ## Hueso del torso para el apuntado visual hacia arriba
var _loops_victoria_restantes: int = 0
var _tiempo_para_examinar: float = 0.0
var _examinando: bool = false
# ═══════════════════════════════════════════════════════════════════════════════
# INICIALIZACIÓN
# ═══════════════════════════════════════════════════════════════════════════════


func _ready():
	active_allies_cache.append(self)
	add_to_group("allies")
	health = vida_maxima
	set_physics_process(false)

	model_root = find_child("ArqueraModel", false, false)
	if model_root:
		_original_model_y_rot = model_root.rotation.y

	# Hueso del torso para el apuntado visual (mismo rig que la protagonista)
	skeleton = find_child("Skeleton3D", true, false)
	if skeleton:
		_spine_bone_idx = skeleton.find_bone("mixamorig_Spine1")
		if _spine_bone_idx == -1:
			_spine_bone_idx = skeleton.find_bone("mixamorig_Spine")

	_setup_animation_player()
	_buscar_arrow_node()
	_crear_hitbox()
	_configurar_particulas_pisada()

	# Ocultar flecha visual
	if arrow_node and is_instance_valid(arrow_node):
		arrow_node.visible = false

	# Sombra procedural debajo del personaje
	var _sombra := SombraPersonaje.new()
	add_child(_sombra)

	global_position.z = plano_profundidad_z
	_aplicar_prioridad_renderizado(-2.0)

	call_deferred("_iniciar")
	call_deferred("_conectar_eventos_oleada")


func _aplicar_prioridad_renderizado(offset: float) -> void:
	for node in find_children("*", "VisualInstance3D", true, false):
		if node is VisualInstance3D:
			node.sorting_offset = offset


func _configurar_particulas_pisada() -> void:
	if _particulas_pisada and is_instance_valid(_particulas_pisada):
		return
	_particulas_pisada = GPUParticles3D.new()
	_particulas_pisada.name = "Particulas_Pisada"
	_particulas_pisada.emitting = false
	_particulas_pisada.amount = 8
	_particulas_pisada.lifetime = 0.8
	_particulas_pisada.visibility_aabb = AABB(Vector3(-1, -0.2, -1), Vector3(2, 1.5, 2))
	add_child(_particulas_pisada)
	_particulas_pisada.position = Vector3(0, 0.05, 0)

	var mat := StandardMaterial3D.new()
	if TEXTURA_HUMO_PISADAS:
		mat.albedo_texture = TEXTURA_HUMO_PISADAS
		mat.particles_anim_h_frames = HUMO_PISADAS_FRAMES_H
		mat.particles_anim_v_frames = HUMO_PISADAS_FRAMES_V
		mat.particles_anim_loop = false
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.render_priority = 2

	var mesh := QuadMesh.new()
	mesh.material = mat
	mesh.size = Vector2(0.3276, 0.3276)
	_particulas_pisada.draw_pass_1 = mesh

	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 50.0
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.25
	pm.gravity = Vector3(0.0, 0.1, 0.0)
	pm.scale_min = 0.4
	pm.scale_max = 0.657
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.08, 0.01, 0.08)
	pm.anim_speed_min = 1.0
	pm.anim_speed_max = 1.0
	pm.anim_offset_min = 0.0
	pm.anim_offset_max = 1.0

	var grad := Gradient.new()
	grad.set_color(0, Color(0.5, 0.5, 0.5, 0.6))
	grad.set_color(1, Color(0.5, 0.5, 0.5, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	pm.color_ramp = grad_tex

	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.25), 0.0, 1.2)
	curve.add_point(Vector2(0.3, 1.0), 0.2, -0.4)
	curve.add_point(Vector2(0.65, 0.6), -0.6, -0.8)
	curve.add_point(Vector2(1.0, 0.0), -1.2, 0.0)
	var curve_tex := CurveTexture.new()
	curve_tex.curve = curve
	pm.scale_curve = curve_tex

	_particulas_pisada.process_material = pm


func _particulas_pisada_emitir() -> void:
	if not _particulas_pisada or not is_instance_valid(_particulas_pisada):
		return
	var corriendo := anim_player and anim_player.current_animation.contains("CORRER")
	_particulas_pisada.emitting = corriendo and current_state != State.DYING and current_state != State.DEAD and paralisis_timer <= 0.0


func _iniciar():
	_log_debug(["[AllyArcher] _iniciar() llamado"])
	_log_debug(["[AllyArcher] anim_player: ", anim_player])
	_log_debug(["[AllyArcher] bow_anim_player: ", bow_anim_player])
	if anim_player:
		anim_player.active = true
		_log_debug(["[AllyArcher] Animaciones disponibles: ", anim_player.get_animation_list()])
	else:
		_log_debug(["[AllyArcher] anim_player es NULL"])
	if bow_anim_player:
		bow_anim_player.active = true
		_log_debug(["[AllyArcher] Anims arco: ", bow_anim_player.get_animation_list()])
	_cambiar_estado(State.IDLE)
	_play_anim(["IDE", "IDLE_001", "IDLE"], 0.0)
	_play_bow_anim("ARCO_IDLE", 0.0)
	set_process(true)


func _setup_animation_player():
	# 1. Desactivar AnimationTree / AnimationMixer importados (GLB trae mixer que secuestra esqueleto)
	var trees = find_children("*", "AnimationTree", true, false)
	for tree in trees:
		tree.active = false
		_log_debug(["[AllyArcher] AnimationTree desactivado: ", tree.name])
	var mixers = find_children("*", "AnimationMixer", true, false)
	for mixer in mixers:
		if mixer is AnimationPlayer:
			continue
		if mixer.has_method("set_active"):
			mixer.active = false
		elif "active" in mixer:
			mixer.set("active", false)
		_log_debug(["[AllyArcher] AnimationMixer desactivado: ", mixer.name])

	# 2. Buscar AnimationPlayer principal (con IDLE, DISPARO, etc.)
	#    Acepta nombres con prefijo (Armature|Armature|IDLE) o sin prefijo (IDLE)
	var all_players = find_children("*", "AnimationPlayer", true, false)
	_log_debug(["[AllyArcher] AnimationPlayers encontrados: ", all_players.size()])

	# Primero imprimir TODOS los players para debug
	for player in all_players:
		_log_debug(
			[
				"[AllyArcher] Player '",
				player.name,
				"' path=",
				player.get_path(),
				" - Anims: ",
				player.get_animation_list()
			]
		)

	for player in all_players:
		var anims = player.get_animation_list()

		# Verificar que tenga animaciones de PERSONAJE
		# Excluir animaciones del arco (contienen "ARCO" o empiezan con "Recurve Bow")
		var is_character = false
		for a in anims:
			var is_bow_anim = a.begins_with("Recurve Bow") or "ARCO" in a
			if is_bow_anim:
				continue
			var has_idle = "IDE" in a or "IDLE" in a
			var has_shoot = "DISPAR" in a or "TOMA" in a or "FLEHCA" in a or "FLECHA" in a or "CORRER" in a
			if has_idle or has_shoot:
				is_character = true
				break

		if is_character:
			anim_player = player
			_log_debug(
				[
					"[AllyArcher] AnimationPlayer de PERSONAJE seleccionado: ",
					player.name,
					" path=",
					player.get_path()
				]
			)
			break

	if not anim_player:
		push_error("[AllyArcher] AnimationPlayer not found with IDLE/SHOOT animations")
		return

	_log_debug(["[AllyArcher] AnimationPlayer seleccionado: ", anim_player.name])

	# 3. Configurar loops en IDE, IDLE y CORRER (EXAMINAR y DISPARO sin loop)
	for anim_name in anim_player.get_animation_list():
		var an_upper := anim_name.to_upper()
		if "EXAMINAR" in an_upper or "DISPAR" in an_upper or "TOMA" in an_upper or "DAÑO" in an_upper or "MUERTE" in an_upper or "VICTORIA" in an_upper:
			var anim = anim_player.get_animation(anim_name)
			if anim:
				anim.loop_mode = Animation.LOOP_NONE
		elif an_upper == "IDE" or an_upper == "IDLE" or "APUNTANDO" in an_upper or "CORRER" in an_upper:
			var anim = anim_player.get_animation(anim_name)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR

	# 4. Buscar AnimationPlayer del arco (separado)
	for player in all_players:
		if player == anim_player:
			continue
		var anims = player.get_animation_list()
		for a in anims:
			if "ARCO" in a or a.begins_with("Recurve Bow"):
				bow_anim_player = player
				break
		if bow_anim_player:
			break

	call_deferred("_aplicar_animaciones_protagonista")


func _aplicar_animaciones_protagonista() -> void:
	if not anim_player:
		return
	if get_tree() == null:
		return
	var prota: Node = get_tree().get_first_node_in_group("player")
	if not prota:
		return
	var prota_ap: AnimationPlayer = null
	var all_prota_players = prota.find_children("*", "AnimationPlayer", true, false)
	for p in all_prota_players:
		var anims = p.get_animation_list()
		var is_character := false
		for a in anims:
			if a.begins_with("Recurve Bow") or "ARCO" in a:
				continue
			if "IDLE" in a or "DISPARO" in a or "TOMAR_FLECHA" in a:
				is_character = true
				break
		if is_character:
			prota_ap = p
			break
	if not prota_ap:
		prota_ap = prota.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not prota_ap or prota_ap == anim_player:
		return
	for lib_name in prota_ap.get_animation_library_list():
		if "Recurve Bow" in lib_name or "ARCO" in lib_name:
			continue
		var lib: AnimationLibrary = prota_ap.get_animation_library(lib_name)
		if lib:
			var has_bow_anim := false
			for an in lib.get_animation_list():
				if an.begins_with("Recurve Bow") or "ARCO" in an:
					has_bow_anim = true
					break
			if has_bow_anim:
				continue
			if not anim_player.has_animation_library(lib_name):
				anim_player.add_animation_library(lib_name, lib)
			else:
				var existing_lib: AnimationLibrary = anim_player.get_animation_library(lib_name)
				for anim_name in lib.get_animation_list():
					if anim_name.begins_with("Recurve Bow") or "ARCO" in anim_name:
						continue
					if not existing_lib.has_animation(anim_name):
						existing_lib.add_animation(anim_name, lib.get_animation(anim_name))
	for lib_name in anim_player.get_animation_library_list():
		if "Recurve Bow" in lib_name or "ARCO" in lib_name:
			anim_player.remove_animation_library(lib_name)


func _buscar_arrow_node():
	arrow_node = find_child("FLECHA", true, false)
	if not arrow_node:
		arrow_node = find_child("BoneAttach_Flecha", true, false)
	if arrow_node and arrow_node.get_parent():
		var parent_attach = arrow_node.get_parent()
		explosive_arrow_node = parent_attach.get_node_or_null("FLECHA_EXPLOSIVA_VISUAL") as Node3D
		if not explosive_arrow_node:
			var glb_scene = load("res://Entities/Flecha_Explosiva/Flecha_Explosiva.glb") as PackedScene
			if glb_scene:
				explosive_arrow_node = glb_scene.instantiate() as Node3D
				explosive_arrow_node.name = "FLECHA_EXPLOSIVA_VISUAL"
				parent_attach.add_child(explosive_arrow_node)
				var rot_adj = Basis(Vector3.UP, deg_to_rad(-90.0))
				explosive_arrow_node.transform = Transform3D(
					arrow_node.transform.basis * rot_adj * (0.305 / 0.4),
					arrow_node.transform.origin
				)
				var tip_light := OmniLight3D.new()
				tip_light.name = "RedTipLight"
				tip_light.light_color = Color(1.0, 0.15, 0.08)
				tip_light.light_energy = 0.8
				tip_light.omni_range = 0.9
				tip_light.position = Vector3(0.0, 0.0, 0.45)
				explosive_arrow_node.add_child(tip_light)
		if explosive_arrow_node:
			explosive_arrow_node.visible = false


func _crear_hitbox():
	hitbox_body = StaticBody3D.new()
	hitbox_body.name = "HitboxBody"
	hitbox_body.add_to_group("allies")
	hitbox_body.set_meta("defensora_owner", self)  ## Permite a los proyectiles aplicar estados sobre la defensora dueña de esta hitbox
	hitbox_body.collision_layer = 2  # Capa 2: el Player (capa 1) no colisiona, flechas enemigas (mask=3) sí
	hitbox_body.collision_mask = 0

	var col = CollisionShape3D.new()
	var shape = CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.6
	col.shape = shape
	col.position = Vector3(0, 0.8, 0)

	hitbox_body.add_child(col)
	add_child(hitbox_body)


# ═══════════════════════════════════════════════════════════════════════════════
# PROCESO PRINCIPAL
# ═══════════════════════════════════════════════════════════════════════════════


func _process(delta):
	_actualizar_rotacion_modelo(delta)
	if _particulas_pisada:
		_particulas_pisada_emitir()

	if current_state == State.DYING or current_state == State.DEAD:
		_restaurar_torso()
		_ocultar_icono_aturdimiento()
		return

	if paralisis_timer > 0.0:
		paralisis_timer -= delta
		_restaurar_torso()
		if _icono_aturdimiento and _icono_aturdimiento.visible:
			var t := Time.get_ticks_msec() / 1000.0
			_icono_aturdimiento.position.y = 3.6 + sin(t * 3.8) * 0.12
		if paralisis_timer <= 0.0:
			paralisis_timer = 0.0
			_ocultar_icono_aturdimiento()
			_play_anim(["IDLE", "IDLE_001"], 0.25)
		else:
			_paralisis_vfx_timer += delta

	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.RELOADING:
			_process_reloading(delta)
		State.AIMING:
			_process_aiming(delta)
		State.SHOOTING:
			_process_shooting(delta)
		State.GETTING_UP:
			_process_getting_up(delta)
		State.CELEBRATING:
			_process_celebrating(delta)

	# Apuntado visual del torso hacia el objetivo activo (gárgola, Lonko o pilar)
	if paralisis_timer <= 0.0 and current_state != State.CELEBRATING:
		_actualizar_apuntado_torso()


## Aplica el estado de parálisis por la duración indicada (4s por defecto):
## No es acumulable (debe pasar el efecto para volver a aplicarse).
## No puede atacar, reproduce animación ELECTROCUTADA, muestra el icono flotante de aturdimiento y restaura el torso.
func aplicar_paralisis(duracion: float = 4.0) -> void:
	if current_state == State.DYING or current_state == State.DEAD or esta_paralizada() or paralisis_timer > 0.0:
		return
	paralisis_timer = duracion
	_ocultar_flecha()
	_restaurar_torso()
	# Cambiar a IDLE PRIMERO: su handler reproduce la animación de idle, y la
	# electrocución se reproduce DESPUÉS para que no la pise (antes el cambio de
	# estado sobreescribía ELECTROCUTAR con el idle y no se veía el calambre)
	if current_state != State.IDLE and current_state != State.GETTING_UP:
		_cambiar_estado(State.IDLE)
	_play_anim(["ELECTROCUTAR", "ELECTROCUTADA"], 0.15, 1.0)
	_mostrar_icono_aturdimiento()


func _setup_icono_aturdimiento() -> void:
	if _icono_aturdimiento:
		return

	_icono_aturdimiento = Sprite3D.new()
	_icono_aturdimiento.name = "IconoAturdimiento"
	var tex: Texture2D = null
	if not FileAccess.file_exists("res://UI/Icons/Icono_aturdimiento.png.import"):
		var img := Image.new()
		if img.load("res://UI/Icons/Icono_aturdimiento.png") == OK:
			tex = ImageTexture.create_from_image(img)
	if not tex:
		tex = load("res://UI/Icons/Icono_aturdimiento.png") as Texture2D
	_icono_aturdimiento.texture = tex
	_icono_aturdimiento.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icono_aturdimiento.pixel_size = 0.0016
	_icono_aturdimiento.shaded = false
	_icono_aturdimiento.no_depth_test = true
	_icono_aturdimiento.render_priority = 12
	_icono_aturdimiento.position = Vector3(0.0, 3.6, 0.1)  # Flota claramente por encima de la cabeza
	_icono_aturdimiento.modulate = Color(0.25, 1.2, 0.35, 0.0)  # Color verde brillante
	_icono_aturdimiento.visible = false
	add_child(_icono_aturdimiento)


func _mostrar_icono_aturdimiento() -> void:
	_setup_icono_aturdimiento()
	if not _icono_aturdimiento:
		return

	_icono_aturdimiento.visible = true
	if _icono_aturdimiento_tween and _icono_aturdimiento_tween.is_valid():
		_icono_aturdimiento_tween.kill()

	_icono_aturdimiento.scale = Vector3.ZERO
	_icono_aturdimiento.modulate = Color(0.25, 1.2, 0.35, 0.0)

	_icono_aturdimiento_tween = create_tween()
	_icono_aturdimiento_tween.set_parallel(true)
	_icono_aturdimiento_tween.tween_property(_icono_aturdimiento, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_icono_aturdimiento_tween.tween_property(_icono_aturdimiento, "modulate:a", 1.0, 0.18)


func _ocultar_icono_aturdimiento() -> void:
	if not _icono_aturdimiento or not _icono_aturdimiento.visible:
		return

	if _icono_aturdimiento_tween and _icono_aturdimiento_tween.is_valid():
		_icono_aturdimiento_tween.kill()

	_icono_aturdimiento_tween = create_tween()
	_icono_aturdimiento_tween.set_parallel(true)
	_icono_aturdimiento_tween.tween_property(_icono_aturdimiento, "scale", Vector3.ZERO, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_icono_aturdimiento_tween.tween_property(_icono_aturdimiento, "modulate:a", 0.0, 0.18)
	_icono_aturdimiento_tween.chain().tween_callback(func():
		if is_instance_valid(_icono_aturdimiento):
			_icono_aturdimiento.visible = false
	)


func esta_paralizada() -> bool:
	return paralisis_timer > 0.0


## Inclina el torso hacia el objetivo mientras apunta/dispara, con la
## misma convención que la protagonista (pitch negativo sobre FORWARD, hueso
## mixamorig_Spine1, multiplicación local). Sin objetivo, restaura la pose.
func _actualizar_apuntado_torso() -> void:
	if not skeleton or _spine_bone_idx == -1:
		return

	if paralisis_timer > 0.0:
		_restaurar_torso()
		return

	var objetivo := _obtener_objetivo_actual()
	var en_estados_disparo := (
		current_state == State.RELOADING
		or current_state == State.AIMING
		or current_state == State.SHOOTING
	)

	if objetivo == null or not en_estados_disparo:
		_restaurar_torso()
		return

	var my_pos: Vector3 = global_position + Vector3(0, 0.5, 0)
	var target_offset: Vector3 = Vector3(0, 0.3, 0)
	if objetivo is PilarLonkoBody or ("es_pilar_enemigo" in objetivo and objetivo.es_pilar_enemigo):
		target_offset = Vector3(0, 1.2, 0)
	elif objetivo is Lonko or ("lonko" in objetivo.name.to_lower()):
		target_offset = Vector3(0, 0.6, 0)
	elif objetivo is GloboAerostatico:
		# Canasto/arquera del globo: centro de su cápsula de colisión
		target_offset = Vector3(0, 0.6, 0)

	var target_pos: Vector3 = objetivo.global_position + target_offset
	var dy: float = target_pos.y - my_pos.y
	var dx: float = absf(target_pos.x - my_pos.x)
	# Pitch negativo = arco hacia arriba (misma convención que Player)
	var pitch: float = clampf(-atan2(maxf(dy, 0.0), maxf(dx, 0.1)), deg_to_rad(-70.0), 0.0)

	skeleton.set_bone_global_pose_override(_spine_bone_idx, Transform3D.IDENTITY, 0.0, false)
	var pose_actual: Transform3D = skeleton.get_bone_global_pose(_spine_bone_idx)
	var pitch_rotation := Quaternion(Vector3.FORWARD, pitch)
	var nueva_basis: Basis = pose_actual.basis * Basis(pitch_rotation)
	skeleton.set_bone_global_pose_override(
		_spine_bone_idx, Transform3D(nueva_basis, pose_actual.origin), 1.0, false
	)


func _restaurar_torso() -> void:
	if skeleton and _spine_bone_idx != -1:
		skeleton.set_bone_global_pose_override(_spine_bone_idx, Transform3D.IDENTITY, 0.0, false)


## IDLE: en espera desarmada al inicio/entre oleadas (IDE y periódicamente IDLE_EXAMINAR), o alerta en combate (IDLE_APUNTANDO)
func _process_idle(delta: float) -> void:
	if paralisis_timer > 0.0:
		state_timer = 0.4
		return

	var hay_enemigos: bool = (_contar_enemigos_en_pantalla() >= enemigos_minimos)
	if not hay_enemigos:
		# Fuera de combate: alternar IDE normal y periódicamente IDLE_EXAMINAR
		if _examinando:
			state_timer -= delta
			if state_timer <= 0.0:
				_examinando = false
				_play_anim(["IDE", "IDLE_001", "IDLE"], 0.3)
				_tiempo_para_examinar = randf_range(tiempo_entre_examinar_min, tiempo_entre_examinar_max)
		else:
			_tiempo_para_examinar -= delta
			if _tiempo_para_examinar <= 0.0:
				_examinando = true
				_play_anim(["IDLE_EXAMINAR", "EXAMINAR"], 0.25)
				state_timer = _get_anim_length(["IDLE_EXAMINAR", "EXAMINAR"])
			else:
				_play_anim(["IDE", "IDLE_001", "IDLE"], 0.3)
		_play_bow_anim("ARCO_IDLE", 0.3)
		return

	# Al detectar enemigos en combate, cancelar cualquier acción pasiva y mantener pose apuntando entre disparos
	_examinando = false
	_play_anim(["IDLE_APUNTANDO", "APUNTAR_IDLE"], 0.2)
	_play_bow_anim("ARCO_TENSAR", 0.2, 1.0)
	state_timer -= delta
	if state_timer <= 0:
		# Ciclo de disparo: TOMAR_FLECHA -> IDLE_APUNTANDO -> DISPARAR_FLECHA
		_cambiar_estado(State.RELOADING)


## RELOADING (TOMAR_FLECHA): la arquera saca y carga una flecha
func _process_reloading(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0:
		_cambiar_estado(State.AIMING)


## AIMING (IDLE_APUNTANDO): apunta en idle un rato según la carga elegida; al terminar, dispara
func _process_aiming(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0:
		_cambiar_estado(State.SHOOTING)


## SHOOTING: animación DISPARAR_FLECHA; en tiempo_suelta_flecha suelta la flecha y sale el proyectil
func _process_shooting(delta: float) -> void:
	_tiempo_ataque_actual += delta
	state_timer -= delta

	# Al llegar a tiempo_suelta_flecha, soltar y disparar proyectil
	if not _flecha_soltada and _tiempo_ataque_actual >= tiempo_suelta_flecha:
		_flecha_soltada = true
		_disparar()
		_ocultar_flecha()
		_play_bow_anim("ARCO_DISPARO", 0.05, 1.0)

	if state_timer <= 0:
		if not _flecha_soltada:
			_flecha_soltada = true
			_disparar()
			_ocultar_flecha()
			_play_bow_anim("ARCO_DISPARO", 0.05, 1.0)
		_cambiar_estado(State.IDLE)


## GETTING_UP: esperar a que termine de levantarse
func _process_getting_up(delta: float) -> void:
	state_timer -= delta
	
	# Parpadeo de invulnerabilidad
	_blink_timer += delta
	if _blink_timer >= 0.16:
		_blink_timer = 0.0
		if model_root:
			model_root.visible = not model_root.visible

	if state_timer <= 0:
		if model_root:
			model_root.visible = true
		_cambiar_estado(State.IDLE)


## CELEBRATING: la animación VICTORIA corre en LOOP (el AnimationPlayer
## la repite sola); aquí solo se agota el tiempo total y se corta a IDLE.
func _process_celebrating(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0:
		_loops_victoria_restantes = 0
		_cambiar_estado(State.IDLE)


## Busca el clip VICTORIA real y lo configura en LOOP_LINEAR para que la
## celebración se repita sin cortes (antes cada re-loop con blend cortaba
## el levantamiento de brazos a mitad, pareciendo que faltan frames).
func _configurar_victoria_loop() -> void:
	if not anim_player:
		return
	for a in anim_player.get_animation_list():
		if "victoria" in a.to_lower():
			var anim := anim_player.get_animation(a)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR
			return


# ═══════════════════════════════════════════════════════════════════════════════
# CAMBIO DE ESTADO
# ═══════════════════════════════════════════════════════════════════════════════


func _cambiar_estado(nuevo: State):
	if nuevo != State.GETTING_UP and nuevo != State.CELEBRATING and model_root:
		model_root.visible = true
		if model_root.rotation.y != _original_model_y_rot:
			if is_inside_tree():
				var tween = create_tween()
				tween.tween_property(model_root, "rotation:y", _original_model_y_rot, 0.3)\
					.set_trans(Tween.TRANS_SINE)\
					.set_ease(Tween.EASE_OUT)
			else:
				model_root.rotation.y = _original_model_y_rot

	current_state = nuevo
	match nuevo:
		State.IDLE:
			var hay_enemigos: bool = (_contar_enemigos_en_pantalla() >= enemigos_minimos)
			_examinando = false
			if not hay_enemigos:
				_play_anim(["IDE", "IDLE_001", "IDLE"], 0.3)
				_play_bow_anim("ARCO_IDLE", 0.3)
				_tiempo_para_examinar = randf_range(tiempo_entre_examinar_min, tiempo_entre_examinar_max)
			else:
				_play_anim(["IDLE_APUNTANDO", "APUNTAR_IDLE"], 0.2)
				_play_bow_anim("ARCO_TENSAR", 0.2, 1.0)
				state_timer = randf_range(idle_min, idle_max)
			_ocultar_flecha()
			_flecha_soltada = false

		State.RELOADING:
			# TOMAR_FLECHA: saca una flecha
			_flecha_soltada = false
			_tiempo_ataque_actual = 0.0
			_ocultar_flecha()
			_play_anim(["TOMAR_FLECHA", "TOMAR_FLEHCA", "TOMA_FLECHA"], 0.15, 1.0)
			_play_bow_anim("ARCO_TENSAR", 0.2, 1.0)
			state_timer = maxf(_get_anim_length(["TOMAR_FLECHA", "TOMAR_FLEHCA", "TOMA_FLECHA"]), 0.3)

		State.AIMING:
			# IDLE_APUNTANDO: mantiene la flecha tensada apuntando
			charge_duration = randf_range(tiempo_apuntado_min, tiempo_apuntado_max)
			_mostrar_flecha()
			_play_anim(["IDLE_APUNTANDO", "APUNTAR_IDLE"], 0.15, 1.0)
			_play_bow_anim("ARCO_TENSAR", 0.2, 1.0)
			AudioManager.play_sfx("bow_tension", -6.0)
			var _dec_fuego := _decidir_disparo_y_objetivo()
			if _dec_fuego.get("type", TipoDisparoAliada.NORMAL) == TipoDisparoAliada.EXPLOSIVO:
				AudioManager.play_sfx("fuego_tensado", 6.0)
			state_timer = charge_duration

		State.SHOOTING:
			# DISPARAR_FLECHA: suelta y dispara
			_flecha_soltada = false
			_tiempo_ataque_actual = 0.0
			_play_anim(["DISPARAR_FLECHA", "SOLTAR_FLECHA", "DISPARAR", "DISPARO"], 0.1, 1.0)
			_play_bow_anim("ARCO_DISPARO", 0.05, 1.0)
			state_timer = maxf(_get_anim_length(["DISPARAR_FLECHA", "SOLTAR_FLECHA", "DISPARAR"]), tiempo_suelta_flecha + 0.2)

		State.DYING:
			_on_dying()
		State.DEAD:
			pass
		State.GETTING_UP:
			_play_anim(["AGACHARSE", "ATERRIZAJE_POST_SALTO_01", "ATERRIZAJE_POST_SALTO_0", "LEVANTARSE"], 0.0)
			_play_bow_anim("ARCO_IDLE", 0.0)
			state_timer = _get_anim_length(["AGACHARSE", "ATERRIZAJE_POST_SALTO_01"])
			_blink_timer = 0.0
			_ocultar_flecha()
			if ultima_muerte_anim == "MUERTE_01" and model_root:
				model_root.rotation.y = _original_model_y_rot + deg_to_rad(90)
		State.CELEBRATING:
			_restaurar_torso()
			_ocultar_flecha()
			# Victoria fluida: clip en LOOP (sin re-plays que cortan los brazos a mitad)
			_configurar_victoria_loop()
			_play_anim("VICTORIA", 0.25, 1.0)
			_play_bow_anim("ARCO_IDLE", 0.25, 1.0)
			var _dur_clip: float = _get_anim_length("VICTORIA")
			state_timer = maxf(_dur_clip, 0.3) * _loops_victoria_restantes


# ═══════════════════════════════════════════════════════════════════════════════
# CELEBRACIÓN DE VICTORIA Y EVENTOS DE OLEADA
# ═══════════════════════════════════════════════════════════════════════════════


func _conectar_eventos_oleada() -> void:
	var spawner = _get_cached_wave_spawner()
	if spawner:
		if spawner.has_signal("oleada_iniciada"):
			if not spawner.oleada_iniciada.is_connected(_on_oleada_iniciada):
				spawner.oleada_iniciada.connect(_on_oleada_iniciada)
		if spawner.has_signal("oleada_completada"):
			if not spawner.oleada_completada.is_connected(_on_oleada_completada):
				spawner.oleada_completada.connect(_on_oleada_completada)


func _on_oleada_iniciada(_numero_oleada: int) -> void:
	if current_state != State.DYING and current_state != State.DEAD:
		_cambiar_estado(State.IDLE)
		_play_anim(["IDE", "IDLE_001", "IDLE"], 0.3)
		_play_bow_anim("ARCO_IDLE", 0.3)


func _on_oleada_completada(_numero_oleada: int) -> void:
	celebrar_victoria()


func celebrar_victoria() -> void:
	if current_state != State.DYING and current_state != State.DEAD:
		_loops_victoria_restantes = randi_range(repeticiones_victoria_min, repeticiones_victoria_max)
		_cambiar_estado(State.CELEBRATING)
		_reproducir_grito_victoria()


## SFX de festejo: grito de victoria de la defensora arquera.
func _reproducir_grito_victoria() -> void:
	var stream: AudioStream = load("res://TEST_/victoria grito defensora arquera aliada.wav")
	if not stream:
		return
	var player := AudioStreamPlayer.new()
	player.add_to_group("pausable_audio")
	player.stream = stream
	player.volume_db = -4.0
	player.bus = "Master"
	var root := get_tree().current_scene
	if root:
		root.add_child(player)
		player.play()
		player.finished.connect(player.queue_free)
	else:
		player.queue_free()


func probar_animacion_victoria() -> void:
	celebrar_victoria()


func _actualizar_rotacion_modelo(delta: float) -> void:
	if not model_root:
		return
	var target_y_rot: float = _original_model_y_rot
	if current_state == State.CELEBRATING:
		target_y_rot = _original_model_y_rot + deg_to_rad(rotacion_victoria_grados)
	model_root.rotation.y = lerp_angle(model_root.rotation.y, target_y_rot, 1.0 - exp(-velocidad_giro_victoria * delta))


# ═══════════════════════════════════════════════════════════════════════════════
# CONTEO DE ENEMIGOS
# ═══════════════════════════════════════════════════════════════════════════════


func _get_cached_wave_spawner() -> Node:
	if is_instance_valid(_cached_wave_spawner):
		return _cached_wave_spawner

	if get_tree() == null:
		return null

	_cached_wave_spawner = get_tree().get_first_node_in_group("wave_spawners")
	if _cached_wave_spawner:
		return _cached_wave_spawner

	var scene_root = get_tree().current_scene
	if scene_root == null:
		scene_root = get_tree().root.get_child(get_tree().root.get_child_count() - 1)

	var wave_spawner = scene_root.find_child("WaveSpawner", true, false)
	if wave_spawner:
		_cached_wave_spawner = wave_spawner
	return _cached_wave_spawner


func _es_imp_escudo(enemy: Node) -> bool:
	if not is_instance_valid(enemy):
		return false
	if enemy is ImpShieldGirl or enemy.is_in_group("shield_imps"):
		return true
	var n: String = enemy.name.to_lower()
	var s: String = enemy.get_script().resource_path.to_lower() if enemy.get_script() else ""
	return ("imp" in n and "escudo" in n) or ("impshield" in n) or ("impshield" in s) or ("imp_escudo" in s)


func _es_lonko(enemy: Node) -> bool:
	if not is_instance_valid(enemy) or not (enemy is Node3D):
		return false
	if enemy is Lonko:
		return true
	var n: String = enemy.name.to_lower()
	var s: String = enemy.get_script().resource_path.to_lower() if enemy.get_script() else ""
	return "lonko" in n or "lonko" in s


## Lonko solo es enemiga válida si está parada encima de un pilar con la animación de emerger ya completa
func _es_lonko_en_pilar_completo(enemy: Node) -> bool:
	if not _es_lonko(enemy):
		return false
	if enemy.has_method("esta_en_pilar_emergido_completo"):
		return enemy.esta_en_pilar_emergido_completo()
	var desplegado: Variant = enemy.get("_pilar_desplegado")
	if desplegado != null and bool(desplegado):
		var girando: Variant = enemy.get("_girando_hacia_fondo")
		var invuln: Variant = enemy.get("_is_invulnerable")
		if girando != null and bool(girando):
			return false
		if invuln != null and bool(invuln):
			return false
		return true
	return false


## Devuelve la cantidad de enemigos presentes en pantalla, vivos, estén o no reconocidos como objetivos
func _contar_enemigos_en_pantalla() -> int:
	var count := 0
	var enemies: Array = []
	var wave_spawner = _get_cached_wave_spawner()
	if wave_spawner and wave_spawner.has_method("get_active_enemies"):
		enemies = wave_spawner.get_active_enemies()
	else:
		enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.is_inside_tree():
			continue
		if enemy.get("is_dead") == true or enemy.get("is_dying") == true or enemy.get("muerto") == true:
			continue
		if enemy.get("current_state") != null:
			var st = enemy.current_state
			if str(st) in ["DYING", "DEAD", "MUERTO"]:
				continue
			if enemy is EnemyBase and (st == EnemyBase.State.DYING or st == EnemyBase.State.DEAD):
				continue
			if enemy is ImpShieldGirl and (st == ImpShieldGirl.State.DYING or st == ImpShieldGirl.State.DEAD):
				continue
		count += 1
	return count


func _contar_enemigos_vivos() -> int:
	var count = 0
	var enemies = []

	var wave_spawner = _get_cached_wave_spawner()
	if wave_spawner and wave_spawner.has_method("get_active_enemies"):
		enemies = wave_spawner.get_active_enemies()
	else:
		enemies = get_tree().get_nodes_in_group("enemies")

	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.is_inside_tree():
			continue
		if _es_imp_escudo(enemy):
			continue  # No reconocer a la Imp de escudo como objetivo directo (se daña por casualidad)
		if _es_lonko(enemy) and not _es_lonko_en_pilar_completo(enemy):
			continue  # Lonko solo se reconoce como enemiga cuando está sobre su pilar con la animación de emerger completa
		if enemy.get("is_dead") == true or enemy.get("is_dying") == true or enemy.get("muerto") == true:
			continue
		if enemy.get("current_state") != null:
			var st = enemy.current_state
			if str(st) in ["DYING", "DEAD", "MUERTO"]:
				continue
			if enemy is EnemyBase and (st == EnemyBase.State.DYING or st == EnemyBase.State.DEAD):
				continue
			if enemy is ImpShieldGirl and (st == ImpShieldGirl.State.DYING or st == ImpShieldGirl.State.DEAD):
				continue
		count += 1
	return count


## Busca la gárgola (enemigo volador) viva más cercana frente a la arquera.
## Las gárgolas vuelan alto (3.3-5.2 m): el arco a ciego nunca las alcanza,
## así que requieren apuntado directo.
func _obtener_gargola_objetivo() -> Node3D:
	var enemies = []

	var wave_spawner = _get_cached_wave_spawner()
	if wave_spawner and wave_spawner.has_method("get_active_enemies"):
		enemies = wave_spawner.get_active_enemies()
	else:
		enemies = EnemyBase.active_enemies_cache

	var mejor: Node3D = null
	var menor_dist: float = INF
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.is_inside_tree():
			continue
		if not (enemy is Gargola):
			continue
		if enemy.current_state == EnemyBase.State.DYING or enemy.current_state == EnemyBase.State.DEAD:
			continue
		# Solo enemigos delante (a la derecha de la arquera)
		if enemy.global_position.x <= global_position.x:
			continue
		var dist: float = absf(enemy.global_position.x - global_position.x)
		if dist < menor_dist:
			menor_dist = dist
			mejor = enemy
	return mejor


## Busca el globo aerostático (vehículo volador) vivo más cercano frente a la arquera.
## Vuela alto (3.3-5.2 m): igual que la gárgola, el arco a ciego no lo alcanza.
func _obtener_globo_objetivo() -> Node3D:
	var enemies = []

	var wave_spawner = _get_cached_wave_spawner()
	if wave_spawner and wave_spawner.has_method("get_active_enemies"):
		enemies = wave_spawner.get_active_enemies()
	else:
		enemies = EnemyBase.active_enemies_cache

	var mejor: Node3D = null
	var menor_dist: float = INF
	for enemy in enemies:
		if not is_instance_valid(enemy) or not enemy.is_inside_tree():
			continue
		if not (enemy is GloboAerostatico):
			continue
		if enemy.current_state == EnemyBase.State.DYING or enemy.current_state == EnemyBase.State.DEAD:
			continue
		# Solo enemigos delante (a la derecha de la arquera)
		if enemy.global_position.x <= global_position.x:
			continue
		var dist: float = absf(enemy.global_position.x - global_position.x)
		if dist < menor_dist:
			menor_dist = dist
			mejor = enemy
	return mejor


## Busca la arquera Lonko viva más cercana frente a la defensora,
## SOLO si está parada encima de su pilar con la animación de emerger completa.
func _obtener_lonko_objetivo() -> Node3D:
	var enemies = []

	var wave_spawner = _get_cached_wave_spawner()
	if wave_spawner and wave_spawner.has_method("get_active_enemies"):
		enemies = wave_spawner.get_active_enemies()
	else:
		enemies = get_tree().get_nodes_in_group("enemies")

	var mejor: Node3D = null
	var menor_dist: float = INF
	for enemy in enemies:
		if not is_instance_valid(enemy) or not (enemy is Node3D) or not enemy.is_inside_tree():
			continue
		if not _es_lonko_en_pilar_completo(enemy):
			continue
		if enemy.get("current_state") != null:
			var st = enemy.current_state
			if str(st) in ["DYING", "DEAD", "MUERTO"]:
				continue
			if enemy is EnemyBase and (st == EnemyBase.State.DYING or st == EnemyBase.State.DEAD):
				continue
		if enemy.get("is_dead") == true or enemy.get("is_dying") == true:
			continue
		# Solo enemigos delante (a la derecha de la arquera)
		if enemy.global_position.x <= global_position.x:
			continue
		var dist: float = absf(enemy.global_position.x - global_position.x)
		if dist < menor_dist:
			menor_dist = dist
			mejor = enemy
	return mejor


## Busca el pilar activo de Lonko más cercano frente a la defensora.
func _obtener_pilar_lonko_objetivo() -> Node3D:
	var pilares = get_tree().get_nodes_in_group("escudos")
	var mejor: Node3D = null
	var menor_dist: float = INF
	for pilar in pilares:
		if not is_instance_valid(pilar) or not (pilar is Node3D) or not pilar.is_inside_tree():
			continue
		var es_pilar: bool = (pilar is PilarLonkoBody)
		if not es_pilar:
			if "es_pilar_enemigo" in pilar and pilar.es_pilar_enemigo:
				es_pilar = true
			elif "pilar" in pilar.name.to_lower():
				es_pilar = true
		if not es_pilar:
			continue
		if "vida_pilar" in pilar and pilar.vida_pilar <= 0:
			continue
		if pilar.global_position.x <= global_position.x:
			continue
		var dist: float = absf(pilar.global_position.x - global_position.x)
		if dist < menor_dist:
			menor_dist = dist
			mejor = pilar
	return mejor


## Obtiene los enemigos vivos activos situados frente a la aliada
func _obtener_enemigos_disponibles() -> Array:
	var enemies = []
	var wave_spawner = _get_cached_wave_spawner()
	if wave_spawner and wave_spawner.has_method("get_active_enemies"):
		enemies = wave_spawner.get_active_enemies()
	else:
		enemies = get_tree().get_nodes_in_group("enemies")

	var validos: Array = []
	for enemy in enemies:
		if not is_instance_valid(enemy) or not (enemy is Node3D) or not enemy.is_inside_tree():
			continue
		if enemy is Lonko or ("lonko" in enemy.name.to_lower()):
			if not _es_lonko_en_pilar_completo(enemy):
				continue
		if enemy.get("current_state") != null:
			var st = enemy.current_state
			if str(st) in ["DYING", "DEAD", "MUERTO"]:
				continue
			if enemy is EnemyBase and (st == EnemyBase.State.DYING or st == EnemyBase.State.DEAD):
				continue
		if enemy.get("is_dead") == true or enemy.get("is_dying") == true:
			continue
		# Solo enemigos delante (a la derecha de la arquera)
		if enemy.global_position.x <= global_position.x:
			continue
		validos.append(enemy)
	return validos


## Sistema de disparo referencia Player: 3 anims TOMAR_FLECHA → IDLE_APUNTANDO → SOLTAR_FLECHA
## Prioridades Arquera — Voladores 2, Básicos 0, Elite 0 (Lonko 1 solo sobre pilar), Guardian 0
## 0 = azar, 1 = fija y apunta, 2 = fija inmediata y elimina
func _decidir_disparo_y_objetivo() -> Dictionary:
	# Prioridad 2 - Voladores: Gárgola y Globo aerostático (máxima)
	var gargola := _obtener_gargola_objetivo()
	var globo := _obtener_globo_objetivo()
	var volador: Node3D = null
	if is_instance_valid(gargola) and is_instance_valid(globo):
		var d1: float = absf(gargola.global_position.x - global_position.x)
		var d2: float = absf(globo.global_position.x - global_position.x)
		volador = gargola if d1 < d2 else globo
	elif is_instance_valid(gargola):
		volador = gargola
	elif is_instance_valid(globo):
		volador = globo
	if is_instance_valid(volador):
		# Prioridad 2: reservar flechas explosivas para voladores
		if flechas_explosivas > 0:
			return { "target": volador, "type": TipoDisparoAliada.EXPLOSIVO }
		return { "target": volador, "type": TipoDisparoAliada.NORMAL }

	# Prioridad 1 - Elite excepción: Arquera lonko solo cuando está sobre pilar completo
	var lonko := _obtener_lonko_objetivo()
	if is_instance_valid(lonko):
		# Reservar flechas explosivas para la arquera Lonko emergida
		if flechas_explosivas > 0:
			return { "target": lonko, "type": TipoDisparoAliada.EXPLOSIVO }
		return { "target": lonko, "type": TipoDisparoAliada.NORMAL }

	# Prioridad 0 - Básicos, Elite sin condición y Guardian: disparo al azar en rango
	if flechas_multiples > 0:
		return { "target": null, "type": TipoDisparoAliada.MULTIPLE }
	if flechas_explosivas > 0:
		return { "target": null, "type": TipoDisparoAliada.EXPLOSIVO }
	return { "target": null, "type": TipoDisparoAliada.NORMAL }


func _obtener_objetivo_actual() -> Node3D:
	var decision := _decidir_disparo_y_objetivo()
	return decision.get("target", null)


# ═══════════════════════════════════════════════════════════════════════════════
# DISPARO (siempre hacia la derecha)
# ═══════════════════════════════════════════════════════════════════════════════


## Almacena flechas múltiples sin resetear las explosivas en reserva
func agregar_flechas_multiples(cantidad: int = 3) -> void:
	flechas_multiples += cantidad


## Almacena flechas explosivas sin resetear las múltiples en reserva
func agregar_flechas_explosivas(cantidad: int = 5) -> void:
	flechas_explosivas += cantidad


func _disparar():
	if not arrow_scene:
		return

	var decision := _decidir_disparo_y_objetivo()
	var objetivo: Node3D = decision.get("target", null)
	var tipo: TipoDisparoAliada = decision.get("type", TipoDisparoAliada.NORMAL)

	var es_flecha_multiple: bool = (tipo == TipoDisparoAliada.MULTIPLE)
	var es_explosiva: bool = (tipo == TipoDisparoAliada.EXPLOSIVO)

	if es_flecha_multiple:
		flechas_multiples = max(0, flechas_multiples - 1)
	elif es_explosiva:
		flechas_explosivas = max(0, flechas_explosivas - 1)

	AudioManager.play_sfx("player_shoot", -6.0)

	# 2. Posición de spawn según el nodo visual activo
	var spawn_pos = global_position + Vector3(0, altura_spawn_flecha, 0)
	if es_explosiva and explosive_arrow_node and is_instance_valid(explosive_arrow_node):
		spawn_pos = explosive_arrow_node.global_position
	elif arrow_node and is_instance_valid(arrow_node):
		spawn_pos = arrow_node.global_position

	# 3. Potencia proporcional al tiempo de apuntado (normalizado contra el máximo configurable)
	var power_ratio: float = 1.0
	if tiempo_apuntado_max > 0.0 and charge_duration > 0.0:
		power_ratio = clamp(charge_duration / tiempo_apuntado_max, 0.0, 1.0)
	var speed = lerp(potencia_minima, potencia_maxima, power_ratio)

	var direction: Vector3
	if objetivo:
		if objetivo is Gargola or objetivo is GloboAerostatico:
			# Más fuerza contra enemigos voladores: trayectoria más plana y directa
			speed *= multiplicador_potencia_volador
		elif objetivo is Lonko or ("lonko" in objetivo.name.to_lower()):
			speed = maxf(speed * 1.35, potencia_maxima * 1.2)
		elif objetivo is PilarLonkoBody or ("es_pilar_enemigo" in objetivo and objetivo.es_pilar_enemigo):
			speed = maxf(speed, potencia_maxima)

		var target_offset: Vector3 = Vector3(0, 0.3, 0)
		if objetivo is PilarLonkoBody or ("es_pilar_enemigo" in objetivo and objetivo.es_pilar_enemigo):
			target_offset = Vector3(0, 1.2, 0)
		elif objetivo is Lonko or ("lonko" in objetivo.name.to_lower()):
			target_offset = Vector3(0, 0.6, 0)
		elif objetivo is GloboAerostatico:
			# Canasto/arquera del globo: centro de su cápsula de colisión
			target_offset = Vector3(0, 0.6, 0)

		var objetivo_pos: Vector3 = objetivo.global_position + target_offset
		var gravedad: float = ProjectSettings.get_setting("physics/3d/default_gravity")
		var vel_objetivo: Vector3 = Vector3.ZERO
		var v_obj = objetivo.get("velocity")
		if v_obj is Vector3:
			vel_objetivo = Vector3(v_obj.x, 0.0, 0.0)

		# 3 pasadas: estimar tiempo de vuelo → predecir posición futura → recomputar
		var punto_apuntado: Vector3 = objetivo_pos
		var tiempo_vuelo: float = 0.0
		for _i in range(3):
			var delta_pos: Vector3 = punto_apuntado - spawn_pos
			var distancia: float = delta_pos.length()
			tiempo_vuelo = distancia / maxf(speed, 0.1)
			punto_apuntado = objetivo_pos + vel_objetivo * tiempo_vuelo

		var delta_final: Vector3 = punto_apuntado - spawn_pos
		var dist_final: float = maxf(delta_final.length(), 0.1)
		direction = delta_final.normalized()
		direction.y += 0.5 * gravedad * tiempo_vuelo * tiempo_vuelo / dist_final
		# Dispersión mínima natural
		direction.y += randf_range(-0.015, 0.015)
		direction.x += randf_range(-0.01, 0.01)
		direction = direction.normalized()
	else:
		# Sin objetivo específico: arco a ciego hacia la derecha
		var angulo = deg_to_rad(randf_range(angulo_disparo_min, angulo_disparo_max))
		direction = Vector3(cos(angulo), sin(angulo), 0).normalized()

	# 4. CASO MÚLTIPLE: Ráfaga de 5 flechas normales
	if es_flecha_multiple:
		_disparar_rafaga_aliada(direction, speed, spawn_pos)
		return

	# 5. CASO ESTÁNDAR / EXPLOSIVA:
	var arrow: Node = null
	if es_explosiva and explosive_arrow_scene:
		arrow = explosive_arrow_scene.instantiate()
	else:
		arrow = arrow_scene.instantiate()

	if "es_explosiva" in arrow:
		arrow.es_explosiva = es_explosiva

	arrow.initialize(direction, speed)
	get_tree().root.add_child(arrow)
	arrow.global_position = spawn_pos


func _disparar_rafaga_aliada(base_direction: Vector3, speed: float, spawn_pos: Vector3) -> void:
	var arrow_1: Node = arrow_scene.instantiate()
	arrow_1.initialize(base_direction, speed)
	get_tree().root.add_child(arrow_1)
	arrow_1.global_position = spawn_pos

	for i in range(4):
		await get_tree().create_timer(0.06, false).timeout
		if not is_instance_valid(self) or not is_inside_tree():
			return

		var arr: Node = arrow_scene.instantiate()
		var dir := base_direction + Vector3(randf_range(-0.02, 0.02), randf_range(-0.02, 0.02), 0.0)
		arr.initialize(dir.normalized(), speed)
		get_tree().root.add_child(arr)
		arr.global_position = spawn_pos
		AudioManager.play_sfx("player_shoot", -8.0)


# ═══════════════════════════════════════════════════════════════════════════════
# FLECHA VISUAL
# ═══════════════════════════════════════════════════════════════════════════════


func _mostrar_flecha():
	var decision := _decidir_disparo_y_objetivo()
	var tipo: TipoDisparoAliada = decision.get("type", TipoDisparoAliada.NORMAL)
	var es_explosiva: bool = (tipo == TipoDisparoAliada.EXPLOSIVO)

	if es_explosiva and explosive_arrow_node and is_instance_valid(explosive_arrow_node):
		if arrow_node and is_instance_valid(arrow_node):
			arrow_node.visible = false
		explosive_arrow_node.visible = true
	else:
		if explosive_arrow_node and is_instance_valid(explosive_arrow_node):
			explosive_arrow_node.visible = false
		if arrow_node and is_instance_valid(arrow_node):
			arrow_node.visible = true


func _ocultar_flecha():
	if arrow_node and is_instance_valid(arrow_node):
		arrow_node.visible = false
	if explosive_arrow_node and is_instance_valid(explosive_arrow_node):
		explosive_arrow_node.visible = false


# ═══════════════════════════════════════════════════════════════════════════════
# DAÑO Y MUERTE
# ═══════════════════════════════════════════════════════════════════════════════

var last_hit_position: Vector3 = Vector3.ZERO
var last_hit_direction: Vector3 = Vector3.LEFT


func take_damage(amount: float):
	if current_state == State.DYING or current_state == State.DEAD or current_state == State.GETTING_UP:
		return

	health -= int(amount)

	# Reproducir animación de daño si sigue vivo (la sangre solo sale al morir)
	if health > 0:
		var dano_anim = ["DAÑO_01", "DAÑO_02"][randi() % 2]
		_play_anim([dano_anim, "DAÑO_01", "DAÑO_02", "DAÑO_HIT", "DAÑO"], 0.05)
		AudioManager.play_sfx("player_hurt")
		# Volver al estado anterior tras la animación de daño
		var dur = _get_anim_length(dano_anim)
		get_tree().create_timer(dur).timeout.connect(
			func():
				if (
					is_instance_valid(self)
					and current_state != State.DYING
					and current_state != State.DEAD
				):
					_cambiar_estado(current_state)
		)

	if health <= 0:
		_cambiar_estado(State.DYING)


func recibir_dano(amount: int):
	take_damage(float(amount))


func curar(cantidad: int = 1) -> void:
	if current_state == State.DYING or current_state == State.DEAD:
		return
	health = min(health + cantidad, vida_maxima)


func revivir() -> void:
	if current_state != State.DEAD and current_state != State.DYING:
		return

	health = vida_maxima
	set_process(true)
	if hitbox_body:
		hitbox_body.collision_layer = 2

	_cambiar_estado(State.GETTING_UP)


## Muestra un diálogo en el globo de este personaje
func decir(clave_o_texto: String, duracion: float = -1.0) -> void:
	# No mostrar diálogos si la defensora no está activa (oculta/modo pacífico) o está muerta
	if not visible or current_state == State.DYING or current_state == State.DEAD or health <= 0:
		return
	if not speech_bubble or not is_instance_valid(speech_bubble):
		speech_bubble = get_node_or_null("SpeechBubbleComponent")
	if speech_bubble and is_instance_valid(speech_bubble):
		speech_bubble.decir(clave_o_texto, duracion)


## Retorna true si la arquera está mostrando un diálogo
func esta_hablando() -> bool:
	if not speech_bubble or not is_instance_valid(speech_bubble):
		return false
	return speech_bubble.esta_hablando()


func _crear_splash_sangre() -> void:
	var blood_scene: PackedScene = preload("res://VFX/Scenes/BloodSplashNormal.tscn")
	if not blood_scene:
		return
	var splash = blood_scene.instantiate() as BloodSplash2D
	if not splash:
		return

	var root := get_tree().current_scene
	if root:
		root.add_child(splash)
	elif get_parent():
		get_parent().add_child(splash)

	var spawn_pos := last_hit_position if not last_hit_position.is_zero_approx() else (global_position + Vector3(0.0, 0.8, 0.0))
	# Invertir dirección: el proyectil impacta viniendo de la derecha hacia la izquierda (-X)
	var dir := last_hit_direction if not last_hit_direction.is_zero_approx() else Vector3.LEFT
	splash.setup(spawn_pos, dir, Color.WHITE)


func _on_dying():
	set_process(false)
	_ocultar_flecha()
	_crear_splash_sangre()

	# Desactivar hitbox
	if hitbox_body:
		hitbox_body.collision_layer = 0

	# Sonido de muerte
	AudioManager.play_sfx("player_death")

	# Reproducir muerte (elegir aleatoriamente entre MUERTE_01 y MUERTE_02)
	var death_anim = ["MUERTE_01", "MUERTE_02"][randi() % 2]
	ultima_muerte_anim = death_anim
	_play_anim(death_anim)
	_play_bow_anim("ARCO_IDLE")

	var dur = _get_anim_length(death_anim)
	get_tree().create_timer(dur + 0.5).timeout.connect(
		func():
			if is_instance_valid(self) and current_state == State.DYING:
				_cambiar_estado(State.DEAD)
	)


func _start_dissolve():
	if is_dissolving:
		return
	is_dissolving = true

	var meshes = find_children("*", "MeshInstance3D", true, false)
	for mesh in meshes:
		if not is_instance_valid(mesh):
			continue
		var mat = ShaderMaterial.new()
		mat.shader = dissolve_shader
		mat.set_shader_parameter("dissolve_amount", 0.0)
		mat.set_shader_parameter("glow_color", Color(0.2, 0.6, 1.0))
		mat.set_shader_parameter("glow_intensity", 3.0)
		mat.set_shader_parameter("edge_thickness", 0.05)
		mat.set_shader_parameter("noise_scale", 20.0)

		var orig = mesh.material_override
		if orig == null and mesh.mesh:
			orig = mesh.mesh.surface_get_material(0)
		if orig and orig is StandardMaterial3D:
			var tex = orig.albedo_texture
			if tex:
				mat.set_shader_parameter("albedo_texture", tex)
			var col = orig.albedo_color
			mat.set_shader_parameter("albedo_tint", Vector3(col.r, col.g, col.b))

		mesh.material_override = mat
		dissolve_materials.append({"mesh": mesh, "material": mat})

	var tween = create_tween()
	tween.tween_method(_update_dissolve, 0.0, 1.0, 1.0)
	tween.tween_callback(_finish_dissolve)


func _update_dissolve(value: float):
	for item in dissolve_materials:
		if is_instance_valid(item["mesh"]):
			item["material"].set_shader_parameter("dissolve_amount", value)


func _finish_dissolve():
	for mesh in find_children("*", "MeshInstance3D", true, false):
		if is_instance_valid(mesh):
			mesh.material_override = null
			mesh.visible = false
	dissolve_materials.clear()
	current_state = State.DEAD
	queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# ANIMACIÓN
# ═══════════════════════════════════════════════════════════════════════════════


func _play_anim(anim_target, blend: float = -1.0, speed: float = 1.0) -> void:
	if not anim_player:
		return
	anim_player.active = true

	var candidates: Array = []
	if anim_target is Array:
		candidates = anim_target
	else:
		candidates = [str(anim_target)]

	var all_anims: PackedStringArray = anim_player.get_animation_list()

	# PASO 1: Búsqueda exacta primero (evita que 'IDE' coincida con 'IDLE_APUNTANDO')
	for cand in candidates:
		var cand_str: String = str(cand).strip_edges().to_lower()
		for a in all_anims:
			var a_str: String = a.to_lower()
			var a_base: String = a_str.get_file() if "/" in a_str else a_str
			if a_str == cand_str or a_base == cand_str:
				if anim_player.current_animation == a and anim_player.is_playing():
					anim_player.speed_scale = speed
					return
				anim_player.play(a, blend, speed)
				anim_player.speed_scale = speed
				return

	# PASO 2: Búsqueda por prefijo / sufijo / substring
	for cand in candidates:
		var cand_str: String = str(cand).strip_edges().to_lower()
		for a in all_anims:
			var a_str: String = a.to_lower()
			var a_base: String = a_str.get_file() if "/" in a_str else a_str
			if a_str.ends_with("/" + cand_str) or cand_str in a_base or cand_str in a_str:
				if anim_player.current_animation == a and anim_player.is_playing():
					anim_player.speed_scale = speed
					return
				anim_player.play(a, blend, speed)
				anim_player.speed_scale = speed
				return


func _play_bow_anim(_anim_name: String, _blend: float = -1.0, _speed: float = 1.0) -> void:
	# Animación del arco desactivada
	pass


func _get_bow_anim_length(anim_name: String) -> float:
	if not bow_anim_player:
		return 1.0
	var all_anims = bow_anim_player.get_animation_list()
	var target_lower = anim_name.to_lower()
	for a in all_anims:
		var a_lower = a.to_lower()
		if a_lower == target_lower or a_lower.ends_with("|" + target_lower) or a_lower.ends_with("/" + target_lower) or target_lower in a_lower:
			var anim = bow_anim_player.get_animation(a)
			if anim:
				return anim.length
	return 1.0


func _get_anim_length(anim_target) -> float:
	if not anim_player:
		return 3.5
	var candidates: Array = []
	if anim_target is Array:
		candidates = anim_target
	else:
		candidates = [str(anim_target)]
	var all_anims := anim_player.get_animation_list()

	# Paso 1: Coincidencia exacta
	for cand in candidates:
		var cand_lower := str(cand).strip_edges().to_lower()
		for a in all_anims:
			var a_lower := a.to_lower()
			var a_base := a_lower.get_file() if "/" in a_lower else a_lower
			if a_lower == cand_lower or a_base == cand_lower:
				var anim := anim_player.get_animation(a)
				if anim:
					return anim.length

	# Paso 2: Coincidencia parcial
	for cand in candidates:
		var cand_lower := str(cand).strip_edges().to_lower()
		for a in all_anims:
			var a_lower := a.to_lower()
			var a_base := a_lower.get_file() if "/" in a_lower else a_lower
			if a_lower.ends_with("/" + cand_lower) or cand_lower in a_base or cand_lower in a_lower:
				var anim := anim_player.get_animation(a)
				if anim:
					return anim.length
	return 3.5


func _log_debug(parts: Array) -> void:
	if not debug_logs_enabled:
		return

	var message := ""
	for part in parts:
		message += str(part)
	print(message)


func _exit_tree():
	active_allies_cache.erase(self)
