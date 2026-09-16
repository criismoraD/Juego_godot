class_name Azulina
extends EnemyBase

## Enemiga Azulina: emerge del agua con salto (squash & stretch), dispara
## su lanza a mitad del salto y al aterrizar, y muere con "Muerte 1" o "Muerte 3".
## Usa las animaciones del GLB: "Ataque salto del agua", "Correr", "Mirar" (quieta),
## "Ataque", "Daño", "Muerte 1" y "Muerte 3".

signal emergencia_completada

const ESCENA_LANZA: PackedScene = preload("res://Entities/Proyectil_Lanza_Azulina/LanzaAzulinaProjectile.tscn")
const ESCENA_SALPICADURA: PackedScene = preload("res://Entities/Enemigo_Azulina/SalpicaduraAzulina.tscn")
const MATERIAL_AZULINA: Material = preload("res://Entities/Enemigo_Azulina/Azulina_MAT.tres")
const MATERIAL_LANZA: Material = preload("res://Entities/Enemigo_Azulina/LanzaAzulina_MAT.tres")
const ANIM_SALTO_AGUA: String = "Ataque salto del agua"  ## Nombre exacto en el GLB (salto de emergencia)

# === EXPORTS ===
@export_category("Emergencia del agua")
@export var emerger_del_agua: bool = true  ## Si true, entra con salto desde el agua hasta el terreno
@export var hundimiento_emergencia: float = 2.5  ## Metros bajo el punto de caída donde nace (en el agua)
@export var alcance_emergencia_x: float = 1.5  ## Metros a la derecha del punto de caída donde nace (salto casi vertical)
@export var deriva_fondo_z: float = 1.0  ## Metros hacia la cámara desde donde nace (cae hacia el fondo)
@export var altura_salto: float = 2.0  ## Altura máxima del arco de emergencia sobre la recta origen→caída
@export var duracion_emergencia: float = 1.4  ## Segundos del salto

@export_category("Salpicadura al emerger")
@export var salpicadura_al_emerger: bool = true  ## Si true, genera el splash donde rompe el agua al emerger

@export_category("Remate al aterrizar")
@export var disparar_al_aterrizar: bool = true  ## Si true, al caer al terreno pasa a SHOOTING y lanza de inmediato
@export_range(0.0, 1.0, 0.05) var momento_disparo_emergencia: float = 0.55  ## Fracción del salto donde dispara entrando (ella entra atacando)

@export_category("Squash and Stretch")
@export var squash_stretch: bool = true  ## Deforma el modelo en el salto: estira al subir, aplasta al caer
@export_range(0.0, 0.4, 0.01) var intensidad_squash: float = 0.18  ## Desviación máxima de escala (conserva volumen)
@export var duracion_recuperacion_squash: float = 0.35  ## Segundos para volver a la forma base tras aterrizar

@export_category("Presencia")
@export var animacion_quieta: String = "Mirar"  ## Idle natural entre ataques (en vez de correr en el sitio)
@export var animaciones_muerte: Array[String] = ["Muerte 1", "Muerte 3"]  ## Muertes posibles, una al azar

@export_category("Ataque de lanza")
@export var tiempo_lanzamiento: float = 0.9  ## Segundo de la animación donde sale la lanza
@export var pausa_entre_lanzamientos_min: float = 1.2
@export var pausa_entre_lanzamientos_max: float = 2.0
@export var velocidad_lanza: float = 14.0  ## Más rápida que el tridente del imp (8)
@export var gravedad_lanza: float = 0.6  ## Más tensa que el tridente (1.2)
@export var dispersion_rad: float = 0.03  ## Dispersión mínima: precisión alta

# === ESTADO PRIVADO ===
var _emergiendo: bool = false
var _tiempo_emergencia: float = 0.0
var _origen_emergencia: Vector3 = Vector3.ZERO
var _destino_emergencia: Vector3 = Vector3.ZERO
var _lanzando: bool = false
var _lanzo_proyectil: bool = false
var _timer_lanzamiento: float = 0.0
var _pausa_lanzamiento: float = 1.5
var _modelo: Node3D = null  ## AzulinaModel cacheado para el squash & stretch
var _escala_modelo_base: float = 0.9  ## Escala de mundo del modelo (se captura en _ready)
var _memoria_squash: float = 0.0  ## Deformación remanente (-1 aplastada .. +1 estirada), decae a 0
var _lanzo_en_emergencia: bool = false  ## Disparo único a mitad del salto de entrada


# === HOOKS DE ENEMYBASE ===
func _on_enemy_ready() -> void:
	rastrear_jugador = false
	_modelo = find_child("AzulinaModel", true, false) as Node3D
	if _modelo:
		_escala_modelo_base = _modelo.scale.x
	_aplicar_material_azulina()
	_forzar_loop_movimiento()
	if emerger_del_agua:
		_iniciar_emergencia()
	else:
		_play_animation("Correr")


func _process_walking(delta: float) -> void:
	if _emergiendo:
		_procesar_emergencia(delta)
		return
	_recuperar_squash(delta)
	super._process_walking(delta)


func _process_shooting(delta: float) -> void:
	velocity.x = 0
	_recuperar_squash(delta)
	if _lanzando:
		_timer_lanzamiento += delta
		if not _lanzo_proyectil and _timer_lanzamiento >= tiempo_lanzamiento:
			_lanzar_lanza()
			_lanzo_proyectil = true
		if _timer_lanzamiento >= _duracion_anim_ataque():
			_lanzando = false
			_pausa_lanzamiento = randf_range(pausa_entre_lanzamientos_min, pausa_entre_lanzamientos_max)
			_play_animation(animacion_quieta)
	else:
		_pausa_lanzamiento -= delta
		if _pausa_lanzamiento <= 0.0:
			_iniciar_ataque()


func _on_state_dying() -> void:
	super._on_state_dying()
	_aplicar_squash_stretch(0.0)
	_play_animation(elegir_animacion_muerte())


func take_damage(amount: float) -> void:
	var viva_antes: bool = health > 0
	super.take_damage(amount)
	if viva_antes and health > 0 and current_state != State.DYING and current_state != State.DEAD:
		_play_animation("Daño")


# === FUNCIONES PÚBLICAS ===
## Inicia la emergencia desde el agua hacia la posición actual.
## El origen queda bajo el punto de caída (en el agua), el ápice
## se alcanza a mitad del salto y la caída es el destino en el terreno.
func emerger_en(destino: Vector3) -> void:
	_destino_emergencia = destino
	_origen_emergencia = destino + Vector3(alcance_emergencia_x, -hundimiento_emergencia, deriva_fondo_z)
	global_position = _origen_emergencia
	_tiempo_emergencia = 0.0
	_emergiendo = true
	_lanzo_en_emergencia = false
	_memoria_squash = 0.0
	velocity = Vector3.ZERO
	_spawnear_salpicadura()
	_play_animation(ANIM_SALTO_AGUA)


## Elige al azar una de las animaciones de muerte configuradas.
func elegir_animacion_muerte() -> String:
	if animaciones_muerte.is_empty():
		return "Muerte 1"
	return animaciones_muerte[randi() % animaciones_muerte.size()]


## Genera el splash donde rompe el agua al emerger (igual que Fuego2D es
## la versión productiva de su escena de pruebas).
func _spawnear_salpicadura() -> void:
	if not salpicadura_al_emerger:
		return
	if not is_inside_tree() or get_tree() == null:
		return
	var sal := ESCENA_SALPICADURA.instantiate() as SalpicaduraAzulina
	if sal == null:
		return
	var raiz: Node = get_tree().current_scene
	if raiz == null:
		raiz = get_tree().root
	raiz.add_child(sal)
	sal.disparar_impacto(_origen_emergencia, false)


## Punto más alto del salto: mitad del recorrido + altura del arco.
func calcular_apice_salto() -> Vector3:
	var apice: Vector3 = _origen_emergencia.lerp(_destino_emergencia, 0.5)
	apice.y += sin(0.5 * PI) * altura_salto
	return apice


# === FUNCIONES PRIVADAS ===
func _iniciar_emergencia() -> void:
	emerger_en(global_position)


func _procesar_emergencia(delta: float) -> void:
	velocity = Vector3.ZERO
	_tiempo_emergencia += delta
	var avance: float = clampf(_tiempo_emergencia / maxf(duracion_emergencia, 0.01), 0.0, 1.0)
	var pos: Vector3 = _origen_emergencia.lerp(_destino_emergencia, avance)
	pos.y += sin(avance * PI) * altura_salto
	global_position = pos
	_aplicar_envolvente_salto(avance)
	if not _lanzo_en_emergencia and avance >= momento_disparo_emergencia:
		_lanzo_en_emergencia = true
		_lanzar_lanza()
	if avance >= 1.0:
		_emergiendo = false
		global_position = _destino_emergencia
		_memoria_squash = -1.0
		_aplicar_squash_stretch(_memoria_squash)
		VFXFactory.spawn_shield_break_smoke(self, _destino_emergencia)
		emergencia_completada.emit()
		_al_aterrizar()


## Envolvente del salto: estira al despegar (+1), relaja en el ápice (0)
## y aplasta al tocar suelo (-1). Con entrada suavizada para no arrancar de golpe.
func _aplicar_envolvente_salto(avance: float) -> void:
	if not squash_stretch:
		return
	var entrada: float = clampf(avance / 0.08, 0.0, 1.0)
	_aplicar_squash_stretch(cos(avance * PI) * entrada)


## Aplica la deformación conservando volumen (lo que crece en Y encoge en XZ).
func _aplicar_squash_stretch(k: float) -> void:
	if _modelo == null:
		return
	var deformacion: float = intensidad_squash * k if squash_stretch else 0.0
	var escala_y: float = 1.0 + deformacion
	var escala_xz: float = 1.0 - deformacion * 0.5
	_modelo.scale = Vector3(_escala_modelo_base * escala_xz, _escala_modelo_base * escala_y, _escala_modelo_base * escala_xz)


## Tras aterrizar, la deformación remanente decae a la forma base.
func _recuperar_squash(delta: float) -> void:
	if _memoria_squash == 0.0:
		return
	_memoria_squash = move_toward(_memoria_squash, 0.0, delta / maxf(duracion_recuperacion_squash, 0.01))
	_aplicar_squash_stretch(_memoria_squash)


## Al caer al terreno (punto 2): dispara la lanza de inmediato o retoma la marcha.
func _al_aterrizar() -> void:
	if current_state == State.DYING or current_state == State.DEAD:
		return
	if disparar_al_aterrizar:
		_change_state(State.SHOOTING)
		_iniciar_ataque()
	else:
		_play_animation("Correr")


func _iniciar_ataque() -> void:
	_lanzando = true
	_lanzo_proyectil = false
	_timer_lanzamiento = 0.0
	_play_animation("Ataque")


func _duracion_anim_ataque() -> float:
	return _get_animation_duration("Ataque")


func _lanzar_lanza() -> void:
	var objetivo: Node3D = player_ref as Node3D
	if not is_instance_valid(objetivo):
		objetivo = get_tree().get_first_node_in_group("player") as Node3D
	var origen: Vector3 = global_position + Vector3(-0.2, 0.5, 0.0)  ## Mano de una Azulina de ~0.9 m
	var direccion := Vector3.LEFT
	if is_instance_valid(objetivo):
		direccion = ((objetivo.global_position + Vector3(0.0, 0.8, 0.0)) - origen).normalized()
	direccion = direccion.rotated(Vector3.UP, randf_range(-dispersion_rad, dispersion_rad))
	var lanza := ESCENA_LANZA.instantiate() as LanzaAzulinaProjectile
	if lanza == null:
		return
	var raiz: Node = get_tree().current_scene
	if raiz == null:
		raiz = get_tree().root
	raiz.add_child(lanza)
	lanza.global_position = origen
	lanza.initialize(direccion, 1.0)
	lanza.velocidad = velocidad_lanza
	lanza.gravedad = gravedad_lanza
	AudioManager.play_sfx("trident_shot")


func _aplicar_material_azulina() -> void:
	if MATERIAL_AZULINA:
		for m in find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi and mi.find_parent("LanzaMano") == null:
				mi.material_override = MATERIAL_AZULINA
	if MATERIAL_LANZA:
		var mano := find_child("LanzaMano", true, false)
		if mano:
			for m in mano.find_children("*", "MeshInstance3D", true, false):
				(m as MeshInstance3D).material_override = MATERIAL_LANZA


func _forzar_loop_movimiento() -> void:
	if anim_player == null:
		return
	var en_bucle: Array[String] = ["Correr", "Correr agachado", "Nadar"]
	if not en_bucle.has(animacion_quieta):
		en_bucle.append(animacion_quieta)
	for nombre_anim in en_bucle:
		for variante in [nombre_anim, "Armature|" + nombre_anim]:
			if anim_player.has_animation(variante):
				anim_player.get_animation(variante).loop_mode = Animation.LOOP_LINEAR
