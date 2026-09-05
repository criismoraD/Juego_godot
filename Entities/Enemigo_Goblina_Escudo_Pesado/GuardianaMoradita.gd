class_name GuardianaMoradita
extends CharacterBody3D

## Enemigo Guardiana Moradita (Clase Guardian).
## Entra corriendo a gran velocidad con humo de pisadas, busca posicionarse
## delante de sus aliados para cubrirlos con su Escudo Pesado.
## Lanza un potente tridente al llegar y cada vez que se reposiciona.
## Comparte 15 HP con su escudo, recibe el bono contra estructuras de la flecha
## explosiva, sufre +5 de daño si es golpeada en plena animación de ataque y no huye.

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTES Y ENUMS
# ═══════════════════════════════════════════════════════════════════════════════
enum State { RUNNING, ATTACKING, DEFENDING, SHIELD_HIT, DYING, DEAD, TURNING }

const VULNERABILIDAD_ATAQUE_DANO_EXTRA: float = 5.0
const VIDA_MAXIMA_DEFAULT: int = 10
const VELOCIDAD_CARRERA_DEFAULT: float = 1.8
const DISTANCIA_PROTECCION_DEFAULT: float = 0.65
const POTENCIA_TRIDENTE_PESADO: float = 2.0
const GRAVEDAD_TRIDENTE_PESADO: float = 0.5
const DANO_TRIDENTE_PESADO: float = 2.0
const TIEMPO_LANZAMIENTO_EN_ATAQUE: float = 0.65
const DURACION_ATAQUE_TOTAL: float = 1.53
const INTERVALO_ATAQUE_DEFENSA: float = 6.0  ## Ataca cada 6 segundos mientras defiende protegiendo a un aliado
const TIEMPO_MINIMO_DEFENSA_PRIMER_ATAQUE: float = 6.0
const TIEMPO_DEFENSA_SIN_ENEMIGOS_ATAQUE: float = 7.0  ## Ataca tras 7 segundos si no hay enemigos a los que proteger

const TIEMPO_VENTANA_IMPACTOS_CONCENTRADOS: float = 0.9
const UMBRAL_IMPACTOS_CONCENTRADOS: int = 3

const TEXTURA_HUMO_PISADAS: Texture2D = preload("res://VFX/Textures/Smoke/Humo_Pisadas_1A-1.png")
const HUMO_PISADAS_FRAMES_H: int = 9
const HUMO_PISADAS_FRAMES_V: int = 1

const DISSOLVE_SHADER: Shader = preload("res://System/Shaders/dissolve.gdshader")
const TRIDENTE_SCENE: PackedScene = preload("res://Entities/Proyectil_Tridente_Imp/ImpTrident.tscn")
const MEDIKIT_SCENE: PackedScene = preload("res://Entities/Item_Medikit/Medikit.tscn")
const SANGRE_SCENE: PackedScene = preload("res://VFX/Scenes/BloodSplashNormal.tscn")
const SANGRE_NO_LETAL_SCENE: PackedScene = preload("res://VFX/Scenes/BloodSplashNoLetal.tscn")
const TEXTURA_SANGRE_EXPLOSION: Texture2D = preload("res://Entities/Enemigo_Goblin/Muerte_Explotado/Sangre_explosion.png")
const ESCUDO_ROTO_SCENE: PackedScene = preload("res://Entities/Enemigo_Imp_Escudo/EscudoImpRoto.tscn")

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORTS
# ═══════════════════════════════════════════════════════════════════════════════
@export_category("Estadísticas")
@export var vida_maxima: int = VIDA_MAXIMA_DEFAULT
@export var velocidad_carrera: float = VELOCIDAD_CARRERA_DEFAULT
@export var distancia_proteccion: float = DISTANCIA_PROTECCION_DEFAULT
@export var rotacion_y_modelo: float = 270.0
@export var color_borde_disolucion: Color = Color(0.8, 0.2, 0.8)  ## Efecto de disolución con brillo y partículas moradas
@export var altura_spawn_tridente: float = 0.52

@export_category("Zona de Entrada (Zona Roja)")
@export var zona_roja_min_x: float = -2.2  ## Límite izquierdo de la zona roja marcada
@export var zona_roja_max_x: float = 0.2   ## Límite derecho de la zona roja (nunca ataca más a la derecha)

# ═══════════════════════════════════════════════════════════════════════════════
# VARIABLES DE ESTADO Y FLAGS
# ═══════════════════════════════════════════════════════════════════════════════
var current_state: State = State.RUNNING
var health: int = VIDA_MAXIMA_DEFAULT
var es_estructura: bool = true  ## Bono de daño contra estructuras (flecha explosiva)
var es_pilar_enemigo: bool = true  ## Reconocimiento por ExplosionFlechaExplosiva
var es_escudo_enemigo: bool = true  ## Reconocimiento por Arrow.gd
var murio_por_explosion: bool = false
var last_hit_position: Vector3 = Vector3.ZERO
var last_hit_direction: Vector3 = Vector3.ZERO
var ultimo_atacante: Node = null  ## Quién dio el último golpe: conteo de muertes por defensora

var enemigo_protegido: Node3D = null
var posicion_objetivo_zona_roja: float = -1.0
var _necesita_atacar: bool = true  ## Ataca al llegar por primera vez y al reposicionarse
var _ha_atacado_en_animacion: bool = false
var primer_ataque_realizado: bool = false
var tiempo_defensa_primer_ataque: float = 0.0
var _timer_defensa: float = 0.0
var _timer_defensa_sin_enemigos: float = 0.0

var _attack_timer: float = 0.0
var _shield_hit_timer: float = 0.0
var _impactos_consecutivos_escudo: int = 0
var _timer_impactos_consecutivos: float = 0.0
var _turn_timer: float = 0.0
var _check_enemigos_timer: float = 0.0
var _died_emitted: bool = false
var is_dissolving: bool = false

var _escudo_meshes: Array[MeshInstance3D] = []
var _cuerpo_meshes: Array[MeshInstance3D] = []
var _dissolve_materials: Array[Dictionary] = []
var _dissolve_particles: GPUParticles3D = null
var _flash_mat: StandardMaterial3D = null
var _flash_rojo_mat: StandardMaterial3D = null
var _audio_correr_descalzo: AudioStreamPlayer3D = null
var _sombra: SombraPersonaje = null

# ═══════════════════════════════════════════════════════════════════════════════
# REFERENCIAS A NODOS
# ═══════════════════════════════════════════════════════════════════════════════
@onready var model_root: Node3D = get_node_or_null("Modelo")
@onready var particulas_pisada: GPUParticles3D = get_node_or_null("Particulas_Pisada")
@onready var escudo_node: Node3D = get_node_or_null("Modelo/Armature/Skeleton3D/BoneAttachment_Shield/EscudoPesado")
var anim_player: AnimationPlayer = null

# ═══════════════════════════════════════════════════════════════════════════════
# SEÑALES
# ═══════════════════════════════════════════════════════════════════════════════
signal died


# ═══════════════════════════════════════════════════════════════════════════════
# CICLO DE VIDA
# ═══════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	collision_layer = 4
	collision_mask = 1  # Solo colisiona con el suelo (Capa 1); nunca con defensas ni restos de enemigos (Capa 2)
	add_to_group("enemies")
	add_to_group("shield_imps")
	add_to_group("guardians")



	health = vida_maxima
	posicion_objetivo_zona_roja = randf_range(zona_roja_min_x, zona_roja_max_x)
	_setup_anim_player()
	_setup_materiales()
	_configurar_particulas_pisada()
	_setup_audio_correr_descalzo()
	_setup_sombra()
	_aplicar_rotacion_modelo()

	_buscar_enemigo_a_proteger()
	_cambiar_estado(State.RUNNING)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta

	if _timer_impactos_consecutivos > 0.0:
		_timer_impactos_consecutivos -= delta
		if _timer_impactos_consecutivos <= 0.0:
			_impactos_consecutivos_escudo = 0

	match current_state:
		State.RUNNING:
			_process_running(delta)
		State.ATTACKING:
			_process_attacking(delta)
		State.DEFENDING:
			_process_defending(delta)
		State.SHIELD_HIT:
			_process_shield_hit(delta)
		State.TURNING:
			_process_turning(delta)
		State.DYING, State.DEAD:
			pass

	# Control de audio de pasos descalzos durante la corrida
	if _audio_correr_descalzo:
		var corriendo: bool = (current_state == State.RUNNING and abs(velocity.x) > 0.1)
		if corriendo and not _audio_correr_descalzo.playing:
			_audio_correr_descalzo.play()
		elif not corriendo and _audio_correr_descalzo.playing:
			_audio_correr_descalzo.stop()

	move_and_slide()

	# Seguridad adicional: si colisiona con cualquier pieza física o hitbox de piernas, ignorarla de inmediato
	for i in range(get_slide_collision_count()):
		var col := get_slide_collision(i)
		var collider = col.get_collider()
		if is_instance_valid(collider) and (collider.name == "PiernasHitbox" or collider is GoblinPiezaFisica or (collider.get_parent() and collider.get_parent() is GoblinPiezaFisica)):
			add_collision_exception_with(collider)



# ═══════════════════════════════════════════════════════════════════════════════
# MÁQUINA DE ESTADOS Y COMPORTAMIENTO
# ═══════════════════════════════════════════════════════════════════════════════
func _cambiar_estado(nuevo_estado: State) -> void:
	if current_state == State.DYING or current_state == State.DEAD:
		return

	current_state = nuevo_estado

	if nuevo_estado != State.RUNNING and _audio_correr_descalzo and _audio_correr_descalzo.playing:
		_audio_correr_descalzo.stop()

	match nuevo_estado:
		State.RUNNING:
			if particulas_pisada:
				particulas_pisada.emitting = true
			_play_anim("Correr", 0.2, 1.2)

		State.ATTACKING:
			if particulas_pisada:
				particulas_pisada.emitting = false
			velocity.x = 0.0
			velocity.z = 0.0
			_attack_timer = 0.0
			_ha_atacado_en_animacion = false
			_necesita_atacar = false
			_play_anim("Ataque arrojar", 0.15, 1.0)
			AudioManager.play_sfx("goblina_ataque")
			AudioManager.play_sfx("goblina_jabalina")

		State.DEFENDING:
			if particulas_pisada:
				particulas_pisada.emitting = false
			velocity.x = 0.0
			velocity.z = 0.0
			_timer_defensa = 0.0
			_timer_defensa_sin_enemigos = 0.0
			_play_anim("Idle escudo", 0.25, 1.0)


		State.SHIELD_HIT:
			if particulas_pisada:
				particulas_pisada.emitting = false
			_shield_hit_timer = 0.45
			_play_anim("Impacto escudo", 0.1, 1.1)

		State.TURNING:
			if particulas_pisada:
				particulas_pisada.emitting = false
			velocity = Vector3.ZERO
			var dur_voltearse: float = 0.8
			if anim_player and anim_player.has_animation("Voltearse"):
				dur_voltearse = anim_player.get_animation("Voltearse").length
			_turn_timer = dur_voltearse
			_play_anim("Voltearse", 0.25, 1.0)
			# Rotar el modelo suavemente hacia la derecha (90.0) para correr de frente hacia el aliado
			if model_root:
				var tw = create_tween()
				tw.tween_property(model_root, "rotation:y", deg_to_rad(90.0), dur_voltearse * 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

		State.DYING:
			if particulas_pisada:
				particulas_pisada.emitting = false
			velocity = Vector3.ZERO
			set_collision_layer_value(3, false)

			# Restaurar material normal del escudo para que no quede rojo al morir
			for mesh in _escudo_meshes:
				if is_instance_valid(mesh):
					mesh.material_overlay = null

			AudioManager.play_sfx("goblina_muerte")

			# Efecto de sangre animada del goblin ballestero al morir
			_spawn_sangre_animada(global_position)
			AudioManager.play_sfx("sangre_splash")

			# Siempre que muere suelta el escudo para que caiga pesadamente hacia adelante
			_soltar_escudo_pesado(murio_por_explosion)
			murio_por_explosion = false

			_soltar_recompensas_muerte()
			var anim_muerte = "Muerte 1" if randf() < 0.5 else "Muerte 2"
			_play_anim(anim_muerte, 0.15, 1.0)

			# Estar unos segundos en el piso tras la animación antes de disolverse
			var dur_anim: float = 1.4
			if anim_player and anim_player.has_animation(anim_muerte):
				dur_anim = anim_player.get_animation(anim_muerte).length
			var tiempo_en_piso: float = dur_anim + 0.8
			var tw_muerte := create_tween()
			tw_muerte.tween_interval(tiempo_en_piso)
			tw_muerte.tween_callback(_start_dissolve)



func _process_turning(delta: float) -> void:
	velocity.x = 0.0
	_turn_timer -= delta
	if _turn_timer <= 0.0:
		# Al terminar de voltearse, pasa suavemente a correr hacia el enemigo detrás
		_cambiar_estado(State.RUNNING)


func _process_running(delta: float) -> void:
	_check_enemigos_timer -= delta
	if _check_enemigos_timer <= 0.0:
		_check_enemigos_timer = 0.35
		_buscar_enemigo_a_proteger()

	if not is_instance_valid(enemigo_protegido) or not enemigo_protegido.is_inside_tree():
		_buscar_enemigo_a_proteger()

	var destino_x: float = posicion_objetivo_zona_roja
	if is_instance_valid(enemigo_protegido):
		destino_x = min(enemigo_protegido.global_position.x - distancia_proteccion, zona_roja_max_x)
	else:
		destino_x = posicion_objetivo_zona_roja

	var diff_x: float = destino_x - global_position.x

	# REGLA OBLIGATORIA: Nunca puede detenerse ni atacar desde el borde de la pantalla / fuera de la zona roja
	if abs(diff_x) <= 0.15 and global_position.x <= zona_roja_max_x:
		velocity.x = 0.0
		# Al llegar al puesto para cubrir al aliado, restablecer orientación hacia el jugador (-X / 270 grados)
		if model_root and abs(model_root.rotation_degrees.y - rotacion_y_modelo) > 5.0:
			model_root.rotation_degrees.y = rotacion_y_modelo
		if _necesita_atacar:
			_cambiar_estado(State.ATTACKING)
		else:
			_cambiar_estado(State.DEFENDING)
		return

	# Si aún está fuera/borde de la pantalla (a la derecha de la zona roja), siempre corre a la izquierda
	if global_position.x > zona_roja_max_x:
		velocity.x = -velocidad_carrera
		if model_root and abs(model_root.rotation_degrees.y - rotacion_y_modelo) > 5.0:
			model_root.rotation_degrees.y = rotacion_y_modelo
	else:
		var dir: float = sign(diff_x)
		velocity.x = dir * velocidad_carrera
		# Orientar el modelo hacia la dirección de avance para correr siempre de frente y nunca de espaldas
		if model_root:
			var rot_y_deseada: float = 90.0 if dir > 0.0 else rotacion_y_modelo
			if abs(model_root.rotation_degrees.y - rot_y_deseada) > 5.0:
				model_root.rotation_degrees.y = rot_y_deseada


func _process_attacking(delta: float) -> void:
	_attack_timer += delta

	# Lanzar el tridente en el fotograma clave de lanzamiento
	if not _ha_atacado_en_animacion and _attack_timer >= TIEMPO_LANZAMIENTO_EN_ATAQUE:
		_ha_atacado_en_animacion = true
		_lanzar_tridente_pesado()

	# Fin de animación de ataque -> después de atacar cada 6 segundos, debe posicionarse delante de otro enemigo cercano
	if _attack_timer >= DURACION_ATAQUE_TOTAL:
		_attack_timer = 0.0
		_timer_defensa = 0.0
		if not primer_ataque_realizado:
			primer_ataque_realizado = true
			tiempo_defensa_primer_ataque = 0.0

		var otro_enemigo := _buscar_otro_enemigo_cercano()
		if otro_enemigo != null:
			enemigo_protegido = otro_enemigo
			var destino_x: float = min(enemigo_protegido.global_position.x - distancia_proteccion, zona_roja_max_x)
			var diff_x: float = destino_x - global_position.x
			if abs(diff_x) > 0.2:
				if diff_x > 0.3:
					_cambiar_estado(State.TURNING)
				else:
					_cambiar_estado(State.RUNNING)
				return

		_cambiar_estado(State.DEFENDING)


func _process_defending(delta: float) -> void:
	tiempo_defensa_primer_ataque += delta

	# Monitorear periódicamente si el aliado protegido sigue vivo o buscar uno nuevo
	_check_enemigos_timer -= delta
	if _check_enemigos_timer <= 0.0:
		_check_enemigos_timer = 0.35
		if not is_instance_valid(enemigo_protegido) or not enemigo_protegido.is_inside_tree():
			_buscar_enemigo_a_proteger()

	if is_instance_valid(enemigo_protegido) and enemigo_protegido.is_inside_tree():
		_timer_defensa_sin_enemigos = 0.0
		# REGLA: Ataca cada 6 segundos mientras defiende protegiendo a un aliado
		_timer_defensa += delta
		if _timer_defensa >= INTERVALO_ATAQUE_DEFENSA:
			_timer_defensa = 0.0
			_cambiar_estado(State.ATTACKING)
			return

		# Si el aliado al que protege se desplazó significativamente, mantener la cobertura
		var destino_x: float = min(enemigo_protegido.global_position.x - distancia_proteccion, zona_roja_max_x)
		var diff_x: float = destino_x - global_position.x
		if abs(diff_x) > 1.2:
			if diff_x > 0.3:
				_cambiar_estado(State.TURNING)
			else:
				_cambiar_estado(State.RUNNING)
	else:
		_timer_defensa = 0.0
		# REGLA: Ataca tras 7 segundos si no hay aliados a los que proteger
		_timer_defensa_sin_enemigos += delta
		if _timer_defensa_sin_enemigos >= TIEMPO_DEFENSA_SIN_ENEMIGOS_ATAQUE:
			_timer_defensa_sin_enemigos = 0.0
			_cambiar_estado(State.ATTACKING)
			return



func _process_shield_hit(delta: float) -> void:
	_shield_hit_timer -= delta
	if _shield_hit_timer <= 0.0:
		_cambiar_estado(State.DEFENDING)


# ═══════════════════════════════════════════════════════════════════════════════
# ATAQUE: TRIDENTE PESADO
# ═══════════════════════════════════════════════════════════════════════════════
func _lanzar_tridente_pesado() -> void:
	AudioManager.play_sfx("trident_shot")

	var player_ref: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	var target_pos: Vector3
	if is_instance_valid(player_ref):
		target_pos = player_ref.global_position + Vector3(0.0, 0.5, 0.0)
	else:
		target_pos = global_position + Vector3(-10.0, 0.0, 0.0)

	var spawn_pos: Vector3 = global_position + Vector3(-0.4, altura_spawn_tridente, 0.0)
	var direction: Vector3 = (target_pos - spawn_pos).normalized()

	# Trayectoria potente y tensa hacia la izquierda
	direction.y += 0.08
	direction = direction.normalized()

	var trident: Node3D = null
	if TRIDENTE_SCENE:
		trident = TRIDENTE_SCENE.instantiate() as Node3D

	if not trident:
		return

	trident.scale = Vector3(1.3, 1.3, 1.3)
	if trident.has_method("initialize"):
		trident.initialize(direction, POTENCIA_TRIDENTE_PESADO)
	if "gravedad" in trident:
		trident.gravedad = GRAVEDAD_TRIDENTE_PESADO
	if "dano" in trident:
		trident.dano = DANO_TRIDENTE_PESADO

	var root: Node = get_tree().current_scene
	if not root:
		root = get_tree().root
	root.add_child(trident)
	trident.global_position = spawn_pos


# ═══════════════════════════════════════════════════════════════════════════════
# BÚSQUEDA DE ALIADOS A PROTEGER
# ═══════════════════════════════════════════════════════════════════════════════
func _buscar_enemigo_a_proteger() -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var mejor_enemigo: Node3D = null
	var menor_distancia: float = INF

	for enemy in enemies:
		if enemy == self or not is_instance_valid(enemy) or not enemy.is_inside_tree():
			continue
		if enemy is ImpShieldGirl or enemy is GuardianaMoradita:
			continue  # No proteger a otras guardianas con escudo

		if enemy is EnemyBase:
			if enemy.current_state == EnemyBase.State.DYING or enemy.current_state == EnemyBase.State.DEAD:
				continue

		# Ignorar enemigos que aún están en el borde de la pantalla o fuera del campo
		if enemy.global_position.x > (zona_roja_max_x + distancia_proteccion):
			continue

		var punto_proteccion_x: float = min(enemy.global_position.x - distancia_proteccion, zona_roja_max_x)
		var dist: float = abs(punto_proteccion_x - global_position.x)
		if dist < menor_distancia:
			menor_distancia = dist
			mejor_enemigo = enemy as Node3D

	if mejor_enemigo:
		enemigo_protegido = mejor_enemigo
	else:
		enemigo_protegido = null


func _buscar_otro_enemigo_cercano() -> Node3D:
	## Busca prioritariamente otro enemigo cercano distinto al actual para reposicionarse tras atacar
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var candidato_otro: Node3D = null
	var dist_min_otro: float = INF
	var candidato_mismo: Node3D = null
	var dist_min_mismo: float = INF

	for enemy in enemies:
		if enemy == self or not is_instance_valid(enemy) or not enemy.is_inside_tree():
			continue
		if enemy is ImpShieldGirl or enemy is GuardianaMoradita:
			continue  # No proteger a otras guardianas con escudo

		if enemy is EnemyBase:
			if enemy.current_state == EnemyBase.State.DYING or enemy.current_state == EnemyBase.State.DEAD:
				continue

		# Ignorar enemigos que aún están en el borde de la pantalla o fuera del campo
		if enemy.global_position.x > (zona_roja_max_x + distancia_proteccion):
			continue

		var punto_proteccion_x: float = min(enemy.global_position.x - distancia_proteccion, zona_roja_max_x)
		var dist: float = abs(punto_proteccion_x - global_position.x)

		if enemy != enemigo_protegido:
			if dist < dist_min_otro:
				dist_min_otro = dist
				candidato_otro = enemy as Node3D
		else:
			if dist < dist_min_mismo:
				dist_min_mismo = dist
				candidato_mismo = enemy as Node3D

	if candidato_otro != null:
		return candidato_otro
	return candidato_mismo



# ═══════════════════════════════════════════════════════════════════════════════
# DAÑO, VULNERABILIDAD Y MUERTE
# ═══════════════════════════════════════════════════════════════════════════════
func take_damage(amount: float, golpe_en_escudo: bool = false) -> void:
	if current_state == State.DYING or current_state == State.DEAD:
		return

	var dano_total: float = amount

	# VULNERABILIDAD TÁCTICA: +5 de daño y sonido de daño si es golpeada en plena animación de ataque
	if current_state == State.ATTACKING:
		dano_total += VULNERABILIDAD_ATAQUE_DANO_EXTRA
		_spawn_sangre()
		AudioManager.play_sfx("goblina_dano")

	health -= int(dano_total)

	if golpe_en_escudo:
		_flash_impacto_escudo_rojo()
		_impactos_consecutivos_escudo += 1
		_timer_impactos_consecutivos = TIEMPO_VENTANA_IMPACTOS_CONCENTRADOS
		if _impactos_consecutivos_escudo >= UMBRAL_IMPACTOS_CONCENTRADOS:
			AudioManager.play_sfx("impacto_escudo_pesado")
		else:
			AudioManager.play_sfx("shield_hit")
	else:
		_flash_impacto()

	if health <= 0:
		health = 0
		_cambiar_estado(State.DYING)
	else:
		if not golpe_en_escudo:
			_spawn_sangre_no_letal()
		if current_state == State.DEFENDING:
			_cambiar_estado(State.SHIELD_HIT)


func recibir_golpe(amount: float = 1.0) -> void:
	take_damage(amount, true)


func recibir_golpe_escudo(amount: float = 1.0) -> void:
	take_damage(amount, true)


func _flash_impacto() -> void:
	if _flash_mat == null:
		_flash_mat = StandardMaterial3D.new()
		_flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_mat.albedo_color = Color(1.0, 1.0, 1.0, 1.0)

	for mesh in _cuerpo_meshes:
		if is_instance_valid(mesh):
			mesh.material_overlay = _flash_mat

	await get_tree().create_timer(0.08, false).timeout

	for mesh in _cuerpo_meshes:
		if is_instance_valid(mesh):
			mesh.material_overlay = null


func _flash_impacto_escudo_rojo() -> void:
	if current_state == State.DYING or current_state == State.DEAD:
		return
	if _flash_rojo_mat == null:
		_flash_rojo_mat = StandardMaterial3D.new()
		_flash_rojo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flash_rojo_mat.albedo_color = Color(1.0, 0.08, 0.08, 1.0)
		_flash_rojo_mat.emission_enabled = true
		_flash_rojo_mat.emission = Color(1.0, 0.0, 0.0)
		_flash_rojo_mat.emission_energy_multiplier = 3.0

	var escudo: Node3D = find_child("EscudoPesado", true, false) as Node3D
	if escudo and is_instance_valid(escudo):
		if not has_meta("_escudo_orig_scale"):
			set_meta("_escudo_orig_scale", escudo.scale)
		var _orig_scale: Vector3 = get_meta("_escudo_orig_scale")
		var _tw := create_tween()
		_tw.tween_property(escudo, "scale", _orig_scale * 1.10, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_tw.tween_property(escudo, "scale", _orig_scale, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	for mesh in _escudo_meshes:
		if is_instance_valid(mesh):
			mesh.material_overlay = _flash_rojo_mat

	await get_tree().create_timer(0.12, false).timeout

	for mesh in _escudo_meshes:
		if is_instance_valid(mesh):
			mesh.material_overlay = null


func _spawn_sangre() -> void:
	if SANGRE_SCENE:
		var sangre: Node3D = SANGRE_SCENE.instantiate() as Node3D
		if sangre:
			var target_parent = get_tree().current_scene if get_tree().current_scene else get_parent()
			target_parent.add_child(sangre)
			var pos_sangre = last_hit_position if last_hit_position != Vector3.ZERO else global_position + Vector3(0.0, 0.5, 0.0)
			sangre.global_position = pos_sangre


func _spawn_sangre_no_letal() -> void:
	if SANGRE_NO_LETAL_SCENE:
		var sangre: Node3D = SANGRE_NO_LETAL_SCENE.instantiate() as Node3D
		if sangre:
			var target_parent = get_tree().current_scene if get_tree().current_scene else get_parent()
			if not target_parent:
				target_parent = self
			target_parent.add_child(sangre)
			var pos_sangre = last_hit_position if last_hit_position != Vector3.ZERO else global_position + Vector3(0.0, 0.5, 0.0)
			if sangre.has_method("setup"):
				sangre.setup(pos_sangre, last_hit_direction)
			elif sangre is Node3D:
				sangre.global_position = pos_sangre


func _soltar_recompensas_muerte() -> void:
	var roll: float = randf()
	var item_scene: PackedScene = null
	if roll < 0.05:
		item_scene = MEDIKIT_SCENE

	if item_scene:
		var item: Node3D = item_scene.instantiate() as Node3D
		if item:
			var target_parent = get_tree().current_scene if get_tree().current_scene else get_parent()
			if not target_parent:
				target_parent = get_tree().root
			target_parent.add_child(item)
			item.global_position = global_position + Vector3(0.0, 0.5, 0.0)


func _soltar_escudo_pesado(por_explosion: bool = false) -> void:
	var escudo: Node3D = find_child("EscudoPesado", true, false) as Node3D
	if not escudo:
		return

	# Asegurar que el escudo mantenga su color original y no permanezca rojo al caer
	for m in escudo.find_children("*", "MeshInstance3D", true, false):
		var mesh := m as MeshInstance3D
		if is_instance_valid(mesh):
			mesh.material_overlay = null
			mesh.material_override = MAT_ESCUDO

	var root_scene: Node = get_tree().current_scene
	if not root_scene:
		root_scene = get_tree().root

	# Obtener posición, rotación y escala real en el mundo ANTES de desparentar
	var tr_escudo: Transform3D = escudo.global_transform
	var pos_global: Vector3 = tr_escudo.origin
	var escala_global: Vector3 = tr_escudo.basis.get_scale()
	var rot_global: Basis = tr_escudo.basis.orthonormalized()

	escudo.get_parent().remove_child(escudo)

	var contenedor := GoblinPiezaFisica.new()
	contenedor.name = "EscudoPesadoCaido"
	contenedor.gravity = 22.0  # Gravedad pesada para caída contundente
	contenedor.humo_al_aterrizar = true  # Humo a ambos lados al tocar el suelo (como el escudo roto de la Imp)
	root_scene.add_child(contenedor)

	# El contenedor asume la posición y rotación del escudo
	contenedor.global_position = pos_global
	contenedor.global_basis = rot_global

	# IMPORTANTE: El escudo adentro debe tener su escala_global real para que NO se agrande 100x
	# (evitando que el scale 100 de mixamo se conserve en el root de la escena)
	escudo.position = Vector3.ZERO
	escudo.rotation = Vector3.ZERO
	escudo.scale = escala_global
	escudo.visible = true

	# Eliminar el área de daño/bloqueo para que no interfiera en combate
	var area = escudo.get_node_or_null("EscudoArea")
	if area:
		area.queue_free()

	# Quitar de _escudo_meshes para que la disolución de la goblina no afecte al escudo caído
	_escudo_meshes.clear()

	contenedor.add_child(escudo)

	# Reproducir sonido de escudo metálico cayendo al suelo con volumen aumentado
	AudioManager.play_escudo_metal_cayendo()

	# Físicas: caer pesadamente hacia adelante (hacia la izquierda / jugador, -X)

	var vel_x: float = -1.1
	var vel_y: float = 0.4
	var rot_z: float = -3.2  # Vuelca hacia adelante en el suelo

	if por_explosion:
		var push_dir: float = -1.0
		if last_hit_position != Vector3.ZERO:
			var dx: float = global_position.x - last_hit_position.x
			if absf(dx) > 0.05:
				push_dir = signf(dx)
		vel_x = push_dir * randf_range(1.6, 2.6)
		vel_y = randf_range(2.0, 3.2)
		rot_z = randf_range(-5.0, 5.0)

	contenedor.iniciar_vuelo(Vector3(vel_x, vel_y, 0.0), rot_z)


func _start_dissolve() -> void:
	if is_dissolving:
		return
	is_dissolving = true

	if is_instance_valid(_sombra):
		_sombra.visible = false

	var meshes: Array[Node] = find_children("*", "MeshInstance3D", true, false)
	for m in meshes:
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

		var orig = mesh.material_override
		if orig == null and mesh.mesh and mesh.mesh.get_surface_count() > 0:
			orig = mesh.mesh.surface_get_material(0)
		if orig and orig is StandardMaterial3D:
			var tex = orig.albedo_texture
			if tex:
				mat.set_shader_parameter("albedo_texture", tex)
			var col = orig.albedo_color
			mat.set_shader_parameter("albedo_tint", Vector3(col.r, col.g, col.b))

		mesh.material_override = mat
		_dissolve_materials.append({"mesh": mesh, "material": mat})

	_crear_particulas_disolucion_moradas()

	var tween: Tween = create_tween()
	tween.tween_method(_update_dissolve, 0.0, 1.0, 1.2)
	tween.tween_callback(_finish_dissolve)


func _crear_particulas_disolucion_moradas() -> void:
	_dissolve_particles = GPUParticles3D.new()
	_dissolve_particles.name = "DissolveParticles"
	_dissolve_particles.amount = 75
	_dissolve_particles.lifetime = 1.0
	_dissolve_particles.one_shot = false
	_dissolve_particles.explosiveness = 0.0
	_dissolve_particles.randomness = 0.3

	var process_mat := ParticleProcessMaterial.new()
	process_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_mat.emission_box_extents = Vector3(0.25, 0.35, 0.25)
	process_mat.direction = Vector3(0, 1, 0)
	process_mat.spread = 25.0
	process_mat.initial_velocity_min = 1.0
	process_mat.initial_velocity_max = 2.0
	process_mat.gravity = Vector3(0, 1.5, 0)
	process_mat.scale_min = 0.5
	process_mat.scale_max = 1.5

	var gradient := Gradient.new()
	gradient.set_color(0, color_borde_disolucion)
	gradient.set_color(1, Color(color_borde_disolucion.r, color_borde_disolucion.g, color_borde_disolucion.b, 0.0))
	var gradient_tex := GradientTexture1D.new()
	gradient_tex.gradient = gradient
	process_mat.color_ramp = gradient_tex

	var scale_curve := Curve.new()
	scale_curve.add_point(Vector2(0, 0.2))
	scale_curve.add_point(Vector2(0.3, 1.0))
	scale_curve.add_point(Vector2(1.0, 0.0))
	var scale_tex := CurveTexture.new()
	scale_tex.curve = scale_curve
	process_mat.scale_curve = scale_tex

	_dissolve_particles.process_material = process_mat

	var sphere := SphereMesh.new()
	sphere.radius = 0.0125
	sphere.height = 0.025

	var part_mat := StandardMaterial3D.new()
	part_mat.albedo_color = color_borde_disolucion
	part_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	part_mat.emission_enabled = true
	part_mat.emission = color_borde_disolucion
	part_mat.emission_energy_multiplier = 8.0
	part_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	part_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sphere.material = part_mat

	_dissolve_particles.draw_pass_1 = sphere
	add_child(_dissolve_particles)
	_dissolve_particles.position = Vector3(0, 0.2, 0)
	_dissolve_particles.emitting = true


func _update_dissolve(val: float) -> void:
	for item in _dissolve_materials:
		if is_instance_valid(item["mesh"]):
			item["material"].set_shader_parameter("dissolve_amount", val)


func _finish_dissolve() -> void:
	for item in _dissolve_materials:
		if is_instance_valid(item["mesh"]):
			item["mesh"].material_override = null
			item["mesh"].visible = false
	_dissolve_materials.clear()

	if _dissolve_particles and is_instance_valid(_dissolve_particles):
		var p_root: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
		var g_pos: Vector3 = _dissolve_particles.global_position
		remove_child(_dissolve_particles)
		p_root.add_child(_dissolve_particles)
		_dissolve_particles.global_position = g_pos
		_dissolve_particles.emitting = false
		var p_ref: GPUParticles3D = _dissolve_particles
		var tw_p := p_ref.create_tween()
		tw_p.tween_interval(1.5)
		tw_p.tween_callback(p_ref.queue_free)
		_dissolve_particles = null

	current_state = State.DEAD
	if not _died_emitted:
		_died_emitted = true
		died.emit()
	queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS DE INICIALIZACIÓN
# ═══════════════════════════════════════════════════════════════════════════════
func _setup_anim_player() -> void:
	var players = find_children("*", "AnimationPlayer", true, false)
	for p in players:
		var player := p as AnimationPlayer
		if player.has_animation("Ataque arrojar") or player.has_animation("Idle escudo"):
			anim_player = player
			break

	if anim_player:
		for anim_name in anim_player.get_animation_list():
			if "Correr" in anim_name or "Idle" in anim_name or "Baile" in anim_name or "Dance" in anim_name:
				var a = anim_player.get_animation(anim_name)
				if a:
					a.loop_mode = Animation.LOOP_LINEAR


const MAT_GOBLINA: Material = preload("res://Entities/Enemigo_Goblina_Escudo_Pesado/GuardianaMoradita_MAT.tres")
const MAT_ESCUDO: Material = preload("res://Entities/Enemigo_Goblina_Escudo_Pesado/EscudoPesado_MAT.tres")

func _setup_materiales() -> void:
	_escudo_meshes.clear()
	_cuerpo_meshes.clear()

	var all_meshes: Array[Node] = find_children("*", "MeshInstance3D", true, false)
	for m in all_meshes:
		var mesh := m as MeshInstance3D
		if mesh.find_parent("EscudoPesado") != null:
			mesh.material_override = MAT_ESCUDO
			_escudo_meshes.append(mesh)
		else:
			mesh.material_override = MAT_GOBLINA
			_cuerpo_meshes.append(mesh)


func _aplicar_rotacion_modelo() -> void:
	if model_root:
		model_root.rotation_degrees.y = rotacion_y_modelo


func _play_anim(anim_name: String, blend_time: float = 0.2, speed: float = 1.0) -> void:
	if not anim_player:
		return
	if anim_player.has_animation(anim_name):
		anim_player.play(anim_name, blend_time, speed)
		return
	# Fallback para variaciones de nombres de animación entre modelos (ej: "Correr" -> "Correr con escudo", "Baile" -> "Dance")
	var anim_name_lower := anim_name.to_lower()
	for a in anim_player.get_animation_list():
		var a_lower := a.to_lower()
		if a_lower == anim_name_lower or anim_name_lower in a_lower or (anim_name_lower == "baile" and a_lower == "dance"):
			anim_player.play(a, blend_time, speed)
			return


func _configurar_particulas_pisada() -> void:
	if not particulas_pisada:
		particulas_pisada = find_child("Particulas_Pisada", true, false) as GPUParticles3D
	if not particulas_pisada:
		return

	var mat := StandardMaterial3D.new()
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
	mesh.size = Vector2(0.6552, 0.6552)
	particulas_pisada.draw_pass_1 = mesh

	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 50.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3(0.0, 0.2, 0.0)
	pm.scale_min = 0.81
	pm.scale_max = 1.314
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.16, 0.02, 0.16)
	pm.anim_speed_min = 1.0
	pm.anim_speed_max = 1.0
	pm.anim_offset_min = 0.0
	pm.anim_offset_max = 1.0

	var grad := Gradient.new()
	grad.set_color(0, Color(0.5, 0.5, 0.5, 0.85))
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

	particulas_pisada.process_material = pm
	particulas_pisada.amount = 16
	particulas_pisada.lifetime = 1.15


func _setup_audio_correr_descalzo() -> void:
	var stream: AudioStream = null
	if ResourceLoader.exists("res://System/Audio/SFX/sonido_correr_descalzo.wav"):
		stream = load("res://System/Audio/SFX/sonido_correr_descalzo.wav") as AudioStream
	elif ResourceLoader.exists("res://TEST_/sonido_correr_descalzo.wav"):
		stream = load("res://TEST_/sonido_correr_descalzo.wav") as AudioStream
	elif ResourceLoader.exists("res://System/Audio/SFX/sonido_correr_descalzo.mp3"):
		stream = load("res://System/Audio/SFX/sonido_correr_descalzo.mp3") as AudioStream
	elif ResourceLoader.exists("res://TEST_/sonido_correr_descalzo.mp3"):
		stream = load("res://TEST_/sonido_correr_descalzo.mp3") as AudioStream

	if stream:
		var stream_mp3 = stream as AudioStreamMP3
		if stream_mp3:
			stream_mp3.loop = true
		var stream_wav = stream as AudioStreamWAV
		if stream_wav:
			stream_wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		_audio_correr_descalzo = AudioStreamPlayer3D.new()
		_audio_correr_descalzo.name = "AudioCorrerDescalzo"
		_audio_correr_descalzo.stream = stream
		_audio_correr_descalzo.bus = "Master"
		_audio_correr_descalzo.volume_db = 6.0
		_audio_correr_descalzo.unit_size = 30.0
		_audio_correr_descalzo.max_db = 6.0
		add_child(_audio_correr_descalzo)


func _setup_sombra() -> void:
	_sombra = SombraPersonaje.new()
	_sombra.opacidad = 1.0
	_sombra.tamano = Vector2(0.55, 0.55)
	_sombra.suavizado = 0.8
	_sombra.altura_max_desvanecimiento = 0.25
	add_child(_sombra)


func _spawn_sangre_animada(pos: Vector3) -> void:
	var tex: Texture2D = TEXTURA_SANGRE_EXPLOSION
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
	sprite.pixel_size = 0.0070

	var root := get_tree().current_scene
	if not root:
		root = get_tree().root
	root.add_child(sprite)
	sprite.global_position = pos + Vector3(0.0, 0.40, 0.0)

	var tw_sangre := sprite.create_tween()
	for f in range(14):
		tw_sangre.tween_property(sprite, "frame", f, 0.04)
	tw_sangre.tween_callback(sprite.queue_free)
