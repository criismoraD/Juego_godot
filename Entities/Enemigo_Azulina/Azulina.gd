class_name Azulina
extends EnemyBase

## Enemiga Azulina: emerge del agua con salto (squash & stretch), dispara
## su lanza a mitad del salto y al aterrizar, y muere con "Muerte 1" o "Muerte 3".
## Usa las animaciones del GLB: "Ataque salto del agua", "Correr", "Mirar" (quieta),
## "Ataque", "Daño", "Muerte 1" y "Muerte 3".

signal emergencia_completada

const ESCENA_LANZA: PackedScene = preload("res://Entities/Proyectil_Lanza_Azulina/LanzaAzulinaProjectile.tscn")
const ESCENA_SALPICADURA: PackedScene = preload("res://Entities/Enemigo_Azulina/SalpicaduraAgua.tscn")
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
@export var emergencia_en_zona_aleatoria: bool = true  ## Si true, el punto de caida se sortea dentro de la zona (no sale siempre del mismo lugar)
@export var usar_centro_zona_personalizado: bool = false  ## Si false, la zona se centra en el punto de spawn
@export var zona_centro: Vector3 = Vector3.ZERO  ## Centro manual de la zona (solo si usar_centro_zona_personalizado)
@export var zona_extension: Vector3 = Vector3(4.0, 0.0, 0.0)  ## Semiextensiones XZ de la zona (Z en 0: fijo al plano enemigo para que las flechas impacten)
@export var aterrizar_en_centro: bool = false  ## Si true, cae en centro_aterrizaje_x aunque emerja en la zona
@export var centro_aterrizaje_x: float = 0.0  ## X del punto de caída (centro del eje)

@export_category("Salpicadura al emerger")
@export var salpicadura_al_emerger: bool = true  ## Si true, genera el splash donde rompe el agua al emerger
@export var profundidad_rotura: float = 0.2  ## Metros bajo el destino (orilla) donde nace el splash
@export var adelanto_camara_salpicadura: float = 1.5  ## Metros hacia la camara desde el origen para que el ledge no lo tape
@export var desplazamiento_lateral_salpicadura: float = -0.5  ## Metros en X desde el origen (negativo = izquierda en pantalla)

@export_category("Remate al aterrizar")
@export var disparar_al_aterrizar: bool = true  ## Si true, al caer al terreno pasa a SHOOTING y lanza de inmediato
@export_range(0.0, 1.0, 0.05) var momento_disparo_emergencia: float = 0.55  ## Fracción del salto donde dispara entrando (ella entra atacando)

@export_category("Squash and Stretch")
@export var squash_stretch: bool = true  ## Deforma el modelo en el salto: estira al subir, aplasta al caer
@export_range(0.0, 0.4, 0.01) var intensidad_squash: float = 0.18  ## Desviación máxima de escala (conserva volumen)
@export var duracion_recuperacion_squash: float = 0.35  ## Segundos para volver a la forma base tras aterrizar

@export_category("Presencia")
@export var animacion_quieta: String = "Idle"  ## Idle natural entre ataques (en vez de correr en el sitio)
@export var animaciones_muerte: Array[String] = ["Muerte 1", "Muerte 3"]  ## Muertes posibles, una al azar
@export_range(0.0, 1.0, 0.05) var fundido_transiciones: float = 0.3  ## Fundido al volver a la calma (quieta, correr, fin de parry)
@export_range(0.0, 1.0, 0.05) var fundido_ataque: float = 0.12  ## Fundido al entrar en acción (ataque, salto, giro)

@export_category("Parry de lanza")
@export var parry_habilitado: bool = true  ## Si true, puede girar la lanza para repeler proyectiles
@export var duracion_parry: float = 3.0  ## Segundos que dura el giro repelente
@export var ataques_para_parry_min: int = 4  ## Mínimo de ataques recibidos para activar al azar
@export var ataques_para_parry_max: int = 5  ## Máximo de ataques recibidos para activar al azar
@export var ventana_multidisparo: float = 0.6  ## Segundos: 2+ impactos en esta ventana activan de inmediato
@export var enfriamiento_parry: float = 5.0  ## Segundos vulnerables tras un parry antes de poder activar otro
@export var animacion_parry: String = "Giro de lanza parry"  ## Giro corto que se repite invertido en loop
@export var escala_lanza_parry: float = 1.5  ## Tamaño del asta durante el giro (el reposo se restaura solo)
@export var forzar_parry_debug: bool = false:  ## DEBUG en juego (árbol Remoto): al activar fuerza el parry para verificar lanza y giro
	set(v):
		forzar_parry_debug = v
		if v and is_node_ready() and is_inside_tree() and not Engine.is_editor_hint():
			_activar_parry()

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
var _tiempo_flinch: float = 0.0  ## Segundos restantes de la animación de daño (bloquea el ataque para que se vea)
var _parry_activo: bool = false  ## Giro de lanza repelente en curso
var _tiempo_parry: float = 0.0  ## Segundos restantes del parry
var _tiempo_enfriamiento: float = 0.0  ## Segundos restantes vulnerables antes del próximo parry
var _contador_ataques: int = 0  ## Ataques recibidos en el ciclo actual (para el sorteo 4-5)
var _umbral_parry: int = 4  ## Ataques necesarios para activar (se sortea 4-5 por ciclo)
var _impactos_recientes: Array[float] = []  ## Tiempos de impactos (para detectar multidisparo)
var _anim_parry_loop: String = ""  ## Nombre del giro duplicado para el ping-pong
var _parry_hacia_atras: bool = false  ## Dirección actual del ping-pong del giro
var _mano: Node3D = null  ## LanzaMano cacheada (solo visible durante el parry)
var _escala_lanza_base: Vector3 = Vector3.ZERO  ## Escala de reposo del asta (se restaura tras el parry)


# === HOOKS DE ENEMYBASE ===
func _on_enemy_ready() -> void:
	rastrear_jugador = false
	_modelo = find_child("AzulinaModel", true, false) as Node3D
	if _modelo:
		_escala_modelo_base = _modelo.scale.x
	_aplicar_material_azulina()
	_forzar_loop_movimiento()
	_umbral_parry = _sortear_umbral_parry()
	_mostrar_lanza(false)
	if emerger_del_agua:
		_iniciar_emergencia()
	else:
		_play_animation("Correr")


func _process_walking(delta: float) -> void:
	if _emergiendo:
		_procesar_emergencia(delta)
		return
	if _procesar_parry(delta):
		return
	_recuperar_squash(delta)
	super._process_walking(delta)


func _process_shooting(delta: float) -> void:
	velocity.x = 0
	_recuperar_squash(delta)
	if _procesar_parry(delta):
		return
	if _tiempo_flinch > 0.0:
		_tiempo_flinch -= delta
		if anim_player != null and not String(anim_player.current_animation).contains("Daño"):
			_play_animation("Daño")
		return
	if _lanzando:
		_timer_lanzamiento += delta
		if not _lanzo_proyectil and _timer_lanzamiento >= tiempo_lanzamiento:
			_lanzar_lanza()
			_lanzo_proyectil = true
		if _timer_lanzamiento >= _duracion_anim_ataque():
			_lanzando = false
			_pausa_lanzamiento = randf_range(pausa_entre_lanzamientos_min, pausa_entre_lanzamientos_max)
			_play_animation(animacion_quieta, fundido_transiciones)
	else:
		_pausa_lanzamiento -= delta
		if _pausa_lanzamiento <= 0.0:
			_iniciar_ataque()


func _on_state_dying() -> void:
	super._on_state_dying()
	_parry_activo = false
	_mostrar_lanza(false)
	_aplicar_squash_stretch(0.0)
	_play_animation(elegir_animacion_muerte())


func take_damage(amount: float) -> void:
	var viva_antes: bool = health > 0
	super.take_damage(amount)
	if viva_antes and health > 0 and not _parry_activo and current_state != State.DYING and current_state != State.DEAD:
		_tiempo_flinch = clampf(_get_animation_duration("Daño"), 0.3, 0.9)
		_play_animation("Daño")


# === PARRY DE LANZA ===
const MARGEN_GIRO_PARRY: float = 0.05  ## Ventana (s) para invertir el giro antes del extremo


## Hook del aura repelente (igual que Arquera Rosa): lo llaman los proyectiles al impactar.
## Devuelve true si el proyectil fue repelido (no hace daño).
func manejar_impacto_aura(flecha: Node) -> bool:
	if not parry_habilitado:
		return false
	if current_state == State.DYING or current_state == State.DEAD:
		return false
	if _parry_activo:
		AudioManager.play_sfx("parry")
		return true
	if _tiempo_enfriamiento > 0.0:
		return false
	if not is_inside_tree():
		return false
	var ahora: float = Time.get_ticks_msec() / 1000.0
	_impactos_recientes.append(ahora)
	while not _impactos_recientes.is_empty() and ahora - _impactos_recientes[0] > ventana_multidisparo:
		_impactos_recientes.pop_front()
	if _impactos_recientes.size() >= 2:
		_activar_parry()
		AudioManager.play_sfx("parry")
		return true
	_contador_ataques += 1
	if _contador_ataques >= _umbral_parry:
		_activar_parry()
		AudioManager.play_sfx("parry")
		return true
	return false


## Inicia el giro repelente de 3 segundos con la lanza visible.
func _activar_parry() -> void:
	_parry_activo = true
	_tiempo_parry = duracion_parry
	_contador_ataques = 0
	_impactos_recientes.clear()
	_umbral_parry = _sortear_umbral_parry()
	_mostrar_lanza(true)
	_iniciar_anim_parry()


## Avanza el parry y su enfriamiento; retorna true para congelar marcha y ataque mientras dura.
func _procesar_parry(delta: float) -> bool:
	if _tiempo_enfriamiento > 0.0:
		_tiempo_enfriamiento -= delta
	if not _parry_activo:
		return false
	_tiempo_parry -= delta
	velocity.x = 0
	_conducir_anim_parry()
	if _tiempo_parry <= 0.0:
		_desactivar_parry()
	return true


## Termina el giro, oculta la lanza, abre la ventana vulnerable y retoma el ciclo de combate.
func _desactivar_parry() -> void:
	_parry_activo = false
	_tiempo_enfriamiento = enfriamiento_parry
	_mostrar_lanza(false)
	if current_state == State.DYING or current_state == State.DEAD:
		return
	if _lanzando:
		_play_animation("Ataque", fundido_transiciones)
	elif current_state == State.SHOOTING:
		_play_animation(animacion_quieta, fundido_transiciones)
	else:
		_play_animation("Correr", fundido_transiciones)


func _sortear_umbral_parry() -> int:
	var minimo: int = maxi(1, ataques_para_parry_min)
	var maximo: int = maxi(minimo, ataques_para_parry_max)
	return randi_range(minimo, maximo)


func _mostrar_lanza(visible: bool) -> void:
	if not is_instance_valid(_mano):
		_mano = find_child("LanzaMano", true, false) as Node3D
	if not is_instance_valid(_mano):
		return
	if visible:
		if _escala_lanza_base == Vector3.ZERO:
			_escala_lanza_base = _mano.scale
		_mano.scale = Vector3.ONE * escala_lanza_parry
	else:
		if _escala_lanza_base != Vector3.ZERO:
			_mano.scale = _escala_lanza_base
	_mano.visible = visible


## El giro es corto: lo duplica y lo repite invertido en loop para que calce.
func _iniciar_anim_parry() -> void:
	if anim_player == null:
		return
	var original: String = ""
	for nombre: String in anim_player.get_animation_list():
		if nombre == animacion_parry:
			original = nombre
			break
	if original.is_empty():
		for nombre: String in anim_player.get_animation_list():
			if nombre.contains(animacion_parry):
				original = nombre
				break
	if original.is_empty():
		push_warning("[Azulina] animación de parry no encontrada: " + animacion_parry)
		return
	_anim_parry_loop = original.replace(" ", "").replace("|", "") + "ParryLoop"
	if not anim_player.has_animation(_anim_parry_loop):
		var giro := anim_player.get_animation(original).duplicate() as Animation
		giro.loop_mode = Animation.LOOP_NONE
		_agregar_animacion(anim_player, _anim_parry_loop, giro)
	_parry_hacia_atras = false
	anim_player.play(_anim_parry_loop, fundido_ataque)


func _conducir_anim_parry() -> void:
	if anim_player == null or _anim_parry_loop.is_empty():
		return
	if anim_player.current_animation != _anim_parry_loop or not anim_player.is_playing():
		return
	var anim := anim_player.get_animation(_anim_parry_loop)
	if anim == null or anim.length <= 0.0:
		return
	var pos: float = anim_player.current_animation_position
	if not _parry_hacia_atras and pos >= anim.length - MARGEN_GIRO_PARRY:
		_parry_hacia_atras = true
		anim_player.play_backwards(_anim_parry_loop)
	elif _parry_hacia_atras and pos <= MARGEN_GIRO_PARRY:
		_parry_hacia_atras = false
		anim_player.play(_anim_parry_loop)


## En Godot 4 las animaciones viven en AnimationLibrary (igual que AzulinaPosando).
func _agregar_animacion(player: AnimationPlayer, nombre: String, anim: Animation) -> void:
	var listas: PackedStringArray = player.get_animation_library_list()
	var libreria: String = ""
	if listas.has(""):
		libreria = ""
	elif listas.size() > 0:
		libreria = listas[0]
	player.get_animation_library(libreria).add_animation(nombre, anim)


# === FUNCIONES PÚBLICAS ===
## Inicia la emergencia desde el agua hacia la posición actual.
## El origen queda bajo el punto de caída (en el agua), el ápice
## se alcanza a mitad del salto y la caída es el destino en el terreno.
func emerger_en(destino: Vector3) -> void:
	var punto_caida := destino
	if emergencia_en_zona_aleatoria:
		var centro := zona_centro if usar_centro_zona_personalizado else destino
		punto_caida = Vector3(
			centro.x + randf_range(-zona_extension.x, zona_extension.x),
			centro.y,
			centro.z + randf_range(-zona_extension.z, zona_extension.z)
		)
	if aterrizar_en_centro:
		punto_caida.x = centro_aterrizaje_x
	_destino_emergencia = punto_caida
	_origen_emergencia = punto_caida + Vector3(alcance_emergencia_x, -hundimiento_emergencia, deriva_fondo_z)
	global_position = _origen_emergencia
	_tiempo_emergencia = 0.0
	_emergiendo = true
	_lanzo_en_emergencia = false
	_memoria_squash = 0.0
	velocity = Vector3.ZERO
	_spawnear_salpicadura()
	if is_inside_tree() and get_tree() != null and not Engine.is_editor_hint():
		AudioManager.play_sfx_3d("entrada_azulina", _origen_emergencia)
	_play_animation(ANIM_SALTO_AGUA, fundido_ataque)


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
	var sal := ESCENA_SALPICADURA.instantiate() as SalpicaduraAgua
	if sal == null:
		return
	var raiz: Node = get_tree().current_scene
	if raiz == null:
		raiz = get_tree().root
	raiz.add_child(sal)
	# Punto de rotura: XZ del origen sumergido adelantado a camara, Y apenas bajo la orilla.
	var punto_rotura := Vector3(
		_origen_emergencia.x + desplazamiento_lateral_salpicadura,
		_destino_emergencia.y - profundidad_rotura,
		_origen_emergencia.z + adelanto_camara_salpicadura
	)
	sal.disparar_impacto(punto_rotura, false)


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
		_play_animation("Correr", fundido_transiciones)


func _iniciar_ataque() -> void:
	_lanzando = true
	_lanzo_proyectil = false
	_timer_lanzamiento = 0.0
	_play_animation("Ataque", fundido_ataque)


func _duracion_anim_ataque() -> float:
	return _get_animation_duration("Ataque")


func _lanzar_lanza() -> void:
	if _parry_activo:
		return
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
			var candidatos: Array[Node] = [mano]
			candidatos.append_array(mano.find_children("*", "MeshInstance3D", true, false))
			for m in candidatos:
				if m is MeshInstance3D:
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
