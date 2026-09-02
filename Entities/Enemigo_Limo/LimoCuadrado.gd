class_name LimoCuadrado
extends "res://System/Core/EnemyBase.gd"

const PROJECTILE_POOL_REF = preload("res://System/Core/ProjectilePool.gd")
const PROJECTILE_SCALE: Vector3 = Vector3.ONE

## Limo cuadrado gelatinoso:
## - Avanza con deformación procedural squash & stretch (babosa).
## - Al recibir un impacto se deforma elásticamente hacia el costado del golpe.
## - Ataca lanzando un tridente igual que el Imp básico (mismo timing y arco).
## - Muerte con disolución estándar del EnemyBase (sin sangre física).
# === CONFIGURACIÓN ESPECÍFICA DEL LIMO ===
@export_category("Combate - Limo")
@export var intervalo_disparo: float = 3.0
@export var velocidad_flecha_min: float = 5.0  ## Velocidad mínima del tridente
@export var velocidad_flecha_max: float = 12.0  ## Velocidad máxima del tridente
@export var arco_altura_min: float = 1.0  ## Altura mínima del arco (parábola)
@export var arco_altura_max: float = 2.0  ## Altura máxima del arco (parábola)
@export var gravedad_tridente: float = 1.0  ## Gravedad del tridente (menor = parábola más ancha)
@export var pausa_idle_min: float = 1.0  ## Pausa mínima en IDLE entre lanzamientos
@export var pausa_idle_max: float = 2.0  ## Pausa máxima en IDLE entre lanzamientos

@export_category("Babosa - Deformación")
@export var velocidad_pulso: float = 3.0  ## Velocidad del pulso gelatinoso al avanzar (suave)
@export var amplitud_aplastar: float = 0.08  ## Cuánto se aplasta/estira en cada pulso (sutil)
@export var estiramiento_avance: float = 0.07  ## Estiramiento horizontal extra mientras camina
@export var amplitud_impacto: float = 0.55  ## Intensidad de la compresión gelatinosa al impactar
@export var duracion_impacto: float = 0.6  ## Duración del rebote de goma completo
@export var frecuencia_rebote: float = 9.0  ## Velocidad de oscilación de la gelatina (wobble)

# === REFERENCIAS Y ESTADO ===
var hueso_arrow_scene = preload("res://Entities/Proyectil_Hueso_Limo/HuesoLimo.tscn")
var material_limo: Material = preload("res://Entities/Enemigo_Limo/LIMO_MAT.tres")

var _modelo_limo: Node3D = null
var _modelo_ataque: Node3D = null
var _en_modelo_ataque: bool = false
var _intercambiando: bool = false  ## True durante el tween de cobertura del intercambio
var _pulso_fase: float = 0.0
var _impacto_dir: float = 0.0  ## Dirección de la compresión (derecha->izquierda según el golpe)
var _impacto_tiempo: float = -1.0  ## <0: sin impacto activo; >=0: segundos desde el impacto

# Ataque (mismo ciclo que el Imp). shoot_timer se hereda de EnemyBase.
var is_throwing: bool = false
var has_thrown: bool = false
var is_idle_pause: bool = false
var throw_anim_timer: float = 0.0
var throw_anim_duration: float = 1.7
var current_throw_time: float = 1.0

# ═══════════════════════════════════════════════════════════════════════════════
# HOOKS DE ENEMYBASE
# ═══════════════════════════════════════════════════════════════════════════════


func _on_enemy_ready() -> void:
	color_borde_disolucion = Color(0.3, 0.9, 0.4)
	rastrear_jugador = false
	tiene_sangre = false
	_play_animation("IDLE")
	_buscar_modelo()
	_aplicar_material()
	_pulso_fase = randf() * TAU
	set_process(true)


func _buscar_modelo() -> void:
	if _modelo_limo and is_instance_valid(_modelo_limo):
		return
	_modelo_limo = find_child("LimoModel", true, false) as Node3D
	if not _modelo_limo:
		_modelo_limo = find_child("Limo cuadrado", true, false) as Node3D
	if not _modelo_limo:
		var meshes := find_children("*", "MeshInstance3D", true, false)
		if meshes.size() > 0:
			_modelo_limo = meshes[0] as Node3D
	_modelo_ataque = find_child("LimoModeloAtaque", true, false) as Node3D
	if _modelo_ataque and is_instance_valid(_modelo_ataque):
		_modelo_ataque.visible = false


func _aplicar_material() -> void:
	if not material_limo:
		return
	var meshes := find_children("*", "MeshInstance3D", true, false)
	for mesh in meshes:
		(mesh as MeshInstance3D).material_override = material_limo


func _on_state_walking() -> void:
	pass


func _on_state_shooting() -> void:
	is_throwing = false
	is_idle_pause = true
	shoot_timer = 0.5


# ═══════════════════════════════════════════════════════════════════════════════
# BABOSA: DEFORMACIÓN PROCEDIMENTAL
# ═══════════════════════════════════════════════════════════════════════════════


func _process(delta: float) -> void:
	super._process(delta)
	_actualizar_deformacion_babosa(delta)


## Pulso gelatinoso: squash & stretch vertical sincronizado con el avance,
## mezclado con la compresión de goma del impacto (jelly wobble amortiguado).
func _actualizar_deformacion_babosa(delta: float) -> void:
	if not _modelo_limo or not is_instance_valid(_modelo_limo):
		return
	if current_state == State.DYING or current_state == State.DEAD:
		return
	# Durante el intercambio de modelos el tween de cobertura manda la escala
	if _intercambiando:
		return

	var moviendose: bool = current_state == State.WALKING and absf(velocity.x) > 0.01
	if moviendose:
		_pulso_fase += delta * velocidad_pulso
	var onda: float = sin(_pulso_fase)  ## -1..1
	var aplastar: float = amplitud_aplastar * onda

	# Escala base: aplastamiento vertical compensado en XZ (conserva volumen)
	var escala_y: float = 1.0 - aplastar
	var escala_xz: float = 1.0 + aplastar * 0.5

	# Estiramiento horizontal extra mientras se desplaza
	if moviendose:
		escala_xz += estiramiento_avance * absf(onda)

	# ═══ IMPACTO GELATINOSO (rebote de goma) ═══
	# El golpe comprime el cuerpo en el eje derecha-izquierda (eje Z local del
	# modelo girado) y lo abomba en Y/X local, oscilando como gelatina.
	var compresion: float = 0.0
	var abombado: float = 0.0
	if _impacto_tiempo >= 0.0:
		_impacto_tiempo += delta
		if _impacto_tiempo >= duracion_impacto:
			_impacto_tiempo = -1.0  # Fin del rebote
		else:
			# T: 0->1 a lo largo del impacto
			var t: float = _impacto_tiempo / duracion_impacto
			# Oscilación amortiguada (gelatina): sin(t*freq) * decaimiento
			var wobble: float = sin(t * TAU * frecuencia_rebote * 0.5) * (1.0 - t)
			compresion = wobble * amplitud_impacto * _impacto_dir
			# Compresión en el eje del golpe, abombado compensatorio (volumen)
			escala_xz *= 1.0 - absf(compresion)
			abombado = absf(compresion) * 0.6
			escala_y *= 1.0 + abombado

	## El modelo está rotado 90° en Y (mirando de costado): su Z local apunta al
	## eje X del mundo (derecha-izquierda en pantalla), por eso la compresión del
	## golpe se aplica sobre la Z local y el abombado sobre X local.
	var raiz: Node3D = _modelo_activo()
	if raiz != self:
		raiz.scale = Vector3(escala_xz + abombado, escala_y, escala_xz)
	else:
		scale = Vector3(escala_xz + abombado, escala_y, escala_xz)


## Modelo visible actual: normal o de ataque.
func _modelo_activo() -> Node3D:
	if _en_modelo_ataque and _modelo_ataque and is_instance_valid(_modelo_ataque):
		return _modelo_ataque
	return _modelo_limo


## Intercambia al modelo de ataque (o vuelve al normal) dentro de una compresión
## gelatinosa: el cambio de malla ocurre en el punto de máxima contracción, donde
## el ojo no distingue un modelo del otro.
func _intercambiar_modelo_ataque(a_ataque: bool) -> void:
	if a_ataque == _en_modelo_ataque:
		return
	if not _modelo_ataque or not is_instance_valid(_modelo_ataque) or not _modelo_limo or not is_instance_valid(_modelo_limo):
		return
	if current_state == State.DYING or current_state == State.DEAD:
		return

	var viejo: Node3D = _modelo_activo()
	_intercambiando = true
	# 1. Contracción rápida (squash) que oculta el pop
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(viejo, "scale:y", 0.55, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(viejo, "scale:x", 1.25, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(viejo, "scale:z", 1.25, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func() -> void:
		# 2. Punto de máxima compresión: intercambio de malla invisible
		_en_modelo_ataque = a_ataque
		_modelo_limo.visible = not a_ataque
		_modelo_ataque.visible = a_ataque
		_modelo_limo.scale = Vector3.ONE
		_modelo_ataque.scale = Vector3.ONE
	)
	# 3. Expansión elástica de retorno (jelly pop)
	var nuevo: Node3D = _modelo_ataque if a_ataque else _modelo_limo
	tw.chain().tween_property(nuevo, "scale", Vector3.ONE * 1.15, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(nuevo, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(func() -> void:
		_intercambiando = false
	)


## Dispara la compresión gelatinosa al recibir un impacto.
## La flecha entra desde la izquierda: el cuerpo se comprime de derecha a izquierda.
func _deformar_por_impacto(direccion_lateral: float) -> void:
	_impacto_dir = signf(direccion_lateral)
	_impacto_tiempo = 0.0


# ═══════════════════════════════════════════════════════════════════════════════
# DAÑO Y MUERTE
# ═══════════════════════════════════════════════════════════════════════════════


func take_damage(amount: float) -> void:
	if current_state == State.DYING or current_state == State.DEAD:
		return
	# Deformación lateral hacia el costado del golpe (las flechas vienen de la izquierda)
	var dir_lateral: float = 1.0
	if last_hit_position != Vector3.ZERO and global_position.x > last_hit_position.x:
		dir_lateral = 1.0  # Impacto desde la izquierda: se desparrama a la derecha
	else:
		dir_lateral = -1.0  # Impacto desde la derecha: hacia la izquierda
	_deformar_por_impacto(dir_lateral)
	super.take_damage(amount)


func _on_state_dying() -> void:
	# Congelar deformación y escala neutra antes de la disolución
	_impacto_tiempo = -1.0
	_en_modelo_ataque = false
	var fx := find_child("AtaqueLimoFX", true, false) as Sprite3D
	if fx and is_instance_valid(fx):
		fx.visible = false
		fx.modulate.a = 1.0
	if _modelo_ataque and is_instance_valid(_modelo_ataque):
		_modelo_ataque.visible = false
	if _modelo_limo and is_instance_valid(_modelo_limo) and _modelo_limo != self:
		_modelo_limo.visible = true
		_modelo_limo.scale = Vector3.ONE
	super._on_state_dying()
	AudioManager.play_sfx("imp_death")
	var anim_length: float = 1.2
	get_tree().create_timer(anim_length).timeout.connect(func() -> void:
		if is_instance_valid(self) and is_inside_tree():
			_die()
	)


# ═══════════════════════════════════════════════════════════════════════════════
# DISPARO / LANZAMIENTO (tridente, mismo patrón del Imp básico)
# ═══════════════════════════════════════════════════════════════════════════════


func _process_shooting(delta):
	velocity.x = 0

	if is_throwing:
		throw_anim_timer += delta
		_actualizar_fx_secuencia_ataque()
		if not has_thrown and throw_anim_timer >= current_throw_time:
			_throw_projectile()
			has_thrown = true
		if throw_anim_timer >= throw_anim_duration:
			is_throwing = false
			is_idle_pause = true
			shoot_timer = randf_range(pausa_idle_min, pausa_idle_max)
			# Fin del ataque: volver al modelo normal con la misma deformación
			_intercambiar_modelo_ataque(false)
	elif is_idle_pause:
		shoot_timer -= delta
		if shoot_timer <= 0:
			is_idle_pause = false
			_iniciar_lanzamiento()
	else:
		_iniciar_lanzamiento()


## Al atacar se cambia al modelo de ataque dentro de una compresión gelatinosa
## (el intercambio de malla queda oculto en el punto de máxima contracción).
func _iniciar_lanzamiento() -> void:
	is_throwing = true
	has_thrown = false
	throw_anim_timer = 0.0
	throw_anim_duration = 0.9
	current_throw_time = 0.55
	_intercambiar_modelo_ataque(true)
	_iniciar_fx_secuencia_ataque()


func _throw_projectile() -> void:
	if not hueso_arrow_scene:
		return

	AudioManager.play_sfx("trident_shot")

	if not player_ref:
		player_ref = get_tree().get_first_node_in_group("player")
		if not player_ref:
			return

	if player_ref.get("is_dead"):
		return

	var hueso := PROJECTILE_POOL_REF.acquire(hueso_arrow_scene) as HuesoLimoProjectile
	if not hueso:
		return

	hueso.scale = PROJECTILE_SCALE
	var spawn_pos = global_position + Vector3(-0.3, altura_spawn_flecha, 0)
	var target_pos = player_ref.global_position + Vector3(0, 0.5, 0)
	var direction = (target_pos - spawn_pos).normalized()

	# Trayectoria parabólica con arco variable (igual que el Imp)
	var arco = randf_range(arco_altura_min, arco_altura_max)
	direction.y += arco
	direction = direction.normalized()

	var potencia = randf_range(velocidad_flecha_min, velocidad_flecha_max)
	hueso.initialize(direction, potencia / 8.0)
	hueso.gravedad = gravedad_tridente

	PROJECTILE_POOL_REF.activate(hueso, get_tree().root, spawn_pos)

	# Secuencia FX: frame final (expulsión del hueso desde el interior)
	_mostrar_fx_expulsion()


## Inicia la secuencia de ataque (spritesheet de 8 frames) sincronizada con
## la carga del lanzamiento: frames 0..6 durante la contracción, frame 7 al
## expulsar el hueso. Complementa el modelo de ataque simulando que el hueso
## sale desde el interior del limo.
func _iniciar_fx_secuencia_ataque() -> void:
	var fx := find_child("AtaqueLimoFX", true, false) as Sprite3D
	if not fx:
		return
	fx.frame = 0
	fx.visible = true
	fx.modulate.a = 1.0


## Avanza la secuencia con el progreso del lanzamiento (llamado por frame
## mientras is_throwing). El último frame queda fijo hasta la expulsión.
func _actualizar_fx_secuencia_ataque() -> void:
	var fx := find_child("AtaqueLimoFX", true, false) as Sprite3D
	if not fx or not fx.visible:
		return
	var total_frames: int = fx.hframes
	if total_frames <= 1:
		return
	# Progreso 0..1 de la carga (hasta el momento del disparo)
	var progreso: float = clampf(throw_anim_timer / current_throw_time, 0.0, 1.0)
	# Recorrer todos los frames menos el último (reservado para la expulsión)
	fx.frame = int(progreso * (total_frames - 1))


## Muestra el frame final de la expulsión y lo desvanece.
func _mostrar_fx_expulsion() -> void:
	var fx := find_child("AtaqueLimoFX", true, false) as Sprite3D
	if not fx:
		return
	fx.frame = fx.hframes - 1
	fx.visible = true
	fx.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(fx, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		if is_instance_valid(fx):
			fx.visible = false
			fx.modulate.a = 1.0
			fx.frame = 0
	)
