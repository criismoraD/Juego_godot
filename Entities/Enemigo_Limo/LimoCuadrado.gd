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
@export var amplitud_impacto: float = 0.3  ## Deformación lateral al recibir un impacto
@export var duracion_impacto: float = 0.45  ## Duración del rebote elástico del impacto

# === REFERENCIAS Y ESTADO ===
var imp_arrow_scene = preload("res://Entities/Proyectil_Tridente_Imp/ImpTrident.tscn")
var material_limo: Material = preload("res://Entities/Enemigo_Limo/LIMO_MAT.tres")

var _modelo_limo: Node3D = null
var _pulso_fase: float = 0.0
var _tween_impacto: Tween = null
var _deformacion_impacto: float = 0.0  ## -1..1: costado de la deformación actual

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
	_modelo_limo = find_child("Limo cuadrado", true, false) as Node3D
	if not _modelo_limo:
		var meshes := find_children("*", "MeshInstance3D", true, false)
		if meshes.size() > 0:
			_modelo_limo = meshes[0] as Node3D


func _aplicar_material() -> void:
	if not material_limo or not _modelo_limo:
		return
	var meshes := _modelo_limo.find_children("*", "MeshInstance3D", true, false)
	if _modelo_limo is MeshInstance3D:
		meshes.append(_modelo_limo)
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


## Pulso gelatinoso: squash & stretch vertical sincronizado con el avance.
## Al avanzar se estira en X (avance) y se aplasta en Y en el punto bajo del pulso.
func _actualizar_deformacion_babosa(delta: float) -> void:
	if not _modelo_limo or not is_instance_valid(_modelo_limo):
		return
	if current_state == State.DYING or current_state == State.DEAD:
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

	# Deformación lateral por impacto (se aplica sobre el pulso)
	var costado: float = _deformacion_impacto
	if absf(costado) > 0.001:
		escala_xz *= 1.0
		escala_y *= 1.0 - absf(costado) * 0.3

	var raiz: Node3D = _modelo_limo
	## El modelo está rotado 90° en Y (mirando de costado): su Z local apunta al
	## eje X del mundo, por eso la deformación lateral se aplica sobre la Z local.
	if raiz != self:
		raiz.scale = Vector3(escala_xz, escala_y, escala_xz * (1.0 + costado * 0.5))
	else:
		scale = Vector3(escala_xz, escala_y, escala_xz * (1.0 + costado * 0.5))


## Deformación elástica hacia un costado al recibir un impacto.
## La flecha entra desde la izquierda: el limo se desparrama hacia la derecha.
func _deformar_por_impacto(direccion_lateral: float) -> void:
	_deformacion_impacto = direccion_lateral * amplitud_impacto
	if _tween_impacto and _tween_impacto.is_valid():
		_tween_impacto.kill()
	_tween_impacto = create_tween()
	_tween_impacto.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# Rebote elástico: la deformación vuelve a 0 oscilando (jelly)
	_tween_impacto.tween_method(
		func(val: float) -> void:
			_deformacion_impacto = val,
		_deformacion_impacto, 0.0, duracion_impacto
	)


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
	if _tween_impacto and _tween_impacto.is_valid():
		_tween_impacto.kill()
		_deformacion_impacto = 0.0
	if _modelo_limo and is_instance_valid(_modelo_limo) and _modelo_limo != self:
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
		if not has_thrown and throw_anim_timer >= current_throw_time:
			_throw_projectile()
			has_thrown = true
		if throw_anim_timer >= throw_anim_duration:
			is_throwing = false
			is_idle_pause = true
			shoot_timer = randf_range(pausa_idle_min, pausa_idle_max)
	elif is_idle_pause:
		shoot_timer -= delta
		if shoot_timer <= 0:
			is_idle_pause = false
			_iniciar_lanzamiento()
	else:
		_iniciar_lanzamiento()


## El limo no tiene animaciones GLB: el "lanzamiento" es una contracción rápida
## del cuerpo (estiramiento vertical) antes de soltar el tridente.
func _iniciar_lanzamiento() -> void:
	is_throwing = true
	has_thrown = false
	throw_anim_timer = 0.0
	throw_anim_duration = 0.9
	current_throw_time = 0.55
	# Contracción gelatinosa previa al lanzamiento (sutil)
	if _modelo_limo and is_instance_valid(_modelo_limo) and _modelo_limo != self:
		var tw := create_tween()
		tw.tween_property(_modelo_limo, "scale:y", 1.18, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(_modelo_limo, "scale:y", 1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _throw_projectile() -> void:
	if not imp_arrow_scene:
		return

	AudioManager.play_sfx("trident_shot")

	if not player_ref:
		player_ref = get_tree().get_first_node_in_group("player")
		if not player_ref:
			return

	if player_ref.get("is_dead"):
		return

	var trident := PROJECTILE_POOL_REF.acquire(imp_arrow_scene) as ImpTridentProjectile
	if not trident:
		return

	trident.scale = PROJECTILE_SCALE
	var spawn_pos = global_position + Vector3(-0.3, altura_spawn_flecha, 0)
	var target_pos = player_ref.global_position + Vector3(0, 0.5, 0)
	var direction = (target_pos - spawn_pos).normalized()

	# Trayectoria parabólica con arco variable (igual que el Imp)
	var arco = randf_range(arco_altura_min, arco_altura_max)
	direction.y += arco
	direction = direction.normalized()

	var potencia = randf_range(velocidad_flecha_min, velocidad_flecha_max)
	trident.initialize(direction, potencia / 8.0)
	trident.gravedad = gravedad_tridente

	PROJECTILE_POOL_REF.activate(trident, get_tree().root, spawn_pos)
