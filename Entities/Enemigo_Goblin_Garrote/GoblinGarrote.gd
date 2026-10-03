class_name GoblinGarrote
extends EnemyBase

## Enemigo Goblin cuerpo a cuerpo armado con garrote.
## Corre hacia el objetivo, ejecuta ataques cuerpo a cuerpo con su garrote,
## tiene un 25% de probabilidad de bloquear ataques melee rivales,
## y al morir por explosión suelta el garrote con física en lugar de una ballesta.

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTES Y ENUMS
# ═══════════════════════════════════════════════════════════════════════════════
const PROBABILIDAD_BLOQUEO_DEFAULT: float = 0.25
const ALCANCE_MELEE_DEFAULT: float = 1.35
const MARGEN_Z_MELEE_DEFAULT: float = 1.2
const DANO_MELEE_DEFAULT: int = 1
const TIEMPO_IMPACTO_MELEE_DEFAULT: float = 0.8
const DURACION_ATAQUE_MELEE_DEFAULT: float = 1.6
const DURACION_BLOQUEO_DEFAULT: float = 0.9
const INTERVALO_ENTRE_ATAQUES_DEFAULT: float = 1.0
const VELOCIDAD_CORRER_DEFAULT: float = 2.4

const TEXTURA_HUMO_PISADAS: Texture2D = preload("res://VFX/Textures/Smoke/Humo_Pisadas_1A-1.png")
const HUMO_PISADAS_FRAMES_H: int = 9
const HUMO_PISADAS_FRAMES_V: int = 1

enum EstadoMelee {
	CORRIENDO,
	ATACANDO,
	BLOQUEANDO,
	MURIENDO,
	DEAD
}

# ═══════════════════════════════════════════════════════════════════════════════
# VARIABLES EXPORTADAS
# ═══════════════════════════════════════════════════════════════════════════════
@export_category("Combate - Goblin Garrote")
@export_range(0.0, 1.0, 0.01) var probabilidad_bloqueo: float = PROBABILIDAD_BLOQUEO_DEFAULT
@export var dano_cuerpo_a_cuerpo: int = DANO_MELEE_DEFAULT
@export var alcance_melee: float = ALCANCE_MELEE_DEFAULT
@export var margen_z_melee: float = MARGEN_Z_MELEE_DEFAULT
@export var tiempo_impacto_melee: float = TIEMPO_IMPACTO_MELEE_DEFAULT
@export var duracion_ataque_total: float = DURACION_ATAQUE_MELEE_DEFAULT
@export var duracion_bloqueo: float = DURACION_BLOQUEO_DEFAULT
@export var intervalo_entre_ataques: float = INTERVALO_ENTRE_ATAQUES_DEFAULT
@export var velocidad_correr: float = VELOCIDAD_CORRER_DEFAULT
@export var direccion_avance: float = -1.0:
	set(v):
		direccion_avance = v
		if is_node_ready():
			_actualizar_orientacion_modelo()
@export var plano_profundidad_z: float = 0.0

# ═══════════════════════════════════════════════════════════════════════════════
# VARIABLES DE ESTADO
# ═══════════════════════════════════════════════════════════════════════════════
var estado_melee: EstadoMelee = EstadoMelee.CORRIENDO
var murio_por_explosion: bool = false

var _timer_ataque: float = 0.0
var _ha_golpeado_en_animacion: bool = false
var _cooldown_ataque_timer: float = 0.0
var _timer_bloqueo: float = 0.0

var _particulas_pisada: GPUParticles3D = null
var _garrote_nodo: Node3D = null


# ═══════════════════════════════════════════════════════════════════════════════
# INICIALIZACIÓN
# ═══════════════════════════════════════════════════════════════════════════════
func _on_enemy_ready() -> void:
	velocidad_caminar = velocidad_correr
	_actualizar_orientacion_modelo()
	_configurar_particulas_pisada()
	_fijar_garrote_mano_derecha()
	set_process(true)
	_cambiar_estado_melee(EstadoMelee.CORRIENDO)


func _actualizar_orientacion_modelo() -> void:
	var modelo := get_node_or_null("GOBLING_REMASTER_ANIMACIONES") as Node3D
	if not is_instance_valid(modelo):
		return
	if direccion_avance < 0.0:
		modelo.rotation_degrees.y = -90.0  # Mirar a la izquierda (-X)
	else:
		modelo.rotation_degrees.y = 90.0   # Mirar a la derecha (+X)


## Asegura que el garrote quede montado en el hueso mixamorig_RightHandIndex1.
func _fijar_garrote_mano_derecha() -> void:
	var skel := get_node_or_null("GOBLING_REMASTER_ANIMACIONES/Armature/Skeleton3D") as Skeleton3D
	if skel == null:
		return
	var idx: int = skel.find_bone("mixamorig_RightHandIndex1")
	if idx == -1:
		push_warning("[GoblinGarrote] Hueso mixamorig_RightHandIndex1 no encontrado.")
		return
	var attach := skel.get_node_or_null("BoneAttachment3D") as BoneAttachment3D
	if attach == null:
		return
	attach.bone_name = "mixamorig_RightHandIndex1"
	attach.bone_idx = idx

	_garrote_nodo = attach.get_node_or_null("GarroteGoblin") as Node3D


# ═══════════════════════════════════════════════════════════════════════════════
# CICLO PRINCIPAL
# ═══════════════════════════════════════════════════════════════════════════════
func _process(delta: float) -> void:
	super._process(delta)
	if _particulas_pisada:
		_particulas_pisada_emitir()


func _physics_process(delta: float) -> void:
	if not _esta_en_piso():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta

	if current_state == State.DYING or current_state == State.DEAD or estado_melee == EstadoMelee.MURIENDO or estado_melee == EstadoMelee.DEAD:
		_process_dying(delta)
		move_and_slide()
		return

	if _cooldown_ataque_timer > 0.0:
		_cooldown_ataque_timer -= delta

	match estado_melee:
		EstadoMelee.CORRIENDO:
			_process_running(delta)
		EstadoMelee.ATACANDO:
			_process_attacking(delta)
		EstadoMelee.BLOQUEANDO:
			_process_blocking(delta)

	move_and_slide()
	if is_in_group("batalla_cosmetica"):
		global_position.z = plano_profundidad_z


# ═══════════════════════════════════════════════════════════════════════════════
# MÁQUINA DE ESTADOS Y COMBATE CUERPO A CUERPO
# ═══════════════════════════════════════════════════════════════════════════════
func _cambiar_estado_melee(nuevo_estado: EstadoMelee) -> void:
	if estado_melee == nuevo_estado or estado_melee == EstadoMelee.MURIENDO or estado_melee == EstadoMelee.DEAD:
		return

	estado_melee = nuevo_estado

	match nuevo_estado:
		EstadoMelee.CORRIENDO:
			velocity.x = direccion_avance * velocidad_correr
			_play_animation("Correr")
		EstadoMelee.ATACANDO:
			velocity.x = 0.0
			_timer_ataque = 0.0
			_ha_golpeado_en_animacion = false
			_play_animation("Ataque melee", -1.0, 1.3)
		EstadoMelee.BLOQUEANDO:
			velocity.x = 0.0
			_timer_bloqueo = duracion_bloqueo
			_play_animation("Bloqueo", 0.05, 1.2)


func _process_running(delta: float) -> void:
	# Comprobar si hay objetivo cuerpo a cuerpo en alcance para iniciar ataque
	if _cooldown_ataque_timer <= 0.0 and _objetivo_en_alcance_melee():
		_cambiar_estado_melee(EstadoMelee.ATACANDO)
		return

	# Si es batalla cosmética, no detenerse por límites de la isla jugable frontal
	if not is_in_group("batalla_cosmetica"):
		var limite_izq: float = _obtener_limite_izquierdo_x()
		var en_borde_plataforma: bool = evitar_caer_plataformas and _esta_en_piso() and not hay_suelo_adelante(-1.0)
		if (limite_izq != -INF and global_position.x <= limite_izq) or en_borde_plataforma:
			velocity.x = 0.0
			if limite_izq != -INF:
				global_position.x = max(global_position.x, limite_izq)
			return

	velocity.x = direccion_avance * velocidad_correr
	walked_distance += velocidad_correr * delta


func _process_attacking(delta: float) -> void:
	velocity.x = 0.0
	_timer_ataque += delta

	# Impacto del garrote en el punto álgido de la animación
	if not _ha_golpeado_en_animacion and _timer_ataque >= tiempo_impacto_melee:
		_ha_golpeado_en_animacion = true
		_ejecutar_golpe_garrote()

	# Fin del ataque
	if _timer_ataque >= duracion_ataque_total:
		_cooldown_ataque_timer = intervalo_entre_ataques
		if _objetivo_en_alcance_melee():
			# Si el objetivo sigue ahí, encadenar nuevo ataque
			_timer_ataque = 0.0
			_ha_golpeado_en_animacion = false
			_play_animation("Ataque melee", 0.1, 1.3)
		else:
			_cambiar_estado_melee(EstadoMelee.CORRIENDO)


func _process_blocking(delta: float) -> void:
	velocity.x = 0.0
	_timer_bloqueo -= delta

	if _timer_bloqueo <= 0.0:
		if _objetivo_en_alcance_melee():
			_cambiar_estado_melee(EstadoMelee.ATACANDO)
		else:
			_cambiar_estado_melee(EstadoMelee.CORRIENDO)


## Aplica el daño cuerpo a cuerpo al objetivo al frente.
func _ejecutar_golpe_garrote() -> void:
	var objetivo := _buscar_objetivo_cercano()
	if not objetivo or not is_instance_valid(objetivo):
		return

	var dist_adelante: float = (objetivo.global_position.x - global_position.x) * direccion_avance
	var dz: float = absf(global_position.z - objetivo.global_position.z)

	if dist_adelante < -0.3 or dist_adelante > alcance_melee + 0.3 or dz > margen_z_melee:
		return

	if objetivo.has_method("recibir_golpe_melee"):
		objetivo.call("recibir_golpe_melee", dano_cuerpo_a_cuerpo, self)
	elif objetivo.has_method("take_damage"):
		if "last_hit_position" in objetivo:
			objetivo.set("last_hit_position", global_position)
		if "last_hit_direction" in objetivo:
			objetivo.set("last_hit_direction", Vector3(direccion_avance, 0.0, 0.0))
		objetivo.call("take_damage", float(dano_cuerpo_a_cuerpo))
	elif objetivo.has_method("recibir_golpe"):
		objetivo.call("recibir_golpe", float(dano_cuerpo_a_cuerpo))

	_play_sfx("impacto_suelo", 0.0)


func _objetivo_en_alcance_melee() -> bool:
	var obj := _buscar_objetivo_cercano()
	if not obj or not is_instance_valid(obj):
		return false

	var dist_adelante: float = (obj.global_position.x - global_position.x) * direccion_avance
	var dz: float = absf(global_position.z - obj.global_position.z)

	return dist_adelante >= -0.3 and dist_adelante <= alcance_melee and dz <= margen_z_melee


func _buscar_objetivo_cercano() -> Node3D:
	if not is_inside_tree():
		return null

	# 1. Protagonista (solo si no es batalla cosmética o está en rango Z)
	if not is_in_group("batalla_cosmetica"):
		var player := get_tree().get_first_node_in_group("player") as Node3D
		if player and is_instance_valid(player):
			var dz_p: float = absf(global_position.z - player.global_position.z)
			if dz_p <= margen_z_melee:
				if "current_health" in player and int(player.get("current_health")) > 0:
					return player
				elif "health" in player and int(player.get("health")) > 0:
					return player

	# 2. Defensoras o aliadas (en el mismo rango Z)
	var aliados := get_tree().get_nodes_in_group("allies")
	var mas_cercano: Node3D = null
	var min_dist_x: float = INF

	for al in aliados:
		if not is_instance_valid(al) or not (al is Node3D):
			continue
		if al is StaticBody3D or al is Area3D:
			continue
		if "health" in al and int(al.get("health")) <= 0:
			continue
		var dz: float = absf(global_position.z - (al as Node3D).global_position.z)
		if dz > margen_z_melee:
			continue

		var dist_adelante: float = ((al as Node3D).global_position.x - global_position.x) * direccion_avance
		if dist_adelante >= -0.5 and dist_adelante < min_dist_x:
			min_dist_x = dist_adelante
			mas_cercano = al as Node3D

	return mas_cercano


# ═══════════════════════════════════════════════════════════════════════════════
# DAÑO Y BLOQUEO CUERPO A CUERPO
# ═══════════════════════════════════════════════════════════════════════════════

## Invocado cuando recibe un ataque cuerpo a cuerpo específico.
## Tiene 25% de probabilidad de bloquearlo por completo.
func recibir_golpe_melee(amount: float, atacante: Node = null) -> bool:
	if amount <= 0.0:
		return false
	if current_state == State.DYING or current_state == State.DEAD or estado_melee == EstadoMelee.MURIENDO or estado_melee == EstadoMelee.DEAD:
		return false

	# 25% de probabilidad de bloqueo SOLO contra ataques cuerpo a cuerpo
	var bloquea: bool = randf() <= probabilidad_bloqueo
	if bloquea:
		_bloquear_ataque(atacante)
		return true

	# Si no bloquea, recibe el daño melee
	take_damage(amount, true)
	return false


## Daño genérico. Solo activa bloqueo si es marcado explícitamente como ataque cuerpo a cuerpo.
func take_damage(amount: float, es_melee: bool = false) -> void:
	if amount <= 0.0:
		return
	if current_state == State.DYING or current_state == State.DEAD or estado_melee == EstadoMelee.MURIENDO or estado_melee == EstadoMelee.DEAD:
		return

	# Si es ataque melee y no venía previamente evaluado, puede intentar bloquear
	if es_melee and randf() <= probabilidad_bloqueo:
		_bloquear_ataque(null)
		return

	# Daño normal (flechas, explosiones, golpes no bloqueados)
	super.take_damage(amount)


func recibir_golpe(amount: float = 1.0) -> void:
	# recibir_golpe genérico trata el impacto como daño estándar
	take_damage(amount, false)


func _bloquear_ataque(atacante: Node = null) -> void:
	_cambiar_estado_melee(EstadoMelee.BLOQUEANDO)
	_play_sfx("shield_hit", 2.0)
	_flash_bloqueo()


func _flash_bloqueo() -> void:
	var flash_mat := StandardMaterial3D.new()
	flash_mat.albedo_color = Color(1.2, 1.2, 0.8, 1.0)
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for m in find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := m as MeshInstance3D
		if mesh_inst and not mesh_inst.name.contains("PartesExplotadas"):
			mesh_inst.material_override = flash_mat

	get_tree().create_timer(0.09).timeout.connect(
		func():
			if is_instance_valid(self):
				for m in find_children("*", "MeshInstance3D", true, false):
					var mesh_inst := m as MeshInstance3D
					if mesh_inst:
						mesh_inst.material_override = null
	)


# ═══════════════════════════════════════════════════════════════════════════════
# MUERTE Y DESMEMBRAMIENTO EXPLOSIVO
# ═══════════════════════════════════════════════════════════════════════════════
func _on_state_dying() -> void:
	estado_melee = EstadoMelee.MURIENDO
	if _particulas_pisada:
		_particulas_pisada.emitting = false

	if murio_por_explosion:
		_ejecutar_explosion_desmembramiento()
		return

	super._on_state_dying()
	_play_sfx("goblin_death", -0.8)

	var death_anims: Array[String] = [
		"ENEMIGO_GOBLING_MUERTE_1", "ENEMIGO_GOBLING_MUERTE_2", "ENEMIGO_GOBLING_MUERTE_3"
	]
	var chosen_death: String = death_anims[randi() % death_anims.size()]
	_play_animation(chosen_death)


## Al morir por explosión: suelta el garrote con física en lugar de la ballesta
## y desmiembra el cuerpo goblin en sus partes.
func _ejecutar_explosion_desmembramiento() -> void:
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)

	# 1. Desactivar el modelo base y sus colisiones
	var modelo_base := get_node_or_null("GOBLING_REMASTER_ANIMACIONES") as Node3D
	if modelo_base:
		for m in modelo_base.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi and not mi.name.contains("garrote"):
				mi.visible = false

	for child in find_children("*", "CollisionShape3D", true, false):
		var cs := child as CollisionShape3D
		if cs:
			cs.set_deferred("disabled", true)

	# 2. Audio de impacto y explosión
	_play_sfx("sangre_splash")
	_play_sfx("goblin_explosive_death", 2.3)

	# 3. Sangre animada
	_spawn_sangre_animada(global_position)
	if ClassDB.class_exists("VFXFactory") or has_node("/root/VFXFactory"):
		var vfx_fac = get_node_or_null("/root/VFXFactory")
		if vfx_fac and vfx_fac.has_method("spawn_ground_blood_splatter"):
			vfx_fac.call("spawn_ground_blood_splatter", self, global_position)

	# 4. Calcular dirección de impulso
	var push_dir: float = 1.0
	if last_hit_position != Vector3.ZERO:
		var dx: float = global_position.x - last_hit_position.x
		if absf(dx) > 0.05:
			push_dir = signf(dx)

	var root_scene: Node = get_tree().current_scene if (get_tree() and get_tree().current_scene) else get_parent()
	if not root_scene:
		root_scene = self

	# 5. GARROTE VOLADOR: en lugar de la ballesta, se desprende el garrote con física
	var garrote: Node3D = _garrote_nodo
	if garrote == null:
		garrote = find_child("GarroteGoblin", true, false) as Node3D

	if garrote and is_instance_valid(garrote):
		var tr_garrote: Transform3D = garrote.global_transform
		if garrote.get_parent():
			garrote.get_parent().remove_child(garrote)

		var cont_garrote := GoblinPiezaFisica.new()
		root_scene.add_child(cont_garrote)
		cont_garrote.global_transform = tr_garrote

		garrote.transform = Transform3D.IDENTITY
		garrote.visible = true
		for m in garrote.find_children("*", "MeshInstance3D", true, false):
			(m as MeshInstance3D).visible = true
			(m as MeshInstance3D).material_override = null
		cont_garrote.add_child(garrote)

		cont_garrote.iniciar_vuelo(
			Vector3(push_dir * randf_range(2.4, 4.4), randf_range(4.2, 6.2), 0.0),
			randf_range(-16.0, 16.0)
		)

	# 6. Partes desmembradas del cuerpo
	var partes_root := get_node_or_null("PartesExplotadas") as Node3D
	if partes_root:
		partes_root.visible = true

		var piernas := partes_root.get_node_or_null("Piernas") as Node3D
		if piernas:
			var tr_piernas: Transform3D = piernas.global_transform
			partes_root.remove_child(piernas)
			root_scene.add_child(piernas)
			piernas.global_transform = tr_piernas

		var piezas: Array[Node3D] = []
		var cabeza := partes_root.get_node_or_null("Cabeza") as Node3D
		var brazo1 := partes_root.get_node_or_null("Brazo_01") as Node3D
		var brazo2 := partes_root.get_node_or_null("Brazo_02") as Node3D
		if cabeza:
			piezas.append(cabeza)
		if brazo1:
			piezas.append(brazo1)
		if brazo2:
			piezas.append(brazo2)

		for pieza in piezas:
			var tr_pieza: Transform3D = pieza.global_transform
			pieza.get_parent().remove_child(pieza)

			var cont := GoblinPiezaFisica.new()
			root_scene.add_child(cont)
			cont.global_transform = tr_pieza

			pieza.transform = Transform3D.IDENTITY
			cont.add_child(pieza)

			var vel: Vector3 = Vector3(
				push_dir * randf_range(1.5, 4.0),
				randf_range(3.5, 6.5),
				randf_range(-0.5, 0.5)
			)
			cont.iniciar_vuelo(vel, randf_range(-14.0, 14.0))

	_die()


func _spawn_sangre_animada(pos: Vector3) -> void:
	var tex: Texture2D = preload("res://Entities/Enemigo_Goblin/Muerte_Explotado/Sangre_explosion.png")
	if not tex:
		return

	var sprite := Sprite3D.new()
	sprite.texture = tex
	sprite.hframes = 1
	sprite.vframes = 14
	sprite.frame = 0
	sprite.pixel_size = 0.007
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.no_depth_test = false
	sprite.render_priority = 3
	sprite.top_level = true

	var parent_node: Node = get_tree().current_scene if (get_tree() and get_tree().current_scene) else get_parent()
	if not parent_node:
		parent_node = self
	parent_node.add_child(sprite)
	sprite.global_position = pos + Vector3(0.0, 0.35, 0.0)

	var tween: Tween = sprite.create_tween()
	tween.tween_property(sprite, "frame", 13, 0.45)
	tween.tween_callback(sprite.queue_free)


# ═══════════════════════════════════════════════════════════════════════════════
# PARTÍCULAS DE PISADAS AL CORRER
# ═══════════════════════════════════════════════════════════════════════════════
func _configurar_particulas_pisada() -> void:
	if _particulas_pisada and is_instance_valid(_particulas_pisada):
		return
	_particulas_pisada = GPUParticles3D.new()
	_particulas_pisada.name = "Particulas_Pisada"
	_particulas_pisada.emitting = false
	_particulas_pisada.amount = 10
	_particulas_pisada.lifetime = 0.9
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
	mesh.size = Vector2(0.393, 0.393)
	_particulas_pisada.draw_pass_1 = mesh
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 50.0
	pm.initial_velocity_min = 0.12
	pm.initial_velocity_max = 0.3
	pm.gravity = Vector3(0.0, 0.12, 0.0)
	pm.scale_min = 0.486
	pm.scale_max = 0.788
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.096, 0.012, 0.096)
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
	var corriendo := estado_melee == EstadoMelee.CORRIENDO and velocity.length_squared() > 0.04
	_particulas_pisada.emitting = corriendo and estado_melee != EstadoMelee.MURIENDO and estado_melee != EstadoMelee.DEAD


func _play_sfx(sfx_name: String, volume_db: float = 0.0) -> void:
	if is_inside_tree() and get_tree().root.has_node("AudioManager"):
		get_tree().root.get_node("AudioManager").call("play_sfx", sfx_name, volume_db)
