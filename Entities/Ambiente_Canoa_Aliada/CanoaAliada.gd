class_name CanoaAliada
extends Node3D
## Canoa aliada de ambientación: flota sobre el agua con un vaivén suave y continuo.
##
## El modelo GLB no trae animaciones horneadas, por lo que el movimiento se genera
## por código combinando oscilaciones sinusoidales desfasadas:
##   - Flotación (Y): sube y baja respecto a la línea de flotación.
##   - Balanceo (Roll Z): se mece de costado.
##   - Cabeceo (Pitch X): proa y popa suben alternadamente.
##   - Deriva (X/Z): se desplaza lentamente dentro del cauce.
##   - Guinada (Yaw Y): gira muy despacio sobre la superficie.
##
## La lógica matemática vive en funciones puras (calcular_desplazamiento /
## calcular_rotacion_grados) para poder testearse unitariamente sin árbol de nodos.

# === SEÑALES ===
signal destino_alcanzado

# === CONSTANTES ===
const SONIDO_NAVEGACION: AudioStream = preload("res://TEST_/sonido_canoa_por_el_rio.mp3")
const FASE_ALEATORIA: float = -1.0  ## Centinela: al iniciar, genera una fase aleatoria
const OFFSET_INICIO_AUDIO: float = 0.25  ## Salta el silencio inicial de compresión MP3
const TIEMPO_DISPARO_CROSSFADE: float = 4.8  ## Comienza el crossfade antes del corte o silencio final del clip
const DURACION_CROSSFADE: float = 1.0  ## Ventana de transición progresiva (equal-power)
const VOLUMEN_SILENCIO_DB: float = -80.0

# === FLOTACIÓN VERTICAL (Y) ===
@export_category("Flotación Vertical (Y)")
@export var amplitud_flotacion: float = 0.05  ## Amplitud del sube y baja sobre el agua (metros)
@export var frecuencia_flotacion: float = 0.35  ## Velocidad de la oscilación vertical (Hz)

# === BALANCEO DE COSTADO (ROLL Z) ===
@export_category("Balanceo Lateral (Roll Z)")
@export var amplitud_balanceo: float = 2.5  ## Amplitud del balanceo lateral (grados)
@export var frecuencia_balanceo: float = 0.28  ## Velocidad del balanceo (Hz)

# === CABECEO PROA-POPA (PITCH X) ===
@export_category("Cabeceo Frontal (Pitch X)")
@export var amplitud_cabeceo: float = 1.5  ## Amplitud del cabeceo proa-popa (grados)
@export var frecuencia_cabeceo: float = 0.42  ## Velocidad del cabeceo (Hz)

# === DERIVA HORIZONTAL (X / Z) ===
@export_category("Deriva Horizontal")
@export var amplitud_deriva_x: float = 0.05  ## Amplitud de la deriva a lo largo del cauce (metros)
@export var frecuencia_deriva_x: float = 0.12  ## Velocidad de la deriva en X (Hz)
@export var amplitud_deriva_z: float = 0.04  ## Amplitud de la deriva transversal (metros)
@export var frecuencia_deriva_z: float = 0.09  ## Velocidad de la deriva en Z (Hz)

# === GUINADA (YAW Y) ===
@export_category("Guinada (Yaw Y)")
@export var amplitud_guinada: float = 2.0  ## Amplitud del giro lento sobre el agua (grados)
@export var frecuencia_guinada: float = 0.15  ## Velocidad de la guinada (Hz)

# === COMPORTAMIENTO ===
@export_category("Comportamiento")
@export var capa_visual: int = 2  ## Capa de renderizado (Fondo = 2)
@export var flotar_al_iniciar: bool = true  ## Si true, comienza a flotar desde el primer frame
@export var escala_tiempo: float = 1.0  ## Multiplicador global de la velocidad de animación
@export var fase_flotacion: float = FASE_ALEATORIA  ## Fase inicial (radianes). -1 = aleatoria
@export var fase_balanceo: float = FASE_ALEATORIA  ## Fase inicial (radianes). -1 = aleatoria
@export var fase_cabeceo: float = FASE_ALEATORIA  ## Fase inicial (radianes). -1 = aleatoria
@export var fase_deriva_x: float = FASE_ALEATORIA  ## Fase inicial (radianes). -1 = aleatoria
@export var fase_deriva_z: float = FASE_ALEATORIA  ## Fase inicial (radianes). -1 = aleatoria
@export var fase_guinada: float = FASE_ALEATORIA  ## Fase inicial (radianes). -1 = aleatoria

# === SONIDO DE NAVEGACIÓN ===
@export_category("Sonido de Navegación")
@export var sonido_navegacion_activo: bool = true  ## Si true, suena en loop mientras navega y se detiene en paradas
@export_range(-30.0, 12.0, 0.5) var volumen_navegacion_db: float = -3.0:  ## Volumen sutil y natural del loop de navegación (dB)
	set(v):
		volumen_navegacion_db = v
		_actualizar_volumen_voces()

@export_range(0.5, 2.0, 0.05) var pitch_navegacion: float = 1.0:
	set(v):
		pitch_navegacion = v
		if is_instance_valid(_audio_navegacion):
			_audio_navegacion.pitch_scale = pitch_navegacion
		if is_instance_valid(_audio_navegacion_b):
			_audio_navegacion_b.pitch_scale = pitch_navegacion

# === ESTADO PRIVADO ===
var _tiempo: float = 0.0
var _posicion_base: Vector3 = Vector3.ZERO
var _rotacion_base: Vector3 = Vector3.ZERO
var _flotando: bool = false
var _fase_flotacion: float = 0.0
var _fase_balanceo: float = 0.0
var _fase_cabeceo: float = 0.0
var _fase_deriva_x: float = 0.0
var _fase_deriva_z: float = 0.0
var _fase_guinada: float = 0.0

var _navegando: bool = false
var _x_destino: float = 0.0
var _velocidad_navegacion: float = 0.0
var _direccion_navegacion: float = 1.0
var _audio_navegacion: AudioStreamPlayer = null
var _audio_navegacion_b: AudioStreamPlayer = null
var _reloj_audio_voz: float = 0.0
var _voz_activa: int = 0
var _en_crossfade: bool = false


# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	add_to_group("canoas_aliadas")
	_posicion_base = position
	_rotacion_base = rotation_degrees
	_inicializar_fases()
	_aplicar_capa_visual_recursiva(self)
	_inicializar_sonido_navegacion()
	_flotando = flotar_al_iniciar
	set_process(_flotando or _navegando)


func _process(delta: float) -> void:
	if delta <= 0.0:
		return

	if _navegando:
		_actualizar_navegacion(delta)

	_actualizar_sonido_navegacion(delta)

	if not _flotando:
		return

	_tiempo += delta * escala_tiempo
	_aplicar_flotacion()


# === FUNCIONES PÚBLICAS ===
## Ordena a todos los tripulantes a bordo que comiencen el combate estético.
func iniciar_combate_tripulacion() -> void:
	for hijo in find_children("*", "TripulanteBarcoFondoAllyArcher", true, false):
		if hijo.has_method("iniciar_combate"):
			hijo.iniciar_combate()


## Inicia el desplazamiento horizontal hacia una coordenada X objetivo.
func navegar_hacia_x(x_destino: float, velocidad: float) -> void:
	_x_destino = x_destino
	_velocidad_navegacion = absf(velocidad)
	_direccion_navegacion = 1.0 if _x_destino > _posicion_base.x else -1.0
	_navegando = true
	_flotando = true
	set_process(true)


## Detiene la navegación horizontal sin frenar la flotación.
func detener_navegacion() -> void:
	_navegando = false


## Indica si la canoa está en movimiento horizontal hacia su destino.
func esta_navegando() -> bool:
	return _navegando


## Fija la posición base (sin desfase sinusoidal).
func fijar_posicion_base(nueva_pos: Vector3) -> void:
	_posicion_base = nueva_pos
	position = _posicion_base


## Retorna la posición base actual.
func obtener_posicion_base() -> Vector3:
	return _posicion_base


## Inicia (o reanuda) el vaivén de la canoa.
func flotar() -> void:
	_flotando = true
	set_process(true)


## Detiene el vaivén y devuelve la canoa a su transformada base.
func detener() -> void:
	_flotando = false
	_navegando = false
	_detener_sonido_navegacion()
	set_process(false)
	_restaurar_transformada_base()


## Oculta inmediatamente la canoa y a sus tripulantes y desactiva su procesamiento.
func ocultar_y_desactivar() -> void:
	visible = false
	_flotando = false
	_navegando = false
	_detener_sonido_navegacion()
	set_process(false)
	for hijo in find_children("*", "TripulanteBarcoFondoAllyArcher", true, false):
		var tripulante := hijo as Node3D
		if is_instance_valid(tripulante):
			tripulante.visible = false
			tripulante.set_process(false)


## Indica si la canoa se está moviendo actualmente.
func esta_flotando() -> bool:
	return _flotando


## Indica si el sonido de navegación está activo en cualquiera de las voces de audio.
func esta_reproduciendo_sonido_navegacion() -> bool:
	return (is_instance_valid(_audio_navegacion) and _audio_navegacion.playing) or \
		(is_instance_valid(_audio_navegacion_b) and _audio_navegacion_b.playing)



## Reinicia el ciclo de flotación desde cero, regenerando las fases aleatorias.
func reiniciar() -> void:
	_tiempo = 0.0
	_inicializar_fases()
	_restaurar_transformada_base()


## Desplazamiento (en metros) respecto a la posición base para un instante dado.
func calcular_desplazamiento(tiempo: float) -> Vector3:
	var onda_x: float = sin(tiempo * frecuencia_deriva_x * TAU + _fase_deriva_x)
	var onda_y: float = sin(tiempo * frecuencia_flotacion * TAU + _fase_flotacion)
	var onda_z: float = sin(tiempo * frecuencia_deriva_z * TAU + _fase_deriva_z)

	return Vector3(
		amplitud_deriva_x * onda_x,
		amplitud_flotacion * onda_y,
		amplitud_deriva_z * onda_z
	)


## Rotación absoluta (en grados) de la canoa para un instante dado.
func calcular_rotacion_grados(tiempo: float) -> Vector3:
	var onda_cabeceo: float = sin(tiempo * frecuencia_cabeceo * TAU + _fase_cabeceo)
	var onda_guinada: float = sin(tiempo * frecuencia_guinada * TAU + _fase_guinada)
	var onda_balanceo: float = sin(tiempo * frecuencia_balanceo * TAU + _fase_balanceo)

	return Vector3(
		_rotacion_base.x + amplitud_cabeceo * onda_cabeceo,
		_rotacion_base.y + amplitud_guinada * onda_guinada,
		_rotacion_base.z + amplitud_balanceo * onda_balanceo
	)


# === FUNCIONES PRIVADAS ===
func _actualizar_navegacion(delta: float) -> void:
	var paso: float = _velocidad_navegacion * delta * _direccion_navegacion
	var nueva_x: float = _posicion_base.x + paso

	var llego: bool = false
	if _direccion_navegacion > 0.0 and nueva_x >= _x_destino:
		llego = true
	elif _direccion_navegacion < 0.0 and nueva_x <= _x_destino:
		llego = true

	if llego:
		_posicion_base.x = _x_destino
		_navegando = false
		destino_alcanzado.emit()
	else:
		_posicion_base.x = nueva_x


func _inicializar_fases() -> void:
	_fase_flotacion = _resolver_fase(fase_flotacion)
	_fase_balanceo = _resolver_fase(fase_balanceo)
	_fase_cabeceo = _resolver_fase(fase_cabeceo)
	_fase_deriva_x = _resolver_fase(fase_deriva_x)
	_fase_deriva_z = _resolver_fase(fase_deriva_z)
	_fase_guinada = _resolver_fase(fase_guinada)


func _resolver_fase(fase_configurada: float) -> float:
	if fase_configurada >= 0.0:
		return fase_configurada
	return randf() * TAU


func _aplicar_flotacion() -> void:
	position = _posicion_base + calcular_desplazamiento(_tiempo)
	rotation_degrees = calcular_rotacion_grados(_tiempo)


func _inicializar_sonido_navegacion() -> void:
	if _audio_navegacion == null:
		_audio_navegacion = get_node_or_null("SonidoNavegacion") as AudioStreamPlayer

	if _audio_navegacion == null:
		if SONIDO_NAVEGACION == null:
			push_warning("[CanoaAliada] Sin stream de navegación; la canoa se moverá en silencio")
			return
		_audio_navegacion = AudioStreamPlayer.new()
		_audio_navegacion.name = "SonidoNavegacion"
		_audio_navegacion.stream = SONIDO_NAVEGACION
		add_child(_audio_navegacion)

	if _audio_navegacion.stream == null and SONIDO_NAVEGACION != null:
		_audio_navegacion.stream = SONIDO_NAVEGACION

	_audio_navegacion.volume_db = volumen_navegacion_db
	_audio_navegacion.pitch_scale = pitch_navegacion
	_audio_navegacion.bus = "Master"

	# Segunda voz complementaria para crossfade en bucle continuo y transparente (sin saltos ni silencios)
	if _audio_navegacion_b == null:
		_audio_navegacion_b = get_node_or_null("SonidoNavegacionB") as AudioStreamPlayer
	if _audio_navegacion_b == null:
		_audio_navegacion_b = AudioStreamPlayer.new()
		_audio_navegacion_b.name = "SonidoNavegacionB"
		_audio_navegacion_b.stream = _audio_navegacion.stream
		add_child(_audio_navegacion_b)

	if _audio_navegacion_b.stream == null:
		_audio_navegacion_b.stream = _audio_navegacion.stream

	_audio_navegacion_b.volume_db = VOLUMEN_SILENCIO_DB
	_audio_navegacion_b.pitch_scale = pitch_navegacion
	_audio_navegacion_b.bus = _audio_navegacion.bus

	if not _audio_navegacion.finished.is_connected(_al_terminar_sonido_navegacion):
		_audio_navegacion.finished.connect(_al_terminar_sonido_navegacion)
	if not _audio_navegacion_b.finished.is_connected(_al_terminar_sonido_navegacion):
		_audio_navegacion_b.finished.connect(_al_terminar_sonido_navegacion)

	_actualizar_sonido_navegacion(0.0)


func _al_terminar_sonido_navegacion() -> void:
	if _navegando and sonido_navegacion_activo:
		_actualizar_sonido_navegacion(0.0)


func _actualizar_volumen_voces() -> void:
	if not _en_crossfade:
		if _voz_activa == 0 and is_instance_valid(_audio_navegacion) and _audio_navegacion.playing:
			_audio_navegacion.volume_db = volumen_navegacion_db
		elif _voz_activa == 1 and is_instance_valid(_audio_navegacion_b) and _audio_navegacion_b.playing:
			_audio_navegacion_b.volume_db = volumen_navegacion_db


func _actualizar_sonido_navegacion(delta: float = 0.0) -> void:
	if not is_instance_valid(_audio_navegacion):
		return

	if not (_navegando and sonido_navegacion_activo):
		_detener_sonido_navegacion()
		return

	# Si ninguna voz está activa, arrancar la voz principal A desde el offset libre de silencio
	var voz_a_reproduciendo: bool = _audio_navegacion.playing
	var voz_b_reproduciendo: bool = is_instance_valid(_audio_navegacion_b) and _audio_navegacion_b.playing
	if not voz_a_reproduciendo and not voz_b_reproduciendo:
		_voz_activa = 0
		_reloj_audio_voz = 0.0
		_en_crossfade = false
		_audio_navegacion.volume_db = volumen_navegacion_db
		_audio_navegacion.pitch_scale = pitch_navegacion
		_audio_navegacion.play(OFFSET_INICIO_AUDIO)
		if is_instance_valid(_audio_navegacion_b):
			_audio_navegacion_b.stop()
			_audio_navegacion_b.volume_db = VOLUMEN_SILENCIO_DB
		return

	if delta <= 0.0:
		return

	_reloj_audio_voz += delta

	# Crossfade activo entre voces
	if _reloj_audio_voz >= TIEMPO_DISPARO_CROSSFADE and _reloj_audio_voz < (TIEMPO_DISPARO_CROSSFADE + DURACION_CROSSFADE):
		_en_crossfade = true
		var ratio: float = clampf((_reloj_audio_voz - TIEMPO_DISPARO_CROSSFADE) / DURACION_CROSSFADE, 0.0, 1.0)
		# Curva equal-power (potencia constante sin caídas de volumen en el centro)
		var ganancia_in: float = sin(ratio * PI * 0.5)
		var ganancia_out: float = cos(ratio * PI * 0.5)

		if _voz_activa == 0:
			if is_instance_valid(_audio_navegacion_b) and not _audio_navegacion_b.playing:
				_audio_navegacion_b.pitch_scale = pitch_navegacion
				_audio_navegacion_b.play(OFFSET_INICIO_AUDIO)
			_audio_navegacion.volume_db = linear_to_db(maxf(ganancia_out, 0.0001)) + volumen_navegacion_db
			if is_instance_valid(_audio_navegacion_b):
				_audio_navegacion_b.volume_db = linear_to_db(maxf(ganancia_in, 0.0001)) + volumen_navegacion_db
		else:
			if not _audio_navegacion.playing:
				_audio_navegacion.pitch_scale = pitch_navegacion
				_audio_navegacion.play(OFFSET_INICIO_AUDIO)
			if is_instance_valid(_audio_navegacion_b):
				_audio_navegacion_b.volume_db = linear_to_db(maxf(ganancia_out, 0.0001)) + volumen_navegacion_db
			_audio_navegacion.volume_db = linear_to_db(maxf(ganancia_in, 0.0001)) + volumen_navegacion_db

	elif _reloj_audio_voz >= (TIEMPO_DISPARO_CROSSFADE + DURACION_CROSSFADE):
		# Fin del crossfade: alternar la voz primaria
		_en_crossfade = false
		if _voz_activa == 0:
			_voz_activa = 1
			_audio_navegacion.stop()
			_audio_navegacion.volume_db = VOLUMEN_SILENCIO_DB
			if is_instance_valid(_audio_navegacion_b):
				_audio_navegacion_b.volume_db = volumen_navegacion_db
			_reloj_audio_voz = DURACION_CROSSFADE
		else:
			_voz_activa = 0
			if is_instance_valid(_audio_navegacion_b):
				_audio_navegacion_b.stop()
				_audio_navegacion_b.volume_db = VOLUMEN_SILENCIO_DB
			_audio_navegacion.volume_db = volumen_navegacion_db
			_reloj_audio_voz = DURACION_CROSSFADE

	else:
		_en_crossfade = false
		if _voz_activa == 0:
			_audio_navegacion.volume_db = volumen_navegacion_db
		elif is_instance_valid(_audio_navegacion_b):
			_audio_navegacion_b.volume_db = volumen_navegacion_db


func _detener_sonido_navegacion() -> void:
	if is_instance_valid(_audio_navegacion) and _audio_navegacion.playing:
		_audio_navegacion.stop()
	if is_instance_valid(_audio_navegacion_b) and _audio_navegacion_b.playing:
		_audio_navegacion_b.stop()
	_reloj_audio_voz = 0.0
	_voz_activa = 0
	_en_crossfade = false


func _restaurar_transformada_base() -> void:
	position = _posicion_base
	rotation_degrees = _rotacion_base


func _aplicar_capa_visual_recursiva(nodo: Node) -> void:
	if nodo is VisualInstance3D:
		nodo.layers = capa_visual
	for hijo in nodo.get_children():
		_aplicar_capa_visual_recursiva(hijo)

