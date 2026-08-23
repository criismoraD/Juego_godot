class_name ImpEnemy
extends EnemyBase

const PROJECTILE_POOL_REF = preload("res://System/Core/ProjectilePool.gd")
const PROJECTILE_SCALE: Vector3 = Vector3.ONE

## Imp enemigo: Camina hacia la izquierda, se detiene y lanza proyectiles.
## Usa animaciones CAMINAR, LANZAR01/LANZAR2. Partículas de muerte ROJAS.
# === CONFIGURACIÓN ESPECÍFICA DEL IMP ===
@export_category("Combate - Imp")
@export var intervalo_disparo: float = 3.0
@export var velocidad_flecha_min: float = 5.0  ## Velocidad mínima del tridente
@export var velocidad_flecha_max: float = 12.0  ## Velocidad máxima del tridente
@export var arco_altura_min: float = 1.0  ## Altura mínima del arco (parábola)
@export var arco_altura_max: float = 2.0  ## Altura máxima del arco (parábola)
@export var gravedad_tridente: float = 1.0  ## Gravedad del tridente (menor = parábola más ancha)
@export var tiempo_lanzamiento_en_animacion: float = 1.7  ## Segundo exacto donde sale el proyectil en LANZAR01
@export var tiempo_lanzamiento_lanzar2: float = 0.88  ## Segundo exacto donde sale el proyectil en LANZAR2
@export var pausa_idle_min: float = 1.0  ## Pausa mínima en IDLE entre lanzamientos
@export var pausa_idle_max: float = 2.0  ## Pausa máxima en IDLE entre lanzamientos
@export_category("Muerte - Explosión")
@export var tiempo_antes_disolver: float = 1.8  ## Tiempo antes de empezar disolución
@export var escala_sangre_min: float = 0.015  ## Escala mínima de las partículas de sangre al morir
@export var escala_sangre_max: float = 0.03   ## Escala máxima de las partículas de sangre al morir
@export_category("Retroceso")
@export var tiempo_retroceder: float = 1.5  ## Duración que se reproduce la animación RETROCEDER tras LANZAR01
@export var offset_post_lanzar: float = 0.3  ## Salto instantáneo de posición al terminar LANZAR01 (antes de RETROCEDER)
@export var desplazamiento_retroceder: float = 0.3  ## Movimiento gradual total durante la animación RETROCEDER
@export var velocidad_correr: float = 1.2  ## Velocidad de movimiento cuando corre (1.2 por defecto)
# === COLOR DE SANGRE (compartido entre todos los Imps) ===
static var sangre_morada: bool = true  ## Toggle rojo/morado para la sangre (morada por defecto)
# === REFERENCIAS ESPECÍFICAS ===
var imp_arrow_scene = preload("res://Entities/Proyectil_Tridente_Imp/ImpTrident.tscn")
var material_imp: Material = preload("res://Entities/Enemigo_Imp/MAT_IMP.tres")
var is_throwing: bool = false  ## True durante la animación de lanzar
var has_thrown: bool = false  ## True después de lanzar en este ciclo
var is_idle_pause: bool = false  ## True durante la pausa IDLE entre lanzamientos
var is_retreating: bool = false  ## True durante la animación RETROCEDER
var retreat_timer: float = 0.0  ## Timer para la duración de RETROCEDER
var current_throw_anim: String = ""  ## Nombre de la animación de lanzamiento actual
var throw_anim_timer: float = 0.0  ## Timer para el momento exacto de lanzamiento
var throw_anim_duration: float = 0.0  ## Duración total de la animación actual
var current_throw_time: float = 0.0  ## Segundo exacto de lanzamiento para la animación actual
var va_a_correr: bool = false  ## Determina si el Imp corre o camina en esta aparición
# ═══════════════════════════════════════════════════════════════════════════════
# HOOKS DE ENEMYBASE
# ═══════════════════════════════════════════════════════════════════════════════


func _on_enemy_ready():
	# Partículas de muerte del mismo color que la sangre
	if sangre_morada:
		color_borde_disolucion = Color(0.4, 0.0, 0.5)
	else:
		color_borde_disolucion = Color(0.6, 0.0, 0.0)

	# El IMP no necesita tracking de spine (apunta por cálculo)
	rastrear_jugador = false

	# Aplicar material del Imp a todos los meshes
	_aplicar_material_imp()

	# Decidir aleatoriamente si corre o camina (50% de probabilidad)
	va_a_correr = randf() < 0.5
	if va_a_correr:
		velocidad_caminar = velocidad_correr
		_play_animation("CORRER")
	else:
		_play_animation("CAMINAR")


func _aplicar_material_imp():
	if not material_imp:
		return
	var meshes = find_children("*", "MeshInstance3D", true, false)
	for mesh in meshes:
		# No sobreescribir materiales de accesorios (casco, estandarte, etc.)
		if _es_hijo_de_bone_attachment(mesh):
			continue
		mesh.material_override = material_imp


## Verifica si un nodo es descendiente de un BoneAttachment3D
func _es_hijo_de_bone_attachment(node: Node) -> bool:
	var parent = node.get_parent()
	while parent and parent != self:
		if parent is BoneAttachment3D:
			return true
		parent = parent.get_parent()
	return false


func _on_state_walking():
	if va_a_correr:
		_play_animation("CORRER")
	else:
		_play_animation("CAMINAR")


func _on_state_shooting():
	# Empieza con IDLE antes del primer lanzamiento
	is_throwing = false
	has_thrown = false
	is_idle_pause = true
	shoot_timer = randf_range(pausa_idle_min, pausa_idle_max)
	_play_animation("IDLE")


func _on_state_dying():
	super._on_state_dying()
	# Sonido de muerte del Imp + explosión
	AudioManager.play_sfx("imp_death")
	AudioManager.play_sfx("explosion_muerte")

	# === ANIMACIÓN DE MUERTE ALEATORIA ===
	var death_anims = ["IMP_MUERTE01", "IMP_MUERTE02"]
	var chosen_death = death_anims[randi() % death_anims.size()]
	var anim_length = _get_animation_duration(chosen_death)
	_play_animation(chosen_death)

	# Iniciar disolución después de la animación de muerte + tiempo extra
	var tiempo_total = max(anim_length, tiempo_antes_disolver)
	get_tree().create_timer(tiempo_total).timeout.connect(
		func():
			if is_instance_valid(self) and is_inside_tree():
				_die()
	)


func _spawn_blood_splash(custom_modulate: Color = Color.WHITE) -> void:
	var color_final: Color = Color(0.8, 0.3, 1.0) if sangre_morada else Color.WHITE
	super._spawn_blood_splash(color_final)



# ═══════════════════════════════════════════════════════════════════════════════
# DISPARO / LANZAMIENTO
# ═══════════════════════════════════════════════════════════════════════════════


func _process_shooting(delta):
	velocity.x = 0

	if rastrear_jugador:
		_track_player()

	if is_throwing:
		# === FASE LANZAMIENTO: esperando el momento exacto del proyectil ===
		throw_anim_timer += delta
		if not has_thrown and throw_anim_timer >= current_throw_time:
			_throw_projectile()
			has_thrown = true
		# Esperar a que termine la animación completa
		if throw_anim_timer >= throw_anim_duration:
			is_throwing = false
			# Si fue LANZAR01, ejecutar RETROCEDER antes del IDLE
			if current_throw_anim == "LANZAR01":
				is_retreating = true
				retreat_timer = tiempo_retroceder
				# Salto instantáneo de posición (offset post-lanzar)
				global_position.x += offset_post_lanzar
				_play_animation("RETROCEDER")
			else:
				# LANZAR2 → directo a pausa IDLE
				is_idle_pause = true
				shoot_timer = randf_range(pausa_idle_min, pausa_idle_max)
				_play_animation("IDLE")
	elif is_retreating:
		# === FASE RETROCEDER: animación de retroceso tras LANZAR01 ===
		# Desplazamiento gradual durante la animación RETROCEDER
		var velocidad_retroceso = desplazamiento_retroceder / tiempo_retroceder
		global_position.x += velocidad_retroceso * delta
		retreat_timer -= delta
		if retreat_timer <= 0:
			is_retreating = false
			is_idle_pause = true
			shoot_timer = randf_range(pausa_idle_min, pausa_idle_max)
			_play_animation("IDLE")
	elif is_idle_pause:
		# === FASE IDLE: esperando entre lanzamientos ===
		shoot_timer -= delta
		if shoot_timer <= 0:
			is_idle_pause = false
			_start_throw_animation()


func _start_throw_animation():
	is_throwing = true
	has_thrown = false
	throw_anim_timer = 0.0
	var lanzar_anims = ["LANZAR01", "LANZAR2"]
	var chosen = lanzar_anims[randi() % lanzar_anims.size()]
	current_throw_anim = chosen
	_play_animation(chosen)
	throw_anim_duration = _get_animation_duration(chosen)
	# Cada animación tiene su propio timing de lanzamiento
	if chosen == "LANZAR2":
		current_throw_time = tiempo_lanzamiento_lanzar2
	else:
		current_throw_time = tiempo_lanzamiento_en_animacion


func _throw_projectile():
	if not imp_arrow_scene:
		return

	# Sonido de lanzamiento del tridente
	AudioManager.play_sfx("trident_shot")

	if not player_ref:
		player_ref = get_tree().get_first_node_in_group("player")
		if not player_ref:
			return

	# No disparar si el jugador está muerto
	if player_ref.get("is_dead"):
		return

	var trident := PROJECTILE_POOL_REF.acquire(imp_arrow_scene) as ImpTridentProjectile
	if not trident:
		return

	trident.scale = PROJECTILE_SCALE
	var spawn_pos = global_position + Vector3(-0.3, altura_spawn_flecha, 0)
	var target_pos = player_ref.global_position + Vector3(0, 0.5, 0)
	var direction = (target_pos - spawn_pos).normalized()

	# Ajustar dirección para trayectoria parabólica (arco variable)
	var arco = randf_range(arco_altura_min, arco_altura_max)
	direction.y += arco
	direction = direction.normalized()

	var potencia = randf_range(velocidad_flecha_min, velocidad_flecha_max)
	trident.initialize(direction, potencia / 8.0)
	# Aplicar gravedad personalizada al tridente
	trident.gravedad = gravedad_tridente
	PROJECTILE_POOL_REF.activate(trident, get_tree().root, spawn_pos)
