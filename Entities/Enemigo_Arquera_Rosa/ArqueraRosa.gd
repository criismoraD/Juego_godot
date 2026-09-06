class_name ArqueraRosa
extends "res://System/Core/EnemyBase.gd"

signal aparicion_en_pantalla(goblin: Node)

## Arquera Rosa: Variante élite de la goblin arquera con textura rosada y rango medio-largo.
## Habilidades:
## 1. Aura Rosada (BasicAreaVFX_04) con sonido continuo de Aura mientras esté activo.
##    Repele hasta 4 proyectiles normales con sonido Parry y pierde intensidad al recibir daño.
##    Al romperse emite nubes de humo rosado a ambos lados y detiene el sonido de aura.
##    Las flechas explosivas ignoran la repulsión y detonan directamente.
## 2. Tensado de arco completo sincronizado con la animación antes de soltar la ráfaga.
## 3. Flechas idénticas al modelo de la protagonista pero teñidas de color rosado brillante con estela mágica.
## 4. Ataque de Disparo Múltiple de 5 flechas consecutivas.
## 5. Reposicionamiento táctico: avanza hacia adelante tras disparar y vuelve a disparar.
## 6. Drop del 100% del power-up de disparo múltiple al morir con efecto de disolución rosado.

const PROJECTILE_POOL_REF = preload("res://System/Core/ProjectilePool.gd")
const PROJECTILE_SCALE: Vector3 = Vector3.ONE
const AURA_SOUND: AudioStream = preload("res://System/Audio/SFX/Aura.mp3")

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS & CONFIGURACIÓN
# ═══════════════════════════════════════════════════════════════════════════════

@export_category("Aura Rosada")
@export var aura_max_vida: int = 4  ## Cantidad de proyectiles que resiste el aura antes de romperse
@export var color_aura_primario: Color = Color(1.0, 0.45, 0.8, 1.0)
@export var color_aura_secundario: Color = Color(0.9, 0.15, 0.65, 1.0)
@export var color_aura_luz: Color = Color(1.0, 0.3, 0.75, 1.0)

@export_category("Combate - Arquera Rosa")
@export var tiempo_tensa_arco: float = 3.1  ## Tiempo que dura tensando el arco para completar la animación antes de soltar la ráfaga
@export var intervalo_disparo: float = 2.5  ## Tiempo de recarga entre ráfagas
@export var velocidad_flecha: float = 9.0  ## Velocidad de los proyectiles
@export var cantidad_flechas_rafaga: int = 5  ## Cantidad de flechas por ráfaga (exactamente 5)
@export var intervalo_flechas_rafaga: float = 0.07  ## Intervalo rápido en segundos entre flechas
@export var poder_disparo_spread: float = 0.03  ## Dispersión angular de la ráfaga
@export var potencia_disparo_min: float = 1.0
@export var potencia_disparo_max: float = 1.8

@export_category("Reposicionamiento")
@export var distancia_reposicion_min: float = 0.6  ## Distancia mínima que avanza para reposicionarse
@export var distancia_reposicion_max: float = 1.2  ## Distancia máxima que avanza para reposicionarse
@export var pausa_post_disparo: float = 0.4  ## Pausa antes de iniciar reposicionamiento

@export_category("Drops")
@export var power_up_multiple_scene: PackedScene = preload("res://Entities/Item_Flecha_Multiple/PowerUpFlechaMultiple.tscn")
@export var drop_chance_flecha_multiple: float = 1.0  ## 100% de drop garantizado

# ═══════════════════════════════════════════════════════════════════════════════
# ESTADO Y REFERENCIAS
# ═══════════════════════════════════════════════════════════════════════════════

var aura_vida: int = 4
var aura_vfx_node: Node3D = null
var aura_anim_player: AnimationPlayer = null
var aura_audio_player: AudioStreamPlayer3D = null

var is_shooting_burst: bool = false
var esta_reposicionando: bool = false
var distancia_reposicion_objetivo: float = 0.0
var distancia_reposicion_caminada: float = 0.0
var drop_realizado: bool = false

var goblin_arrow_scene: PackedScene = preload("res://Entities/Proyectil_Flecha_Arquera_Rosa/RosaArrow.tscn")
var bow_anim_player: AnimationPlayer = null
var flecha_visual_mano: Node3D = null
var _pose_base_flecha_mano: Transform3D = Transform3D.IDENTITY
var _aparecio_en_pantalla: bool = false
var _tiempo_desde_spawn: float = 0.0

# ═══════════════════════════════════════════════════════════════════════════════
# INICIALIZACIÓN
# ═══════════════════════════════════════════════════════════════════════════════

func _on_enemy_ready() -> void:
	color_borde_disolucion = Color(1.0, 0.25, 0.75)  # Efecto de disolución y partículas rosado
	health = vida_maxima
	aura_vida = aura_max_vida

	# Aplicar textura rosada a la malla del personaje
	var mat_rosa: Material = load("res://Entities/Enemigo_Arquera_Rosa/MAT_ARQUERA_ROSA.tres")
	if mat_rosa:
		for child: Node in find_children("*", "MeshInstance3D", true, false):
			var mesh_inst := child as MeshInstance3D
			if not mesh_inst:
				continue
			if mesh_inst.find_parent("ARCO_GOBLING_GIRL") != null or mesh_inst.find_parent("FlechaMano") != null or mesh_inst.find_parent("BasicAreaVFX_04") != null:
				continue
			mesh_inst.material_override = mat_rosa

	_setup_aura_vfx()
	_configurar_flecha_visual_mano()
	_actualizar_visibilidad_flecha_mano(false)

	# Buscar AnimationPlayer del arco
	var bow_node := find_child("ARCO_GOBLING_GIRL", true, false)
	if bow_node:
		var bow_players := bow_node.find_children("*", "AnimationPlayer", true, false)
		if not bow_players.is_empty():
			bow_anim_player = bow_players[0] as AnimationPlayer

	# Verificar que anim_player es el principal del personaje
	if anim_player and not _has_main_animation(anim_player):
		var all_players := find_children("*", "AnimationPlayer", true, false)
		for player: Node in all_players:
			var ap := player as AnimationPlayer
			if ap and ap != bow_anim_player and _has_main_animation(ap):
				anim_player = ap
				break

	if anim_player:
		for anim_name_full: StringName in anim_player.get_animation_list():
			if "CAMINA" in String(anim_name_full) or "CAMINAR" in String(anim_name_full):
				var anim := anim_player.get_animation(anim_name_full)
				if anim:
					anim.loop_mode = Animation.LOOP_LINEAR

	_play_animation("GIRL_GOB_CAMINA")
	_play_bow_animation("ARCO_IDLE")

	_aparecio_en_pantalla = false
	_tiempo_desde_spawn = 0.0


## Retorna true si la goblin rosada está visible dentro de la pantalla
func esta_en_pantalla(margen_seguro_px: float = 60.0) -> bool:
	if not is_inside_tree():
		return false

	# Ignorar si está en origen o no ha sido posicionada en el mundo por el spawner
	if global_position == Vector3.ZERO or (absf(global_position.x) < 0.01 and absf(global_position.z) < 0.01):
		return false

	# El spawner en NIVEL01 y NIVEL_TUTORIAL se ubica en X >= 4.7.
	# El borde de pantalla derecho está en X ~4.22. Si X > 4.15, sigue fuera del campo visual.
	if global_position.x > 4.15:
		return false

	var cam := CameraUtils.obtener_camara_juego(self)
	if not cam or not is_instance_valid(cam):
		return global_position.x <= 3.8

	var pos_cuerpo := global_position + Vector3(0.0, 0.8, 0.0)
	if cam.is_position_behind(pos_cuerpo):
		return false

	var screen_pos := cam.unproject_position(pos_cuerpo)
	var vp := cam.get_viewport() if is_instance_valid(cam) else get_viewport()
	var vp_rect := vp.get_visible_rect() if vp else Rect2(0, 0, 1920, 1080)
	var rect_seguro := vp_rect.grow(-margen_seguro_px)

	return rect_seguro.has_point(screen_pos)


func _notificar_aparicion_en_pantalla() -> void:
	if _aparecio_en_pantalla:
		return
	_aparecio_en_pantalla = true
	aparicion_en_pantalla.emit(self)
	if is_inside_tree() and get_tree():
		var scene := get_tree().current_scene
		if scene and scene.has_method("_on_goblin_rosada_en_pantalla"):
			scene._on_goblin_rosada_en_pantalla(self)
		elif scene and scene.has_method("_on_goblin_rosada_aparecida"):
			scene._on_goblin_rosada_aparecida(self)


func _process(delta: float) -> void:
	super._process(delta)
	_tiempo_desde_spawn += delta
	# Esperar al menos 0.2s tras spawnear para asegurar que fue posicionada por el spawner
	if _tiempo_desde_spawn < 0.2:
		return
	if not _aparecio_en_pantalla and esta_en_pantalla():
		_notificar_aparicion_en_pantalla()


func _setup_aura_vfx() -> void:
	aura_vfx_node = find_child("BasicAreaVFX_04", true, false) as Node3D
	if not aura_vfx_node:
		var aura_scene := preload("res://assets/BinbunVFX/magic_areas/effects/basic_area/basic_area_vfx_04.tscn")
		if aura_scene:
			aura_vfx_node = aura_scene.instantiate() as Node3D
			add_child(aura_vfx_node)
			aura_vfx_node.position = Vector3(0.0, 0.01, 0.0)

	if aura_vfx_node:
		aura_vfx_node.scale = Vector3(0.65, 0.65, 0.65)
		aura_vfx_node.set("primary_color", color_aura_primario)
		aura_vfx_node.set("secondary_color", color_aura_secundario)
		aura_vfx_node.set("light_color", color_aura_luz)
		aura_anim_player = aura_vfx_node.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if aura_anim_player and aura_anim_player.has_animation("main"):
			aura_anim_player.play("main")

	# Reproductor de audio continuo del aura protectora
	if not aura_audio_player:
		aura_audio_player = AudioStreamPlayer3D.new()
		aura_audio_player.name = "AuraAudioPlayer"
		aura_audio_player.stream = AURA_SOUND
		aura_audio_player.unit_size = 25.0
		aura_audio_player.max_db = 6.0
		aura_audio_player.volume_db = 2.0
		aura_audio_player.bus = "Master"
		aura_audio_player.finished.connect(func() -> void:
			if is_instance_valid(aura_audio_player) and aura_vida > 0 and is_inside_tree() and current_state != State.DYING and current_state != State.DEAD:
				aura_audio_player.play()
		)
		add_child(aura_audio_player)
		aura_audio_player.play()


# ═══════════════════════════════════════════════════════════════════════════════
# INTERACCIÓN CON EL AURA ROSADA (REPULSIÓN Y REDUCCIÓN DE INTENSIDAD)
# ═══════════════════════════════════════════════════════════════════════════════

## Devuelve true si el proyectil fue repelido/desviado por el aura
func manejar_impacto_aura(flecha: Node) -> bool:
	if aura_vida <= 0:
		return false  # Aura rota, pasa daño normal

	# Si es flecha explosiva, penetra / detona inmediatamente y rompe el aura
	if flecha and ("es_explosiva" in flecha and flecha.es_explosiva):
		_romper_aura()
		return false

	# Flecha normal: se absorbe un impacto y se repele
	aura_vida -= 1
	AudioManager.play_sfx("parry")
	_actualizar_intensidad_aura()

	if aura_vida <= 0:
		_romper_aura()

	return true


func _actualizar_intensidad_aura() -> void:
	if not aura_vfx_node or not is_instance_valid(aura_vfx_node):
		return

	var ratio: float = clampf(float(aura_vida) / float(aura_max_vida), 0.0, 1.0)
	var target_scale := Vector3(0.65, 0.65, 0.65) * (0.35 + 0.65 * ratio)

	var tween := create_tween()
	tween.tween_property(aura_vfx_node, "scale", target_scale, 0.2).set_ease(Tween.EASE_OUT)

	var light_node := aura_vfx_node.find_child("Light", true, false) as OmniLight3D
	if light_node:
		tween.parallel().tween_property(light_node, "light_energy", 4.0 * ratio, 0.2)

	if aura_audio_player and is_instance_valid(aura_audio_player):
		var target_db: float = lerpf(-8.0, 2.0, ratio)
		var tween_audio := create_tween()
		tween_audio.tween_property(aura_audio_player, "volume_db", target_db, 0.2)

	if aura_anim_player and aura_anim_player.has_animation("main"):
		aura_anim_player.stop()
		aura_anim_player.play("main")


func _romper_aura() -> void:
	aura_vida = 0
	AudioManager.play_sfx("shield_break", 5.0)

	_spawn_smoke_aura_break()

	if aura_audio_player and is_instance_valid(aura_audio_player):
		var tween_audio := create_tween()
		tween_audio.tween_property(aura_audio_player, "volume_db", -40.0, 0.2)
		tween_audio.tween_callback(func() -> void:
			if is_instance_valid(aura_audio_player):
				aura_audio_player.stop()
		)

	if aura_vfx_node and is_instance_valid(aura_vfx_node):
		var tween := create_tween()
		tween.tween_property(aura_vfx_node, "scale", Vector3(1.2, 0.05, 1.2), 0.2).set_ease(Tween.EASE_OUT)
		tween.tween_callback(func() -> void:
			if is_instance_valid(aura_vfx_node):
				aura_vfx_node.visible = false
		)


func _spawn_smoke_aura_break() -> void:
	var tex: Texture2D = load("res://VFX/Textures/Smoke/Smoke_2A-2.png") as Texture2D
	if not tex:
		return

	var root_scene := get_tree().current_scene
	if not root_scene:
		root_scene = get_tree().root

	for side in [-1, 1]:
		var puf: GPUParticles3D = GPUParticles3D.new()
		puf.amount = 4
		puf.lifetime = 0.75
		puf.one_shot = true
		puf.explosiveness = 0.3
		puf.randomness = 0.3
		puf.visibility_aabb = AABB(Vector3(-1.5, -1.2, -1.5), Vector3(3, 3, 3))

		var pmat: ParticleProcessMaterial = ParticleProcessMaterial.new()
		pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
		pmat.direction = Vector3(side * 0.8, 0.35, 0.0)
		pmat.spread = 22.0
		pmat.initial_velocity_min = 0.8
		pmat.initial_velocity_max = 1.4
		pmat.gravity = Vector3(0.0, -0.3, 0.0)
		pmat.scale_min = 0.55
		pmat.scale_max = 0.85
		pmat.anim_speed_min = 0.9
		pmat.anim_speed_max = 1.1

		var grad: Gradient = Gradient.new()
		grad.set_color(0, Color(1.0, 0.35, 0.8, 0.9))
		grad.set_color(1, Color(1.0, 0.15, 0.65, 0.0))

		var grad_tex: GradientTexture1D = GradientTexture1D.new()
		grad_tex.gradient = grad
		pmat.color_ramp = grad_tex
		pmat.turbulence_enabled = true
		pmat.turbulence_noise_strength = 0.01

		puf.process_material = pmat

		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.vertex_color_use_as_albedo = true
		mat.albedo_color = Color(1.0, 0.5, 0.85)
		mat.albedo_texture = tex
		mat.particles_anim_h_frames = 6
		mat.particles_anim_v_frames = 1
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.billboard_keep_scale = true

		var quad: QuadMesh = QuadMesh.new()
		quad.size = Vector2(0.85, 0.85)
		quad.material = mat
		puf.draw_pass_1 = quad

		root_scene.add_child(puf)
		puf.global_position = global_position + Vector3(side * 0.3, 0.05, 0.0)
		puf.emitting = true
		puf.layers = 1048575

		get_tree().create_timer(1.3, false).timeout.connect(func() -> void:
			if is_instance_valid(puf):
				puf.queue_free()
		)


# ═══════════════════════════════════════════════════════════════════════════════
# FÍSICA Y MOVIMIENTO (CAMINATA Y REPOSICIONAMIENTO)
# ═══════════════════════════════════════════════════════════════════════════════

func _process_walking(delta: float) -> void:
	if modo_pacifico:
		velocity.x = -velocidad_caminar
		walked_distance += velocidad_caminar * delta
		if global_position.x <= limite_pacifico_x:
			velocity.x = 0
			if not pacifico_detenido:
				pacifico_detenido = true
				_on_pacifico_detenido()
		return

	# Límite infranqueable de la isla enemiga
	var limite_izq: float = _obtener_limite_izquierdo_x()
	if global_position.x <= limite_izq:
		velocity.x = 0
		global_position.x = max(global_position.x, limite_izq)
		esta_reposicionando = false
		_change_state(State.SHOOTING)
		return

	velocity.x = -velocidad_caminar

	if esta_reposicionando:
		distancia_reposicion_caminada += velocidad_caminar * delta
		if distancia_reposicion_caminada >= distancia_reposicion_objetivo or global_position.x - 0.2 <= limite_izq:
			esta_reposicionando = false
			velocity.x = 0
			_change_state(State.SHOOTING)
	else:
		walked_distance += velocidad_caminar * delta
		if walked_distance >= target_walk_distance:
			if _check_spacing():
				_change_state(State.SHOOTING)
			else:
				if global_position.x - 0.3 > limite_izq:
					target_walk_distance += 0.3
				else:
					_change_state(State.SHOOTING)


func _on_state_walking() -> void:
	is_shooting_burst = false
	_actualizar_visibilidad_flecha_mano(false)
	_play_animation("GIRL_GOB_CAMINA")
	_play_bow_animation("ARCO_IDLE")


func _on_state_shooting() -> void:
	velocity.x = 0
	_iniciar_ciclo_disparo()


# ═══════════════════════════════════════════════════════════════════════════════
# CICLO DE DISPARO (TENSADO + 5 FLECHAS + REPOSICIONAMIENTO)
# ═══════════════════════════════════════════════════════════════════════════════

func _process_shooting(_delta: float) -> void:
	velocity.x = 0.0
	if rastrear_jugador:
		_track_player()


func _iniciar_ciclo_disparo() -> void:
	if is_shooting_burst or current_state != State.SHOOTING:
		return

	if not player_ref or not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player")
		if not player_ref:
			return

	if player_ref.get("is_dead"):
		return

	is_shooting_burst = true

	# 1. Fase de Tensado del Arco Normal (completa la animación antes de soltar la ráfaga)
	_play_animation("GIRL_GOB_DISPARO")
	_play_bow_animation("ARCO_TENSAR")
	_actualizar_visibilidad_flecha_mano(true)

	await get_tree().create_timer(tiempo_tensa_arco, false).timeout
	if not is_instance_valid(self) or not is_inside_tree() or current_state != State.SHOOTING:
		is_shooting_burst = false
		return

	# 2. Fase de Disparo de exactamente 5 flechas rosadas en sucesión
	_play_bow_animation("ARCO_DISPARO")

	for i in range(cantidad_flechas_rafaga):
		if not is_instance_valid(self) or not is_inside_tree() or current_state != State.SHOOTING:
			break
		if player_ref and player_ref.get("is_dead"):
			break

		_disparar_flecha_individual()

		if i < cantidad_flechas_rafaga - 1:
			await get_tree().create_timer(intervalo_flechas_rafaga, false).timeout

	_actualizar_visibilidad_flecha_mano(false)
	_play_bow_animation("ARCO_IDLE")
	is_shooting_burst = false

	# 3. Pausa post-disparo antes de avanzar
	if is_instance_valid(self) and is_inside_tree() and current_state == State.SHOOTING:
		await get_tree().create_timer(pausa_post_disparo, false).timeout
		if is_instance_valid(self) and is_inside_tree() and current_state == State.SHOOTING:
			_iniciar_reposicionamiento()


func _disparar_flecha_individual() -> void:
	if not goblin_arrow_scene:
		return
	if not is_instance_valid(player_ref):
		player_ref = get_tree().get_first_node_in_group("player")
		if not player_ref:
			return

	var arrow := PROJECTILE_POOL_REF.acquire(goblin_arrow_scene) as RosaArrowProjectile
	if not arrow:
		return

	arrow.scale = PROJECTILE_SCALE
	AudioManager.play_sfx("goblin_girl_shoot")

	var spawn_pos: Vector3
	if flecha_visual_mano and is_instance_valid(flecha_visual_mano) and flecha_visual_mano.visible:
		spawn_pos = flecha_visual_mano.global_position
	else:
		spawn_pos = global_position + Vector3(-0.3, altura_spawn_flecha, 0.0)

	var target_pos: Vector3 = player_ref.global_position + Vector3(0.0, 0.35, 0.0)
	var diff: Vector3 = target_pos - spawn_pos
	var horizontal_dist: float = absf(diff.x)

	# Arco parabólico equilibrado: compensación suave de altura para impacto directo
	var arc_compensation: float = clampf(horizontal_dist * 0.10, 0.08, 0.32)
	var base_direction: Vector3 = diff.normalized()
	var launch_direction: Vector3 = Vector3(base_direction.x, base_direction.y + arc_compensation, 0.0).normalized()

	var spread := Vector3(
		randf_range(-poder_disparo_spread, poder_disparo_spread),
		randf_range(-poder_disparo_spread, poder_disparo_spread),
		0.0
	)
	var dir: Vector3 = (launch_direction + spread).normalized()
	var potencia: float = randf_range(potencia_disparo_min, potencia_disparo_max)

	arrow.initialize(dir, potencia)
	PROJECTILE_POOL_REF.activate(arrow, get_tree().root, spawn_pos)


func _iniciar_reposicionamiento() -> void:
	var limite_izq: float = _obtener_limite_izquierdo_x()
	# Si ya estamos en el límite de la isla, no podemos avanzar más: recargar y volver a disparar
	if global_position.x <= limite_izq + 0.35:
		await get_tree().create_timer(intervalo_disparo, false).timeout
		if is_instance_valid(self) and is_inside_tree() and current_state == State.SHOOTING:
			_iniciar_ciclo_disparo()
		return

	distancia_reposicion_objetivo = randf_range(distancia_reposicion_min, distancia_reposicion_max)
	distancia_reposicion_caminada = 0.0
	esta_reposicionando = true
	_change_state(State.WALKING)


# ═══════════════════════════════════════════════════════════════════════════════
# DAÑO, MUERTE & DROP DEL 100%
# ═══════════════════════════════════════════════════════════════════════════════

func take_damage(amount: float) -> void:
	if current_state == State.DYING or current_state == State.DEAD:
		return
	_actualizar_visibilidad_flecha_mano(false)
	super.take_damage(amount)


func _on_state_dying() -> void:
	if aura_audio_player and is_instance_valid(aura_audio_player):
		aura_audio_player.stop()

	if aura_vfx_node and is_instance_valid(aura_vfx_node):
		aura_vfx_node.visible = false

	_dropear_power_up_multiple()
	_actualizar_visibilidad_flecha_mano(false)
	super._on_state_dying()
	AudioManager.play_sfx("goblin_girl_death")

	# Animaciones reales de muerte
	var death_anims: Array[String] = ["MUERTE1", "MUERTE2", "MUERTE3"]
	var chosen_death: String = death_anims[randi() % death_anims.size()]
	var anim_length: float = _get_animation_duration(chosen_death)
	_play_animation(chosen_death)
	_play_bow_animation("ARCO_IDLE")

	get_tree().create_timer(anim_length + 0.5).timeout.connect(
		func() -> void:
			if is_instance_valid(self) and is_inside_tree():
				_die()
	)


func _exit_tree() -> void:
	if aura_audio_player and is_instance_valid(aura_audio_player):
		aura_audio_player.stop()
	super._exit_tree()


## Umbral de munición múltiple de la protagonista:
## - Con 3 o menos: el drop del power-up es 100% garantizado.
## - Con más de 3: el drop baja a 15%.
const UMBRAL_MUNICION_MULTIPLE_DROP: int = 3
const DROP_CHANCE_MUNICION_ALTA: float = 0.15


func _dropear_power_up_multiple() -> void:
	if drop_realizado:
		return
	drop_realizado = true

	if not power_up_multiple_scene:
		return

	# Histéresis de drop según munición múltiple de la protagonista
	var player := get_tree().get_first_node_in_group("player")
	if is_instance_valid(player) and "flechas_multiples" in player:
		if int(player.flechas_multiples) > UMBRAL_MUNICION_MULTIPLE_DROP:
			if randf() > DROP_CHANCE_MUNICION_ALTA:
				return

	var power_up = power_up_multiple_scene.instantiate()
	if not power_up:
		return

	var scene_root := get_tree().current_scene
	if not scene_root:
		scene_root = get_tree().root
	scene_root.add_child(power_up)
	power_up.global_position = global_position + Vector3(0.0, 0.4, 0.0)


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS DE ANIMACIÓN Y ARCO
# ═══════════════════════════════════════════════════════════════════════════════

func _has_main_animation(player: AnimationPlayer) -> bool:
	if not player:
		return false
	for a: StringName in player.get_animation_list():
		if "GIRL_GOB" in String(a) or "CAMINA" in String(a):
			return true
	return false


func _play_bow_animation(anim_name: String) -> void:
	if not bow_anim_player:
		return
	for a: StringName in bow_anim_player.get_animation_list():
		if anim_name.to_lower() in String(a).to_lower():
			bow_anim_player.play(a)
			return


func _configurar_flecha_visual_mano() -> void:
	flecha_visual_mano = find_child("FlechaMano", true, false) as Node3D
	if flecha_visual_mano:
		_pose_base_flecha_mano = flecha_visual_mano.transform


func _actualizar_visibilidad_flecha_mano(p_visible: bool) -> void:
	if flecha_visual_mano and is_instance_valid(flecha_visual_mano):
		flecha_visual_mano.visible = p_visible
		if p_visible:
			flecha_visual_mano.transform = _pose_base_flecha_mano
