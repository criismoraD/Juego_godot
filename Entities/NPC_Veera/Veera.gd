@tool
class_name Veera
extends Node3D

## NPC Neutral Veera: Patrulla una distancia configurable caminando
## con la animación 'Caminar'. Al alcanzar el límite del recorrido,
## desacelera suavemente, rota 180 grados de forma orgánica en el Pivot
## manteniendo la marcha activa, cambia de sentido y retoma el avance
## con aceleración progresiva en un ciclo continuo sin fin.
## Porta una Espada Veera equipada en su mano derecha (mixamorig_RightHand)
## y una Cola Veera acoplada a su cadera (mixamorig_Hips).
## Mismo funcionamiento que el NPC Orco Cerdo del nivel pueblo
## (patrulla, poses, tinte morado y diálogo con [E]).

# ─────────────────────────────────────────────
# SEÑALES
# ─────────────────────────────────────────────
signal estado_cambiado(nuevo_estado: Estado)
signal animacion_cambiada(nombre_animacion: StringName)
signal direccion_cambiada(nueva_direccion: float)
signal pose_estatica_cambiada(nueva_pose: String)
signal dialogo_iniciado(linea: String)
signal dialogo_avanzado(indice: int, linea: String)
signal dialogo_terminado
signal proximidad_jugador_cambiada(cerca: bool)

# ─────────────────────────────────────────────
# ENUMS Y CONSTANTES
# ─────────────────────────────────────────────
const POSE_RESPIRACION: String = "Respiracion"
const POSE_SECRETO: String = "Secreto"

enum Estado {
	CAMINANDO,
	GIRANDO,
	ESTATICO,
}

enum Direccion {
	DERECHA = 1,
	IZQUIERDA = -1,
}

const MATERIAL_DEFECTO: StandardMaterial3D = preload("res://Entities/NPC_Veera/Veera_Mat.tres")
const ESCENA_ESPADA: PackedScene = preload("res://Entities/NPC_Veera/EspadaVeera.tscn")
const ESCENA_COLA: PackedScene = preload("res://Entities/NPC_Veera/ColaVeera.tscn")
const NOMBRE_ANIM_CAMINAR: StringName = &"Caminar"
const HUESO_MANO_DERECHA: String = "mixamorig_RightHand"
const HUESO_CADERA: String = "mixamorig_Hips"
## Los GLB de espada y cola vienen en metros y el esqueleto en cm (x0.01):
## hay que escalarlos al acoplarlos (ver escala_accesorios).
const ESCALA_COMPENSACION_ACCESORIOS: float = 100.0
const ANGULO_PIVOT_DERECHA: float = 90.0
const ANGULO_PIVOT_IZQUIERDA: float = -90.0
const VELOCIDAD_MINIMA_DESACELERACION: float = 0.2

const COLOR_TINTE_MORADO: Color = Color(0.78, 0.48, 0.95, 0.0)
const ALFA_TINTE_MAXIMO: float = 0.22
const TEXTO_PROMPT_DEFECTO: String = "[E] Hablar"
const ALTURA_DEFECTO_PROMPT: float = 1.25
const LINEAS_DIALOGO_DEFECTO: PackedStringArray = [
	"VEERA_PUEBLO_1",
	"VEERA_PUEBLO_2"
]

# ─────────────────────────────────────────────
# EXPORTS – Configuración Visual
# ─────────────────────────────────────────────
@export_category("Configuración Visual")
@export var material_npc: StandardMaterial3D = MATERIAL_DEFECTO:
	set(nuevo_material):
		material_npc = nuevo_material
		_aplicar_material()

@export_flags_3d_render var capa_visual: int = 1:
	set(nueva_capa):
		capa_visual = nueva_capa
		_aplicar_capa_visual()

# ─────────────────────────────────────────────
# EXPORTS – Patrulla y Recorrido
# ─────────────────────────────────────────────
@export_category("Patrulla y Recorrido")
@export var estatico: bool = false:  ## Si está activo, detiene la patrulla y ejecuta la pose estática configurada (ej. 'Secreto')
	set(valor):
		estatico = valor
		_actualizar_modo_estatico()

@export var direccion_inicial: Direccion = Direccion.DERECHA:  ## Dirección inicial: DERECHA (+X) o IZQUIERDA (-X)
	set(nueva_dir):
		direccion_inicial = nueva_dir
		_direccion_actual = 1.0 if direccion_inicial == Direccion.DERECHA else -1.0
		_configurar_pivot()
		_actualizar_orientacion_visual()

@export var distancia_recorrido: float = 6.0  ## Distancia total a recorrer antes de girar (metros)
@export var velocidad_caminar: float = 1.8   ## Velocidad de caminata horizontal (m/s)
@export_range(0.2, 2.5, 0.05) var tiempo_giro: float = 1.4  ## Tiempo que toma rotar 180° al girar (lento y suave)
@export_range(0.1, 1.5, 0.05) var tiempo_transicion: float = 0.3  ## Tiempo de crossfade al iniciar animación
@export_range(0.1, 2.0, 0.05) var distancia_desaceleracion: float = 0.6  ## Distancia previa al límite para desacelerar suavemente
@export_range(0.1, 2.0, 0.05) var tiempo_aceleracion: float = 0.6  ## Tiempo de aceleración tras girar

@export_category("Pasos")
@export var pasos_activos: bool = false  ## Suena sonido_pasos en bucle al caminar (requiere sonido_pasos asignado)
@export_range(0.2, 2.0, 0.05) var paso_cada_metros: float = 0.5  ## Intervalo referencial de paso
@export_range(4.0, 30.0, 0.5) var distancia_max_pasos: float = 8.5  ## Solo suena cerca del jugador
@export_range(-24.0, 6.0, 0.5) var volumen_pasos_db: float = 0.0

@export_category("Sonido Diálogo")
@export var sonido_pasos: AudioStream = null  ## Pasos en bucle al caminar (null = silencioso)
@export var sonido_dialogo: AudioStream = null  ## One-shot al iniciar el diálogo con [E] (null = silencioso)
@export var sonido_dialogo_activo: bool = false  ## Reproduce el sonido al iniciar el diálogo con [E]
@export_range(-24.0, 6.0, 0.5) var volumen_sonido_dialogo_db: float = 0.0  ## Volumen del sonido de diálogo

@export_group("Posado 360 Grados", "posar_")
@export var posar_360: bool = false:  ## Habilita posar libremente la orientación en cualquier ángulo de 0 a 360°
	set(valor):
		posar_360 = valor
		_actualizar_orientacion_visual()

@export_range(0.0, 360.0, 0.5, "suffix:°") var posar_angulo: float = 90.0:  ## Ángulo Y de orientación (0° = Frente, 90° = Derecha, 180° = Espalda, 270° = Izquierda)
	set(grados):
		posar_angulo = wrapf(grados, 0.0, 360.0)
		if not posar_360:
			posar_360 = true
		_actualizar_orientacion_visual()

@export_group("")

# ─────────────────────────────────────────────
# EXPORTS – Modo Estático y Poses
# ─────────────────────────────────────────────
@export_category("Modo Estático y Poses")
@export_enum("Respiracion", "Idle", "Baile", "Ataque 1", "Ataque 2", "Parry") var pose_estatica: String = POSE_RESPIRACION:  ## Pose o animación cuando Veera está estática ('Respiracion' = procedural sin clip)
	set(nueva_pose):
		pose_estatica = nueva_pose
		pose_estatica_cambiada.emit(pose_estatica)
		if estatico:
			_actualizar_modo_estatico()

@export_range(0.1, 2.0, 0.05) var velocidad_anim_pose: float = 1.0:  ## Velocidad de reproducción para la pose animada
	set(valor):
		velocidad_anim_pose = maxf(valor, 0.05)
		_aplicar_velocidad_animacion()

@export_group("Respiración Procedural", "respiracion_")
@export_range(0.5, 4.0, 0.1) var respiracion_velocidad: float = 1.8  ## Velocidad del ciclo de respiración (rad/s)
@export_range(0.005, 0.08, 0.005) var respiracion_intensidad: float = 0.02  ## Intensidad de la deformación sutil de respiración (2%)
@export_group("")

# ─────────────────────────────────────────────
# EXPORTS – Espada y Cola
# ─────────────────────────────────────────────
@export_category("Espada y Cola")
@export var equipar_espada: bool = true:
	set(valor):
		equipar_espada = valor
		if is_node_ready():
			_configurar_espada()
@export var equipar_cola: bool = true:
	set(valor):
		equipar_cola = valor
		if is_node_ready():
			_configurar_cola()
@export var escala_accesorios: float = ESCALA_COMPENSACION_ACCESORIOS  ## x100: los GLB de espada/cola vienen en metros y el esqueleto en cm
@export var espada_offset_pos: Vector3 = Vector3.ZERO  ## Ajuste fino de la espada en la mano (unidades del hueso, cm)
@export var espada_offset_rot: Vector3 = Vector3.ZERO  ## Rotación extra de la espada en grados
@export var cola_offset_pos: Vector3 = Vector3(0.0, 2.0, -8.0)  ## Base de la cola detrás de la cadera (cm)
@export var cola_offset_rot: Vector3 = Vector3(-110.0, 0.0, 0.0)  ## La cola modelada en +Y se tumba hacia atrás y abajo

# ─────────────────────────────────────────────
# EXPORTS – Nombres de Animaciones
# ─────────────────────────────────────────────
@export_category("Animación")
@export var anim_caminar: StringName = NOMBRE_ANIM_CAMINAR

# ─────────────────────────────────────────────
# EXPORTS – Previsualización en Editor
# ─────────────────────────────────────────────
@export_category("Previsualización en Editor")
@export_enum("Ninguna", "Caminar", "Idle", "Baile", "Ataque 1", "Ataque 2", "Parry") var previsualizar_animacion: String = "Ninguna":
	set(nombre):
		previsualizar_animacion = nombre
		_actualizar_previsualizacion_editor()

# ─────────────────────────────────────────────
# EXPORTS – Interacción y Diálogo
# ─────────────────────────────────────────────
@export_category("Interacción y Diálogo")
@export var dialogo_interactivo: bool = false:  ## Habilita detección de proximidad, tinte morado y diálogo con [E]
	set(valor):
		dialogo_interactivo = valor
		if is_inside_tree() and is_node_ready():
			_actualizar_configuracion_dialogo()

@export var radio_interaccion: float = 1.35  ## Distancia en metros para activar la proximidad y prompt
@export var duracion_vinetas: float = 6.0  ## Duración en segundos de cada viñeta antes de auto-avanzar (0 = solo manual)
## Claves de traducción (translations.csv) o texto literal; SpeechBubbleUI las resuelve con tr().
@export var lineas_dialogo: PackedStringArray = [
	"VEERA_PUEBLO_1",
	"VEERA_PUEBLO_2"
]

# ─────────────────────────────────────────────
# VARIABLES PRIVADAS
# ─────────────────────────────────────────────
var _estado_actual: Estado = Estado.CAMINANDO
var _direccion_actual: float = 1.0
var _distancia_acumulada: float = 0.0
var _tiempo_en_estado: float = 0.0
var _activo: bool = true
var _velocidad_actual: float = 1.8
var _angulo_giro_inicio: float = ANGULO_PIVOT_DERECHA
var _angulo_giro_destino: float = ANGULO_PIVOT_IZQUIERDA

var _anim_player_ref: AnimationPlayer = null
var _pivot_visual: Node3D = null
var _reproductor_pasos: AudioStreamPlayer = null
var _reproductor_dialogo: AudioStreamPlayer = null
var _dist_desde_ultimo_paso: float = 0.0
var _bone_attachment: BoneAttachment3D = null
var _bone_attachment_cola: BoneAttachment3D = null
var _instancia_espada: Node3D = null
var _instancia_cola: Node3D = null
var _nodo_modelo_ref: Node3D = null
var _tiempo_respiracion: float = 0.0
var _escala_base_modelo: Vector3 = Vector3.ONE

var _jugador_cerca: bool = false
var _cerca_por_area: bool = false
var _dialogo_activo: bool = false
var _indice_dialogo: int = 0
var _estaba_caminando_antes_de_dialogo: bool = false
var _direccion_previa_dialogo: float = 1.0
var _angulo_pivot_previo_dialogo: float = 90.0
var _tween_giro_dialogo: Tween = null
var _tint_mat: StandardMaterial3D = null
var _tween_proximidad: Tween = null
var _jugador_ref: Node3D = null

@onready var prompt_hablar: Label3D = %PromptHablar if has_node("%PromptHablar") else null
@onready var speech_bubble: SpeechBubbleComponent = %SpeechBubbleComponent if has_node("%SpeechBubbleComponent") else null
@onready var area_interaccion: Area3D = %AreaInteraccion if has_node("%AreaInteraccion") else null

# ─────────────────────────────────────────────
# BUILT-INS
# ─────────────────────────────────────────────
func _ready() -> void:
	_velocidad_actual = velocidad_caminar
	_configurar_pivot()
	_construir_audio_pasos()
	_construir_audio_dialogo()
	_capturar_escala_base()
	_aplicar_material()
	_aplicar_capa_visual()
	_configurar_espada()
	_configurar_cola()
	_inicializar_animator()
	
	_direccion_actual = 1.0 if direccion_inicial == Direccion.DERECHA else -1.0
	_actualizar_orientacion_visual()
	
	if Engine.is_editor_hint():
		_actualizar_previsualizacion_editor()
		if estatico:
			_actualizar_modo_estatico()
		return

	add_to_group("npcs")
	add_to_group("npc_dialogo")

	if _es_dialogo_activo():
		_configurar_dialogo_interactivo()

	if estatico:
		pausar()
	else:
		iniciar_caminata()


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not _activo:
		return
	
	if _es_dialogo_activo():
		_procesar_proximidad_jugador(delta)
	
	if _dialogo_activo:
		_detener_audio_pasos()
		_procesar_respiracion(delta)
		return

	if estatico:
		_detener_audio_pasos()
		if pose_estatica.to_lower() == "respiracion":
			_procesar_respiracion(delta)
		return
	
	_tiempo_en_estado += delta
	
	match _estado_actual:
		Estado.CAMINANDO:
			_procesar_caminata(delta)
				
		Estado.GIRANDO:
			_detener_audio_pasos()
			_procesar_giro(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not _es_dialogo_activo() or not _jugador_cerca:
		return
	if not _dialogo_activo and _hay_otro_npc_hablando():
		return

	var es_tecla_e: bool = (event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_E or event.keycode == KEY_ENTER))
	var es_accion_interact: bool = event.is_action_pressed("interact") if InputMap.has_action("interact") else false
	if es_tecla_e or es_accion_interact:
		_interactuar_o_avanzar_dialogo()
		get_viewport().set_input_as_handled()


# ─────────────────────────────────────────────
# FUNCIONES PÚBLICAS
# ─────────────────────────────────────────────

## Inicia el estado de caminata en la dirección actual con aceleración suave.
func iniciar_caminata() -> void:
	_cambiar_estado(Estado.CAMINANDO)
	_tiempo_en_estado = 0.0

	var ap := _obtener_animation_player()
	if ap and ap.has_animation(anim_caminar):
		var clip := ap.get_animation(anim_caminar)
		if clip:
			clip.loop_mode = Animation.LOOP_LINEAR
		if ap.current_animation != anim_caminar or not ap.is_playing():
			ap.play(anim_caminar, 0.3)
		animacion_cambiada.emit(anim_caminar)


## Inicia la rotación de 180 grados del Pivot al alcanzar el límite manteniendo la caminata.
func iniciar_giro() -> void:
	_cambiar_estado(Estado.GIRANDO)
	_tiempo_en_estado = 0.0
	_velocidad_actual = 0.0

	_configurar_pivot()
	if is_instance_valid(_pivot_visual):
		_angulo_giro_inicio = _pivot_visual.rotation_degrees.y
		if _direccion_actual > 0.0:
			_angulo_giro_destino = _angulo_giro_inicio + 180.0
		else:
			_angulo_giro_destino = _angulo_giro_inicio - 180.0

	# Mantener 'Caminar' activa sin cambiar a ninguna animación torcida
	var ap := _obtener_animation_player()
	if ap and ap.has_animation(anim_caminar) and not ap.is_playing():
		ap.play(anim_caminar)


## Retorna el estado actual del NPC.
func obtener_estado() -> Estado:
	return _estado_actual


## Retorna la dirección horizontal actual (1.0 = derecha, -1.0 = izquierda).
func obtener_direccion() -> float:
	return _direccion_actual


## Retorna la distancia acumulada en el tramo actual.
func obtener_distancia_acumulada() -> float:
	return _distancia_acumulada


## Retorna la velocidad horizontal efectiva actual.
func obtener_velocidad_actual() -> float:
	return _velocidad_actual


## Permite calibrar la distancia del recorrido y la velocidad de caminata.
func configurar_patrulla(distancia: float, velocidad: float) -> void:
	distancia_recorrido = maxf(distancia, 0.5)
	velocidad_caminar = maxf(velocidad, 0.1)


## Retorna la instancia de la espada acoplada, si existe.
func obtener_espada() -> Node3D:
	if not is_instance_valid(_instancia_espada):
		_instancia_espada = find_child("EspadaVeera", true, false) as Node3D
	return _instancia_espada


## Retorna la instancia de la cola acoplada, si existe.
func obtener_cola() -> Node3D:
	if not is_instance_valid(_instancia_cola):
		_instancia_cola = find_child("ColaVeera", true, false) as Node3D
	return _instancia_cola


## Pausa la patrulla y deja a Veera en modo estático con respiración sutil.
func pausar() -> void:
	estatico = true
	_actualizar_modo_estatico()


## Reanuda la patrulla y caminata de Veera.
func reanudar() -> void:
	estatico = false
	_actualizar_modo_estatico()


## Retorna true si Veera está actualmente en modo estático.
func esta_estatico() -> bool:
	return estatico


## Permite cambiar la pose estática activa de Veera (ej. 'Idle', 'Baile').
func cambiar_pose_estatica(nueva_pose: String) -> void:
	pose_estatica = nueva_pose


## Retorna la pose estática configurada actualmente.
func obtener_pose_estatica() -> String:
	return pose_estatica


## Aplica manualmente el material configurado a las mallas de Veera.
func aplicar_material() -> void:
	_aplicar_material()


## Permite posar a Veera en cualquier ángulo de 360 grados.
func posar(angulo_grados: float) -> void:
	posar_360 = true
	posar_angulo = wrapf(angulo_grados, 0.0, 360.0)
	_actualizar_orientacion_visual()


## Retorna el ángulo Y actual de orientación / posado.
func obtener_angulo_posado() -> float:
	_configurar_pivot()
	if is_instance_valid(_pivot_visual):
		return _pivot_visual.rotation_degrees.y
	return posar_angulo


## Retorna si el diálogo interactivo está actualmente habilitado en Veera.
func es_dialogo_activo() -> bool:
	return _es_dialogo_activo()


## Retorna true si el jugador está actualmente dentro del radio de interacción.
func esta_jugador_cerca() -> bool:
	return _jugador_cerca


## Retorna true si una conversación está actualmente abierta.
func esta_hablando_dialogo() -> bool:
	return _dialogo_activo


## Retorna el índice actual de viñeta (0 = no iniciado, 1 = viñeta 1, 2 = viñeta 2).
func obtener_indice_dialogo() -> int:
	return _indice_dialogo


## Simula o dispara la interacción del jugador (equivalente a presionar [E]).
func interactuar() -> void:
	_interactuar_o_avanzar_dialogo()


## Avanza forzadamente a la siguiente viñeta de diálogo.
func avanzar_dialogo() -> void:
	_avanzar_dialogo()


## Cierra el diálogo activo inmediatamente.
func cerrar_dialogo() -> void:
	_cerrar_dialogo()


## Retorna el material de tinte morado utilizado en el overlay.
func obtener_material_tinte() -> StandardMaterial3D:
	return _tint_mat


## Retorna la referencia al nodo Label3D del prompt [E] Hablar.
func obtener_prompt_hablar() -> Label3D:
	return _obtener_prompt_hablar()


## Retorna la referencia al componente SpeechBubbleComponent.
func obtener_speech_bubble() -> SpeechBubbleComponent:
	return _obtener_speech_bubble()


## Retorna el AnimationPlayer del modelo.
func obtener_animation_player() -> AnimationPlayer:
	return _obtener_animation_player()


## Retorna el nodo del modelo 3D.
func obtener_nodo_modelo() -> Node3D:
	return _obtener_nodo_modelo()


## Retorna la escala base capturada del modelo.
func obtener_escala_base_modelo() -> Vector3:
	return _escala_base_modelo


## Retorna la dirección que el NPC seguía en su ruta antes de hablar.
func obtener_direccion_previa_dialogo() -> float:
	return _direccion_previa_dialogo


## Retorna el ángulo Y actual de rotación del Pivot visual.
func obtener_angulo_pivot() -> float:
	_configurar_pivot()
	if is_instance_valid(_pivot_visual):
		return _pivot_visual.rotation_degrees.y
	return 0.0


## Orienta manualmente al NPC hacia la posición del jugador.
func orientar_hacia_jugador(animado: bool = true) -> void:
	_orientar_hacia_jugador(animado)


## Permite simular o fijar programáticamente la proximidad del jugador (útil para tests y cinemáticas).
func fijar_jugador_cerca(cerca: bool) -> void:
	_cerca_por_area = cerca
	if _jugador_cerca != cerca:
		_jugador_cerca = cerca
		_on_proximidad_jugador_cambiada(cerca)


## Retorna si las condiciones para emitir pasos se cumplen actualmente.
func puede_sonar_pasos() -> bool:
	return _puede_sonar_pasos()


## Retorna el reproductor de sonido de pasos.
func obtener_reproductor_pasos() -> AudioStreamPlayer:
	if not is_instance_valid(_reproductor_pasos):
		_construir_audio_pasos()
	return _reproductor_pasos


## Reproduce manualmente el sonido de diálogo (equivale al que suena con [E]).
func reproducir_sonido_dialogo() -> void:
	_reproducir_sonido_dialogo()


## Retorna el reproductor del sonido de diálogo.
func obtener_reproductor_dialogo() -> AudioStreamPlayer:
	if not is_instance_valid(_reproductor_dialogo):
		_construir_audio_dialogo()
	return _reproductor_dialogo


# ─────────────────────────────────────────────
# FUNCIONES PRIVADAS
# ─────────────────────────────────────────────

func _procesar_caminata(delta: float) -> void:
	var distancia_restante: float = distancia_recorrido - _distancia_acumulada

	# Gestionar desaceleración suave al aproximarse al final del recorrido
	if distancia_restante <= distancia_desaceleracion:
		var factor_freno: float = clampf(distancia_restante / maxf(distancia_desaceleracion, 0.01), 0.0, 1.0)
		var vel_deseada: float = lerpf(VELOCIDAD_MINIMA_DESACELERACION, velocidad_caminar, factor_freno)
		_velocidad_actual = move_toward(_velocidad_actual, vel_deseada, (velocidad_caminar / 0.4) * delta)
	else:
		# Aceleración progresiva desde el arranque o tras girar
		var tasa_acel: float = velocidad_caminar / maxf(tiempo_aceleracion, 0.05)
		_velocidad_actual = move_toward(_velocidad_actual, velocidad_caminar, tasa_acel * delta)

	var paso: float = _velocidad_actual * delta
	position.x += _direccion_actual * paso
	_distancia_acumulada += paso

	# Audio continuo de pasos mientras camina y el jugador está cerca
	if pasos_activos:
		_procesar_audio_pasos(delta)

	if _distancia_acumulada >= distancia_recorrido:
		iniciar_giro()


## Crea el reproductor de audio para los pasos con bucle habilitado.
func _construir_audio_pasos() -> void:
	if is_instance_valid(_reproductor_pasos):
		return
	_reproductor_pasos = AudioStreamPlayer.new()
	_reproductor_pasos.name = "PasosVeera"
	if sonido_pasos != null:
		var stream_dup := sonido_pasos.duplicate() as AudioStream
		if is_instance_valid(stream_dup):
			if stream_dup is AudioStreamMP3:
				(stream_dup as AudioStreamMP3).loop = true
			elif stream_dup is AudioStreamWAV:
				(stream_dup as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
			_reproductor_pasos.stream = stream_dup
		else:
			_reproductor_pasos.stream = sonido_pasos
	_reproductor_pasos.volume_db = volumen_pasos_db
	_reproductor_pasos.bus = "Master"
	add_child(_reproductor_pasos)


## Solo suena cuando Veera está en marcha activa, el jugador está cerca y hay stream asignado.
func _puede_sonar_pasos() -> bool:
	if not pasos_activos:
		return false
	if sonido_pasos == null:
		return false
	if estatico or _estado_actual != Estado.CAMINANDO or _dialogo_activo:
		return false
	var jugador := _obtener_jugador()
	if not is_instance_valid(jugador):
		return false
	var dist: float = global_position.distance_to(jugador.global_position)
	if dist > distancia_max_pasos:
		return false
	return true


## Procesa la reproducción y el volumen del audio de pasos según la distancia al jugador.
func _procesar_audio_pasos(_delta: float) -> void:
	if not _puede_sonar_pasos():
		_detener_audio_pasos()
		return

	if not is_instance_valid(_reproductor_pasos):
		_construir_audio_pasos()

	var jugador := _obtener_jugador()
	if not is_instance_valid(jugador):
		_detener_audio_pasos()
		return

	var dist: float = global_position.distance_to(jugador.global_position)
	var factor: float = clampf(1.0 - (dist / maxf(distancia_max_pasos, 0.1)), 0.0, 1.0)
	var vol_efectivo: float = volumen_pasos_db + lerpf(-18.0, 0.0, factor)
	_reproductor_pasos.volume_db = vol_efectivo

	if not _reproductor_pasos.playing:
		_reproductor_pasos.play()


func _detener_audio_pasos() -> void:
	if is_instance_valid(_reproductor_pasos) and _reproductor_pasos.playing:
		_reproductor_pasos.stop()


func _reproducir_paso() -> void:
	_procesar_audio_pasos(0.0)


## Crea el reproductor del sonido de diálogo (one-shot, sin bucle).
func _construir_audio_dialogo() -> void:
	if is_instance_valid(_reproductor_dialogo):
		return
	_reproductor_dialogo = AudioStreamPlayer.new()
	_reproductor_dialogo.name = "SonidoDialogo"
	_reproductor_dialogo.stream = sonido_dialogo
	_reproductor_dialogo.volume_db = volumen_sonido_dialogo_db
	_reproductor_dialogo.bus = "Master"
	add_child(_reproductor_dialogo)


## Reproduce el sonido al hablar con Veera. Se reinicia si ya estaba sonando.
func _reproducir_sonido_dialogo() -> void:
	if not sonido_dialogo_activo:
		return
	if sonido_dialogo == null:
		return
	if not is_inside_tree():
		return
	if not is_instance_valid(_reproductor_dialogo):
		_construir_audio_dialogo()
	if not is_instance_valid(_reproductor_dialogo):
		return
	_reproductor_dialogo.volume_db = volumen_sonido_dialogo_db
	if _reproductor_dialogo.playing:
		_reproductor_dialogo.stop()
	_reproductor_dialogo.play()


func _procesar_giro(delta: float) -> void:
	_configurar_pivot()

	if is_instance_valid(_pivot_visual) and tiempo_giro > 0.0:
		var progreso: float = clampf(_tiempo_en_estado / tiempo_giro, 0.0, 1.0)
		var curva_suave: float = 0.5 - 0.5 * cos(progreso * PI)
		_pivot_visual.rotation_degrees.y = lerpf(_angulo_giro_inicio, _angulo_giro_destino, curva_suave)

	if _tiempo_en_estado >= tiempo_giro:
		_finalizar_giro()


func _configurar_pivot() -> void:
	if is_instance_valid(_pivot_visual):
		return
	_pivot_visual = get_node_or_null("Pivot") as Node3D
	if not _pivot_visual:
		_pivot_visual = get_node_or_null("Model") as Node3D
	if not _pivot_visual:
		var modelos := find_children("*", "Node3D", false, false)
		if not modelos.is_empty():
			_pivot_visual = modelos[0] as Node3D


func _actualizar_orientacion_visual() -> void:
	_configurar_pivot()
	if not is_instance_valid(_pivot_visual):
		return
	if posar_360:
		_pivot_visual.rotation_degrees.y = posar_angulo
		return
	# En vista 2.5D: derecha (+X) = 90 grados en Y, izquierda (-X) = -90 grados en Y
	if _direccion_actual > 0.0:
		_pivot_visual.rotation_degrees.y = ANGULO_PIVOT_DERECHA
	else:
		_pivot_visual.rotation_degrees.y = ANGULO_PIVOT_IZQUIERDA


func _finalizar_giro() -> void:
	_direccion_actual = -_direccion_actual
	_distancia_acumulada = 0.0
	if posar_360:
		posar_angulo = wrapf(posar_angulo + 180.0, 0.0, 360.0)
	_actualizar_orientacion_visual()
	direccion_cambiada.emit(_direccion_actual)
	_cambiar_estado(Estado.CAMINANDO)
	_tiempo_en_estado = 0.0


func _inicializar_animator() -> void:
	var ap := _obtener_animation_player()
	if not ap:
		return

	if ap.has_animation(anim_caminar):
		var clip_caminar := ap.get_animation(anim_caminar)
		if clip_caminar:
			clip_caminar.loop_mode = Animation.LOOP_LINEAR

	var anim_secreto := _resolver_nombre_animacion_pose(POSE_SECRETO)
	if not anim_secreto.is_empty() and ap.has_animation(anim_secreto):
		var clip_secreto := ap.get_animation(anim_secreto)
		if clip_secreto:
			clip_secreto.loop_mode = Animation.LOOP_LINEAR


func _configurar_espada() -> void:
	_instancia_espada = _equipar_en_hueso(
		"EspadaVeera", ESCENA_ESPADA, HUESO_MANO_DERECHA,
		equipar_espada, espada_offset_pos, espada_offset_rot, true
	)


func _configurar_cola() -> void:
	_instancia_cola = _equipar_en_hueso(
		"ColaVeera", ESCENA_COLA, HUESO_CADERA,
		equipar_cola, cola_offset_pos, cola_offset_rot, false
	)


## Equipa un accesorio en un hueso del esqueleto: reutiliza el nodo de la
## escena si ya existe, lo oculta si está desactivado, o lo crea
## dinámicamente con un BoneAttachment3D si no existe.
func _equipar_en_hueso(
	nombre_nodo: String, escena: PackedScene, hueso: String,
	equipar: bool, offset_pos: Vector3, offset_rot: Vector3,
	es_mano: bool
) -> Node3D:
	var instancia := find_child(nombre_nodo, true, false) as Node3D

	if not equipar:
		if is_instance_valid(instancia):
			instancia.visible = false
		return instancia

	# Si ya existe en la escena (.tscn editable), respetar su transform de editor y activarla
	if is_instance_valid(instancia):
		instancia.visible = true
		_asegurar_bone_idx(instancia, hueso)
		return instancia

	# Si no existe, crearlo dinámicamente en el hueso indicado
	var skel: Skeleton3D = _obtener_skeleton()
	if not skel:
		return null

	var bone_idx: int = skel.find_bone(hueso)
	if bone_idx == -1:
		return null

	var attachment: BoneAttachment3D = null
	if es_mano:
		attachment = _bone_attachment
	else:
		attachment = _bone_attachment_cola
	if not is_instance_valid(attachment) or attachment.bone_name != hueso:
		for att in skel.find_children("*", "BoneAttachment3D", false, false):
			var ba := att as BoneAttachment3D
			if ba and ba.bone_name == hueso:
				attachment = ba
				break
	if not is_instance_valid(attachment):
		attachment = BoneAttachment3D.new()
		attachment.name = "BoneAttachment_" + nombre_nodo
		attachment.bone_name = hueso
		attachment.bone_idx = bone_idx
		skel.add_child(attachment)
	if es_mano:
		_bone_attachment = attachment
	else:
		_bone_attachment_cola = attachment

	if escena:
		instancia = escena.instantiate() as Node3D
		instancia.name = nombre_nodo
		attachment.add_child(instancia)
		instancia.position = offset_pos
		instancia.rotation_degrees = offset_rot
		instancia.scale = Vector3.ONE * maxf(escala_accesorios, 0.01)
	return instancia


## Corrige el bone_idx del BoneAttachment padre: la escena hornea el
## bone_name pero el índice se resuelve en runtime para no depender
## del orden de huesos del GLB importado.
func _asegurar_bone_idx(instancia: Node3D, hueso: String) -> void:
	if not is_instance_valid(instancia):
		return
	var skel: Skeleton3D = _obtener_skeleton()
	if skel == null:
		return
	var idx: int = skel.find_bone(hueso)
	if idx == -1:
		return
	var attach := instancia.get_parent() as BoneAttachment3D
	if attach != null and attach.bone_idx != idx:
		attach.bone_idx = idx


func _obtener_skeleton() -> Skeleton3D:
	var skels := find_children("*", "Skeleton3D", true, false)
	if not skels.is_empty():
		return skels[0] as Skeleton3D
	return null


func _obtener_animation_player() -> AnimationPlayer:
	if is_instance_valid(_anim_player_ref):
		return _anim_player_ref
	
	var ap := get_node_or_null("%AnimationPlayer") as AnimationPlayer
	if ap:
		_anim_player_ref = ap
		return _anim_player_ref
	
	ap = get_node_or_null("Pivot/Model/AnimationPlayer") as AnimationPlayer
	if ap:
		_anim_player_ref = ap
		return _anim_player_ref
		
	ap = get_node_or_null("Pivot/AnimationPlayer") as AnimationPlayer
	if ap:
		_anim_player_ref = ap
		return _anim_player_ref
	
	var encontrados := find_children("*", "AnimationPlayer", true, false)
	if not encontrados.is_empty():
		_anim_player_ref = encontrados[0] as AnimationPlayer
		return _anim_player_ref
	
	return null


func _cambiar_estado(nuevo: Estado) -> void:
	if _estado_actual == nuevo:
		return
	_estado_actual = nuevo
	estado_cambiado.emit(_estado_actual)


func _aplicar_material() -> void:
	if material_npc == null:
		return
	_aplicar_material_recursivo_npc(self)


func _aplicar_material_recursivo_npc(nodo: Node) -> void:
	if nodo is MeshInstance3D:
		var mi := nodo as MeshInstance3D
		mi.material_override = material_npc
		if mi.mesh != null and mi.mesh.get_surface_count() > 0:
			for s in range(mi.mesh.get_surface_count()):
				mi.set_surface_override_material(s, material_npc)
	for hijo in nodo.get_children():
		if hijo is BoneAttachment3D:
			continue  # La espada y la cola llevan sus propios materiales
		_aplicar_material_recursivo_npc(hijo)


func _aplicar_capa_visual() -> void:
	_asignar_capa_visual_recursiva(self, capa_visual)


func _asignar_capa_visual_recursiva(nodo: Node, capa: int) -> void:
	if nodo is VisualInstance3D:
		(nodo as VisualInstance3D).layers = capa
	for hijo in nodo.get_children():
		_asignar_capa_visual_recursiva(hijo, capa)


func _actualizar_modo_estatico() -> void:
	if not is_inside_tree() and not is_node_ready():
		return
	
	if estatico:
		_cambiar_estado(Estado.ESTATICO)
		_velocidad_actual = 0.0
		var ap := _obtener_animation_player()
		var anim_pose := _resolver_nombre_animacion_pose(pose_estatica)
		if ap and not anim_pose.is_empty() and pose_estatica.to_lower() != "respiracion":
			_restaurar_transform_modelo()
			ap.speed_scale = velocidad_anim_pose
			var clip := ap.get_animation(anim_pose)
			if clip:
				clip.loop_mode = Animation.LOOP_LINEAR
			if ap.current_animation != anim_pose or not ap.is_playing():
				ap.play(anim_pose, tiempo_transicion)
			animacion_cambiada.emit(anim_pose)
		else:
			if ap:
				ap.stop()
	else:
		_restaurar_transform_modelo()
		if not Engine.is_editor_hint():
			iniciar_caminata()


func _capturar_escala_base() -> void:
	var nodo_modelo := _obtener_nodo_modelo()
	if is_instance_valid(nodo_modelo):
		_escala_base_modelo = nodo_modelo.scale


func _restaurar_transform_modelo() -> void:
	var nodo_modelo := _obtener_nodo_modelo()
	if is_instance_valid(nodo_modelo):
		nodo_modelo.scale = _escala_base_modelo


func _obtener_nodo_modelo() -> Node3D:
	if is_instance_valid(_nodo_modelo_ref):
		return _nodo_modelo_ref
	_configurar_pivot()
	if is_instance_valid(_pivot_visual):
		var model_node := _pivot_visual.get_node_or_null("Model") as Node3D
		if model_node:
			_nodo_modelo_ref = model_node
			return _nodo_modelo_ref
		return _pivot_visual
	return null


func _procesar_respiracion(delta: float) -> void:
	_tiempo_respiracion += delta * respiracion_velocidad
	var onda: float = sin(_tiempo_respiracion)
	
	var nodo_modelo := _obtener_nodo_modelo()
	if not is_instance_valid(nodo_modelo):
		return
	
	# Deformación sutil de respiración orgánica:
	# El eje Y (pecho vertical y elevación de hombros) se expande con la inhalación (+respiracion_intensidad)
	# Los ejes Z (profundidad torácica) y X (ancho) acompañan proporcionalmente
	var factor_y: float = 1.0 + (onda * respiracion_intensidad)
	var factor_z: float = 1.0 + (onda * respiracion_intensidad * 0.8)
	var factor_x: float = 1.0 + (onda * respiracion_intensidad * 0.4)
	
	nodo_modelo.scale = Vector3(
		_escala_base_modelo.x * factor_x,
		_escala_base_modelo.y * factor_y,
		_escala_base_modelo.z * factor_z
	)


func _actualizar_previsualizacion_editor() -> void:
	if not Engine.is_editor_hint():
		return
	var ap := _obtener_animation_player()
	if not ap:
		return
	if previsualizar_animacion == "Ninguna" or previsualizar_animacion.is_empty():
		if not estatico:
			ap.stop()
		return
	var anim_nombre := _resolver_nombre_animacion_pose(previsualizar_animacion)
	if not anim_nombre.is_empty() and ap.has_animation(anim_nombre):
		var clip := ap.get_animation(anim_nombre)
		if clip:
			clip.loop_mode = Animation.LOOP_LINEAR
		if anim_nombre == anim_caminar:
			ap.speed_scale = 1.0
		else:
			ap.speed_scale = velocidad_anim_pose
		ap.play(anim_nombre)


func _aplicar_velocidad_animacion() -> void:
	var ap := _obtener_animation_player()
	if not ap:
		return
	if ap.current_animation == anim_caminar or (Engine.is_editor_hint() and previsualizar_animacion == anim_caminar):
		ap.speed_scale = 1.0
	else:
		ap.speed_scale = velocidad_anim_pose


func _resolver_nombre_animacion_pose(pose: String) -> StringName:
	var ap := _obtener_animation_player()
	if not ap:
		return StringName()
	if ap.has_animation(pose):
		return StringName(pose)
	for anim in ap.get_animation_list():
		if anim.to_lower() == pose.to_lower():
			return StringName(anim)
	return StringName()


# ─────────────────────────────────────────────
# MÉTODOS PRIVADOS – Interacción y Diálogo
# ─────────────────────────────────────────────

func _es_dialogo_activo() -> bool:
	return dialogo_interactivo or name.to_lower().contains("texto")


func _actualizar_configuracion_dialogo() -> void:
	if not is_inside_tree():
		return
	if _es_dialogo_activo():
		_configurar_dialogo_interactivo()
	else:
		_desactivar_dialogo_interactivo()


func _desactivar_dialogo_interactivo() -> void:
	if _dialogo_activo:
		_cerrar_dialogo()
	if _jugador_cerca:
		_jugador_cerca = false
		_animar_proximidad(false)
	var prompt := _obtener_prompt_hablar()
	if is_instance_valid(prompt):
		prompt.visible = false


func _configurar_dialogo_interactivo() -> void:
	_configurar_tinte_morado()
	_configurar_area_interaccion()
	var prompt := _obtener_prompt_hablar()
	if is_instance_valid(prompt):
		prompt.text = "[E] " + tr("PERRENA_PROMPT_HABLAR")
		prompt.modulate.a = 0.0
		prompt.outline_modulate.a = 0.0
		prompt.visible = false
	var sb := _obtener_speech_bubble()
	if is_instance_valid(sb):
		if not sb.dialogo_terminado.is_connected(_on_speech_bubble_dialogo_terminado):
			sb.dialogo_terminado.connect(_on_speech_bubble_dialogo_terminado)


func _configurar_tinte_morado() -> void:
	if _tint_mat == null:
		_tint_mat = StandardMaterial3D.new()
		_tint_mat.cull_mode = BaseMaterial3D.CULL_BACK
		_tint_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_tint_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_tint_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
		_tint_mat.albedo_color = COLOR_TINTE_MORADO

	var meshes: Array[MeshInstance3D] = _obtener_mesh_instances(self)
	for mi in meshes:
		mi.material_overlay = _tint_mat


func _obtener_mesh_instances(nodo: Node) -> Array[MeshInstance3D]:
	var lista: Array[MeshInstance3D] = []
	if nodo is MeshInstance3D:
		lista.append(nodo as MeshInstance3D)
	for hijo in nodo.get_children():
		lista.append_array(_obtener_mesh_instances(hijo))
	return lista


func _obtener_prompt_hablar() -> Label3D:
	if is_instance_valid(prompt_hablar):
		return prompt_hablar
	prompt_hablar = get_node_or_null("%PromptHablar") as Label3D
	if not prompt_hablar:
		prompt_hablar = find_child("PromptHablar", true, false) as Label3D
	if not prompt_hablar and _es_dialogo_activo():
		_crear_prompt_hablar_dinamico()
	return prompt_hablar


func _crear_prompt_hablar_dinamico() -> void:
	if is_instance_valid(prompt_hablar):
		return
	var lbl := Label3D.new()
	lbl.name = "PromptHablar"
	lbl.transform.origin = Vector3(0.0, ALTURA_DEFECTO_PROMPT, 0.0)
	lbl.pixel_size = 0.0035
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.render_priority = 2
	lbl.no_depth_test = true
	lbl.modulate = Color(1.0, 1.0, 1.0, 0.0)
	lbl.outline_modulate = Color(0.05, 0.05, 0.08, 0.0)
	lbl.text = "[E] " + tr("PERRENA_PROMPT_HABLAR")
	lbl.font_size = 22
	lbl.outline_size = 5
	lbl.visible = false
	add_child(lbl)
	prompt_hablar = lbl


func _obtener_speech_bubble() -> SpeechBubbleComponent:
	if is_instance_valid(speech_bubble):
		return speech_bubble
	speech_bubble = get_node_or_null("%SpeechBubbleComponent") as SpeechBubbleComponent
	if not speech_bubble:
		speech_bubble = find_child("SpeechBubbleComponent", true, false) as SpeechBubbleComponent
	if not speech_bubble and _es_dialogo_activo():
		_crear_speech_bubble_dinamico()
	return speech_bubble


func _crear_speech_bubble_dinamico() -> void:
	if is_instance_valid(speech_bubble):
		return
	var sb := SpeechBubbleComponent.new()
	sb.name = "SpeechBubbleComponent"
	sb.offset_cabeza = Vector3(0.0, ALTURA_DEFECTO_PROMPT, 0.0)
	add_child(sb)
	speech_bubble = sb
	sb.dialogo_terminado.connect(_on_speech_bubble_dialogo_terminado)


func _configurar_area_interaccion() -> void:
	var area := get_node_or_null("%AreaInteraccion") as Area3D
	if not area:
		area = find_child("AreaInteraccion", true, false) as Area3D
	if not area:
		area = Area3D.new()
		area.name = "AreaInteraccion"
		area.collision_layer = 0
		area.collision_mask = 3
		var col := CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var shape := SphereShape3D.new()
		shape.radius = radio_interaccion
		col.shape = shape
		col.position.y = 0.5
		area.add_child(col)
		add_child(area)
	area_interaccion = area

	if not area.body_entered.is_connected(_on_body_entered_interaccion):
		area.body_entered.connect(_on_body_entered_interaccion)
	if not area.body_exited.is_connected(_on_body_exited_interaccion):
		area.body_exited.connect(_on_body_exited_interaccion)


func _on_body_entered_interaccion(body: Node3D) -> void:
	if not _es_dialogo_activo():
		return
	if body.is_in_group("player") or body.is_in_group("player_interior") or body is CharacterBody3D:
		_cerca_por_area = true


func _on_body_exited_interaccion(body: Node3D) -> void:
	if not _es_dialogo_activo():
		return
	if body.is_in_group("player") or body.is_in_group("player_interior") or body is CharacterBody3D:
		_cerca_por_area = false


func _obtener_jugador() -> Node3D:
	if is_instance_valid(_jugador_ref):
		return _jugador_ref
	var arbol := get_tree()
	if arbol == null:
		return null
	var j := arbol.get_first_node_in_group("player") as Node3D
	if not is_instance_valid(j):
		j = arbol.get_first_node_in_group("player_interior") as Node3D
	if not is_instance_valid(j) and arbol.current_scene:
		j = arbol.current_scene.find_child("Player", true, false) as Node3D
	_jugador_ref = j
	return _jugador_ref


func _procesar_proximidad_jugador(_delta: float) -> void:
	var jugador := _obtener_jugador()
	if not is_instance_valid(jugador):
		return
	var dist: float = global_position.distance_to(jugador.global_position)
	var cerca_fisica: bool = (dist <= radio_interaccion) or _cerca_por_area
	# Solo el NPC en conversación permanece morado: si otro habla, apagar el propio.
	var cerca: bool = cerca_fisica
	if not _dialogo_activo and cerca_fisica and _hay_otro_npc_hablando():
		cerca = false

	if cerca != _jugador_cerca:
		_jugador_cerca = cerca
		_on_proximidad_jugador_cambiada(cerca)


func _on_proximidad_jugador_cambiada(cerca: bool) -> void:
	_jugador_cerca = cerca
	proximidad_jugador_cambiada.emit(cerca)
	_animar_proximidad(cerca)
	if not cerca:
		if _dialogo_activo:
			_cerrar_dialogo()


func _animar_proximidad(activo: bool) -> void:
	if _tween_proximidad and _tween_proximidad.is_valid():
		_tween_proximidad.kill()

	_tween_proximidad = create_tween().set_parallel(true)
	var duracion: float = 0.3 if activo else 0.25
	var target_alpha_tint: float = ALFA_TINTE_MAXIMO if activo else 0.0
	var target_alpha_prompt: float = 1.0 if activo else 0.0

	var prompt := _obtener_prompt_hablar()
	if prompt and is_instance_valid(prompt):
		if activo and not _dialogo_activo:
			prompt.visible = true
		var alfa_final_prompt: float = 0.0 if _dialogo_activo else target_alpha_prompt
		_tween_proximidad.tween_property(prompt, "modulate:a", alfa_final_prompt, duracion).set_trans(Tween.TRANS_SINE)
		_tween_proximidad.tween_property(prompt, "outline_modulate:a", alfa_final_prompt, duracion).set_trans(Tween.TRANS_SINE)
		if not activo:
			_tween_proximidad.chain().tween_callback(func() -> void:
				if not _jugador_cerca and is_instance_valid(prompt):
					prompt.visible = false
			)

	if _tint_mat == null:
		_configurar_tinte_morado()

	if _tint_mat:
		_tween_proximidad.tween_method(
			func(alpha: float) -> void:
				if _tint_mat:
					_tint_mat.albedo_color = Color(COLOR_TINTE_MORADO.r, COLOR_TINTE_MORADO.g, COLOR_TINTE_MORADO.b, alpha),
			_tint_mat.albedo_color.a,
			target_alpha_tint,
			duracion
		).set_trans(Tween.TRANS_SINE)


func _interactuar_o_avanzar_dialogo() -> void:
	if not _es_dialogo_activo() or not _jugador_cerca:
		return
	if not _dialogo_activo and _hay_otro_npc_hablando():
		return

	if not _dialogo_activo:
		_iniciar_dialogo()
	else:
		_avanzar_dialogo()


func _girar_hacia_direccion_x(dir_x: float, animado: bool = true) -> void:
	_configurar_pivot()
	if not is_instance_valid(_pivot_visual):
		return

	var angulo_objetivo: float = ANGULO_PIVOT_DERECHA if dir_x > 0.0 else ANGULO_PIVOT_IZQUIERDA

	if _tween_giro_dialogo and _tween_giro_dialogo.is_valid():
		_tween_giro_dialogo.kill()

	if not animado or not is_inside_tree():
		_pivot_visual.rotation_degrees.y = angulo_objetivo
		return

	# Calcular el camino angular más corto usando wrapf
	var angulo_act_rad: float = deg_to_rad(_pivot_visual.rotation_degrees.y)
	var angulo_obj_rad: float = deg_to_rad(angulo_objetivo)
	var diff_rad: float = wrapf(angulo_obj_rad - angulo_act_rad, -PI, PI)
	var angulo_final: float = _pivot_visual.rotation_degrees.y + rad_to_deg(diff_rad)

	_tween_giro_dialogo = create_tween()
	_tween_giro_dialogo.tween_property(_pivot_visual, "rotation_degrees:y", angulo_final, 0.2)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)


func _orientar_hacia_jugador(animado: bool = true) -> void:
	var jugador := _obtener_jugador()
	if not is_instance_valid(jugador):
		return
	var dir_x: float = 1.0 if jugador.global_position.x >= global_position.x else -1.0
	_girar_hacia_direccion_x(dir_x, animado)


func _restaurar_orientacion_estatica() -> void:
	_configurar_pivot()
	if not is_instance_valid(_pivot_visual):
		return
	if posar_360:
		_pivot_visual.rotation_degrees.y = posar_angulo
	else:
		_girar_hacia_direccion_x(_direccion_previa_dialogo, true)


func _iniciar_dialogo() -> void:
	if lineas_dialogo.is_empty():
		return
	if _hay_otro_npc_hablando():
		return

	_dialogo_activo = true
	_apagar_resaltado_otros_npcs()
	_indice_dialogo = 0

	# Guardar la dirección y orientación previas para reanudar la ruta al terminar
	_direccion_previa_dialogo = _direccion_actual
	_configurar_pivot()
	if is_instance_valid(_pivot_visual):
		_angulo_pivot_previo_dialogo = _pivot_visual.rotation_degrees.y
	else:
		_angulo_pivot_previo_dialogo = ANGULO_PIVOT_DERECHA if _direccion_actual > 0.0 else ANGULO_PIVOT_IZQUIERDA

	# Girarse hacia el lado donde está el jugador
	_orientar_hacia_jugador(true)

	var ap := _obtener_animation_player()
	if ap and is_instance_valid(ap) and ap.is_playing():
		ap.pause()

	if _estado_actual == Estado.CAMINANDO or _estado_actual == Estado.GIRANDO:
		_estaba_caminando_antes_de_dialogo = true
		_velocidad_actual = 0.0
	else:
		_estaba_caminando_antes_de_dialogo = false

	var prompt := _obtener_prompt_hablar()
	if prompt and is_instance_valid(prompt):
		prompt.visible = false
		prompt.modulate.a = 0.0
		prompt.outline_modulate.a = 0.0

	_reproducir_sonido_dialogo()
	_avanzar_dialogo()


func _avanzar_dialogo() -> void:
	var sb := _obtener_speech_bubble()
	if not sb:
		return

	# Si el jugador cambió de lado mientras leía, mantenerse mirando hacia él
	_orientar_hacia_jugador(true)

	if _indice_dialogo < lineas_dialogo.size():
		var texto_linea: String = lineas_dialogo[_indice_dialogo]
		var idx_actual: int = _indice_dialogo
		_indice_dialogo += 1
		sb.decir(texto_linea, duracion_vinetas)
		if idx_actual == 0:
			dialogo_iniciado.emit(texto_linea)
		else:
			dialogo_avanzado.emit(_indice_dialogo, texto_linea)
	else:
		_cerrar_dialogo()


func _cerrar_dialogo() -> void:
	if not _dialogo_activo and _indice_dialogo == 0:
		return

	_dialogo_activo = false
	_indice_dialogo = 0

	_restaurar_transform_modelo()

	var ap := _obtener_animation_player()
	if ap and is_instance_valid(ap) and not ap.is_playing():
		if not estatico or pose_estatica.to_lower() != "respiracion":
			ap.play()

	var sb := _obtener_speech_bubble()
	if sb and is_instance_valid(sb):
		sb.ocultar()

	dialogo_terminado.emit()

	if _jugador_cerca:
		var prompt := _obtener_prompt_hablar()
		if prompt and is_instance_valid(prompt):
			prompt.visible = true
			var tween := create_tween().set_parallel(true)
			tween.tween_property(prompt, "modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)
			tween.tween_property(prompt, "outline_modulate:a", 1.0, 0.2).set_trans(Tween.TRANS_SINE)

	# Al terminar el diálogo, restaurar la ruta y orientación original
	if _estaba_caminando_antes_de_dialogo and not estatico:
		_direccion_actual = _direccion_previa_dialogo
		_girar_hacia_direccion_x(_direccion_actual, true)
		_velocidad_actual = velocidad_caminar
	elif estatico:
		_restaurar_orientacion_estatica()


func _on_speech_bubble_dialogo_terminado() -> void:
	if not _dialogo_activo:
		return

	if _indice_dialogo >= lineas_dialogo.size():
		_cerrar_dialogo()
	else:
		_avanzar_dialogo()


## True si algún otro NPC del grupo está actualmente en conversación.
## Solo el NPC en conversación debe permanecer morado.
func _hay_otro_npc_hablando() -> bool:
	var arbol := get_tree()
	if arbol == null:
		return false
	for nodo in arbol.get_nodes_in_group("npc_dialogo"):
		if nodo == self:
			continue
		if not is_instance_valid(nodo):
			continue
		if nodo.has_method("esta_hablando_dialogo"):
			if bool(nodo.call("esta_hablando_dialogo")):
				return true
	return false


## Apaga el resaltado de los demás NPCs al iniciar este diálogo.
func _apagar_resaltado_otros_npcs() -> void:
	var arbol := get_tree()
	if arbol == null:
		return
	for nodo in arbol.get_nodes_in_group("npc_dialogo"):
		if nodo == self:
			continue
		if not is_instance_valid(nodo):
			continue
		if nodo.has_method("_forzar_apagado_proximidad"):
			nodo.call("_forzar_apagado_proximidad")


## Apaga prompt y tinte propios cuando otro NPC inicia su diálogo.
func _forzar_apagado_proximidad() -> void:
	if _dialogo_activo:
		return
	_jugador_cerca = false
	_animar_proximidad(false)
