@tool
class_name SubmarinoRio
extends Node3D

## Submarino interactivo para el nivel del río.
## - Permanece sumergido hasta que la cámara o la canoa se aproximan.
## - Emerge suavemente hasta la altura configurada (altura_emergido_y).
## - En superficie realiza un movimiento suave de flotación y balanceo.
## - Cuenta con una plataforma sólida con colisión en la cubierta (zona rosada)
##   y un punto de spawn en la puerta de la torreta (zona celeste).
## - Despliega enemigos según la selección del Inspector (Imp, Pirata Goblin o Goblin Arquera).
## - Cuando todos los enemigos desplegados son eliminados, desciende lentamente
##   hacia las profundidades hasta salir de escena y liberarse.
## - Despedida del cañón: al morir los enemigos de la plataforma, el cañón de
##   cubierta se eleva apuntando al cielo y dispara el ult de Lonko
##   (Flecha_Electrica_Ataque) desde su boca, con leve deformación al disparar;
##   luego regresa a su forma y el submarino se hunde normalmente.

signal emergido
signal enemigo_desplegado(enemigo: Node3D)
signal todos_enemigos_derrotados
signal sumersion_completada
signal canon_disparo_final_realizado

enum TipoEnemigo {
	IMP,
	PIRATA_GOBLIN,
	GOBLIN_ARQUERA,
	PIRATA,
	IMP_EMBAJADOR
}

enum State {
	SUMERGIDO,
	EMERGIENDO,
	EN_SUPERFICIE,
	ESPERANDO_MUERTE,
	DISPARO_FINAL,
	SUMERGIENDOSE,
	DESAPARECIDO
}

const ESCENA_IMP: PackedScene = preload("res://Entities/Enemigo_Imp/ImpEnemy.tscn")
const ESCENA_GOBLIN_ARQUERA: PackedScene = preload("res://Entities/Enemigo_Goblin_Girl/GoblinGirl.tscn")
const ESCENA_GOBLIN_BASE: PackedScene = preload("res://Entities/Enemigo_Goblin/Goblin.tscn")
const ESCENA_PIRATA: PackedScene = preload("res://Entities/Enemigo_Pirata_Goblin/PirataGoblin.tscn")
const ESCENA_IMP_EMBAJADOR: PackedScene = preload("res://Entities/Enemigo_Imp_Estandarte/ImpEnemyEstandarte.tscn")
const ESCENA_FLECHA_LONKO: PackedScene = preload("res://Entities/Enemigo_Lonko/Flecha_Electrica_Ataque.tscn")
const SFX_CANON_DISPARO: AudioStream = preload("res://Entities/Enemigo_Lonko/EXPLOSION01.mp3")
const SFX_CANON_ENGRANAJE: AudioStream = preload("res://TEST_/Engranaje cañon.mp3")
const SFX_SPLASH: String = "res://TEST_/splash sonido.mp3"
const SFX_EMERGIENDO: String = "res://TEST_/submarino_emergiendo.mp3"
const ESCENA_ONDA_SPLASH: PackedScene = preload("res://TEST_/swimming-in-godot-from-scracth/SCENES/splash_vfx.tscn")
## Velocidad de caminata de los enemigos sobre la cubierta del submarino (m/s)
const VELOCIDAD_CAMINATA_CUBIERTA: float = 2.0
## Tiempo de pausa al detenerse en su posición antes de comenzar el ataque (s)
const TIEMPO_DETENCION_PREVIO_ATAQUE: float = 0.15

# === EXPORTS ===
@export_category("Enemigos")
## Tipo de enemigo que saldrá por la escotilla del submarino
@export var tipo_enemigo: TipoEnemigo = TipoEnemigo.GOBLIN_ARQUERA

## Cantidad total de enemigos a desplegar
@export_range(1, 6, 1) var cantidad_enemigos: int = 2

## Intervalo de tiempo en segundos entre la salida de cada enemigo
@export var intervalo_spawn: float = 1.0

## Escena personalizada opcional para Pirata Goblin cuando esté lista
@export var escena_pirata_custom: PackedScene = null

@export_category("Mezcla de Enemigos")
## Cantidades por tipo para mezclar el despliegue (ej: 3 piratas + 1 embajador + 1 arquera).
## Si todas están en 0 se usa el modo clásico (tipo_enemigo x cantidad_enemigos).
## Máximo 13 por tipo para soportar al Jefe Submarino (7 piratas + 3 arqueras + 3 imp).
@export_range(0, 13, 1) var cantidad_imp: int = 0
@export_range(0, 13, 1) var cantidad_pirata: int = 0
@export_range(0, 13, 1) var cantidad_goblin_arquera: int = 0
@export_range(0, 13, 1) var cantidad_imp_embajador: int = 0
@export var mezclar_orden_aleatorio: bool = true  ## Si false, salen agrupados por tipo en orden de la lista

@export_category("Inmersión y Emergencia")
## Si está activo, el submarino emergerá exactamente a la altura Y en la que lo coloques en el editor.
@export var usar_posicion_editor_como_emergido: bool = true

## Altura Y a la que emerge en el agua (solo si 'usar_posicion_editor_como_emergido' es false).
@export var altura_emergido_y: float = -0.3

## Metros que desciende bajo el agua al estar sumergido
@export var profundidad_sumergido: float = 3.5

## Rapidez vertical de ascenso al emerger (m/s)
@export var velocidad_emerger: float = 1.2

## Rapidez vertical de descenso al sumergirse tras vencer a los enemigos (m/s)
@export var velocidad_sumergir: float = 0.8

## Modificador de velocidad y tono (pitch_scale) al sumergirse para que suene más lento y pesado
@export_range(0.5, 1.0, 0.02) var pitch_sonido_sumersion: float = 0.78

## Si true, emerge automáticamente cuando la cámara/jugador se acerca en X
@export var activar_al_entrar_en_camara: bool = true

## Distancia horizontal en X con la cámara para emerger ya centrada en cuadro
## (no al asomar por el borde, para apreciar la animación completa)
@export var distancia_activacion_x: float = 2.5
@export_category("Bloqueo de Canoa")
@export var margen_bloqueo_proa: float = 5.0  ## Mitad del casco + margen: la canoa se detiene antes de tocarlo

@export_category("Flotación")
## Si true, realiza un suave balanceo y cabeceo al estar en la superficie
@export var flotacion_activa: bool = true
@export var amplitud_floteo: float = 0.05  ## Sube y baja en metros
@export var velocidad_floteo: float = 0.8  ## Ciclos por segundo
@export var amplitud_balanceo: float = 1.0  ## Balanceo lateral en grados
@export var amplitud_cabeceo: float = 0.6  ## Cabeceo proa-popa en grados

@export_category("Zona Prohibida de la Vela")
@export var vela_x_min: float = -1.8  ## Borde izquierdo de la vela en X local del submarino
@export var vela_x_max: float = -0.4  ## Borde derecho de la vela en X local del submarino
@export var margen_vela: float = 0.6  ## Margen extra a cada lado para no quedar tapados
@export var separacion_puestos: float = 0.6  ## Distancia mínima entre puestos en cubierta
var _offsets_deck_usados: Array[float] = []  ## Puestos ya asignados en este despliegue (X local)

@export_category("Material")
@export var material_submarino: StandardMaterial3D:
	set(nuevo_material):
		if material_submarino == nuevo_material:
			return
		material_submarino = nuevo_material
		_aplicar_material()

@export_category("Casco Húmedo al Emerger")
@export var efecto_humedo_al_emerger: bool = true  ## El casco sale mojado (oscuro y brillante) y se seca paulatino
@export var tiempo_secado_humedo: float = 6.0  ## Segundos hasta volver al aspecto seco
@export_category("Onda al Emerger")
@export var mostrar_onda_al_emerger: bool = true  ## Anillo de onda del splash nuevo al romper la superficie
@export var escala_onda_emerger: float = 2.5  ## Tamaño de la onda respecto al submarino
@export var duracion_onda_emerger: float = 3.0  ## Segundos visible la onda (su animación es en loop)
@export_category("Goteo de Cubierta")
@export var gotas_al_emerger: bool = true  ## La cubierta gotea al emerger hasta que el casco se seca
@export var cantidad_gotas: int = 40  ## Gotas simultáneas cayendo de la cubierta

@export_category("Cañón - Disparo Final")
@export var canon_disparo_final: bool = true  ## Al morir los enemigos, el cañón dispara el ult de Lonko antes de hundirse
@export var canon_tiempo_apuntado: float = 0.8  ## Segundos que tarda el cañón en elevarse hacia el cielo
@export var canon_pausa_antes_disparo: float = 0.4  ## Pausa apuntando arriba antes de disparar
@export var canon_lado_boca: float = -1.0  ## Boca en -X: al elevar sube la boca con giro horario en pantalla (default)
@export var canon_offset_boca: Vector3 = Vector3(0.62, 0.35, 0.0)  ## Reserva si la malla no se encuentra (X en valor absoluto, el signo lo pone lado_boca)
@export var canon_margen_boca: float = 0.35  ## Cuánto sobresale el punto de disparo más allá de la boca
@export var canon_escala_disparo: float = 1.1  ## Expansión sutil del cañón al disparar (1.1 = +10%)
@export var canon_duracion_deformacion: float = 0.35  ## Duración del punch de expansión al disparar
@export var canon_tiempo_regreso: float = 0.6  ## Segundos para volver a la forma original tras disparar

# === VARIABLES PRIVADAS ===
var current_state: State = State.SUMERGIDO
var _altura_objetivo_y: float = 0.0
var _tiempo_floteo: float = 0.0
var _enemigos_vivos: Array[Node3D] = []
var _enemigos_restantes_por_spawnear: int = 0
var _timer_spawn: float = 0.0
var _spawneo_iniciado: bool = false
var _y_limite_desaparicion: float = -20.0
var _notificador_pantalla: VisibleOnScreenNotifier3D = null
var _mats_humedos: Array = []  ## Materiales duplicados del casco en secado
var _tween_secado: Tween = null
var _goteo_cubierta: GPUParticles3D = null  ## Gotas que caen de la cubierta hasta secarse
var _disparo_canon_realizado: bool = false  ## El cañón solo dispara su despedida una vez
var _canon_modelo: Node3D = null  ## Nodo CanonModel de la cubierta
var _canon_rot_base: Vector3 = Vector3.ZERO  ## Rotación del cañón tal como quedó en el editor
var _canon_escala_base: Vector3 = Vector3.ONE  ## Escala del cañón tal como quedó en el editor
var _boca_canon: Marker3D = null  ## Punto de salida del ult en la punta del cañón (creado por código)
var _boca_canon_manual: bool = false  ## True si BocaCanon ya venía en la escena: se respeta tal cual, sin reposicionar
var _tween_canon: Tween = null
var _cola_mezcla: Array = []  ## Cola de TipoEnemigo a desplegar (mezcla o modo clásico)
var _total_oleada: int = 0  ## Total de enemigos del despliegue actual (para repartir puestos)
var _amplitudes_oleaje_base: Dictionary = {}
var _tween_oleaje: Tween = null

# === ONREADY ===
@onready var pivot_flotacion: Node3D = find_child("PivotFlotacion", true, false) as Node3D
@onready var modelo: Node3D = find_child("Model", true, false) as Node3D
@onready var spawn_point: Marker3D = find_child("SpawnPoint", true, false) as Marker3D
@onready var plataforma_cubierta: CollisionObject3D = find_child("PlataformaCubierta", true, false) as CollisionObject3D
@onready var audio_splash: AudioStreamPlayer3D = find_child("AudioSplash", true, false) as AudioStreamPlayer3D


# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	_aplicar_material()
	add_to_group("submarinos")
	add_to_group("submarino")
	if is_in_group("enemies"):
		remove_from_group("enemies")
	if is_in_group("enemigos"):
		remove_from_group("enemigos")
	if Engine.is_editor_hint():
		return
	_configurar_altura_inicial()
	_enemigos_restantes_por_spawnear = cantidad_enemigos
	_construir_cola_mezcla()
	_configurar_notificador_camara()
	_crear_goteo_cubierta()
	_preparar_canon()


## Arma la cola de despliegue: mezcla por cantidades o modo clásico.
## Si todas las cantidades están en 0, repite tipo_enemigo x cantidad_enemigos.
func _construir_cola_mezcla() -> void:
	_cola_mezcla.clear()
	for i in range(maxi(cantidad_imp, 0)):
		_cola_mezcla.append(TipoEnemigo.IMP)
	for i in range(maxi(cantidad_pirata, 0)):
		_cola_mezcla.append(TipoEnemigo.PIRATA)
	for i in range(maxi(cantidad_goblin_arquera, 0)):
		_cola_mezcla.append(TipoEnemigo.GOBLIN_ARQUERA)
	for i in range(maxi(cantidad_imp_embajador, 0)):
		_cola_mezcla.append(TipoEnemigo.IMP_EMBAJADOR)
	if _cola_mezcla.is_empty():
		for i in range(maxi(cantidad_enemigos, 0)):
			_cola_mezcla.append(tipo_enemigo)
	elif mezclar_orden_aleatorio:
		_cola_mezcla.shuffle()
	_total_oleada = _cola_mezcla.size()
	_enemigos_restantes_por_spawnear = _total_oleada


## Localiza el cañón de cubierta, guarda su transformada base del editor y crea
## el marcador de la boca por código (sin tocar la escena, que suele estar abierta).
func _preparar_canon() -> void:
	_canon_modelo = find_child("CanonModel", true, false) as Node3D
	if not is_instance_valid(_canon_modelo):
		return
	_canon_rot_base = _canon_modelo.rotation
	_canon_escala_base = _canon_modelo.scale
	_boca_canon = _canon_modelo.get_node_or_null("BocaCanon") as Marker3D
	if _boca_canon == null:
		_boca_canon = Marker3D.new()
		_boca_canon.name = "BocaCanon"
		_canon_modelo.add_child(_boca_canon)
	else:
		_boca_canon_manual = true
	_actualizar_posicion_boca_canon()
	for m in _canon_modelo.find_children("*", "MeshInstance3D", true, false):
		if m is MeshInstance3D and not m.is_in_group("outline_meshes"):
			m.add_to_group("outline_meshes")



func _configurar_notificador_camara() -> void:
	if is_instance_valid(_notificador_pantalla):
		return
	_notificador_pantalla = find_child("NotificadorCamaraSubmarino", true, false) as VisibleOnScreenNotifier3D
	if not _notificador_pantalla:
		_notificador_pantalla = VisibleOnScreenNotifier3D.new()
		_notificador_pantalla.name = "NotificadorCamaraSubmarino"
		_notificador_pantalla.aabb = AABB(Vector3(-4.5, -profundidad_sumergido - 1.0, -2.5), Vector3(9.0, profundidad_sumergido + 5.0, 5.0))
		add_child(_notificador_pantalla)
	# NOTA: sin conexión automática a emerger; la emergencia la decide la
	# distancia a cámara centrada (_procesar_estado_sumergido).


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	match current_state:
		State.SUMERGIDO:
			_procesar_estado_sumergido()

		State.EMERGIENDO:
			_procesar_estado_emergiendo(delta)

		State.EN_SUPERFICIE:
			_aplicar_movimiento_flotacion(delta)
			_procesar_spawn_enemigos(delta)

		State.ESPERANDO_MUERTE:
			_aplicar_movimiento_flotacion(delta)
			_verificar_enemigos_vivos()

		State.DISPARO_FINAL:
			_aplicar_movimiento_flotacion(delta)

		State.SUMERGIENDOSE:
			_procesar_estado_sumergiendose(delta)

		State.DESAPARECIDO:
			pass


# === FUNCIONES PÚBLICAS ===
## Inicia manualmente la emergencia del submarino
func emerger() -> void:
	if current_state == State.SUMERGIDO:
		current_state = State.EMERGIENDO
		_reproducir_sfx_emergiendo()
		_aplicar_efecto_humedo()
		_iniciar_goteo_cubierta()


## Retorna true si el submarino ya está en superficie o combatiendo
func esta_en_superficie() -> bool:
	return current_state == State.EN_SUPERFICIE or current_state == State.ESPERANDO_MUERTE or current_state == State.DISPARO_FINAL


## Retorna true si el submarino debe considerarse una entidad hostil / obstáculo activo en el río
func es_enemigo_activo() -> bool:
	return esta_en_superficie()


## Sacudida de oleaje ante impacto potente (ej. Ult de Perrena):
## eleva las amplitudes de flotación y balanceo del submarino inmediatamente
## y las retorna de forma suave, natural y fluida a sus valores base con amortiguación gradual (EASE_OUT).
func sacudida_oleaje(duracion: float = 2.0, multiplicador: float = 4.5) -> void:
	if _amplitudes_oleaje_base.is_empty():
		_amplitudes_oleaje_base = {
			"floteo": amplitud_floteo,
			"bal": amplitud_balanceo,
			"cab": amplitud_cabeceo,
			"vel": velocidad_floteo,
		}

	var base_floteo: float = float(_amplitudes_oleaje_base["floteo"])
	var base_bal: float = float(_amplitudes_oleaje_base["bal"])
	var base_cab: float = float(_amplitudes_oleaje_base["cab"])
	var base_vel: float = float(_amplitudes_oleaje_base["vel"])

	amplitud_floteo = base_floteo * multiplicador
	amplitud_balanceo = base_bal * multiplicador
	amplitud_cabeceo = base_cab * multiplicador
	velocidad_floteo = base_vel * 1.35
	flotacion_activa = true

	_generar_onda_emerger()

	if not is_inside_tree() or get_tree() == null:
		return

	if is_instance_valid(_tween_oleaje) and _tween_oleaje.is_valid():
		_tween_oleaje.kill()

	# Distribución temporal: sostenido breve del impacto y retorno gradual/amortiguado (EASE_OUT)
	var dur_total: float = maxf(duracion, 0.4)
	var tiempo_sostenido: float = maxf(0.1, dur_total * 0.3)
	var tiempo_retorno: float = maxf(0.6, dur_total * 0.8)

	_tween_oleaje = create_tween()
	_tween_oleaje.set_parallel(true)

	_tween_oleaje.tween_property(self, "amplitud_floteo", base_floteo, tiempo_retorno)\
		.set_delay(tiempo_sostenido).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween_oleaje.tween_property(self, "amplitud_balanceo", base_bal, tiempo_retorno)\
		.set_delay(tiempo_sostenido).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween_oleaje.tween_property(self, "amplitud_cabeceo", base_cab, tiempo_retorno)\
		.set_delay(tiempo_sostenido).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween_oleaje.tween_property(self, "velocidad_floteo", base_vel, tiempo_retorno)\
		.set_delay(tiempo_sostenido).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	_tween_oleaje.chain().tween_callback(func() -> void:
		if is_instance_valid(self):
			amplitud_floteo = base_floteo
			amplitud_balanceo = base_bal
			amplitud_cabeceo = base_cab
			velocidad_floteo = base_vel
	)


# === FUNCIONES PRIVADAS ===
func _configurar_altura_inicial() -> void:
	if usar_posicion_editor_como_emergido:
		_altura_objetivo_y = position.y
	else:
		_altura_objetivo_y = altura_emergido_y

	# Colocar inmediatamente sumergido bajo el agua
	position.y = _altura_objetivo_y - profundidad_sumergido
	_y_limite_desaparicion = _altura_objetivo_y - profundidad_sumergido - 3.0


func _procesar_estado_sumergido() -> void:
	if not activar_al_entrar_en_camara:
		return

	# Emerger solo con la cámara ya centrada (no al asomar por el borde),
	# para que la animación de emerger se aprecie completa.
	var cam := _obtener_camara_activa()
	if cam == null:
		return

	var dx: float = global_position.x - cam.global_position.x
	if dx <= distancia_activacion_x and dx >= -8.0:
		emerger()


func _procesar_estado_emergiendo(delta: float) -> void:
	position.y = move_toward(position.y, _altura_objetivo_y, velocidad_emerger * delta)
	if is_equal_approx(position.y, _altura_objetivo_y):
		position.y = _altura_objetivo_y
		current_state = State.EN_SUPERFICIE
		add_to_group("enemies")
		add_to_group("enemigos")
		_reproducir_sfx_splash()
		_generar_onda_emerger()
		emergido.emit()
		_procesar_spawn_enemigos(0.0)


func _procesar_spawn_enemigos(delta: float) -> void:
	if _enemigos_restantes_por_spawnear <= 0:
		if _enemigos_vivos.is_empty():
			_iniciar_sumersion()
		else:
			current_state = State.ESPERANDO_MUERTE
		return

	_timer_spawn -= delta
	if _timer_spawn <= 0.0:
		_timer_spawn = intervalo_spawn
		_spawnear_un_enemigo()
		_enemigos_restantes_por_spawnear -= 1


func _spawnear_un_enemigo() -> void:
	var tipo: TipoEnemigo = tipo_enemigo
	if not _cola_mezcla.is_empty():
		tipo = _cola_mezcla.pop_front()
	var packed := _resolver_escena_enemigo(tipo)
	if not packed:
		return

	var enemigo_inst: Node = packed.instantiate()
	if not (enemigo_inst is Node3D):
		enemigo_inst.queue_free()
		return

	var enemigo := enemigo_inst as Node3D

	# Pre-configuración antes de add_child para que _ready() no inicialice distancias largas de caminata
	_preconfigurar_enemigo(enemigo)

	# Agregar al escenario actual
	var padre_destino: Node = get_parent() if get_parent() else self
	padre_destino.add_child(enemigo)

	# Ubicación de spawn (la puerta celeste de la torreta)
	var pos_origen: Vector3 = spawn_point.global_position if is_instance_valid(spawn_point) else global_position
	enemigo.global_position = pos_origen

	# Ajustar plano Z al del submarino
	enemigo.global_position.z = global_position.z

	# Embarcar en la plataforma: vivos y cadáveres siguen el vaivén de flotación
	# y el hundimiento (si no, quedan flotando en el aire y se ve irreal).
	if is_instance_valid(pivot_flotacion):
		enemigo.reparent(pivot_flotacion)

	# Configuración de comportamiento en río una vez dentro del árbol
	_configurar_enemigo_para_rio(enemigo)

	# Distribuir a los enemigos a lo largo de la plataforma de la cubierta (zona rosada)
	var total: int = _total_oleada if _total_oleada > 0 else cantidad_enemigos
	var indice: int = total - _enemigos_restantes_por_spawnear
	var offset_x: float = _calcular_offset_deck_x(indice, total)
	var pos_destino: Vector3 = pos_origen + Vector3(offset_x, 0.0, 0.0)

	# Orientación durante la caminata según dirección del desplazamiento
	var delta_x: float = pos_destino.x - pos_origen.x
	if delta_x > 0.05:
		enemigo.rotation.y = PI  # Mirar a la derecha (hacia popa) al desplazarse
	else:
		enemigo.rotation.y = 0.0  # Mirar a la izquierda (hacia proa / jugador)

	# Iniciar animación de caminata activa
	_iniciar_animacion_caminata(enemigo)

	var dist_x: float = absf(delta_x)
	var duracion_caminata: float = clampf(dist_x / VELOCIDAD_CAMINATA_CUBIERTA, 0.3, 1.2)

	# Desplazamiento lineal a pie hasta su posición asignada
	var tw := enemigo.create_tween()
	tw.tween_property(enemigo, "global_position:x", pos_destino.x, duracion_caminata).set_trans(Tween.TRANS_LINEAR)

	# Al llegar al destino: orientarse hacia el jugador y detener la caminata
	tw.tween_callback(_al_llegar_enemigo_a_destino.bind(enemigo))

	# Breve pausa natural de detención ("detenerse para atacar")
	tw.tween_interval(TIEMPO_DETENCION_PREVIO_ATAQUE)

	# Pasar formalmente al estado de ataque / disparo
	tw.tween_callback(_al_iniciar_combate_enemigo_en_deck.bind(enemigo))

	if enemigo.has_signal("died"):
		enemigo.connect("died", tw.kill, CONNECT_ONE_SHOT)



	_enemigos_vivos.append(enemigo)
	enemigo.tree_exited.connect(_verificar_enemigos_vivos)
	enemigo_desplegado.emit(enemigo)


func _al_llegar_enemigo_a_destino(enemigo: Node3D) -> void:
	if not is_instance_valid(enemigo):
		return
	enemigo.rotation.y = 0.0
	_detener_animacion_caminata(enemigo)


func _al_iniciar_combate_enemigo_en_deck(enemigo: Node3D) -> void:
	if not is_instance_valid(enemigo):
		return
	_iniciar_combate_enemigo(enemigo)


func _iniciar_animacion_caminata(enemigo: Node3D) -> void:
	if not is_instance_valid(enemigo):

		return
	if enemigo is EnemyBase:
		var eb := enemigo as EnemyBase
		if eb.current_state >= EnemyBase.State.DYING:
			return
		eb.current_state = EnemyBase.State.WALKING
	if "esta_en_submarino" in enemigo:
		enemigo.set("esta_en_submarino", true)
	if "va_a_correr" in enemigo:
		enemigo.set("va_a_correr", true)
	if "pasivo_hasta_ser_atacado" in enemigo:
		enemigo.set("pacifico_detenido", false)
		if enemigo.has_method("_play_animation"):
			enemigo.call("_play_animation", "IMP_IDLE", 0.2, 1.0)
			return
	if enemigo is PirataGoblin or enemigo.is_in_group("piratas_submarino") or enemigo.has_meta("en_submarino"):
		if enemigo.has_method("_play_animation"):
			enemigo.call("_play_animation", "CORRER")
			return
	if enemigo.has_method("_on_state_walking"):
		enemigo.call("_on_state_walking")
	elif enemigo.has_method("_play_animation"):
		var anims_posibles: Array[String] = [
			"GIRL_GOB_CAMINA",
			"ENEMIGO_GOBLING_CORRER",
			"CORRER",
			"CAMINAR",
			"WALK"
		]
		for anim in anims_posibles:
			if "anim_player" in enemigo and enemigo.anim_player and enemigo.anim_player.has_animation(anim):
				enemigo.call("_play_animation", anim)
				break


func _detener_animacion_caminata(enemigo: Node3D) -> void:
	if not is_instance_valid(enemigo):
		return
	if enemigo is EnemyBase:
		var eb := enemigo as EnemyBase
		if eb.current_state >= EnemyBase.State.DYING:
			return

	if "pasivo_hasta_ser_atacado" in enemigo:
		if enemigo.has_method("_on_pacifico_detenido"):
			enemigo.call("_on_pacifico_detenido")
		else:
			enemigo.call("_play_animation", "IMP_IDLE_001", 0.2, 1.0)
			enemigo.call("_play_bow_animation", "ARCO_IDLE")
			enemigo.call("_actualizar_visual_arma", false)
	elif enemigo is GoblinGirl:

		enemigo.call("_play_animation", "GIRL_GOB_CAMINA", -1.0, 0.0)
		enemigo.call("_play_bow_animation", "ARCO_IDLE")
	elif enemigo is ImpEnemy:
		enemigo.call("_play_animation", "IDLE", 0.2, 1.0)
	elif enemigo is Goblin:
		enemigo.call("_play_animation", "ENEMIGO_GOBLING_CORRER", -1.0, 0.0)
	elif enemigo.has_method("_play_animation"):
		if "anim_player" in enemigo and enemigo.anim_player:
			if enemigo.anim_player.has_animation("IDLE"):
				enemigo.call("_play_animation", "IDLE", 0.2, 1.0)
			elif enemigo.anim_player.has_animation("Armature|IDLE"):
				enemigo.call("_play_animation", "IDLE", 0.2, 1.0)
			else:
				enemigo.call("_play_animation", enemigo.anim_player.current_animation, -1.0, 0.0)


func _iniciar_combate_enemigo(enemigo: Node3D) -> void:
	if not is_instance_valid(enemigo):
		return
	enemigo.rotation.y = 0.0
	if enemigo is EnemyBase:
		var eb := enemigo as EnemyBase
		if eb.current_state >= EnemyBase.State.DYING:
			return
		eb.velocidad_caminar = 0.0
		eb.target_walk_distance = 0.0
		eb.walked_distance = 1.0
		eb._change_state(EnemyBase.State.SHOOTING)
	elif enemigo.has_method("_change_state"):
		enemigo.call("_change_state", 1)


func _calcular_offset_deck_x(indice: int, total: int) -> float:
	# La cubierta se extiende hacia la proa (-X) y ligeramente hacia popa (+X).
	# Los puestos NUNCA quedan en la zona de la vela (los taparía el modelo):
	# se reparten a sus costados con separación mínima.
	if indice <= 0:
		_offsets_deck_usados.clear()
	var spawn_x: float = spawn_point.position.x if is_instance_valid(spawn_point) else 0.0
	var base: float
	if total <= 1:
		base = -1.0
	else:
		var paso: float = 3.6 / float(max(1, total - 1))
		base = -2.4 + (indice * paso)
	var sub: float = spawn_x + base
	sub = _empujar_fuera_vela(sub)
	sub = _separar_puesto(sub)
	sub = clampf(sub, -3.55, 1.5)
	_offsets_deck_usados.append(sub)
	return sub - spawn_x


## Saca una posición de la banda prohibida de la vela por el lado más cercano.
func _empujar_fuera_vela(sub: float) -> float:
	var lo: float = vela_x_min - margen_vela
	var hi: float = vela_x_max + margen_vela
	if sub < lo or sub > hi:
		return sub
	return lo if absf(sub - lo) <= absf(hi - sub) else hi


## Separa el puesto de los ya asignados para que no se encimen.
func _separar_puesto(sub: float) -> float:
	var lo: float = vela_x_min - margen_vela
	var hi: float = vela_x_max + margen_vela
	var dir: float = -0.65 if sub < (lo + hi) * 0.5 else 0.65
	for _i in range(8):
		var libre := true
		for u in _offsets_deck_usados:
			if absf(sub - u) < separacion_puestos:
				libre = false
				break
		if libre:
			break
		sub += dir * separacion_puestos
		sub = clampf(sub, -3.55, 1.5)
		if sub >= lo and sub <= hi:
			sub = lo if dir < 0.0 else hi
	return sub


func _preconfigurar_enemigo(enemigo: Node3D) -> void:
	if "distancia_minima_caminar" in enemigo:
		enemigo.set("distancia_minima_caminar", 0.0)
	if "distancia_maxima_caminar" in enemigo:
		enemigo.set("distancia_maxima_caminar", 0.0)
	if "velocidad_caminar" in enemigo:
		enemigo.set("velocidad_caminar", 0.0)
	if "solo_atacar_en_pantalla" in enemigo:
		enemigo.set("solo_atacar_en_pantalla", true)
	if "activar_al_entrar_en_camara" in enemigo:
		enemigo.set("activar_al_entrar_en_camara", false)
	if "esta_en_submarino" in enemigo:
		enemigo.set("esta_en_submarino", true)
	if "va_a_correr" in enemigo:
		enemigo.set("va_a_correr", true)
	enemigo.set_meta("en_submarino", true)
	enemigo.add_to_group("piratas_submarino")


func _configurar_enemigo_para_rio(enemigo: Node3D) -> void:
	enemigo.add_to_group("enemies")
	if "solo_atacar_en_pantalla" in enemigo:
		enemigo.set("solo_atacar_en_pantalla", true)
	if "activar_al_entrar_en_camara" in enemigo:
		enemigo.set("activar_al_entrar_en_camara", false)
	if "_dormida_por_camara" in enemigo:
		enemigo.set("_dormida_por_camara", false)
	if "_dormido_por_camara" in enemigo:
		enemigo.set("_dormido_por_camara", false)
	if "pasivo_hasta_ser_atacado" in enemigo:
		enemigo.set("pasivo_hasta_ser_atacado", true)
	if "esta_en_submarino" in enemigo:
		enemigo.set("esta_en_submarino", true)
	if "va_a_correr" in enemigo:
		enemigo.set("va_a_correr", true)
	enemigo.set_meta("en_submarino", true)
	enemigo.add_to_group("piratas_submarino")

	enemigo.set_physics_process(true)
	enemigo.set_process(true)

	if "velocidad_caminar" in enemigo:
		enemigo.set("velocidad_caminar", 0.0)
	if "target_walk_distance" in enemigo:
		enemigo.set("target_walk_distance", 999999.0)
	if "walked_distance" in enemigo:
		enemigo.set("walked_distance", 0.0)

	var cam := _obtener_camara_activa()
	if cam and "_camara_cache_pantalla" in enemigo:
		enemigo.set("_camara_cache_pantalla", cam)


func _resolver_escena_enemigo(tipo: TipoEnemigo) -> PackedScene:
	## Todas las escenas son preload: sin load() en runtime, sin hitches al spawnear.
	match tipo:
		TipoEnemigo.IMP:
			return ESCENA_IMP
		TipoEnemigo.PIRATA_GOBLIN:
			if escena_pirata_custom != null:
				return escena_pirata_custom
			return ESCENA_PIRATA
		TipoEnemigo.GOBLIN_ARQUERA:
			return ESCENA_GOBLIN_ARQUERA
		TipoEnemigo.PIRATA:
			return ESCENA_PIRATA
		TipoEnemigo.IMP_EMBAJADOR:
			return ESCENA_IMP_EMBAJADOR
	# Fallback seguro
	return ESCENA_GOBLIN_ARQUERA


func _on_enemigo_eliminado(enemigo: Node3D) -> void:
	_enemigos_vivos.erase(enemigo)
	if current_state == State.ESPERANDO_MUERTE and _enemigos_vivos.is_empty():
		todos_enemigos_derrotados.emit()
		_iniciar_sumersion()


func _verificar_enemigos_vivos() -> void:
	var vivos: Array[Node3D] = []
	for e in _enemigos_vivos:
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			var muerto: bool = false
			if "health" in e and float(e.get("health")) <= 0.0:
				muerto = true
			if e.get("is_dead") == true or e.get("is_dying") == true:
				muerto = true
			if not muerto:
				vivos.append(e)
	_enemigos_vivos = vivos
	if _enemigos_vivos.is_empty():
		todos_enemigos_derrotados.emit()
		_iniciar_sumersion()


## Virtual: las subclases (ej. JefeSubmarinoRio) pueden sobreescribirla para
## encadenar fases en vez de hundirse y liberarse. La versión base mantiene
## el comportamiento clásico: cañón final y luego hundimiento con queue_free.
func _iniciar_sumersion() -> void:
	if current_state == State.SUMERGIENDOSE or current_state == State.DESAPARECIDO or current_state == State.DISPARO_FINAL:
		return
	# Despedida del cañón: antes de hundirse, dispara el ult de Lonko al cielo.
	if canon_disparo_final and not _disparo_canon_realizado and _canon_listo_para_disparo():
		current_state = State.DISPARO_FINAL
		_ejecutar_secuencia_canon_final()
		return
	_sumergirse_y_liberar()


## Hundimiento real con queue_free (usado por la base y por la muerte final del jefe).
func _sumergirse_y_liberar() -> void:
	if current_state == State.SUMERGIENDOSE or current_state == State.DESAPARECIDO:
		return
	current_state = State.SUMERGIENDOSE
	_detener_goteo_cubierta()
	_generar_onda_emerger()
	if is_in_group("enemies"):
		remove_from_group("enemies")
	if is_in_group("enemigos"):
		remove_from_group("enemigos")
	_desactivar_colisiones()
	_remover_grupos_enemigos_restantes()
	_reproducir_sfx_splash()
	_reproducir_sfx_sumergiendose()


## True si el cañón existe y puede protagonizar su disparo final.
func _canon_listo_para_disparo() -> bool:
	return is_instance_valid(_canon_modelo) and is_instance_valid(_boca_canon)


## La secuencia sigue vigente: sin esto, los awaits huérfanos no hacen nada.
func _sigo_en_secuencia_canon() -> bool:
	if not is_instance_valid(self):
		return false
	if not is_inside_tree():
		return false
	if get_tree() == null:
		return false
	return current_state == State.DISPARO_FINAL


## Espera segura que sobrevive a reload_current_scene / queue_free.
## Devuelve false si el nodo salió del árbol durante la espera.
func _esperar_canon_segundos(segundos: float) -> bool:
	if not _sigo_en_secuencia_canon():
		return false
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	if segundos > 0.0:
		await tree.create_timer(segundos).timeout
	if not _sigo_en_secuencia_canon():
		return false
	return true


## Recalcula la boca en local del cañón (respeta cambios del Inspector en caliente).
## Si BocaCanon se colocó a mano en la escena se deja intacta; si no, se deriva
## de la malla real (tolera giros y desplazamientos hechos en el editor) más un margen.
func _actualizar_posicion_boca_canon() -> void:
	if not is_instance_valid(_boca_canon) or _boca_canon_manual:
		return
	if not is_instance_valid(_canon_modelo):
		return
	var lado: float = 1.0 if canon_lado_boca >= 0.0 else -1.0
	var malla := _buscar_malla_canon()
	if malla != null and malla.mesh != null:
		var aabb_global: AABB = malla.global_transform * malla.mesh.get_aabb()
		var aabb_local: AABB = _canon_modelo.global_transform.affine_inverse() * aabb_global
		var punta_x: float = aabb_local.position.x if lado < 0.0 else aabb_local.end.x
		var centro: Vector3 = aabb_local.get_center()
		_boca_canon.position = Vector3(punta_x + lado * maxf(canon_margen_boca, 0.0), centro.y, centro.z)
		return
	_boca_canon.position = Vector3(lado * absf(canon_offset_boca.x), canon_offset_boca.y, canon_offset_boca.z)


## Primera malla con geometría bajo el cañón (para derivar la boca real).
func _buscar_malla_canon() -> MeshInstance3D:
	if not is_instance_valid(_canon_modelo):
		return null
	for m in _canon_modelo.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi != null and mi.mesh != null:
			return mi
	return null


## Despedida del cañón: apunta al cielo, dispara el ult de Lonko desde la boca
## con leve expansión, regresa a su forma y recién ahí se hunde normalmente.
func _ejecutar_secuencia_canon_final() -> void:
	_disparo_canon_realizado = true
	if not _canon_listo_para_disparo():
		_iniciar_sumersion()
		return
	if not _sigo_en_secuencia_canon():
		return
	# 1. Elevar el cañón apuntando al cielo (el largo del cañón es el eje X).
	if _tween_canon and _tween_canon.is_valid():
		_tween_canon.kill()
	var lado: float = 1.0 if canon_lado_boca >= 0.0 else -1.0
	_reproducir_sfx_engranaje(_canon_modelo.global_position)
	if not is_inside_tree():
		return
	_tween_canon = create_tween()
	_tween_canon.tween_property(_canon_modelo, "rotation", _canon_rot_base + Vector3(0.0, 0.0, lado * PI * 0.5), maxf(canon_tiempo_apuntado, 0.05)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if not await _esperar_canon_segundos(maxf(canon_tiempo_apuntado, 0.05)):
		return
	# 2. Pausa de apuntado antes del disparo.
	if not await _esperar_canon_segundos(maxf(canon_pausa_antes_disparo, 0.0)):
		return
	# 3. Disparo del ult desde la boca + deformación sutil.
	_disparar_ult_desde_canon()
	canon_disparo_final_realizado.emit()
	_deformar_canon_disparo()
	if not await _esperar_canon_segundos(maxf(canon_duracion_deformacion, 0.05)):
		return
	# 4. Regreso a la forma original y hundimiento normal.
	_restaurar_canon()
	if not await _esperar_canon_segundos(maxf(canon_tiempo_regreso, 0.05)):
		return
	# La despedida terminó: salir del estado para que _iniciar_sumersion avance.
	current_state = State.ESPERANDO_MUERTE
	_iniciar_sumersion()


## Instancia el ult de Lonko en la boca del cañón, en vertical como el original.
func _disparar_ult_desde_canon() -> void:
	if not _canon_listo_para_disparo():
		return
	if not is_inside_tree() or get_tree() == null:
		return
	_actualizar_posicion_boca_canon()
	var spawn_pos: Vector3 = _boca_canon.global_position
	if not is_instance_valid(ESCENA_FLECHA_LONKO):
		return
	var arrow := ESCENA_FLECHA_LONKO.instantiate() as FlechaElectricaAtaque
	if arrow == null:
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var root: Node = tree.current_scene
	if root == null:
		root = tree.root
	if root == null:
		return
	root.add_child(arrow)
	arrow.global_position = spawn_pos
	arrow.initialize(Vector3.UP, 1.0)
	arrow.scale = Vector3.ONE * 0.9
	_reproducir_sfx_canon(spawn_pos)


## Expansión sutil del cañón al disparar para enfatizar el disparo.
func _deformar_canon_disparo() -> void:
	if not is_instance_valid(_canon_modelo):
		return
	if not is_inside_tree():
		return
	if _tween_canon and _tween_canon.is_valid():
		_tween_canon.kill()
	var objetivo: Vector3 = _canon_escala_base * maxf(canon_escala_disparo, 1.01)
	var t_fuera: float = maxf(canon_duracion_deformacion * 0.35, 0.05)
	var t_vuelta: float = maxf(canon_duracion_deformacion * 0.65, 0.05)
	_tween_canon = create_tween()
	_tween_canon.tween_property(_canon_modelo, "scale", objetivo, t_fuera).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_canon.tween_property(_canon_modelo, "scale", _canon_escala_base, t_vuelta).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Devuelve el cañón a su rotación y escala originales del editor.
func _restaurar_canon() -> void:
	if not is_instance_valid(_canon_modelo):
		return
	if not is_inside_tree() or get_tree() == null:
		return
	if _tween_canon and _tween_canon.is_valid():
		_tween_canon.kill()
	_reproducir_sfx_engranaje(_canon_modelo.global_position)
	_tween_canon = create_tween().set_parallel(true)
	_tween_canon.tween_property(_canon_modelo, "scale", _canon_escala_base, 0.1)
	_tween_canon.tween_property(_canon_modelo, "rotation", _canon_rot_base, maxf(canon_tiempo_regreso, 0.05)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Estampido del cañón en su boca (explosión grave reutilizada de Lonko).
func _reproducir_sfx_canon(pos: Vector3) -> void:
	if not is_instance_valid(SFX_CANON_DISPARO):
		return
	var player := AudioStreamPlayer3D.new()
	player.name = "SfxCanonDisparo"
	player.stream = SFX_CANON_DISPARO
	player.unit_size = 25.0
	player.volume_db = 0.0
	player.bus = "Master"
	var root: Node = get_tree().current_scene if get_tree() else get_parent()
	if root:
		root.add_child(player)
		player.global_position = pos
		player.play()
		player.finished.connect(player.queue_free)


## Crujido del engranaje mientras el cañón se mueve (al elevar y al regresar).
func _reproducir_sfx_engranaje(pos: Vector3) -> void:
	if not is_instance_valid(SFX_CANON_ENGRANAJE):
		return
	var player := AudioStreamPlayer3D.new()
	player.name = "SfxCanonEngranaje"
	player.stream = SFX_CANON_ENGRANAJE
	player.unit_size = 25.0
	player.volume_db = 0.0
	player.bus = "Master"
	var root: Node = get_tree().current_scene if get_tree() else get_parent()
	if root:
		root.add_child(player)
		player.global_position = pos
		player.play()
		player.finished.connect(player.queue_free)


func _desactivar_colisiones() -> void:
	for col in find_children("*", "CollisionShape3D", true, false):
		if col is CollisionShape3D:
			col.set_deferred("disabled", true)


func _remover_grupos_enemigos_restantes() -> void:
	for e in _enemigos_vivos:
		if is_instance_valid(e):
			if e.is_in_group("enemies"):
				e.remove_from_group("enemies")
			if e.is_in_group("enemigos"):
				e.remove_from_group("enemigos")


func _procesar_estado_sumergiendose(delta: float) -> void:
	position.y = move_toward(position.y, _y_limite_desaparicion, velocidad_sumergir * delta)
	if position.y <= _y_limite_desaparicion:
		current_state = State.DESAPARECIDO
		sumersion_completada.emit()
		queue_free()


func _aplicar_movimiento_flotacion(delta: float) -> void:
	if not flotacion_activa or not is_instance_valid(pivot_flotacion):
		return
	_tiempo_floteo += delta * velocidad_floteo
	pivot_flotacion.position.y = sin(_tiempo_floteo * TAU) * amplitud_floteo
	pivot_flotacion.rotation = Vector3(
		sin(_tiempo_floteo * TAU * 0.75) * deg_to_rad(amplitud_cabeceo),
		0.0,
		sin(_tiempo_floteo * TAU * 0.6) * deg_to_rad(amplitud_balanceo)
	)


func _aplicar_material() -> void:
	if material_submarino == null:
		var mat_path := "res://Levels/Rio_En_Canoa_Con_Parallax/Submarino_Mat.tres"
		if ResourceLoader.exists(mat_path):
			material_submarino = load(mat_path) as StandardMaterial3D
	if material_submarino == null or not is_instance_valid(modelo):
		return
	_asignar_material_recursivo(modelo)


func _asignar_material_recursivo(nodo: Node) -> void:
	if nodo is MeshInstance3D:
		var mi := nodo as MeshInstance3D
		mi.material_override = material_submarino
	for c in nodo.get_children():
		_asignar_material_recursivo(c)



func _reproducir_sfx_splash() -> void:
	if is_instance_valid(audio_splash) and audio_splash.stream != null:
		audio_splash.play()
	elif ResourceLoader.exists(SFX_SPLASH):
		var stream := load(SFX_SPLASH) as AudioStream
		if stream:
			var player := AudioStreamPlayer3D.new()
			player.stream = stream
			player.unit_size = 25.0
			player.volume_db = 2.0
			player.bus = "Master"
			var root: Node = get_tree().current_scene if get_tree() else get_parent()
			if root:
				root.add_child(player)
				player.global_position = global_position
				player.play()
				player.finished.connect(player.queue_free)


## Sonido del submarino emergiendo (se dispara al iniciar la emergencia).
func _reproducir_sfx_emergiendo() -> void:
	if not ResourceLoader.exists(SFX_EMERGIENDO):
		return
	var stream := load(SFX_EMERGIENDO) as AudioStream
	if not stream:
		return
	var player := AudioStreamPlayer3D.new()
	player.name = "SfxEmergiendo"
	player.stream = stream
	player.unit_size = 25.0
	player.volume_db = 2.0
	player.bus = "Master"
	var root: Node = get_tree().current_scene if get_tree() else get_parent()
	if root:
		root.add_child(player)
		player.global_position = global_position
		player.play()
		player.finished.connect(player.queue_free)


## Onda del splash nuevo al romper la superficie (solo el anillo, sin pilar).
func _generar_onda_emerger() -> void:
	if not mostrar_onda_al_emerger:
		return
	if not is_inside_tree() or get_tree() == null:
		return
	var onda = ESCENA_ONDA_SPLASH.instantiate()
	if onda == null:
		return
	var raiz: Node = get_tree().current_scene
	if raiz == null:
		raiz = get_tree().root
	if raiz == null:
		return
	raiz.add_child(onda)
	onda.global_position = global_position
	onda.scale = Vector3(escala_onda_emerger, escala_onda_emerger, escala_onda_emerger)
	# Solo el anillo de onda (1); fuera gotas, burbujas, impacto, pilar y remate
	if onda.has_method("toggle_layer_index"):
		for i in range(6):
			onda.toggle_layer_index(i, i == 1)
	if onda.has_method("play_splash"):
		onda.play_splash()
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	tree.create_timer(duracion_onda_emerger).timeout.connect(func():
		if is_instance_valid(onda):
			onda.queue_free()
	)


## Casco mojado al emerger (espíritu del shader bloody-pool, adaptado al casco):
## oscurece y abrillanta con tinte agua, y se seca paulatino a lo seco.
## Duplica por malla para no teñir el material compartido.
func _aplicar_efecto_humedo() -> void:
	if not efecto_humedo_al_emerger:
		return
	if _tween_secado and _tween_secado.is_valid():
		_tween_secado.kill()
	_tween_secado = null
	_mats_humedos.clear()
	var raiz: Node3D = modelo if is_instance_valid(modelo) else self
	for m in raiz.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi == null or not is_instance_valid(mi):
			continue
		var base: Material = mi.material_override
		if base == null and mi.mesh and mi.mesh.get_surface_count() > 0:
			base = mi.mesh.surface_get_material(0)
		if not (base is StandardMaterial3D):
			continue
		var mat := (base as StandardMaterial3D).duplicate() as StandardMaterial3D
		mi.material_override = mat
		var c: Color = mat.albedo_color
		var datos := {
			"mat": mat,
			"albedo": c,
			"albedo_mojado": Color(c.r * 0.45, c.g * 0.55, c.b * 0.7, c.a),
			"rough": mat.roughness,
			"metal": mat.metallic,
		}
		_mats_humedos.append(datos)
		mat.albedo_color = datos["albedo_mojado"]
		mat.roughness = 0.12
		mat.metallic = maxf(mat.metallic, 0.35)
	if _mats_humedos.is_empty():
		return
	_tween_secado = create_tween()
	_tween_secado.tween_method(_aplicar_secado, 0.0, 1.0, maxf(tiempo_secado_humedo, 0.1))


## Goteo de la cubierta: emisor dimensionado a la plataforma, apagado hasta emerger.
func _crear_goteo_cubierta() -> void:
	if is_instance_valid(_goteo_cubierta):
		return
	var ext := Vector3(2.6, 0.05, 1.3)
	var pos_pivot := Vector3(-1.04, 1.9, 0.0)
	if is_instance_valid(plataforma_cubierta):
		for hijo in plataforma_cubierta.find_children("*", "CollisionShape3D", true, false):
			var col := hijo as CollisionShape3D
			if col and col.shape is BoxShape3D:
				var caja := (col.shape as BoxShape3D).size
				ext = Vector3(caja.x * 0.5, 0.05, caja.z * 0.5)
				pos_pivot = plataforma_cubierta.position + Vector3(0, caja.y * 0.5 + 0.02, 0)
				break
	_goteo_cubierta = GPUParticles3D.new()
	_goteo_cubierta.name = "GoteoCubierta"
	_goteo_cubierta.emitting = false
	_goteo_cubierta.amount = cantidad_gotas
	_goteo_cubierta.lifetime = 0.9
	_goteo_cubierta.one_shot = false
	_goteo_cubierta.explosiveness = 0.0
	_goteo_cubierta.randomness = 0.6
	_goteo_cubierta.visibility_aabb = AABB(Vector3(-4, -3, -3), Vector3(8, 5, 6))
	var padre_nodo: Node = pivot_flotacion if is_instance_valid(pivot_flotacion) else self
	padre_nodo.add_child(_goteo_cubierta)
	if padre_nodo == self and is_instance_valid(pivot_flotacion):
		_goteo_cubierta.position = (pivot_flotacion as Node3D).position + pos_pivot
	else:
		_goteo_cubierta.position = pos_pivot
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = ext
	pm.direction = Vector3(0, -1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 1.0
	pm.gravity = Vector3(0, -7.0, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	var grad := Gradient.new()
	grad.set_color(0, Color(0.55, 0.8, 1.0, 0.9))
	grad.set_color(1, Color(0.55, 0.8, 1.0, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	pm.color_ramp = grad_tex
	_goteo_cubierta.process_material = pm
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color(0.55, 0.8, 1.0)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var gota := SphereMesh.new()
	gota.radius = 0.035
	gota.height = 0.07
	gota.material = mat
	_goteo_cubierta.draw_pass_1 = gota


## Progreso de secado 0 (mojado) → 1 (seco) sobre los duplicados vigentes.
func _aplicar_secado(t: float) -> void:
	for d in _mats_humedos:
		var mat: StandardMaterial3D = d.get("mat")
		if not is_instance_valid(mat):
			continue
		mat.albedo_color = (d["albedo_mojado"] as Color).lerp(d["albedo"] as Color, t)
		mat.roughness = lerpf(0.12, float(d["rough"]), t)
		mat.metallic = lerpf(maxf(float(d["metal"]), 0.35), float(d["metal"]), t)
	if t >= 1.0:
		_detener_goteo_cubierta()


## Enciende el goteo de cubierta (llueve del casco hasta secarse).
func _iniciar_goteo_cubierta() -> void:
	if not gotas_al_emerger:
		return
	if not is_instance_valid(_goteo_cubierta):
		_crear_goteo_cubierta()
	if is_instance_valid(_goteo_cubierta):
		_goteo_cubierta.amount = cantidad_gotas
		_goteo_cubierta.emitting = true


## Apaga el goteo de cubierta.
func _detener_goteo_cubierta() -> void:
	if is_instance_valid(_goteo_cubierta):
		_goteo_cubierta.emitting = false


## Sonido del submarino sumergiéndose (mismo audio de emerger pero más despacio y con tono más bajo/pesado).
func _reproducir_sfx_sumergiendose() -> void:
	if not ResourceLoader.exists(SFX_EMERGIENDO):
		return
	var stream := load(SFX_EMERGIENDO) as AudioStream
	if not stream:
		return
	var player := AudioStreamPlayer3D.new()
	player.name = "SfxSumergiendose"
	player.stream = stream
	player.unit_size = 25.0
	player.volume_db = 2.0
	player.pitch_scale = pitch_sonido_sumersion
	player.bus = "Master"
	var root: Node = get_tree().current_scene if get_tree() else get_parent()
	if root:
		root.add_child(player)
		player.global_position = global_position
		player.play()
		player.finished.connect(player.queue_free)


func _obtener_camara_activa() -> Camera3D:
	if get_viewport():
		var cam := get_viewport().get_camera_3d()
		if cam:
			return cam
	var cam_main = get_tree().get_first_node_in_group("camara_principal") if get_tree() else null
	if cam_main is Camera3D:
		return cam_main as Camera3D
	return null
