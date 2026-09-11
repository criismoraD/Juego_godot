class_name CanastaCaida
extends GoblinPiezaFisica

## Canasta que cae con física y al impactar provoca muerte explosiva (5 de daño).
## Usa el mismo efecto morado que los enemigos.

const COLOR_MORADO: Color = Color(0.8, 0.2, 0.8)
const RADIO_DANO: float = 1.5
const DANO: float = 5.0
const MAX_ENEMIGOS_DANADOS: int = 6  ## Tope de enemigos aplastados por impacto de canasta
const TEXTURA_ROCAS_RES: Texture2D = preload("res://Entities/Enemigo_Lonko/ROCAS.png")
const SFX_IMPACTO_PESADO: AudioStream = preload("res://Entities/Enemigo_GloboAerostatico/Audio/Impacto_pesado.mp3")
const TEXTURA_SANGRE_DECAL: Texture2D = preload("res://Entities/Enemigo_Goblin/Muerte_Explotado/Mancha_Sangre_Suelo.png")
const TEXTURA_HUMO_CANASTA: Texture2D = preload("res://VFX/Textures/Smoke/Smoke_2A-2.png")

# === CONFIGURACIÓN - SQUASH AND STRETCH ===
@export_category("Squash and Stretch")
@export var habilitar_squash_stretch: bool = true  ## Activa deformación squash & stretch en caída libre y al impactar
@export_range(0.0, 1.0, 0.01) var stretch_maximo_caida: float = 0.55  ## Estiramiento vertical acentuado y visible al caer (hasta +55%)
@export_range(0.0, 0.80, 0.01) var squash_maximo_impacto: float = 0.55  ## Compresión vertical extrema al golpear el suelo (hasta -55% de altura)
@export var velocidad_stretch_aire: float = 14.0  ## Rapidez con la que se deforma durante la aceleración en el aire
@export var offset_entierro_suelo: float = -0.05  ## Desplazamiento vertical al impactar para enterrarse en el suelo (evita flotar)

var _area_dano: Area3D = null
var _golpeados: Dictionary = {}
var _danio_habilitado: bool = false
var _impacto_efecto_hecho: bool = false

# === ESTADO SQUASH AND STRETCH ===
var _visual_node: Node3D = null
var _original_visual_scale: Vector3 = Vector3.ONE
var _squash_stretch_current: Vector3 = Vector3.ONE
var _squash_tween: Tween = null
var _is_squash_tween_active: bool = false
var _fall_start_y: float = 0.0

func _ready() -> void:
	super._ready()
	_tiempo_para_disolver = 4.0
	_fall_start_y = global_position.y
	_obtener_nodo_visual()
	# Eliminar sombra de Canasta.glb (pedido: sin sombra)
	for mi in find_children("*", "MeshInstance3D", true, false):
		if mi is MeshInstance3D:
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for sombra in find_children("*", "SombraPersonaje", true, false):
		if is_instance_valid(sombra):
			sombra.queue_free()
	_crear_area_dano()
	# Evitar dañar globos recién spawneados en el suelo el primer frame (están a Y~0.6 antes de subir a 3.3-5.2)
	# Habilitar daño tras 0.6s cuando ya han alcanzado altura de vuelo
	get_tree().create_timer(0.6).timeout.connect(func():
		if is_instance_valid(self):
			_danio_habilitado = true
	)

func _exit_tree() -> void:
	if _squash_tween and _squash_tween.is_valid():
		_squash_tween.kill()

func iniciar_vuelo(initial_vel: Vector3, initial_rot_z: float) -> void:
	super.iniciar_vuelo(initial_vel, initial_rot_z)
	_fall_start_y = global_position.y
	_obtener_nodo_visual()

func _crear_area_dano() -> void:
	_area_dano = Area3D.new()
	_area_dano.name = "AreaDanoCanasta"
	_area_dano.monitoring = true
	_area_dano.monitorable = false
	_area_dano.collision_layer = 0
	_area_dano.collision_mask = 4
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.4, 1.0, 1.4)
	col.shape = box
	_area_dano.add_child(col)
	add_child(_area_dano)
	_area_dano.body_entered.connect(_on_body_entered)
	_area_dano.area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	_tiempo_vida += delta
	if _tiempo_vida >= _tiempo_para_disolver and not _disolviendo:
		_disolviendo = true
		iniciar_disolucion(1.2, COLOR_MORADO)

	if not active or resting or es_piernas:
		return

	_actualizar_squash_stretch_caida(delta)

	var prev_vel_y: float = velocity.y
	velocity.y -= gravity * delta
	velocity.z = 0.0
	var move_step := velocity * delta
	var target_pos := global_position + move_step
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.25, 0), target_pos)
	query.collision_mask = 1 # Solo suelo (capa 1), ignora barreras 512 para caer en cualquier parte del mapa
	if _static_body and is_instance_valid(_static_body):
		query.exclude = [_static_body.get_rid()]
	var hit := space_state.intersect_ray(query)
	var impacto_este_frame: bool = false
	var es_plataforma := false
	var es_suelo_valido := false
	if hit and hit.has("collider"):
		var col = hit["collider"]
		if col is AnimatableBody3D:
			es_plataforma = true
		elif is_instance_valid(col) and col.name.contains("Plataforma"):
			es_plataforma = true
		elif hit.has("normal") and hit["normal"] is Vector3:
			# Solo considerar impacto si la normal es de suelo (y > 0.5), no pared vertical de barrera
			es_suelo_valido = (hit["normal"] as Vector3).y > 0.5
		else:
			es_suelo_valido = true
	else:
		es_suelo_valido = true
	# Si es plataforma one-way, ignorar y caer libre en cualquier parte del escenario (no flotar)
	if hit and hit.has("position") and not es_plataforma and es_suelo_valido:
		# Enterrarse ligeramente en el suelo al impactar (sin flotar en el aire)
		global_position.y = hit.position.y + offset_entierro_suelo
		global_position.x = hit.position.x
		if not resting:
			impacto_este_frame = true
		velocity = Vector3.ZERO
		rot_speed_z = 0.0
		resting = true
		active = false
	else:
		global_position = target_pos
		# Caída libre sobre agua/vacío: dejar caer sin forzar y=0, disolverá a los 4s igualmente
		if global_position.y < -3.0 and not resting:
			impacto_este_frame = true
			velocity = Vector3.ZERO
			rot_speed_z = 0.0
			resting = true
			active = false
	if not resting:
		# Caer más recta y sin girar descontrolada (amortiguación suave de inclinación)
		rot_speed_z = move_toward(rot_speed_z, 0.0, delta * 3.0)
		rotation.z = move_toward(rotation.z, 0.0, delta * 2.0)
		rotate_z(rot_speed_z * delta)
	# Excepción: puede traspasar el límite de enemigos, pero al hacerlo pierde daño
	if _danio_habilitado and global_position.x <= _obtener_limite_enemigos_x():
		_danio_habilitado = false
		if _area_dano:
			_area_dano.monitoring = false
			_area_dano.monitorable = false
	# Daño único solo al impactar contra el suelo, no continuo durante la caída ni en reposo
	# y solo si ya está habilitado (globos recién spawneados aún en Y~0 no deben morir)
	if impacto_este_frame and not _impacto_efecto_hecho:
		_impacto_efecto_hecho = true
		var caida_dist: float = maxf(0.0, _fall_start_y - global_position.y) if _fall_start_y > global_position.y else 0.0
		_disparar_squash_impacto(prev_vel_y, caida_dist)
		_spawn_humo_y_piedras_impacto()
		if _danio_habilitado:
			_chequear_area_impacto_once()
		# Desactivar área para no seguir golpeando futuros spawns (evita explosiones en esquina)
		if _area_dano:
			_area_dano.monitoring = false
			_area_dano.monitorable = false

func _chequear_area() -> void:
	# No usado continuo para evitar explosiones espontáneas en esquina con nuevos spawns
	return

func _chequear_area_impacto_once() -> void:
	# Recolectar candidatos dentro del radio con su distancia
	var candidatos: Array = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy.is_inside_tree():
			continue
		if enemy.is_in_group("allies") or enemy.is_in_group("player"):
			continue
		# Evitar cadena infinita entre globos: la canasta no debe matar otros globos en vuelo
		if enemy is GloboAerostatico:
			continue
		var id := enemy.get_instance_id()
		if _golpeados.has(id):
			continue
		if not (enemy is Node3D):
			continue
		var dist: float = global_position.distance_to((enemy as Node3D).global_position)
		if dist <= RADIO_DANO:
			candidatos.append({"enemy": enemy, "dist": dist})
	# Aplastar como máximo a MAX_ENEMIGOS_DANADOS, priorizando los más cercanos
	candidatos.sort_custom(func(a, b): return a["dist"] < b["dist"])
	var a_aplastar: int = mini(candidatos.size(), MAX_ENEMIGOS_DANADOS - _golpeados.size())
	for i in range(a_aplastar):
		_aplicar(candidatos[i]["enemy"])

func _on_body_entered(body: Node) -> void:
	if not _danio_habilitado: return
	if _impacto_efecto_hecho: return
	if not is_instance_valid(body): return
	if body.is_in_group("allies") or body.is_in_group("player"): return
	if body is GloboAerostatico: return
	if not body.is_in_group("enemies") and not ("murio_por_explosion" in body): return
	var id := body.get_instance_id()
	if _golpeados.has(id): return
	_aplicar(body)

func _on_area_entered(area: Area3D) -> void:
	if not _danio_habilitado: return
	if _impacto_efecto_hecho: return
	var target: Node = area.get_parent() if area.get_parent() else area
	if not is_instance_valid(target): return
	if target.is_in_group("allies") or target.is_in_group("player"): return
	if target is GloboAerostatico: return
	var id := target.get_instance_id()
	if _golpeados.has(id): return
	if target.is_in_group("enemies") or ("murio_por_explosion" in target):
		_aplicar(target)

func _aplicar(enemy: Node) -> void:
	if enemy is GloboAerostatico:
		return
	# Tope de enemigos dañados por impacto: la canasta solo aplasta a 6 como máximo
	if _golpeados.size() >= MAX_ENEMIGOS_DANADOS:
		return
	var id := enemy.get_instance_id()
	_golpeados[id] = true
	if "last_hit_position" in enemy:
		enemy.set("last_hit_position", global_position)
	if "last_hit_direction" in enemy:
		enemy.set("last_hit_direction", Vector3.DOWN)
	if "murio_por_explosion" in enemy:
		enemy.set("murio_por_explosion", true)
	if enemy.has_method("take_damage"):
		enemy.call("take_damage", DANO)
	elif enemy.has_method("recibir_golpe"):
		enemy.call("recibir_golpe", DANO)
	# Mancha de sangre sobre la textura de la propia canasta (toma forma del mimbre) — no en el suelo
	_manchar_canasta_con_sangre()


func _manchar_canasta_con_sangre() -> void:
	# Decal proyectado sobre la propia canasta — la textura toma la forma del mimbre/trenzado
	var tex: Texture2D = TEXTURA_SANGRE_DECAL
	if not tex:
		return
	var meshes := find_children("*", "MeshInstance3D", true, false)
	for m in meshes:
		var mi := m as MeshInstance3D
		if not mi or not is_instance_valid(mi):
			continue
		for i in range(2):
			var decal := Decal.new()
			decal.name = "ManchaSangreCanasta_%d" % i
			decal.texture_albedo = tex
			decal.size = Vector3(0.55, 0.55, 0.22)
			decal.albedo_mix = 1.0
			decal.cull_mask = 1
			decal.distance_fade_begin = 8.0
			decal.distance_fade_length = 2.0
			mi.add_child(decal)
			# Distribuir manchas aleatorias sobre la superficie lateral/inferior de la canasta
			var offset := Vector3(randf_range(-0.18, 0.18), randf_range(0.05, 0.22), randf_range(-0.18, 0.18))
			decal.position = offset
			decal.rotation_degrees = Vector3(90 + randf_range(-18, 18), randf_range(0, 360), randf_range(-12, 12))
			# Desvanecer con la canasta (ella se disuelve a los 4s)
			var tw_d := decal.create_tween()
			tw_d.tween_interval(3.2)
			tw_d.tween_callback(decal.queue_free)

func _spawn_humo_y_piedras_impacto() -> void:
	# Humo de destrucción de escudo a ambos lados — mismo efecto pero un poco más grande (x1.25)
	VFXFactory.spawn_shield_break_smoke(self, global_position)
	_crear_humo_escalado(1.28)
	# Pequeñas piedras que rebotan - mismas que al emerger el pilar de Lonko (ROCAS.png)
	_crear_particulas_piedras_rebote()
	# Sonido Impacto pesado al golpear suelo
	_reproducir_sonido_impacto_pesado()


func _crear_particulas_piedras_rebote() -> void:
	var parts := GPUParticles3D.new()
	parts.name = "ParticulasPiedrasCanasta"
	parts.amount = 28
	parts.lifetime = 2.2
	parts.one_shot = true
	parts.explosiveness = 0.85
	var pmat := ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(0.35, 0.08, 0.35)
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 45.0
	pmat.initial_velocity_min = 2.8
	pmat.initial_velocity_max = 5.8
	pmat.gravity = Vector3(0, -11.5, 0)
	pmat.scale_min = 0.22
	pmat.scale_max = 0.48
	pmat.anim_offset_min = 0.0
	pmat.anim_offset_max = 1.0
	pmat.angle_min = 0.0
	pmat.angle_max = 360.0
	pmat.angular_velocity_min = -220.0
	pmat.angular_velocity_max = 220.0
	parts.process_material = pmat
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = TEXTURA_ROCAS_RES
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.billboard_keep_scale = true
	mat.particles_anim_h_frames = 4
	mat.particles_anim_v_frames = 1
	mat.particles_anim_loop = false
	mat.render_priority = -1
	var quad := QuadMesh.new()
	quad.size = Vector2(0.28, 0.28)
	quad.material = mat
	parts.draw_pass_1 = quad
	var root := get_tree().current_scene
	if not root:
		root = get_tree().root
	root.add_child(parts)
	parts.global_position = global_position + Vector3(0, 0.08, 0)
	parts.emitting = true
	get_tree().create_timer(3.0).timeout.connect(func():
		if is_instance_valid(parts):
			parts.queue_free()
	)


func _crear_humo_escalado(factor: float = 1.28) -> void:
	# Replica exacta del humo VFXFactory pero escalado factor ~1.28 para "un poco más grande"
	var tex: Texture2D = TEXTURA_HUMO_CANASTA
	if not tex:
		return
	var floor_pos := global_position
	var world_3d := get_world_3d()
	if world_3d and world_3d.direct_space_state:
		var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.5, 0), global_position + Vector3(0, -6, 0))
		q.collision_mask = 1
		var hit := world_3d.direct_space_state.intersect_ray(q)
		if hit and hit.has("position"):
			floor_pos = hit["position"]
	for side in [-1, 1]:
		var puf := GPUParticles3D.new()
		puf.amount = 4
		puf.lifetime = 0.75
		puf.one_shot = true
		puf.explosiveness = 0.3
		puf.randomness = 0.3
		var pmat := ParticleProcessMaterial.new()
		pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
		pmat.direction = Vector3(side * 0.85, 0.35, 0)
		pmat.spread = 20.0
		pmat.initial_velocity_min = 0.8
		pmat.initial_velocity_max = 1.6
		pmat.gravity = Vector3(0, -0.3, 0)
		pmat.scale_min = 0.55 * factor
		pmat.scale_max = 0.85 * factor
		var grad := Gradient.new()
		grad.set_color(0, Color(0.96, 0.94, 0.88, 0.85))
		grad.set_color(1, Color(0.96, 0.94, 0.88, 0.0))
		var gtex := GradientTexture1D.new()
		gtex.gradient = grad
		pmat.color_ramp = gtex
		pmat.turbulence_enabled = true
		pmat.turbulence_noise_strength = 0.008
		puf.process_material = pmat
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.vertex_color_use_as_albedo = true
		mat.albedo_texture = tex
		mat.particles_anim_h_frames = 6
		mat.particles_anim_v_frames = 1
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.billboard_keep_scale = true
		var quad := QuadMesh.new()
		quad.size = Vector2(0.8 * factor, 0.8 * factor)
		quad.material = mat
		puf.draw_pass_1 = quad
		var root := get_tree().current_scene
		if not root:
			root = get_tree().root
		root.add_child(puf)
		puf.global_position = floor_pos + Vector3(side * 0.25, 0.04, 0)
		puf.emitting = true
		var tw_puf := puf.create_tween()
		tw_puf.tween_interval(1.2)
		tw_puf.tween_callback(puf.queue_free)

func _reproducir_sonido_impacto_pesado() -> void:
	if not SFX_IMPACTO_PESADO:
		push_warning("[CanastaCaida] SFX Impacto pesado nulo")
		return
	var player := AudioStreamPlayer.new()
	player.stream = SFX_IMPACTO_PESADO
	player.volume_db = -4.0
	player.bus = "Master"
	var root: Node = get_tree().current_scene
	if not root:
		root = get_tree().root
	root.add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


func _obtener_limite_enemigos_x() -> float:
	var barreras := get_tree().get_nodes_in_group("barrera_limite")
	var limite: float = -20.0
	for b in barreras:
		if b is Node3D:
			limite = max(limite, (b as Node3D).global_position.x)
	return limite


# ==============================================================================
# SQUASH AND STRETCH - CAÍDA Y ATERRIZAJE
# ==============================================================================

const VELOCIDAD_CAIDA_MAX_REF: float = 12.0
const DISTANCIA_CAIDA_MAX_REF: float = 3.0
const COMPRESION_MIN_IMPACTO: float = 0.30
const DURACION_HOLD_SQUASH: float = 0.05
const DURACION_REBOTE_SQUASH: float = 0.12
const DURACION_AMORTIGUACION_SQUASH: float = 0.08
const DURACION_ASENTAMIENTO_SQUASH: float = 0.10
const DURACION_ENDEREZADO_ROT_Z: float = 0.12

func set_visual_node(nodo: Node3D) -> void:
	_visual_node = nodo
	if _visual_node and is_instance_valid(_visual_node):
		_original_visual_scale = _visual_node.scale
		_squash_stretch_current = Vector3.ONE


func _obtener_nodo_visual() -> Node3D:
	if _visual_node and is_instance_valid(_visual_node):
		return _visual_node
	for child in get_children():
		if child is Node3D and child != _area_dano and child != _static_body and not child is Area3D:
			if not child.name.begins_with("Mancha") and not child.name.begins_with("Particulas"):
				_visual_node = child as Node3D
				_original_visual_scale = _visual_node.scale
				_squash_stretch_current = Vector3.ONE
				return _visual_node
	return null


func _aplicar_escala_modelo(factor: Vector3) -> void:
	_squash_stretch_current = factor
	var visual: Node3D = _obtener_nodo_visual()
	if visual and is_instance_valid(visual):
		visual.scale = _original_visual_scale * factor


func _actualizar_squash_stretch_caida(delta: float) -> void:
	if not habilitar_squash_stretch:
		return
	var visual: Node3D = _obtener_nodo_visual()
	if not visual or not is_instance_valid(visual):
		return
	if _is_squash_tween_active:
		return

	var target_factor: Vector3 = Vector3.ONE

	if active and not resting:
		# Estiramiento vertical exagerado en caída libre (con adelgazamiento X/Z para conservar volumen)
		if velocity.y < -0.5:
			var vel_descenso: float = -velocity.y
			var dist_caida: float = maxf(0.0, _fall_start_y - global_position.y) if _fall_start_y > global_position.y else 0.0
			var ratio_vel: float = clampf((vel_descenso - 0.5) / VELOCIDAD_CAIDA_MAX_REF, 0.0, 1.0)
			var ratio_dist: float = clampf(dist_caida / DISTANCIA_CAIDA_MAX_REF, 0.0, 1.0)
			var ratio: float = maxf(ratio_vel, ratio_dist)
			# Curva smoothstep para transición elástica orgánica
			var factor_suave: float = ratio * ratio * (3.0 - 2.0 * ratio)
			var sy: float = 1.0 + factor_suave * stretch_maximo_caida
			var sxz: float = 1.0 / sqrt(sy)
			target_factor = Vector3(sxz, sy, sxz)

	_squash_stretch_current = _squash_stretch_current.lerp(target_factor, clampf(velocidad_stretch_aire * delta, 0.0, 1.0))
	_aplicar_escala_modelo(_squash_stretch_current)


func _disparar_squash_impacto(vel_y_impacto: float, dist_caida: float) -> void:
	if not habilitar_squash_stretch:
		return
	var visual: Node3D = _obtener_nodo_visual()
	if not visual or not is_instance_valid(visual):
		return

	if _squash_tween and _squash_tween.is_valid():
		_squash_tween.kill()

	_is_squash_tween_active = true

	var velocidad_impacto: float = -vel_y_impacto
	var t_vel: float = clampf((velocidad_impacto - 1.0) / VELOCIDAD_CAIDA_MAX_REF, 0.0, 1.0)
	var t_dist: float = clampf(dist_caida / DISTANCIA_CAIDA_MAX_REF, 0.0, 1.0)
	var t: float = maxf(t_vel, t_dist)
	var t_suave: float = t * t * (3.0 - 2.0 * t)

	# Compresión vertical exagerada al chocar contra el suelo
	var compresion: float = lerpf(COMPRESION_MIN_IMPACTO, squash_maximo_impacto, t_suave)
	var squash_y: float = 1.0 - compresion
	var squash_xz: float = 1.0 / sqrt(squash_y)

	# Rebote elástico enérgico hacia arriba (overshoot)
	var rebote_y: float = 1.0 + lerpf(0.15, 0.28, t_suave)
	var rebote_xz: float = 1.0 / sqrt(rebote_y)

	# Micro amortiguación secundaria
	var asentamiento_y: float = 1.0 - (compresion * 0.18)
	var asentamiento_xz: float = 1.0 / sqrt(asentamiento_y)

	var squash_val := Vector3(squash_xz, squash_y, squash_xz)
	var rebote_val := Vector3(rebote_xz, rebote_y, rebote_xz)
	var asentamiento_val := Vector3(asentamiento_xz, asentamiento_y, asentamiento_xz)

	# En el impacto exacto, aplicar deformación máxima de squash
	_aplicar_escala_modelo(squash_val)

	# Enderezar la inclinación Z suavemente para que repose plana en el suelo
	var tw_rot := create_tween()
	tw_rot.tween_property(self, "rotation:z", 0.0, DURACION_ENDEREZADO_ROT_Z).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_squash_tween = create_tween()
	# 1. Congelar brevemente en squash para máxima legibilidad visual (0.05s)
	_squash_tween.tween_interval(DURACION_HOLD_SQUASH)
	# 2. Rebote elástico enérgico hacia arriba con overshoot (0.12s)
	_squash_tween.tween_method(_aplicar_escala_modelo, squash_val, rebote_val, DURACION_REBOTE_SQUASH).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 3. Micro amortiguación secundaria (0.08s)
	_squash_tween.tween_method(_aplicar_escala_modelo, rebote_val, asentamiento_val, DURACION_AMORTIGUACION_SQUASH).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# 4. Asentamiento final a la escala normal (0.10s)
	_squash_tween.tween_method(_aplicar_escala_modelo, asentamiento_val, Vector3.ONE, DURACION_ASENTAMIENTO_SQUASH).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_squash_tween.tween_callback(func():
		_is_squash_tween_active = false
		_squash_stretch_current = Vector3.ONE
		_aplicar_escala_modelo(Vector3.ONE)
	)


func _reset_squash_stretch() -> void:
	if _squash_tween and _squash_tween.is_valid():
		_squash_tween.kill()
	_is_squash_tween_active = false
	_squash_stretch_current = Vector3.ONE
	_aplicar_escala_modelo(Vector3.ONE)
