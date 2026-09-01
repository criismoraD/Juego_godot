class_name Goblin
extends "res://System/Core/EnemyBase.gd"

const PROJECTILE_POOL_REF = preload("res://System/Core/ProjectilePool.gd")
const PROJECTILE_SCALE: Vector3 = Vector3.ONE
const TEXTURA_HUMO_PISADAS: Texture2D = preload("res://VFX/Textures/Smoke/Humo_Pisadas_1A-1.png")
const HUMO_PISADAS_FRAMES_H: int = 9
const HUMO_PISADAS_FRAMES_V: int = 1
var _particulas_pisada: GPUParticles3D = null

## Goblin estándar: Camina, se detiene y dispara flechas rectas con ballesta.
# === CONFIGURACIÓN ESPECÍFICA DEL GOBLIN ===
@export_category("Combate - Goblin")
@export var intervalo_disparo: float = 3.5
@export var velocidad_flecha: float = 8.0
@export var velocidad_recarga: float = 2.0  ## Multiplicador de velocidad de la animación de recarga (2.0 = doble de rápido)

@export_category("Drops - Goblin")
@export var power_up_explosivo_scene: PackedScene = preload("res://Entities/Item_Flecha_Explosiva/PowerUpFlechaExplosiva.tscn")
@export_range(0.0, 1.0, 0.01) var drop_chance_flecha_explosiva: float = 0.05  ## 5% de probabilidad de drop
## Munición que otorga EL DROP DE ESTE enemigo al jugador (excepción: 5 en vez de 10)
@export var municion_drop_jugador: int = 5

# === REFERENCIAS ESPECÍFICAS ===
var goblin_arrow_scene = preload("res://Entities/Proyectil_Flecha_Goblin/GoblinArrow.tscn")
var is_reloading: bool = false
var murio_por_explosion: bool = false
# ═══════════════════════════════════════════════════════════════════════════════
# HOOKS DE ENEMYBASE
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
	var corriendo := current_state == State.WALKING or velocity.length_squared() > 0.04
	_particulas_pisada.emitting = corriendo and current_state != State.DYING and current_state != State.DEAD


func _process(delta: float) -> void:
	super._process(delta)
	if _particulas_pisada:
		_particulas_pisada_emitir()


func _on_enemy_ready():
	_configurar_particulas_pisada()
	set_process(true)
	_play_animation("ENEMIGO_GOBLING_CORRER")


func _on_state_walking():
	_play_animation("ENEMIGO_GOBLING_CORRER")


func _on_state_shooting():
	_play_animation("ENEMIGO_GOBLING_DISPARO")
	shoot_timer = 0.5  # Pequeño delay antes del primer disparo


func _on_state_dying():
	if murio_por_explosion:
		_ejecutar_explosion_desmembramiento()
		return

	super._on_state_dying()
	AudioManager.play_sfx("goblin_death", -0.8)  # +15% vs -2.0 (≈+1.2 dB) pedido
	_drop_power_up()

	# Elegir aleatoriamente entre las 3 animaciones de muerte
	var death_anims = [
		"ENEMIGO_GOBLING_MUERTE_1", "ENEMIGO_GOBLING_MUERTE_2", "ENEMIGO_GOBLING_MUERTE_3"
	]
	var chosen_death = death_anims[randi() % death_anims.size()]

	# Girar el modelo 180 grados en Y para ocultar la cara con culling/color negro a la cámara
	if chosen_death == "ENEMIGO_GOBLING_MUERTE_2":
		$GOBLING_REMASTER_ANIMACIONES.rotate_y(PI)

	var anim_length = _get_animation_duration(chosen_death)
	_play_animation(chosen_death)

	get_tree().create_timer(anim_length + 0.5).timeout.connect(
		func():
			if is_instance_valid(self) and is_inside_tree():
				_die()
	)


func _ejecutar_explosion_desmembramiento() -> void:
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)

	var root_scene := get_tree().current_scene
	if not root_scene:
		root_scene = get_tree().root

	# 1. Ocultar modelo intacto del goblin
	var model = get_node_or_null("GOBLING_REMASTER_ANIMACIONES")
	if model:
		model.visible = false

	# 2. Reproducir audio de impacto, muerte explosiva y sangre con volumen balanceado
	AudioManager.play_sfx("sangre_splash")
	AudioManager.play_sfx("goblin_explosive_death", 2.3)  # +30% vs 0.0 (≈+2.3 dB) pedido

	# 3. Spawnear animación de sangre 2D (14 cuadros verticales de Sangre_explosion.png)
	_spawn_sangre_animada(global_position)
	VFXFactory.spawn_ground_blood_splatter(self, global_position)

	# 4. Dropear power-up si aplica
	_drop_power_up()

	# 5. Calcular dirección de expulsión según el punto de impacto de la explosión
	var push_dir: float = 1.0
	if last_hit_position != Vector3.ZERO:
		var dx: float = global_position.x - last_hit_position.x
		if abs(dx) > 0.05:
			push_dir = sign(dx)
		else:
			push_dir = 1.0

	# 5b. Ballesta: se desprende del brazo y sale volando con el resto de piezas.
	# EXCEPCIÓN oleada 5: allí la ballesta flotante molesta (aparece "de la nada"
	# entre los pilares Lonko) → desaparece junto con el modelo.
	var spawner_ref := _get_cached_wave_spawner()
	var en_oleada_5: bool = spawner_ref != null and spawner_ref.oleada_combate == 5
	var ballesta := get_node_or_null("GOBLING_REMASTER_ANIMACIONES/Armature/Skeleton3D/BoneAttachment3D/BALLES_GOBLING") as Node3D
	if ballesta and not en_oleada_5:
		var tr_ballesta: Transform3D = ballesta.global_transform
		ballesta.get_parent().remove_child(ballesta)

		var cont_ballesta := GoblinPiezaFisica.new()
		root_scene.add_child(cont_ballesta)
		cont_ballesta.global_transform = tr_ballesta

		ballesta.transform = Transform3D.IDENTITY
		ballesta.visible = true
		for m in ballesta.find_children("*", "MeshInstance3D", true, false):
			m.visible = true
			m.material_override = null
		cont_ballesta.add_child(ballesta)

		cont_ballesta.iniciar_vuelo(
			Vector3(push_dir * randf_range(2.4, 4.4), randf_range(4.2, 6.2), 0.0),
			randf_range(-16.0, 16.0)
		)

	# 6. Gestionar partes del cuerpo desmembrado
	var partes_root = get_node_or_null("PartesExplotadas") as Node3D
	if partes_root:
		partes_root.visible = true

		# A. PIERNAS: Se quedan firmes en el suelo e interactúan con flechas
		var piernas := partes_root.get_node_or_null("Piernas") as Node3D
		if piernas:
			var piernas_tr: Transform3D = piernas.global_transform
			piernas.get_parent().remove_child(piernas)

			var cont_piernas := GoblinPiezaFisica.new()
			cont_piernas.es_piernas = true
			root_scene.add_child(cont_piernas)
			cont_piernas.global_transform = piernas_tr

			piernas.transform = Transform3D.IDENTITY
			piernas.visible = true
			for m in piernas.find_children("*", "MeshInstance3D", true, false):
				m.visible = true
				m.material_override = null
			cont_piernas.add_child(piernas)

		# B. CABEZA, BRAZO_01, BRAZO_02: Salen disparadas con física e interactúan con el suelo
		var piezas_data: Array[Dictionary] = [
			{
				"nodo": partes_root.get_node_or_null("Cabeza"),
				"vel": Vector3(push_dir * randf_range(2.0, 3.8), randf_range(4.5, 6.5), 0.0),
				"rot": randf_range(-14.0, 14.0)
			},
			{
				"nodo": partes_root.get_node_or_null("Brazo_01"),
				"vel": Vector3(push_dir * randf_range(2.6, 4.8), randf_range(3.8, 5.8), 0.0),
				"rot": randf_range(-18.0, 18.0)
			},
			{
				"nodo": partes_root.get_node_or_null("Brazo_02"),
				"vel": Vector3(push_dir * randf_range(1.5, 3.2), randf_range(3.2, 4.8), 0.0),
				"rot": randf_range(-12.0, 12.0)
			}
		]

		for data in piezas_data:
			var p_nodo: Node3D = data["nodo"]
			if not p_nodo:
				continue

			var global_tr: Transform3D = p_nodo.global_transform
			p_nodo.get_parent().remove_child(p_nodo)

			# Crear contenedor físico GoblinPiezaFisica
			var contenedor := GoblinPiezaFisica.new()
			root_scene.add_child(contenedor)
			contenedor.global_transform = global_tr

			p_nodo.transform = Transform3D.IDENTITY
			p_nodo.visible = true
			for m in p_nodo.find_children("*", "MeshInstance3D", true, false):
				m.visible = true
				m.material_override = null
			contenedor.add_child(p_nodo)

			contenedor.iniciar_vuelo(data["vel"], data["rot"])

	# 7. Eliminar entidad goblin inmediatamente sin alterar las partes extraídas
	queue_free()


func _spawn_sangre_animada(pos: Vector3) -> void:
	var tex: Texture2D = preload("res://Entities/Enemigo_Goblin/Muerte_Explotado/Sangre_explosion.png")
	if not tex:
		return

	var sprite := Sprite3D.new()
	sprite.texture = tex
	sprite.vframes = 14
	sprite.hframes = 1
	sprite.frame = 0
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.render_priority = 3
	sprite.no_depth_test = false
	sprite.pixel_size = 0.0070  # Tamaño duplicado para mayor impacto visual

	var root := get_tree().current_scene
	if not root:
		root = get_tree().root
	root.add_child(sprite)
	sprite.global_position = pos + Vector3(0.0, 0.40, 0.0)

	var anim_task := func():
		for f in range(14):
			if not is_instance_valid(sprite) or not sprite.is_inside_tree():
				return
			sprite.frame = f
			await sprite.get_tree().create_timer(0.04, false).timeout
		if is_instance_valid(sprite):
			sprite.queue_free()

	anim_task.call()


func _drop_power_up() -> void:
	if not power_up_explosivo_scene:
		return
	var chance_efectiva := _get_effective_drop_chance(drop_chance_flecha_explosiva)
	if randf() > chance_efectiva:
		return
	var item := power_up_explosivo_scene.instantiate() as Node3D
	if not item:
		return
	# Excepción Goblin Ballestero: su drop solo suma 5 al contador del jugador
	if "municion_a_otorgar_jugador" in item:
		item.municion_a_otorgar_jugador = municion_drop_jugador
	var target_parent := get_tree().current_scene
	if target_parent:
		target_parent.add_child(item)
	elif get_parent():
		get_parent().add_child(item)
	item.global_position = global_position + Vector3(0.0, 0.5, 0.0)


func _get_effective_drop_chance(base_chance: float) -> float:
	# Mitiga a 5% si el jugador tiene >=30 flechas explosivas hasta bajar a <25 (histéresis en Player)
	var player := get_tree().get_first_node_in_group("player") if get_tree() else null
	if player and player.has_method("get_effective_explosive_drop_chance"):
		return player.get_effective_explosive_drop_chance(base_chance)
	if player and "flechas_explosivas" in player and "is_explosive_drop_throttled" in player:
		if player.is_explosive_drop_throttled():
			return min(base_chance, 0.05)
	# Fallback sin Player: si no hay referencia, usar base
	return base_chance


# ═══════════════════════════════════════════════════════════════════════════════
# DISPARO
# ═══════════════════════════════════════════════════════════════════════════════


func _process_shooting(delta):
	velocity.x = 0

	if rastrear_jugador:
		_track_player()

	# No contar timer mientras recarga
	if is_reloading:
		return

	shoot_timer -= delta
	if shoot_timer <= 0:
		_shoot_arrow()
		_start_reload()


func _shoot_arrow():
	if not goblin_arrow_scene:
		return

	if not player_ref:
		player_ref = get_tree().get_first_node_in_group("player")
		if not player_ref:
			return

	# No disparar si el jugador está muerto
	if player_ref.get("is_dead"):
		return

	var arrow := PROJECTILE_POOL_REF.acquire(goblin_arrow_scene) as GoblinArrowProjectile
	if not arrow:
		return

	arrow.scale = PROJECTILE_SCALE
	AudioManager.play_sfx("goblin_shoot")

	var spawn_pos = global_position + Vector3(-0.3, altura_spawn_flecha, 0)
	var target_pos = player_ref.global_position + Vector3(0, 0.5, 0)
	var direction = (target_pos - spawn_pos).normalized()

	# Calcular power para que la velocidad sea la configurada (velocidad_flecha)
	# velocidad = 10 + (30 - 10) * power  =>  power = (velocidad - 10) / 20
	var power = (velocidad_flecha - 10.0) / 20.0
	arrow.initialize(direction, power)
	arrow.speed = velocidad_flecha

	PROJECTILE_POOL_REF.activate(arrow, get_tree().root, spawn_pos)


# ═══════════════════════════════════════════════════════════════════════════════
# RECARGA
# ═══════════════════════════════════════════════════════════════════════════════


func _start_reload():
	is_reloading = true
	# Reproducir recarga con blend suave desde disparo
	_play_animation("ENEMIGO_GOBLING_RECARGA", 0.2, velocidad_recarga)

	var reload_duration = _get_animation_duration("ENEMIGO_GOBLING_RECARGA") / velocidad_recarga
	get_tree().create_timer(reload_duration - 0.2).timeout.connect(
		func():
			if is_instance_valid(self) and is_inside_tree() and current_state == State.SHOOTING:
				# Volver a disparo con blend largo para suavizar la transición
				_play_animation("ENEMIGO_GOBLING_DISPARO", 0.3)
				is_reloading = false
				shoot_timer = intervalo_disparo
	)
