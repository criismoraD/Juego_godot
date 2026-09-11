class_name DefensoraPerrena
extends Node3D

## Defensora Aliada Perrena: defensora especial invocada por el ítem de refuerzo.
## - Vida: 3 HP.
## - Ataque: arroja hachas rotatorias parabólicas (HachaPerrena) usando la animación "arrojar".
## - Prioridades de Objetivo:
##     * Prioridad 2 (Máxima): Escudos del escenario (es_escudo_enemigo) y Clase Guardián (Imp escudo, Guardiana moradita).
##     * Prioridad 1: Enemigos de Élite (Lonko, Arquera Rosa).
##     * Prioridad 0: Resto de enemigos (Básicos, voladores, etc.).
## - Habilidad Especial:
##     * Ocurre cada 6 ataques.
##     * Realiza su animación "Celebracion" con un aura mágica protectora activa.
##     * Mientras celebra es completamente INMUNE a daño.
##     * A continuación dispara 5 hachas al azar hacia el frente enemigo.

signal ataque_lanzado(contador: int)
signal habilidad_ejecutada
signal vida_cambiada(nueva_vida: int)
signal murio
signal impacto_registrado(contador: int)
signal fase_ascenso_iniciada

enum State { DEPLOYING, IDLE, ATTACKING, CELEBRATING, DYING, DEAD }

const HACHA_SCENE: PackedScene = preload("res://Entities/Proyectil_Hacha_Perrena/HachaPerrena.tscn")
const MAT_PERRENA: Material = preload("res://Entities/Jugador_Perrena/PERRENA_MAT.tres")
const MAT_HACHA: Material = preload("res://Entities/Proyectil_Hacha_Perrena/HACHA_PERRENA_MAT.tres")
const SFX_CELEBRACION: String = "res://TEST_/Guaf perrena exit menu.wav"
const SFX_SWOOSH_HACHA: String = "res://TEST_/Tensado de flecha explosiva.wav"
const DISSOLVE_SHADER: Shader = preload("res://System/Shaders/dissolve.gdshader")
const IMPACTOS_REQUERIDOS_PARA_SUBIR: int = 6
const ATAQUES_PARA_ESPECIAL: int = 7  ## El ataque especial se ejecuta al 7mo ataque lanzado
const TEXTURA_HUMO_PISADAS: Texture2D = preload("res://VFX/Textures/Smoke/Humo_Pisadas_1A-1.png")
const HUMO_PISADAS_FRAMES_H: int = 9
const HUMO_PISADAS_FRAMES_V: int = 1

@export_category("Estadísticas")
@export var vida_maxima: int = 3
@export var health: int = 3
@export var es_inmune: bool = false

@export_category("Despliegue y Movimiento")
@export var auto_desplegar: bool = false
@export var velocidad_caminar: float = 1.6  ## Velocidad reducida para trote natural
@export var velocidad_escaleras: float = 0.85  ## Velocidad reducida para trepar escaleras
var en_despliegue: bool = false
var en_fase_escudo_suelo: bool = false
var impactos_fase_suelo: int = 0
var _iniciando_ascenso: bool = false
var impactos_para_especial: int = 0
var especial_cargado: bool = false

@export_category("Cadencia de Ataque")
@export var tiempo_espera_ataque_min: float = 1.4
@export var tiempo_espera_ataque_max: float = 2.2
@export var rango_deteccion_max_x: float = 24.0

var current_state: State = State.IDLE
var contador_ataques: int = 0
var hitbox_body: StaticBody3D = null
var anim_player: AnimationPlayer = null
var aura_vfx: Node3D = null
var hacha_mano: Node3D = null
var model_root: Node3D = null
var armature_node: Node3D = null
var armature_original_rotation: Vector3 = Vector3.ZERO
var punto_spawn_hacha: Marker3D = null

var _particulas_pisada: GPUParticles3D = null
var _malla_humo_der: QuadMesh = null
var _malla_humo_izq: QuadMesh = null
var _prev_pos_x: float = 0.0

var _tiempo_para_proximo_ataque: float = 1.0
var _tiempo_en_estado: float = 0.0
var _hacha_arrojada_en_ciclo: bool = false
var _objetivo_actual: Node = null


func _ready() -> void:
	add_to_group("allies")
	add_to_group("defensoras")

	# Paridad visual con su modelo jugable: escala 0.3 a nivel de raíz
	scale = Vector3(0.3, 0.3, 0.3)

	health = vida_maxima
	_setup_nodos_y_modelo()
	_setup_hitbox()
	_setup_aura()
	_setup_hacha_mano()
	_configurar_particulas_pisada()
	_prev_pos_x = global_position.x

	if auto_desplegar:
		desplegar_hacia_primer_escudo()
	else:
		_cambiar_estado(State.IDLE)


func _setup_nodos_y_modelo() -> void:
	model_root = find_child("PerrenaModel", true, false) as Node3D
	if not model_root:
		model_root = find_child("Perrena", true, false) as Node3D
	if model_root:
		model_root.scale = Vector3(6.0, 6.0, 6.0)
		for mesh in model_root.find_children("*", "MeshInstance3D", true, false):
			if mesh is MeshInstance3D:
				(mesh as MeshInstance3D).material_override = MAT_PERRENA

	armature_node = find_child("Armature", true, false) as Node3D
	if not armature_node:
		armature_node = model_root
	if armature_node:
		armature_original_rotation = armature_node.rotation

	anim_player = _resolver_animation_player()
	_configurar_loops_animaciones()


func _configurar_loops_animaciones() -> void:
	if not anim_player:
		return
	for anim_name in ["Correr", "Caminar", "Escaleras", "Idle", "Idle agachada", "Baile"]:
		if anim_player.has_animation(anim_name):
			var a := anim_player.get_animation(anim_name)
			if a:
				a.loop_mode = Animation.LOOP_LINEAR



func _resolver_animation_player() -> AnimationPlayer:
	# Resolver el AnimationPlayer corporal de Perrena
	var players = find_children("*", "AnimationPlayer", true, false)
	for p in players:
		if p is AnimationPlayer and (p.has_animation("arrojar") or p.has_animation("Correr")):
			return p as AnimationPlayer
	for p in players:
		if p is AnimationPlayer and p.has_animation("Idle"):
			return p as AnimationPlayer
	return null


func _setup_hitbox() -> void:
	hitbox_body = StaticBody3D.new()
	hitbox_body.name = "HitboxBody"
	hitbox_body.add_to_group("allies")
	hitbox_body.set_meta("defensora_owner", self)
	hitbox_body.collision_layer = 2  # Capa 2 defensora
	hitbox_body.collision_mask = 0

	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	# Escalado proporcional al padre (0.3) para medir 0.35m radio y 1.7m alto en el mundo
	shape.radius = 1.16
	shape.height = 5.66
	col.shape = shape
	col.position = Vector3(0.0, 2.83, 0.0)
	hitbox_body.add_child(col)
	add_child(hitbox_body)


func _setup_aura() -> void:
	aura_vfx = find_child("BasicAreaVFX_04", true, false) as Node3D
	if not aura_vfx:
		var aura_scene := preload("res://assets/BinbunVFX/magic_areas/effects/basic_area/basic_area_vfx_04.tscn")
		if aura_scene:
			aura_vfx = aura_scene.instantiate() as Node3D
			add_child(aura_vfx)
			aura_vfx.position = Vector3(0.0, 0.02, 0.0)
			aura_vfx.scale = Vector3(2.167, 2.167, 2.167)
			aura_vfx.set("primary_color", Color(1.0, 0.35, 0.8, 1.0))
			aura_vfx.set("secondary_color", Color(0.9, 0.15, 0.65, 1.0))
			aura_vfx.set("light_color", Color(1.0, 0.5, 0.85, 1.0))
	else:
		aura_vfx.scale = Vector3(2.167, 2.167, 2.167)

	if aura_vfx:
		aura_vfx.visible = false
		var aura_anim := aura_vfx.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if aura_anim and aura_anim.has_animation("main"):
			aura_anim.play("main")


func _setup_hacha_mano() -> void:
	var skel := find_child("Skeleton3D", true, false) as Skeleton3D
	if not skel:
		return

	var idx_mano: int = skel.find_bone("mixamorig_RightHand")
	if idx_mano != -1:
		var attach := BoneAttachment3D.new()
		attach.name = "BoneAttach_HachaMano"
		attach.bone_name = "mixamorig_RightHand"
		skel.add_child(attach)

		var hacha_model_scene := load("res://TEST_/Hacha perrena/Hacha perrena.glb") as PackedScene
		if hacha_model_scene:
			hacha_mano = hacha_model_scene.instantiate() as Node3D
			hacha_mano.name = "HachaManoVisual"
			hacha_mano.scale = Vector3(0.08, 0.08, 0.08)
			hacha_mano.rotation_degrees = Vector3(0, 90, 45)
			attach.add_child(hacha_mano)
			for mesh in hacha_mano.find_children("*", "MeshInstance3D", true, false):
				if mesh is MeshInstance3D:
					(mesh as MeshInstance3D).material_override = MAT_HACHA
			hacha_mano.visible = false

	punto_spawn_hacha = Marker3D.new()
	punto_spawn_hacha.name = "PuntoSpawnHacha"
	punto_spawn_hacha.position = Vector3(0.8, 3.8, 0.0)
	add_child(punto_spawn_hacha)


func _orientar_modelo_derecha() -> void:
	if armature_node:
		armature_node.rotation.y = armature_original_rotation.y


func _orientar_modelo_izquierda() -> void:
	if armature_node:
		armature_node.rotation.y = armature_original_rotation.y + PI


func _orientar_modelo_escalera() -> void:
	if armature_node:
		armature_node.rotation.y = armature_original_rotation.y - PI / 2.0


func _configurar_particulas_pisada() -> void:
	if _particulas_pisada and is_instance_valid(_particulas_pisada):
		return
	_particulas_pisada = GPUParticles3D.new()
	_particulas_pisada.name = "Particulas_Pisada"
	_particulas_pisada.emitting = false
	_particulas_pisada.amount = 22
	_particulas_pisada.lifetime = 0.7
	_particulas_pisada.visibility_aabb = AABB(Vector3(-2, -0.5, -2), Vector3(4, 3, 4))
	add_child(_particulas_pisada)
	_particulas_pisada.position = Vector3(-0.15, 0.05, 0.0)

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
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 2

	_malla_humo_der = QuadMesh.new()
	_malla_humo_der.material = mat
	_malla_humo_der.size = Vector2(0.85, 0.85)
	_malla_humo_izq = QuadMesh.new()
	_malla_humo_izq.material = mat
	_malla_humo_izq.size = Vector2(-0.85, 0.85)
	_particulas_pisada.draw_pass_1 = _malla_humo_der

	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(-1.0, 0.45, 0.0).normalized()
	pm.spread = 55.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 0.95
	pm.gravity = Vector3(0.0, 0.35, 0.0)
	pm.scale_min = 0.8
	pm.scale_max = 1.5
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.12, 0.02, 0.12)
	pm.anim_speed_min = 1.0
	pm.anim_speed_max = 1.0
	pm.anim_offset_min = 0.0
	pm.anim_offset_max = 1.0

	var grad := Gradient.new()
	grad.set_color(0, Color(0.72, 0.72, 0.72, 0.85))
	grad.set_color(1, Color(0.72, 0.72, 0.72, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	pm.color_ramp = grad_tex

	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.3), 0.0, 1.5)
	curve.add_point(Vector2(0.35, 1.0), 0.2, -0.3)
	curve.add_point(Vector2(0.7, 0.7), -0.5, -0.8)
	curve.add_point(Vector2(1.0, 0.0), -1.2, 0.0)
	var curve_tex := CurveTexture.new()
	curve_tex.curve = curve
	pm.scale_curve = curve_tex

	_particulas_pisada.process_material = pm


func _particulas_pisada_emitir() -> void:
	if not _particulas_pisada or not is_instance_valid(_particulas_pisada):
		return

	var delta_x: float = global_position.x - _prev_pos_x
	_prev_pos_x = global_position.x

	var anim_actual: String = anim_player.current_animation.to_upper() if anim_player else ""
	var es_escalera: bool = anim_actual.contains("ESCALERA") or anim_actual.contains("ESCALAR")
	var corriendo: bool = (anim_actual.contains("CORRER") or absf(delta_x) > 0.005) and not es_escalera and en_despliegue
	var viva_y_activa: bool = (current_state != State.DYING and current_state != State.DEAD and current_state != State.CELEBRATING)

	var debe_emitir: bool = corriendo and viva_y_activa
	_particulas_pisada.emitting = debe_emitir

	if debe_emitir:
		var mirando_derecha: bool = delta_x >= 0.0
		var malla_humo: QuadMesh = _malla_humo_der if mirando_derecha else _malla_humo_izq
		if malla_humo and _particulas_pisada.draw_pass_1 != malla_humo:
			_particulas_pisada.draw_pass_1 = malla_humo

		var pm: ParticleProcessMaterial = _particulas_pisada.process_material as ParticleProcessMaterial
		if pm:
			if mirando_derecha:
				pm.direction = Vector3(-1.0, 0.45, 0.0).normalized()
				_particulas_pisada.position = Vector3(-0.15, 0.05, 0.0)
			else:
				pm.direction = Vector3(1.0, 0.45, 0.0).normalized()
				_particulas_pisada.position = Vector3(0.15, 0.05, 0.0)



func _play_anim(anim_target: Variant, blend: float = 0.15, speed: float = 1.0) -> void:
	if not anim_player:
		return
	var lista: Array = []
	if anim_target is Array:
		lista = anim_target
	elif anim_target is String:
		lista = [anim_target]

	for a in lista:
		var a_str: String = str(a)
		if anim_player.has_animation(a_str):
			if anim_player.current_animation != a_str or not anim_player.is_playing():
				anim_player.play(a_str, blend, speed)
			return


## Fase 1 de despliegue:
## Llega corriendo desde la puerta baja mirando hacia adelante (+X),
## se posiciona detrás del primer escudo (EscudoDestruible6) y los pinchos,
## y entra en guardia defensiva hasta impactar a 6 objetivos (enemigos, escudos o pilares).
func desplegar_hacia_primer_escudo(start_override_x: float = NAN) -> void:
	_cambiar_estado(State.DEPLOYING)
	en_despliegue = true
	en_fase_escudo_suelo = false
	impactos_fase_suelo = 0
	_iniciando_ascenso = false
	scale = Vector3(0.3, 0.3, 0.3)

	var floor_y: float = 0.185
	var start_x: float = -11.5

	if not is_nan(start_override_x):
		start_x = start_override_x
	else:
		var root_scene := get_tree().current_scene if get_tree() else null
		if root_scene:
			var puerta := root_scene.find_child("PUERTA_TRIGER", true, false) as Node3D
			if puerta and is_instance_valid(puerta):
				start_x = puerta.global_position.x - 2.0

	var primer_escudo_x: float = -6.8
	if get_tree():
		var escudos := get_tree().get_nodes_in_group("escudos")
		var escudo_suelo: Node3D = null
		var menor_y: float = 999.0
		for esc in escudos:
			if is_instance_valid(esc) and esc is Node3D:
				var ey: float = (esc as Node3D).global_position.y
				if ey < 1.0 and ey < menor_y:
					menor_y = ey
					escudo_suelo = esc as Node3D
		if escudo_suelo:
			primer_escudo_x = escudo_suelo.global_position.x - 0.28

	# Iniciar en el suelo
	global_position = Vector3(start_x, floor_y, 0.0)

	var walk_speed: float = 2.8

	# Correr mirando hacia adelante (+X)
	_orientar_modelo_derecha()
	_play_anim(["Correr", "Caminar", "Armature|Armature|CORRER_ADELANTE", "CORRER"], 0.15, 1.0)
	var tw := create_tween()
	var dist: float = absf(primer_escudo_x - global_position.x)
	tw.tween_property(self, "global_position:x", primer_escudo_x, dist / walk_speed)
	await tw.finished
	if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
		return

	# Detenerse detrás del escudo y los pinchos en guardia defensiva
	en_despliegue = false
	en_fase_escudo_suelo = true
	_orientar_modelo_derecha()
	_play_anim(["Idle", "IDLE", "Armature|Armature|IDLE"], 0.2, 1.0)
	_cambiar_estado(State.IDLE)


## Fase 2 de despliegue:
## Tras conseguir los 6 impactos requeridos en el suelo, Perrena corre hacia la izquierda
## a la Escalera 1, trepa por las plataformas hasta el último piso y se posiciona junto al escudo superior.
func iniciar_ascenso_a_ultimo_piso() -> void:
	if current_state == State.DYING or current_state == State.DEAD:
		return

	en_fase_escudo_suelo = false
	_iniciando_ascenso = false
	_cambiar_estado(State.DEPLOYING)
	en_despliegue = true
	fase_ascenso_iniciada.emit()

	var p1_ladder_x: float = -7.58
	var p1_top_y: float = 1.585
	var p2_ladder_x: float = -8.33
	var p2_top_y: float = 3.143
	var p3_ladder_x: float = -9.11
	var p3_top_y: float = 4.58
	var p3_escudo_x: float = -8.80

	if get_tree():
		for esc in get_tree().get_nodes_in_group("escudos"):
			if is_instance_valid(esc) and esc is Node3D:
				var e3d := esc as Node3D
				if e3d.global_position.y > 4.0:
					p3_escudo_x = e3d.global_position.x - 0.65
					break

	var walk_speed: float = 2.8
	var climb_speed: float = 1.5

	# 1. Correr hacia la izquierda (-X) para alcanzar la Escalera 1
	_orientar_modelo_izquierda()
	_play_anim(["Correr", "Caminar", "Armature|Armature|CORRER_ADELANTE", "CORRER"], 0.15, 1.0)
	var tw1 := create_tween()
	var dist1: float = absf(p1_ladder_x - global_position.x)
	tw1.tween_property(self, "global_position:x", p1_ladder_x, dist1 / walk_speed)
	await tw1.finished
	if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
		return

	# 2. Subir Escalera 1 hasta Plataforma 1 (orientada a la pared)
	_orientar_modelo_escalera()
	_play_anim(["Escaleras", "SUBIR_ESCALERAS", "SUBIR_ESCALERA", "ESCALAR"], 0.15, 1.0)
	var tw_climb1 := create_tween()
	var climb_dist1: float = absf(p1_top_y - global_position.y)
	tw_climb1.tween_property(self, "global_position:y", p1_top_y, climb_dist1 / climb_speed)
	await tw_climb1.finished
	if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
		return

	_play_anim(["Aterrizar", "ATERRIZAJE", "Idle"], 0.15, 1.0)
	await get_tree().create_timer(0.12).timeout
	if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
		return

	# 3. Caminar por Plataforma 1 hacia Escalera 2 (hacia la izquierda)
	_orientar_modelo_izquierda()
	_play_anim(["Correr", "Caminar", "Armature|Armature|CORRER_ADELANTE", "CORRER"], 0.15, 1.0)
	var tw2 := create_tween()
	var dist2: float = absf(p2_ladder_x - global_position.x)
	tw2.tween_property(self, "global_position:x", p2_ladder_x, dist2 / walk_speed)
	await tw2.finished
	if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
		return

	# 4. Subir Escalera 2 hasta Plataforma 2
	_orientar_modelo_escalera()
	_play_anim(["Escaleras", "SUBIR_ESCALERAS", "SUBIR_ESCALERA", "ESCALAR"], 0.15, 1.0)
	var tw_climb2 := create_tween()
	var climb_dist2: float = absf(p2_top_y - global_position.y)
	tw_climb2.tween_property(self, "global_position:y", p2_top_y, climb_dist2 / climb_speed)
	await tw_climb2.finished
	if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
		return

	_play_anim(["Aterrizar", "ATERRIZAJE", "Idle"], 0.15, 1.0)
	await get_tree().create_timer(0.12).timeout
	if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
		return

	# 5. Caminar por Plataforma 2 hacia Escalera 3 (hacia la izquierda)
	_orientar_modelo_izquierda()
	_play_anim(["Correr", "Caminar", "Armature|Armature|CORRER_ADELANTE", "CORRER"], 0.15, 1.0)
	var tw3 := create_tween()
	var dist3: float = absf(p3_ladder_x - global_position.x)
	tw3.tween_property(self, "global_position:x", p3_ladder_x, dist3 / walk_speed)
	await tw3.finished
	if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
		return

	# 6. Subir Escalera 3 hasta Plataforma 3 (el último piso)
	_orientar_modelo_escalera()
	_play_anim(["Escaleras", "SUBIR_ESCALERAS", "SUBIR_ESCALERA", "ESCALAR"], 0.15, 1.0)
	var tw_climb3 := create_tween()
	var climb_dist3: float = absf(p3_top_y - global_position.y)
	tw_climb3.tween_property(self, "global_position:y", p3_top_y, climb_dist3 / climb_speed)
	await tw_climb3.finished
	if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
		return

	_play_anim(["Aterrizar", "ATERRIZAJE", "Idle"], 0.15, 1.0)
	await get_tree().create_timer(0.12).timeout
	if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
		return

	# 7. Posicionarse en el último piso cerca del escudo (hacia la derecha)
	_orientar_modelo_derecha()
	_play_anim(["Correr", "Caminar", "Armature|Armature|CORRER_ADELANTE", "CORRER"], 0.15, 1.0)
	var tw4 := create_tween()
	var dist4: float = absf(p3_escudo_x - global_position.x)
	tw4.tween_property(self, "global_position:x", p3_escudo_x, dist4 / walk_speed)
	await tw4.finished
	if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
		return

	# Finalizar despliegue: Idle mirando hacia el frente de combate y ladrido alegre
	_finalizar_despliegue()


## Despliega a Perrena directamente hacia el último piso (método directo / compatibilidad)
func desplegar_hacia_ultimo_piso(start_override_x: float = NAN) -> void:
	_cambiar_estado(State.DEPLOYING)
	en_despliegue = true
	en_fase_escudo_suelo = false
	scale = Vector3(0.3, 0.3, 0.3)

	# Coordenadas reales de pisos y escaleras de la torre
	var floor_y: float = 0.185
	var p1_top_y: float = 1.585
	var p2_top_y: float = 3.143
	var p3_top_y: float = 4.58

	var start_x: float = -11.5
	if not is_nan(start_override_x):
		start_x = start_override_x
	else:
		var root_scene := get_tree().current_scene if get_tree() else null
		if root_scene:
			var puerta := root_scene.find_child("PUERTA_TRIGER", true, false) as Node3D
			if puerta and is_instance_valid(puerta):
				start_x = puerta.global_position.x - 2.0

	var p1_ladder_x: float = -7.58
	var p2_ladder_x: float = -8.33
	var p3_ladder_x: float = -9.11
	var p3_escudo_x: float = -8.80

	if get_tree():
		for esc in get_tree().get_nodes_in_group("escudos"):
			if is_instance_valid(esc) and esc is Node3D:
				var e3d := esc as Node3D
				if e3d.global_position.y > 4.0:
					p3_escudo_x = e3d.global_position.x - 0.65
					break

	global_position = Vector3(start_x, floor_y, 0.0)

	var walk_speed: float = 2.8
	var climb_speed: float = 1.5

	# 1. Correr por el suelo hacia la Escalera 1 (mirando a la derecha)
	_orientar_modelo_derecha()
	_play_anim(["Correr", "Caminar", "Armature|Armature|CORRER_ADELANTE", "CORRER"], 0.15, 1.0)
	var tw1 := create_tween()
	var dist1: float = absf(p1_ladder_x - global_position.x)
	tw1.tween_property(self, "global_position:x", p1_ladder_x, dist1 / walk_speed)
	await tw1.finished
	if not is_instance_valid(self) or current_state == State.DYING or current_state == State.DEAD:
		return

	# Continuar con el ascenso
	iniciar_ascenso_a_ultimo_piso()


func _finalizar_despliegue() -> void:
	en_despliegue = false
	_orientar_modelo_derecha()
	_play_anim(["Idle", "IDLE", "Armature|Armature|IDLE"], 0.2, 1.0)
	_reproducir_sfx_celebracion()
	_cambiar_estado(State.IDLE)


func _physics_process(delta: float) -> void:
	if current_state == State.DYING or current_state == State.DEAD:
		return

	_particulas_pisada_emitir()
	_tiempo_en_estado += delta

	match current_state:
		State.DEPLOYING:
			return
		State.IDLE:
			_proceso_idle(delta)
		State.ATTACKING:
			_proceso_atacando(delta)
		State.CELEBRATING:
			_proceso_celebrando(delta)


func _proceso_idle(delta: float) -> void:
	_tiempo_para_proximo_ataque -= delta
	if _tiempo_para_proximo_ataque <= 0.0:
		_intentar_iniciar_ataque()


func _intentar_iniciar_ataque() -> void:
	# El ataque especial / ulti ocurre cada 7 ataques lanzados (independiente de impactos)
	if especial_cargado or contador_ataques >= (ATAQUES_PARA_ESPECIAL - 1):
		_iniciar_habilidad_especial()
		return

	# Buscar objetivo según prioridades requeridas
	_objetivo_actual = _buscar_mejor_objetivo(false)
	if not is_instance_valid(_objetivo_actual):
		# Sin enemigos válidos en pantalla: permanece en IDLE esperando
		_tiempo_para_proximo_ataque = 0.5
		return

	_iniciar_ataque_normal()


func _iniciar_ataque_normal() -> void:
	_cambiar_estado(State.ATTACKING)
	_hacha_arrojada_en_ciclo = false
	if hacha_mano:
		hacha_mano.visible = true

	if anim_player and anim_player.has_animation("arrojar"):
		anim_player.play("arrojar", 0.1, 1.2)
	else:
		_lanzar_hacha_hacia_objetivo(_objetivo_actual)


func _proceso_atacando(_delta: float) -> void:
	# En el instante del lanzamiento dentro de la animación (~0.35s) soltar el proyectil
	if not _hacha_arrojada_en_ciclo and _tiempo_en_estado >= 0.32:
		_hacha_arrojada_en_ciclo = true
		if hacha_mano:
			hacha_mano.visible = false
		_lanzar_hacha_hacia_objetivo(_objetivo_actual)
		contador_ataques += 1
		ataque_lanzado.emit(contador_ataques)

	# Fin de animación arrojar (~0.7s)
	if _tiempo_en_estado >= 0.7:
		_cambiar_estado(State.IDLE)


func _iniciar_habilidad_especial() -> void:
	_cambiar_estado(State.CELEBRATING)
	contador_ataques = 0
	es_inmune = true

	# Activar aura rosada protectora
	if aura_vfx:
		aura_vfx.visible = true
		var aura_anim := aura_vfx.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if aura_anim and aura_anim.has_animation("main"):
			aura_anim.play("main")

	# SFX y animación de celebración
	if anim_player and anim_player.has_animation("Celebracion"):
		anim_player.play("Celebracion", 0.15, 1.0)
	elif anim_player and anim_player.has_animation("Idle"):
		anim_player.play("Idle", 0.15, 1.0)

	_reproducir_sfx_celebracion()


func _proceso_celebrando(_delta: float) -> void:
	# Duración de celebración con aura inmune (~1.6s)
	if _tiempo_en_estado >= 1.6:
		# Finaliza inmunidad y aura
		es_inmune = false
		if aura_vfx:
			aura_vfx.visible = false

		# Disparar 1 sola hacha de mayor tamaño, mayor velocidad/potencia y 100% de acierto
		_lanzar_hacha_especial()
		contador_ataques = 0
		impactos_para_especial = 0
		especial_cargado = false
		habilidad_ejecutada.emit()
		_cambiar_estado(State.IDLE)


## Ataque Especial de Perrena:
## Arroja 1 sola hacha de mayor tamaño con 100% de acierto hacia el objetivo fijado,
## a mayor velocidad y potencia, con prioridad 1 contra cualquier enemigo y daño/efecto de flecha explosiva.
func _lanzar_hacha_especial() -> void:
	var root := get_tree().current_scene if get_tree() else get_parent()
	if not root:
		return

	# Prioridad 1 contra cualquier tipo de enemigo del juego
	var target: Node = _buscar_mejor_objetivo(true)
	var spawn_p: Vector3 = punto_spawn_hacha.global_position if punto_spawn_hacha else (global_position + Vector3(0.2, 1.2, 0.0))

	var target_pos: Vector3 = spawn_p + Vector3(10.0, 0.0, 0.0)
	if is_instance_valid(target) and target is Node3D:
		target_pos = (target as Node3D).global_position + Vector3(0.0, 0.4, 0.0)

	var dir := (target_pos - spawn_p).normalized()
	if dir.length_squared() < 0.01:
		dir = Vector3.RIGHT

	var hacha := HACHA_SCENE.instantiate() as HachaPerrenaProjectile
	if not hacha:
		return

	root.add_child(hacha)
	hacha.global_position = spawn_p
	hacha.impactado.connect(_on_hacha_impacto)
	# Disparar hacha especial: escala 2.0x, velocidad 26.0 y 100% de acierto guiado hacia el objetivo
	hacha.initialize(dir, 1.0, self, true, target)


func _lanzar_hacha_hacia_objetivo(target: Node) -> void:
	var root := get_tree().current_scene if get_tree().current_scene else get_tree().root
	if not root:
		return

	var spawn_p: Vector3 = punto_spawn_hacha.global_position if punto_spawn_hacha else (global_position + Vector3(0.2, 1.2, 0.0))
	var target_pos: Vector3 = spawn_p + Vector3(8.0, 0.0, 0.0)

	if is_instance_valid(target) and target is Node3D:
		target_pos = (target as Node3D).global_position + Vector3(0.0, 0.4, 0.0)

	# Cálculo de trayectoria parabólica hacia el blanco
	var dx: float = maxf(target_pos.x - spawn_p.x, 1.5)
	var dy: float = target_pos.y - spawn_p.y
	var grav: float = ProjectSettings.get_setting("physics/3d/default_gravity")

	# Ángulo base de lanzamiento según la distancia (arco elevado para sortear obstáculos)
	var ang_deg: float = clampf(24.0 + dx * 0.9, 22.0, 48.0)
	var ang_rad: float = deg_to_rad(ang_deg)

	# V = sqrt( (g * dx^2) / (2 * cos^2(theta) * (dx * tan(theta) - dy)) )
	var denom: float = 2.0 * pow(cos(ang_rad), 2.0) * (dx * tan(ang_rad) - dy)
	var vel_mag: float = 12.0
	if denom > 0.01:
		vel_mag = sqrt((grav * dx * dx) / denom)
	vel_mag = clampf(vel_mag, 7.0, 22.0)

	var dir := Vector3(cos(ang_rad), sin(ang_rad), 0.0).normalized()
	var potencia_factor: float = vel_mag / 12.0

	var hacha := HACHA_SCENE.instantiate() as HachaPerrenaProjectile
	if hacha:
		root.add_child(hacha)
		hacha.global_position = spawn_p
		hacha.impactado.connect(_on_hacha_impacto)
		hacha.initialize(dir, potencia_factor, self)


func _on_hacha_impacto(target: Node) -> void:
	if not is_instance_valid(target):
		return

	# Comprobar si el impacto fue a un enemigo, escudo o pilar
	var es_impacto_valido: bool = false
	if target.is_in_group("enemies"):
		es_impacto_valido = true
	elif ("es_escudo_enemigo" in target and target.es_escudo_enemigo) or (target.has_meta("es_escudo_enemigo") and target.get_meta("es_escudo_enemigo")):
		es_impacto_valido = true
	elif ("es_pilar_enemigo" in target and target.es_pilar_enemigo) or (target.has_meta("es_pilar_enemigo") and target.get_meta("es_pilar_enemigo")) or target is PilarLonkoBody or "pilar" in target.name.to_lower():
		es_impacto_valido = true
	elif target.is_in_group("escudos"):
		es_impacto_valido = true

	if not es_impacto_valido:
		return

	# Registrar impacto válido
	impactos_para_especial += 1
	impacto_registrado.emit(impactos_para_especial)

	# Al completar impactos en suelo (si estuviese en fase de suelo)
	if en_fase_escudo_suelo:
		impactos_fase_suelo += 1
		if impactos_fase_suelo >= IMPACTOS_REQUERIDOS_PARA_SUBIR and not _iniciando_ascenso:
			_iniciando_ascenso = true
			call_deferred("iniciar_ascenso_a_ultimo_piso")


## Sistema de Selección por Prioridades:
## Ataque normal:
##   * Prioridad 2: Escudos de escenario (es_escudo_enemigo) y Clase Guardián (ImpShieldGirl, GuardianaMoradita)
##   * Prioridad 1: Enemigos de Élite (Lonko, ArqueraRosa)
##   * Prioridad 0: Resto de enemigos
## Ataque especial:
##   * Prioridad 1: CUALQUIER tipo de enemigo del juego
##   * Prioridad 0: Escudos y defensas del escenario si no hay enemigos
func _buscar_mejor_objetivo(es_ataque_especial: bool = false) -> Node:
	var objetivos_p2: Array[Node] = []
	var objetivos_p1: Array[Node] = []
	var objetivos_p0: Array[Node] = []

	var my_x: float = global_position.x

	# 1. Escudos del escenario en grupo "escudos"
	for escudo in get_tree().get_nodes_in_group("escudos"):
		if not is_instance_valid(escudo) or not (escudo is Node3D):
			continue
		var es_escudo_enem: bool = false
		if "es_escudo_enemigo" in escudo:
			es_escudo_enem = escudo.es_escudo_enemigo
		elif escudo.has_meta("es_escudo_enemigo"):
			es_escudo_enem = bool(escudo.get_meta("es_escudo_enemigo"))
		elif escudo.get("es_escudo_enemigo") != null:
			es_escudo_enem = bool(escudo.get("es_escudo_enemigo"))
		else:
			es_escudo_enem = true

		if es_escudo_enem:
			var ex: float = (escudo as Node3D).global_position.x
			if ex > my_x and (ex - my_x) <= rango_deteccion_max_x:
				if es_ataque_especial:
					objetivos_p0.append(escudo)
				else:
					objetivos_p2.append(escudo)

	# 2. Enemigos en grupo "enemies"
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not (enemy is Node3D):
			continue
		if enemy.get("is_dead") == true or enemy.get("is_dying") == true or enemy.get("muerto") == true:
			continue

		var ex: float = (enemy as Node3D).global_position.x
		if ex <= my_x or (ex - my_x) > rango_deteccion_max_x:
			continue

		if es_ataque_especial:
			# El ataque especial tiene Prioridad 1 contra CUALQUIER tipo de enemigo del juego
			objetivos_p1.append(enemy)
		else:
			var n_lower: String = enemy.name.to_lower()
			# Prioridad 2: Clase Guardián
			if enemy is ImpShieldGirl or enemy is GuardianaMoradita:
				objetivos_p2.append(enemy)
			elif ("imp" in n_lower and "escudo" in n_lower) or ("guardiana" in n_lower and "moradita" in n_lower):
				objetivos_p2.append(enemy)
			# Prioridad 1: Élite (Lonko, Arquera Rosa)
			elif enemy is Lonko or enemy is ArqueraRosa or enemy.get("es_elite") == true:
				objetivos_p1.append(enemy)
			elif "lonko" in n_lower or "rosa" in n_lower:
				objetivos_p1.append(enemy)
			# Prioridad 0: Resto
			else:
				objetivos_p0.append(enemy)

	# Retornar el más cercano de la prioridad más alta disponible
	if objetivos_p2.size() > 0:
		return _obtener_mas_cercano(objetivos_p2)
	if objetivos_p1.size() > 0:
		return _obtener_mas_cercano(objetivos_p1)
	if objetivos_p0.size() > 0:
		return _obtener_mas_cercano(objetivos_p0)

	return null


func _obtener_mas_cercano(lista: Array[Node]) -> Node:
	var mejor: Node = null
	var min_dist: float = 99999.0
	for item in lista:
		if is_instance_valid(item) and item is Node3D:
			var d: float = absf((item as Node3D).global_position.x - global_position.x)
			if d < min_dist:
				min_dist = d
				mejor = item
	return mejor


func take_damage(amount: float) -> void:
	if es_inmune or current_state == State.DYING or current_state == State.DEAD:
		return

	health -= int(amount)
	vida_cambiada.emit(health)

	if health > 0:
		if anim_player and anim_player.has_animation("impacto"):
			anim_player.play("impacto", 0.05, 1.2)
	else:
		_morir()


func recibir_dano(amount: int) -> void:
	take_damage(float(amount))


func curar(amount: int = 1) -> void:
	if current_state == State.DYING or current_state == State.DEAD:
		return
	health = mini(health + amount, vida_maxima)
	vida_cambiada.emit(health)


func _morir() -> void:
	_cambiar_estado(State.DYING)
	murio.emit()

	if hitbox_body:
		hitbox_body.collision_layer = 0

	if anim_player and anim_player.has_animation("Muerte 1"):
		anim_player.play("Muerte 1", 0.1, 1.0)

	_iniciar_desintegracion_celeste()


## Desintegración celeste idéntica al efecto de partículas de las ballesteras:
## disolución con shader + partículas celestes y queue_free
func _iniciar_desintegracion_celeste() -> void:
	var color_celeste := Color(0.25, 0.85, 1.0, 1.0)
	var duracion: float = 1.0

	var meshes: Array[Node] = []
	if model_root:
		meshes = model_root.find_children("*", "MeshInstance3D", true, false)
	else:
		meshes = find_children("*", "MeshInstance3D", true, false)

	var dissolve_mats: Array = []
	for node in meshes:
		if not is_instance_valid(node):
			continue
		var mi := node as MeshInstance3D
		var mat := ShaderMaterial.new()
		mat.shader = DISSOLVE_SHADER
		mat.set_shader_parameter("dissolve_amount", 0.0)
		mat.set_shader_parameter("glow_color", color_celeste)
		mat.set_shader_parameter("glow_intensity", 4.0)
		mat.set_shader_parameter("edge_thickness", 0.05)
		mat.set_shader_parameter("noise_scale", 20.0)

		var orig: Material = mi.material_override
		if orig == null and mi.mesh and mi.mesh.get_surface_count() > 0:
			orig = mi.mesh.surface_get_material(0)
		if orig and orig is StandardMaterial3D:
			var std := orig as StandardMaterial3D
			if std.albedo_texture:
				mat.set_shader_parameter("albedo_texture", std.albedo_texture)
			var col := std.albedo_color
			mat.set_shader_parameter("albedo_tint", Vector3(col.r, col.g, col.b))

		mi.material_override = mat
		dissolve_mats.append(mat)

	var p := GPUParticles3D.new()
	p.name = "ParticulasMuerteCeleste"
	p.amount = 180
	p.lifetime = 2.0
	p.one_shot = false
	p.explosiveness = 0.0
	p.randomness = 0.3

	var p_mat := ParticleProcessMaterial.new()
	p_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	p_mat.emission_box_extents = Vector3(0.2, 0.5, 0.1)
	p_mat.direction = Vector3(0, 1, 0)
	p_mat.spread = 20.0
	p_mat.initial_velocity_min = 0.1
	p_mat.initial_velocity_max = 1.0
	p_mat.gravity = Vector3(0, 0.1, 0)
	p_mat.scale_min = 0.5
	p_mat.scale_max = 1.5

	var gradient := Gradient.new()
	gradient.set_color(0, color_celeste)
	gradient.set_color(1, Color(color_celeste.r, color_celeste.g, color_celeste.b, 0.0))
	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	p_mat.color_ramp = gradient_tex

	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0, 0.2))
	scale_curve.add_point(Vector2(0.3, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	var scale_tex := CurveTexture.new()
	scale_tex.curve = scale_curve
	p_mat.scale_curve = scale_tex

	p.process_material = p_mat

	var sphere := SphereMesh.new()
	sphere.radius = 0.0125
	sphere.height = 0.025

	var part_mat := StandardMaterial3D.new()
	part_mat.albedo_color = color_celeste
	part_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	part_mat.emission_enabled = true
	part_mat.emission = color_celeste
	part_mat.emission_energy_multiplier = 4.0
	part_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	part_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.material = part_mat

	p.draw_pass_1 = sphere

	var scene_root: Node = get_tree().current_scene if get_tree() else get_parent()
	if scene_root:
		scene_root.add_child(p)
		p.global_position = global_position + Vector3(0, 0.4, 0)
		p.emitting = true
	else:
		add_child(p)
		p.position = Vector3(0, 0.4, 0)
		p.emitting = true

	var tw := create_tween()
	tw.tween_method(
		func(val: float) -> void:
			for m in dissolve_mats:
				if is_instance_valid(m):
					m.set_shader_parameter("dissolve_amount", val),
		0.0, 1.0, duracion)

	if get_tree():
		get_tree().create_timer(duracion * 0.7).timeout.connect(func():
			if is_instance_valid(p):
				p.emitting = false
		)
		get_tree().create_timer(duracion + 2.0).timeout.connect(func():
			if is_instance_valid(p):
				p.queue_free()
		)

	tw.finished.connect(queue_free)



func _cambiar_estado(nuevo_estado: State) -> void:
	current_state = nuevo_estado
	_tiempo_en_estado = 0.0

	if current_state == State.IDLE:
		_tiempo_para_proximo_ataque = randf_range(tiempo_espera_ataque_min, tiempo_espera_ataque_max)
		if hacha_mano:
			hacha_mano.visible = false
		if anim_player and anim_player.has_animation("Idle"):
			anim_player.play("Idle", 0.2, 1.0)


func _reproducir_sfx_celebracion() -> void:
	var stream := load(SFX_CELEBRACION) as AudioStream
	if not stream:
		return
	var audio := AudioStreamPlayer3D.new()
	audio.stream = stream
	audio.unit_size = 18.0
	audio.volume_db = 2.5
	audio.bus = "Master"
	add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)
