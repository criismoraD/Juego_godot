class_name ImperioGirlMelee
extends CharacterBody3D

## Defensora aliada Imperio Girl Melee.
## Usa el mismo modelo de Imperio Girl que la defensora arquera,
## pero lleva la Espada Imperial (igual que Imperio Man) y ataca
## cuerpo a cuerpo siguiendo la misma lógica que GoblinGarrote:
## corre hacia el enemigo más cercano, lo ataca y regresa a patrulla.
## Diferencias frente a GoblinGarrote:
##   - Está del lado aliado: ataca ENEMIGOS, no aliados/protagonista.
##   - Tiene 3 de vida (en lugar de 1).
##   - Al morir se disuelve en color dorado (igual que Imperio Man).
##   - No tiene mecánica de bloqueo (no es escudo).
##   - Registra la señal "died" para el sistema de oleadas.

# ═══════════════════════════════════════════════════════════════════════════════
# SEÑALES
# ═══════════════════════════════════════════════════════════════════════════════
signal died

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTES
# ═══════════════════════════════════════════════════════════════════════════════
const VIDA_MAXIMA_DEFAULT: int = 3
const VELOCIDAD_CORRER_DEFAULT: float = 2.2
const ALCANCE_MELEE_DEFAULT: float = 1.6
const MARGEN_Z_MELEE_DEFAULT: float = 1.4
const DANO_MELEE_DEFAULT: int = 1
const TIEMPO_IMPACTO_MELEE_DEFAULT: float = 0.45
const DURACION_ATAQUE_DEFAULT: float = 0.90
const INTERVALO_ENTRE_ATAQUES_DEFAULT: float = 0.30
const VELOCIDAD_ANIMACION_ATAQUE_DEFAULT: float = 1.2
const COLOR_FLASH_DANO_DEFAULT: Color = Color(1.0, 0.12, 0.12, 1.0)
const DURACION_DISOLUCION: float = 1.2

const MAT_IMPERIO_GIRL: Material = preload(
		"res://Entities/Jugador_ImperioGirl/IMPERIO_GIRL_MAT.tres")
const MAT_ESPADA: Material = preload(
		"res://Entities/Enemigo_ImperioMan/EspadaImperial_Mat.tres")
const ESCENA_ESPADA: PackedScene = preload(
		"res://Entities/Enemigo_ImperioMan/Espada imperial.glb")
const DISSOLVE_SHADER: Shader = preload(
		"res://System/Shaders/dissolve.gdshader")
const SANGRE_NO_LETAL_SCENE: PackedScene = preload(
		"res://VFX/Scenes/BloodSplashNoLetal.tscn")

const ESCALA_ESPADA_MANO: float = 0.65
## Offset de la Espada Imperial (misma que ImperioMan) en mano derecha.
## Sincronizado con el ajuste visual hecho en ImperioGirlMelee.tscn
## (BoneAttachment_Espada en mixamorig_RightHand, bone_idx 36).
## El attachment va en mixamorig_RightHand para sujetarla en mano derecha.
const OFFSET_ATTACH_ESPADA: Transform3D = Transform3D(
	Vector3(-0.98632663, 0.1328633, -0.09750244),
	Vector3(-0.14458364, -0.9815574, 0.12506114),
	Vector3(-0.07908821, 0.13744828, 0.98734665),
	Vector3(8.093573, -7.4328775, -36.55694))
const OFFSET_ESPADA_EN_MANO: Transform3D = Transform3D(
	Vector3(-3.005569, -39.058876, -10.861121),
	Vector3(39.002327, 0.18604362, -11.46206),
	Vector3(11.062564, -11.267748, 37.459995),
	Vector3(33.67076, 3.9593983, 11.352989))
const PREFIJO_ARMATURE_COMPLETO: String = "Armature|Armature|"
const PREFIJO_ARMATURE_CORTO: String = "Armature|"

## Animaciones nativas del GLB de Imperio Girl mapeadas a alias de combate.
const MAPEO_ANIMS: Dictionary = {
	"IDLE": "Idle espera",
	"CORRER": "Correr",
	"CAMINAR": "Caminar",
	"ATAQUE": "Ataque espada",     # preferido; si no existe usa el melee de arquera
	"HIT": "Hit",
	"MUERTE": "Muerte1",
}

## Alias que deben reproducirse en loop.
const ALIAS_EN_LOOP: Array[String] = ["IDLE", "CORRER", "CAMINAR"]

# ═══════════════════════════════════════════════════════════════════════════════
# ENUMS
# ═══════════════════════════════════════════════════════════════════════════════
enum Estado { CORRIENDO, ATACANDO, MURIENDO, DEAD }

# ═══════════════════════════════════════════════════════════════════════════════
# VARIABLES EXPORTADAS
# ═══════════════════════════════════════════════════════════════════════════════
@export_category("Estadísticas – Imperio Girl Melee")
@export var vida_maxima: int = VIDA_MAXIMA_DEFAULT
@export var velocidad_correr: float = VELOCIDAD_CORRER_DEFAULT
@export var direccion_avance: float = 1.0:
	set(v):
		direccion_avance = v
		if is_node_ready():
			_actualizar_orientacion_modelo()
@export var dano_cuerpo_a_cuerpo: int = DANO_MELEE_DEFAULT
@export var alcance_melee: float = ALCANCE_MELEE_DEFAULT
@export var margen_z_melee: float = MARGEN_Z_MELEE_DEFAULT
@export var tiempo_impacto_melee: float = TIEMPO_IMPACTO_MELEE_DEFAULT
@export var duracion_ataque_total: float = DURACION_ATAQUE_DEFAULT
@export var intervalo_entre_ataques: float = INTERVALO_ENTRE_ATAQUES_DEFAULT
@export var velocidad_animacion_ataque: float = VELOCIDAD_ANIMACION_ATAQUE_DEFAULT
@export var plano_profundidad_z: float = 0.0
@export var color_borde_disolucion: Color = Color(1.0, 0.75, 0.2, 1.0)
## Color del flash de parpadeo al recibir daño (rojo de impacto).
@export var color_flash_impacto: Color = COLOR_FLASH_DANO_DEFAULT
## Si true, silencia los efectos de sonido de ataque y muerte (útil en batallas cosméticas de fondo).
@export var silenciar_audio: bool = false

# ═══════════════════════════════════════════════════════════════════════════════
# VARIABLES DE ESTADO
# ═══════════════════════════════════════════════════════════════════════════════
var health: int = VIDA_MAXIMA_DEFAULT
var estado: Estado = Estado.CORRIENDO
var last_hit_position: Vector3 = Vector3.ZERO
var last_hit_direction: Vector3 = Vector3.ZERO

var _timer_ataque: float = 0.0
var _ha_golpeado_en_animacion: bool = false
var _cooldown_ataque_timer: float = 0.0
var _is_dissolving: bool = false
var _dissolve_materials: Array = []

var _hit_squash_tween: Tween = null
var _escala_base_modelo: Vector3 = Vector3.ONE

# ═══════════════════════════════════════════════════════════════════════════════
# REFERENCIAS ONREADY
# ═══════════════════════════════════════════════════════════════════════════════
var anim_player: AnimationPlayer = null
var _model_root: Node3D = null



# ═══════════════════════════════════════════════════════════════════════════════
# FUNCIONES BUILT-IN
# ═══════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	health = vida_maxima
	collision_layer = 2
	collision_mask = 1

	add_to_group("allies")
	add_to_group("defensoras")

	_model_root = find_child("ImperioGirlModel", true, false) as Node3D
	if is_instance_valid(_model_root):
		_escala_base_modelo = _model_root.scale

	_actualizar_orientacion_modelo()
	_aplicar_material_imperio()
	_equipar_espada_mano_derecha()
	_remapear_animaciones()
	_resolver_anim_player()
	_cambiar_estado(Estado.CORRIENDO)


func _actualizar_orientacion_modelo() -> void:
	if not is_instance_valid(_model_root):
		_model_root = find_child("ImperioGirlModel", true, false) as Node3D
	if not is_instance_valid(_model_root):
		return
	if direccion_avance > 0.0:
		_model_root.rotation_degrees.y = 90.0   # Mirar a la derecha (+X)
	else:
		_model_root.rotation_degrees.y = -90.0  # Mirar a la izquierda (-X)


func _physics_process(delta: float) -> void:
	if estado == Estado.MURIENDO or estado == Estado.DEAD:
		return

	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta

	if _cooldown_ataque_timer > 0.0:
		_cooldown_ataque_timer -= delta

	match estado:
		Estado.CORRIENDO:
			_process_corriendo(delta)
		Estado.ATACANDO:
			_process_atacando(delta)

	move_and_slide()
	global_position.z = plano_profundidad_z


# ═══════════════════════════════════════════════════════════════════════════════
# MÁQUINA DE ESTADOS
# ═══════════════════════════════════════════════════════════════════════════════
func _cambiar_estado(nuevo: Estado) -> void:
	if estado == Estado.MURIENDO or estado == Estado.DEAD:
		return
	if estado == nuevo:
		return

	estado = nuevo

	match nuevo:
		Estado.CORRIENDO:
			velocity.x = direccion_avance * velocidad_correr
			_play_anim("CORRER", 0.15, 1.0)
		Estado.ATACANDO:
			# Impulso fluido hacia adelante al inicio del swing para dar contundencia e inercia
			velocity.x = direccion_avance * (velocidad_correr * 0.35)
			_timer_ataque = 0.0
			_ha_golpeado_en_animacion = false
			_play_anim("ATAQUE", 0.08, velocidad_animacion_ataque)
		Estado.MURIENDO:
			_morir()


func _process_corriendo(delta: float) -> void:
	if _cooldown_ataque_timer <= 0.0 and _enemigo_en_alcance():
		_cambiar_estado(Estado.ATACANDO)
		return
	velocity.x = direccion_avance * velocidad_correr


func _process_atacando(delta: float) -> void:
	# Desaceleración suave del paso hacia adelante durante el swing
	velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
	_timer_ataque += delta

	# Punto de impacto de la espada sincronizado con el corte
	if not _ha_golpeado_en_animacion and _timer_ataque >= tiempo_impacto_melee:
		_ha_golpeado_en_animacion = true
		_ejecutar_golpe_espada()

	# Fin del ataque
	if _timer_ataque >= duracion_ataque_total:
		_cooldown_ataque_timer = intervalo_entre_ataques
		if _enemigo_en_alcance():
			# Encadenar otro ataque continuo y fluido sin pausar
			_timer_ataque = 0.0
			_ha_golpeado_en_animacion = false
			velocity.x = direccion_avance * (velocidad_correr * 0.25)
			_play_anim("ATAQUE", 0.06, velocidad_animacion_ataque)
		else:
			_cambiar_estado(Estado.CORRIENDO)



# ═══════════════════════════════════════════════════════════════════════════════
# COMBATE
# ═══════════════════════════════════════════════════════════════════════════════
func _ejecutar_golpe_espada() -> void:
	if get_tree() == null:
		return
	if not silenciar_audio and is_inside_tree() and get_tree().root.has_node("AudioManager"):
		get_tree().root.get_node("AudioManager").call(
				"play_sfx", "lanzar_espada_pirata", 0.0)

	# Golpea exactamente UNA unidad por swing: el primer enemigo válido en alcance.
	var golpe_aplicado: bool = false
	for grupo in ["enemies", "enemigos"]:
		if golpe_aplicado:
			break
		for objetivo in get_tree().get_nodes_in_group(grupo):
			if not is_instance_valid(objetivo) or not (objetivo is Node3D):
				continue
			var victima := objetivo as Node3D
			var dist_adelante: float = (victima.global_position.x - global_position.x) * direccion_avance
			if dist_adelante < 0.0 or dist_adelante > alcance_melee:
				continue
			if absf(victima.global_position.z - global_position.z) > margen_z_melee:
				continue
			if "health" in victima and int(victima.get("health")) <= 0:
				continue
			if victima.has_method("take_damage"):
				if "last_hit_position" in victima:
					var pos_sangre: Vector3 = victima.global_position + Vector3(0.0, 0.45, 0.0)
					victima.set("last_hit_position", pos_sangre)
				if "last_hit_direction" in victima:
					victima.set("last_hit_direction", Vector3(direccion_avance, 0.0, 0.0))
				if "ultimo_atacante" in victima:
					victima.set("ultimo_atacante", self)
				victima.call("take_damage", float(dano_cuerpo_a_cuerpo))
			elif victima.has_method("recibir_golpe"):
				if "last_hit_position" in victima:
					var pos_sangre: Vector3 = victima.global_position + Vector3(0.0, 0.45, 0.0)
					victima.set("last_hit_position", pos_sangre)
				if "last_hit_direction" in victima:
					victima.set("last_hit_direction", Vector3(direccion_avance, 0.0, 0.0))
				victima.call("recibir_golpe", float(dano_cuerpo_a_cuerpo))
			# Un solo impacto por swing: salir de ambos bucles.
			golpe_aplicado = true
			break



func _enemigo_en_alcance() -> bool:
	if get_tree() == null:
		return false
	for grupo in ["enemies", "enemigos"]:
		for objetivo in get_tree().get_nodes_in_group(grupo):
			if not is_instance_valid(objetivo) or not (objetivo is Node3D):
				continue
			var victima := objetivo as Node3D
			var dist_adelante: float = (victima.global_position.x - global_position.x) * direccion_avance
			if dist_adelante < -0.3 or dist_adelante > alcance_melee + 0.3:
				continue
			if absf(victima.global_position.z - global_position.z) > margen_z_melee:
				continue
			if "health" in victima and int(victima.get("health")) <= 0:
				continue
			return true
	return false


# ═══════════════════════════════════════════════════════════════════════════════
# DAÑO Y MUERTE
# ═══════════════════════════════════════════════════════════════════════════════
func take_damage(amount: float) -> void:
	if estado == Estado.MURIENDO or estado == Estado.DEAD:
		return
	if amount <= 0.0:
		return

	health -= int(amount)
	_play_anim("HIT", 0.04, 1.25)
	_flash_impacto()
	_aplicar_squash_stretch_impacto()

	if health <= 0:
		health = 0
		_cambiar_estado(Estado.MURIENDO)
	else:
		_spawn_sangre_no_letal()


func recibir_golpe(amount: float = 1.0) -> void:
	take_damage(amount)


func _morir() -> void:
	if _hit_squash_tween and _hit_squash_tween.is_valid():
		_hit_squash_tween.kill()
	if is_instance_valid(_model_root):
		_model_root.scale = _escala_base_modelo

	estado = Estado.MURIENDO
	velocity = Vector3.ZERO
	_play_anim("MUERTE")

	var col := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if is_instance_valid(col):
		col.set_deferred("disabled", true)

	if not silenciar_audio and is_inside_tree() and get_tree().root.has_node("AudioManager"):
		get_tree().root.get_node("AudioManager").call("play_sfx", "imp_death", 0.0)

	died.emit()

	# Si no forma parte de una batalla cosmética gestionada por spawner,
	# se desvanece tras unos segundos de respaldo.
	if not is_in_group("batalla_cosmetica"):
		get_tree().create_timer(4.0, false).timeout.connect(func() -> void:
			if is_instance_valid(self) and estado == Estado.MURIENDO and not _is_dissolving:
				desvanecer_y_liberar()
		)


## Desvanece el cadáver con el shader de disolución y libera el nodo.
## Invocado por el gestor de cadáveres cuando se supera el límite en pantalla.
func desvanecer_y_liberar() -> void:
	if _is_dissolving or is_queued_for_deletion():
		return
	_start_dissolve()


# ═══════════════════════════════════════════════════════════════════════════════
# VISUAL – FLASH DE IMPACTO Y SQUASH & STRETCH
# ═══════════════════════════════════════════════════════════════════════════════
## Visual – Flash de daño de color rojo para acentuar el impacto recibido.
func _flash_impacto() -> void:
	var flash_mat := StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.albedo_color = color_flash_impacto

	var meshes := find_children("*", "MeshInstance3D", true, false)
	for m in meshes:
		var mi := m as MeshInstance3D
		if is_instance_valid(mi):
			mi.material_overlay = flash_mat

	get_tree().create_timer(0.12, false).timeout.connect(func() -> void:
		if not is_instance_valid(self):
			return
		for m in find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if is_instance_valid(mi) and mi.material_overlay == flash_mat:
				mi.material_overlay = null
	)


## Aplica un efecto visual de estirar y contraer (Squash & Stretch)
## sobre el modelo para intensificar y hacer contundente el impacto recibido.
func _aplicar_squash_stretch_impacto() -> void:
	if not is_instance_valid(_model_root):
		return

	if _hit_squash_tween and _hit_squash_tween.is_valid():
		_hit_squash_tween.kill()

	var base_scale: Vector3 = _escala_base_modelo if _escala_base_modelo != Vector3.ZERO else _model_root.scale

	# 1. Contracción / Squash (compresión en Y y expansión en X/Z)
	var squash_scale: Vector3 = Vector3(
		base_scale.x * 1.25,
		base_scale.y * 0.75,
		base_scale.z * 1.25
	)

	# 2. Rebote elástico / Stretch (se estira hacia arriba y se comprime en X/Z)
	var stretch_scale: Vector3 = Vector3(
		base_scale.x * 0.90,
		base_scale.y * 1.18,
		base_scale.z * 0.90
	)

	_model_root.scale = squash_scale

	_hit_squash_tween = create_tween()
	# Transición hacia el stretch elástico
	_hit_squash_tween.tween_property(_model_root, "scale", stretch_scale, 0.08)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Retorno amortiguado y suave a la escala base
	_hit_squash_tween.tween_property(_model_root, "scale", base_scale, 0.12)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ═══════════════════════════════════════════════════════════════════════════════
# VISUAL – SANGRE NO LETAL
# ═══════════════════════════════════════════════════════════════════════════════
func _spawn_sangre_no_letal() -> void:
	if not SANGRE_NO_LETAL_SCENE:
		return
	var sangre := SANGRE_NO_LETAL_SCENE.instantiate() as Node3D
	if not is_instance_valid(sangre):
		return
	var parent_node: Node = get_tree().current_scene if get_tree() else get_parent()
	if not parent_node:
		parent_node = self
	parent_node.add_child(sangre)
	var pos_sangre: Vector3 = last_hit_position if last_hit_position != Vector3.ZERO \
			else global_position + Vector3(0.0, 0.5, 0.0)
	if sangre.has_method("setup"):
		sangre.call("setup", pos_sangre, last_hit_direction)
	else:
		sangre.global_position = pos_sangre


# ═══════════════════════════════════════════════════════════════════════════════
# VISUAL – DISOLUCIÓN DORADA AL MORIR
# ═══════════════════════════════════════════════════════════════════════════════
func _start_dissolve() -> void:
	if _is_dissolving:
		return
	_is_dissolving = true

	for m in find_children("*", "MeshInstance3D", true, false):
		var mesh := m as MeshInstance3D
		if not is_instance_valid(mesh):
			continue
		var mat := ShaderMaterial.new()
		mat.shader = DISSOLVE_SHADER
		mat.set_shader_parameter("dissolve_amount", 0.0)
		mat.set_shader_parameter("glow_color", color_borde_disolucion)
		mat.set_shader_parameter("glow_intensity", 8.0)
		mat.set_shader_parameter("edge_thickness", 0.05)
		mat.set_shader_parameter("noise_scale", 20.0)

		var orig: Material = mesh.material_override
		if orig == null and mesh.mesh != null and mesh.mesh.get_surface_count() > 0:
			orig = mesh.mesh.surface_get_material(0)
		if orig is StandardMaterial3D:
			var tex: Texture2D = (orig as StandardMaterial3D).albedo_texture
			if tex:
				mat.set_shader_parameter("albedo_texture", tex)
			var col: Color = (orig as StandardMaterial3D).albedo_color
			mat.set_shader_parameter("albedo_tint", Vector3(col.r, col.g, col.b))

		mesh.material_override = mat
		_dissolve_materials.append(mat)

	var tween: Tween = create_tween()
	tween.tween_method(_update_dissolve, 0.0, 1.0, DURACION_DISOLUCION)
	tween.tween_callback(_finish_dissolve)


func _update_dissolve(val: float) -> void:
	for mat in _dissolve_materials:
		if is_instance_valid(mat):
			(mat as ShaderMaterial).set_shader_parameter("dissolve_amount", val)


func _finish_dissolve() -> void:
	estado = Estado.DEAD
	queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# SETUP – MODELO Y MATERIALES
# ═══════════════════════════════════════════════════════════════════════════════

## Aplica la textura de Imperio Girl a todas las mallas del modelo.
## IMPORTANTE: excluye la EspadaImperial para no tapar su material.
func _aplicar_material_imperio() -> void:
	if not is_instance_valid(_model_root):
		return
	for mesh in _model_root.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh as MeshInstance3D
		if not is_instance_valid(mi):
			continue
		# No tocar la espada (está bajo BoneAttachment_Espada / EspadaImperial)
		var p: Node = mi.get_parent()
		var dentro_espada: bool = false
		while is_instance_valid(p) and p != _model_root and p != self:
			if p.name == "EspadaImperial" or p.name == "BoneAttachment_Espada":
				dentro_espada = true
				break
			p = p.get_parent()
		if dentro_espada:
			continue
		mi.material_override = MAT_IMPERIO_GIRL


## Ata la Espada Imperial a la mano derecha de Imperio Girl.
func _equipar_espada_mano_derecha() -> void:
	var esqueleto := _buscar_skeleton()
	if not is_instance_valid(esqueleto):
		push_warning("[ImperioGirlMelee] Sin Skeleton3D: espada sin atar.")
		return

	var idx_hueso: int = _resolver_hueso_mano_derecha(esqueleto)
	if idx_hueso < 0:
		push_warning("[ImperioGirlMelee] Sin hueso mano derecha: espada sin atar.")
		return

	# Si ya existe la espada en la escena, sólo reparamos el attachment
	var existente := find_child("EspadaImperial", true, false) as Node3D
	if is_instance_valid(existente):
		var attach_existente := existente.get_parent() as BoneAttachment3D
		if is_instance_valid(attach_existente):
			attach_existente.bone_idx = idx_hueso
			attach_existente.bone_name = esqueleto.get_bone_name(idx_hueso)
		_aplicar_material_espada()
		return

	# Crear attachment y espada por código (misma Espada Imperial que ImperioMan)
	var attach := BoneAttachment3D.new()
	attach.name = "BoneAttachment_Espada"
	esqueleto.add_child(attach)
	attach.bone_idx = idx_hueso
	attach.bone_name = esqueleto.get_bone_name(idx_hueso)
	attach.transform = OFFSET_ATTACH_ESPADA

	var espada: Node3D = ESCENA_ESPADA.instantiate() as Node3D
	if not is_instance_valid(espada):
		return
	espada.name = "EspadaImperial"
	espada.transform = OFFSET_ESPADA_EN_MANO
	attach.add_child(espada)
	_aplicar_material_espada()


func _aplicar_material_espada() -> void:
	var espada := find_child("EspadaImperial", true, false) as Node
	if not is_instance_valid(espada):
		return
	for m in espada.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if is_instance_valid(mi):
			mi.material_override = MAT_ESPADA
			if mi.mesh != null and mi.mesh.get_surface_count() > 0:
				mi.set_surface_override_material(0, MAT_ESPADA)


func _buscar_skeleton() -> Skeleton3D:
	var esqueletos := find_children("*", "Skeleton3D", true, false)
	if not esqueletos.is_empty():
		return esqueletos[0] as Skeleton3D
	return null


func _resolver_hueso_mano_derecha(esqueleto: Skeleton3D) -> int:
	if not is_instance_valid(esqueleto):
		return -1
	var candidatos: Array[String] = [
		"mixamorig:RightHand", "mixamorig_RightHand", "RightHand", "Hand_R", "R_Hand"
	]
	for nombre in candidatos:
		var idx: int = esqueleto.find_bone(nombre)
		if idx >= 0:
			return idx
	# Búsqueda difusa
	for i in range(esqueleto.get_bone_count()):
		var nl: String = esqueleto.get_bone_name(i).to_lower()
		if "finger" in nl or "index" in nl or "thumb" in nl:
			continue
		if "righthand" in nl or "hand.r" in nl or "r_hand" in nl:
			return i
	return -1


# ═══════════════════════════════════════════════════════════════════════════════
# SETUP – ANIMACIONES
# ═══════════════════════════════════════════════════════════════════════════════

## Registra en el AnimationPlayer del modelo los alias de combate
## (IDLE, CORRER, ATAQUE, HIT, MUERTE) mapeados desde los clips nativos del GLB.
func _remapear_animaciones() -> void:
	var anim_p := _buscar_anim_player_corporal()
	if anim_p == null:
		push_warning("[ImperioGirlMelee] Sin AnimationPlayer corporal: sin alias de animación.")
		return

	for destino in MAPEO_ANIMS.keys():
		var origen: String = MAPEO_ANIMS[destino]
		var destino_completo: String = PREFIJO_ARMATURE_COMPLETO + destino
		if anim_p.has_animation(destino_completo):
			continue
		var fuente := _buscar_animacion_nativa(anim_p, origen)
		if fuente == null:
			# Fallback para ATAQUE: intentar con el clip de ataque del GLB de arquera
			if destino == "ATAQUE":
				fuente = _buscar_animacion_nativa(anim_p, "Ataque")
			if fuente == null:
				push_warning("[ImperioGirlMelee] Sin clip nativo para '%s' (buscaba '%s')" \
						% [destino_completo, origen])
				continue
		if destino in ALIAS_EN_LOOP:
			fuente.loop_mode = Animation.LOOP_LINEAR
		_registrar_alias(anim_p, destino_completo, fuente)
		_registrar_alias(anim_p, PREFIJO_ARMATURE_CORTO + destino, fuente)
		_registrar_alias(anim_p, destino, fuente)


func _resolver_anim_player() -> void:
	anim_player = _buscar_anim_player_corporal()


func _buscar_anim_player_corporal() -> AnimationPlayer:
	if is_instance_valid(_model_root):
		var directo := _model_root.get_node_or_null("AnimationPlayer") as AnimationPlayer
		if directo:
			return directo
	for n in find_children("*", "AnimationPlayer", true, false):
		var ap := n as AnimationPlayer
		if ap and (ap.has_animation("Idle espera") or ap.has_animation("Correr") \
				or ap.has_animation("Muerte1")):
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


func _play_anim(alias: String, blend: float = 0.15, speed: float = 1.0) -> void:
	if anim_player == null:
		return
	# Intentar primero con prefijo completo, luego alias corto
	var candidatos: Array[String] = [
		PREFIJO_ARMATURE_COMPLETO + alias,
		PREFIJO_ARMATURE_CORTO + alias,
		alias,
	]
	for c in candidatos:
		if anim_player.has_animation(c):
			anim_player.play(c, blend, speed)
			return
	# Búsqueda difusa por subcadena
	var alias_bajo: String = alias.to_lower()
	for a in anim_player.get_animation_list():
		if alias_bajo in String(a).to_lower():
			anim_player.play(a, blend, speed)
			return
	push_warning("[ImperioGirlMelee] Animación no encontrada: '%s'" % alias)
