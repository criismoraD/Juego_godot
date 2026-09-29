@tool
class_name GatenoNPC
extends Node3D

## NPC Neutral Gateno:
## Patrulla una distancia configurable caminando horizontalmente en perspectiva 2.5D.
## Al alcanzar el límite del recorrido, desacelera suavemente, rota 180 grados de forma
## orgánica en el Pivot manteniendo la marcha activa, cambia de sentido y retoma el avance
## con aceleración progresiva en un ciclo continuo sin fin.
## Porta una Katana equipada en su mano derecha (mixamorig_RightHand).
## En modo estático dispone de la lista completa de animaciones de su modelo,
## siendo 'Entrenamiento' la pose configurada por defecto.
## Implementa sistema de interacción y diálogo: detección de proximidad con tinte morado,
## prompt "[E] Hablar", viñetas con SpeechBubbleComponent, giro suave de frente hacia el
## jugador y reproducción de su animación de 'Idle' mientras habla, retornando a su estado
## original al finalizar.

# ─────────────────────────────────────────────
# 1. SEÑALES
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
# 2. ENUMS Y CONSTANTES
# ─────────────────────────────────────────────
const POSE_ENTRENAMIENTO: String = "Entrenamiento"
const POSE_IDLE: String = "Idle"
const POSE_RESPIRACION: String = "Respiracion"

enum Estado {
	CAMINANDO,
	GIRANDO,
	ESTATICO,
}

enum Direccion {
	DERECHA = 1,
	IZQUIERDA = -1,
}

const MATERIAL_DEFECTO: StandardMaterial3D = preload("res://Entities/NPC_Gateno/Gateno_Mat.tres")
const ESCENA_KATANA: PackedScene = preload("res://Entities/NPC_Gateno/Katana.tscn")
const NOMBRE_ANIM_CAMINAR: StringName = &"Caminar"
const HUESO_MANO_DERECHA: String = "mixamorig_RightHand"
const ANGULO_PIVOT_DERECHA: float = 90.0
const ANGULO_PIVOT_IZQUIERDA: float = -90.0
const VELOCIDAD_MINIMA_DESACELERACION: float = 0.2

const COLOR_TINTE_MORADO: Color = Color(0.78, 0.48, 0.95, 0.0)
const ALFA_TINTE_MAXIMO: float = 0.22
const TEXTO_PROMPT_DEFECTO: String = "[E] Hablar"
const ALTURA_DEFECTO_PROMPT: float = 1.35
const OFFSET_CABEZA_DEFECTO: Vector3 = Vector3(0.0, 1.25, 0.0)
const LINEAS_DIALOGO_DEFECTO: PackedStringArray = [
	"GATENO_PUEBLO_1",
	"GATENO_PUEBLO_2"
]

# ─────────────────────────────────────────────
# 3. EXPORTS – Configuración Visual
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
# 4. EXPORTS – Patrulla y Recorrido
# ─────────────────────────────────────────────
@export_category("Patrulla y Recorrido")
@export var estatico: bool = false:  ## Si está activo, detiene la patrulla y ejecuta la pose estática configurada (por defecto 'Entrenamiento')
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
@export_range(0.2, 2.0, 0.05) var tiempo_giro: float = 0.8  ## Tiempo que toma rotar 180° al girar
@export_range(0.1, 1.5, 0.05) var tiempo_transicion: float = 0.3  ## Tiempo de crossfade al iniciar animación
@export_range(0.1, 2.0, 0.05) var distancia_desaceleracion: float = 0.6  ## Distancia previa al límite para desacelerar suavemente
@export_range(0.1, 2.0, 0.05) var tiempo_aceleracion: float = 0.6  ## Tiempo de aceleración tras girar

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
# 5. EXPORTS – Modo Estático y Poses
# ─────────────────────────────────────────────
@export_category("Modo Estático y Poses")
@export_enum("Entrenamiento", "Idle", "Bloqueo", "Caminar", "Correr", "Disparo flecha", "Hit", "Muerte", "Muerte 2", "Subir escalera", "Victoria", "Respiracion") var pose_estatica: String = POSE_ENTRENAMIENTO:  ## Pose o animación cuando Gateno está estático (por defecto 'Entrenamiento')
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
# 6. EXPORTS – Katana Mano Derecha
# ─────────────────────────────────────────────
@export_category("Katana Mano Derecha")
@export var equipar_katana: bool = true:
	set(valor):
		equipar_katana = valor
		if is_node_ready():
			_configurar_katana()

@export var katana_pos_local: Vector3 = Vector3(0.0, 0.05, 0.0)
@export var katana_rot_local_grados: Vector3 = Vector3(0.0, 0.0, 0.0)
@export var katana_escala_local: Vector3 = Vector3(1.0, 1.0, 1.0)

# ─────────────────────────────────────────────
# 7. EXPORTS – Nombres de Animaciones
# ─────────────────────────────────────────────
@export_category("Animación")
@export var anim_caminar: StringName = NOMBRE_ANIM_CAMINAR

# ─────────────────────────────────────────────
# 8. EXPORTS – Previsualización en Editor
# ─────────────────────────────────────────────
@export_category("Previsualización en Editor")
@export_enum("Ninguna", "Entrenamiento", "Idle", "Bloqueo", "Caminar", "Correr", "Disparo flecha", "Hit", "Muerte", "Muerte 2", "Subir escalera", "Victoria") var previsualizar_animacion: String = "Ninguna":
	set(nombre):
		previsualizar_animacion = nombre
		_actualizar_previsualizacion_editor()

# ─────────────────────────────────────────────
# 9. EXPORTS – Interacción y Diálogo
# ─────────────────────────────────────────────
@export_category("Interacción y Diálogo")
@export var dialogo_interactivo: bool = true:  ## Habilita detección de proximidad, tinte morado y diálogo interactivo con [E]
	set(valor):
		dialogo_interactivo = valor
		_actualizar_configuracion_dialogo()

@export var radio_interaccion: float = 2.2  ## Distancia máxima para activar la interacción (estar frente a Gateno)
@export var duracion_vinetas: float = 6.0   ## Duración en segundos de cada viñeta antes de auto-avanzar (0 = solo manual)
## Claves de traducción (translations.csv); SpeechBubbleUI las resuelve con tr().
@export var lineas_dialogo: PackedStringArray = LINEAS_DIALOGO_DEFECTO
@export var dummy_boya: DummyBoya = null  ## Referencia opcional al DummyBoya vecino que se detiene al hablar

# ─────────────────────────────────────────────
# 10. VARIABLES PRIVADAS
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
var _bone_attachment: BoneAttachment3D = null
var _instancia_katana: Node3D = null
var _nodo_modelo_ref: Node3D = null
var _tiempo_respiracion: float = 0.0
var _escala_base_modelo: Vector3 = Vector3.ONE

var _jugador_cerca: bool = false
var _cerca_por_area: bool = false
var _dialogo_activo: bool = false
var _indice_dialogo: int = 0
var _direccion_previa_dialogo: float = 1.0
var _angulo_pivot_previo_dialogo: float = 90.0
var _pose_previa_dialogo: String = ""
var _estaba_caminando_antes_de_dialogo: bool = false
var _tint_mat: StandardMaterial3D = null
var _tween_proximidad: Tween = null
var _tween_giro_dialogo: Tween = null
var _jugador_ref: Node3D = null

# ─────────────────────────────────────────────
# 11. ONREADY
# ─────────────────────────────────────────────
@onready var prompt_hablar: Label3D = %PromptHablar if has_node("%PromptHablar") else null
@onready var speech_bubble: SpeechBubbleComponent = %SpeechBubbleComponent if has_node("%SpeechBubbleComponent") else null
@onready var area_interaccion: Area3D = %AreaInteraccion if has_node("%AreaInteraccion") else null

# ─────────────────────────────────────────────
# 12. BUILT-INS
# ─────────────────────────────────────────────
func _ready() -> void:
	add_to_group("npcs")
	add_to_group("npc_dialogo")
	_velocidad_actual = velocidad_caminar
	_configurar_pivot()
	_capturar_escala_base()
	_aplicar_material()
	_aplicar_capa_visual()
	_configurar_katana()
	_inicializar_animator()
	_configurar_dialogo_interactivo()

	_direccion_actual = 1.0 if direccion_inicial == Direccion.DERECHA else -1.0
	_actualizar_orientacion_visual()

	if Engine.is_editor_hint():
		_actualizar_previsualizacion_editor()
		if estatico:
			_actualizar_modo_estatico()
		return

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
		return

	if estatico:
		if pose_estatica.to_lower() == "respiracion":
			_procesar_respiracion(delta)
		return

	_tiempo_en_estado += delta

	match _estado_actual:
		Estado.CAMINANDO:
			_procesar_caminata(delta)
		Estado.GIRANDO:
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
# 13. FUNCIONES PÚBLICAS
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
			ap.play(anim_caminar, tiempo_transicion)
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

	var ap := _obtener_animation_player()
	if ap and ap.has_animation(anim_caminar) and not ap.is_playing():
		ap.play(anim_caminar)


## Cambia la dirección horizontal manualmente.
func cambiar_direccion() -> void:
	_direccion_actual = -_direccion_actual
	_distancia_acumulada = 0.0
	_actualizar_orientacion_visual()
	direccion_cambiada.emit(_direccion_actual)


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


## Retorna la instancia de la katana acoplada, si existe.
func obtener_katana() -> Node3D:
	if not is_instance_valid(_instancia_katana):
		_instancia_katana = find_child("Katana", true, false) as Node3D
	return _instancia_katana


## Alias polimórfico de arma para compatibilidad con sistemas genéricos.
func obtener_arma() -> Node3D:
	return obtener_katana()


## Pausa la patrulla y deja a Gateno en modo estático ejecutando su pose configurada (por defecto 'Entrenamiento').
func pausar() -> void:
	estatico = true
	_actualizar_modo_estatico()


## Reanuda la patrulla y caminata de Gateno.
func reanudar() -> void:
	estatico = false
	_actualizar_modo_estatico()


## Retorna true si Gateno está actualmente en modo estático.
func esta_estatico() -> bool:
	return estatico


## Permite cambiar la pose estática activa (ej. 'Entrenamiento', 'Idle', 'Victoria').
func cambiar_pose_estatica(nueva_pose: String) -> void:
	pose_estatica = nueva_pose


## Retorna la pose estática configurada actualmente.
func obtener_pose_estatica() -> String:
	return pose_estatica


## Aplica manualmente el material configurado a las mallas de Gateno.
func aplicar_material() -> void:
	_aplicar_material()


## Permite posar a Gateno en cualquier ángulo de 360 grados.
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


## Retorna el ángulo Y del pivot visual actual.
func obtener_angulo_pivot() -> float:
	return obtener_angulo_posado()


## Interacciona con el NPC o avanza la conversación activa.
func interactuar() -> void:
	_interactuar_o_avanzar_dialogo()


## Avanza explícitamente a la siguiente viñeta de diálogo.
func avanzar_dialogo() -> void:
	_avanzar_dialogo()


## Cierra el diálogo activo inmediatamente.
func cerrar_dialogo() -> void:
	_cerrar_dialogo()


## Retorna true si Gateno está hablando actualmente.
func esta_hablando_dialogo() -> bool:
	return _dialogo_activo


## Retorna true si el sistema de diálogo interactivo está habilitado.
func es_dialogo_activo() -> bool:
	return _es_dialogo_activo()


## Retorna true si el jugador se encuentra dentro del rango de proximidad.
func esta_jugador_cerca() -> bool:
	return _jugador_cerca


## Retorna el índice actual de viñeta de diálogo (0 si cerrado, 1 para la primera, etc.).
func obtener_indice_dialogo() -> int:
	return _indice_dialogo


## Retorna la dirección que tenía antes de comenzar el diálogo.
func obtener_direccion_previa_dialogo() -> float:
	return _direccion_previa_dialogo


## Retorna el material de overlay con tinte morado.
func obtener_material_tinte() -> StandardMaterial3D:
	return _tint_mat


## Retorna la referencia al nodo Label3D del prompt [E] Hablar.
func obtener_prompt_hablar() -> Label3D:
	return _obtener_prompt_hablar()


## Retorna la referencia al componente SpeechBubbleComponent.
func obtener_speech_bubble() -> SpeechBubbleComponent:
	return _obtener_speech_bubble()


## Orienta a Gateno para mirar de frente al jugador.
func orientar_hacia_jugador(animado: bool = true) -> void:
	_orientar_hacia_jugador(animado)


## Permite forzar o simular programáticamente la proximidad del jugador (tests/cinemáticas).
func fijar_jugador_cerca(cerca: bool) -> void:
	_cerca_por_area = cerca
	if _jugador_cerca != cerca:
		_jugador_cerca = cerca
		_on_proximidad_jugador_cambiada(cerca)


## Retorna la referencia al DummyBoya vinculado o cercano.
func obtener_dummy_boya() -> DummyBoya:
	return _obtener_dummy_boya()


# ─────────────────────────────────────────────
# 14. FUNCIONES PRIVADAS – Movimiento y Patrulla
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

	if _distancia_acumulada >= distancia_recorrido:
		iniciar_giro()


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

	var anim_entrenamiento := _resolver_nombre_animacion_pose(POSE_ENTRENAMIENTO)
	if not anim_entrenamiento.is_empty() and ap.has_animation(anim_entrenamiento):
		var clip_entrenamiento := ap.get_animation(anim_entrenamiento)
		if clip_entrenamiento:
			clip_entrenamiento.loop_mode = Animation.LOOP_LINEAR

	var anim_idle := _resolver_nombre_animacion_pose(POSE_IDLE)
	if not anim_idle.is_empty() and ap.has_animation(anim_idle):
		var clip_idle := ap.get_animation(anim_idle)
		if clip_idle:
			clip_idle.loop_mode = Animation.LOOP_LINEAR


func _configurar_katana() -> void:
	_instancia_katana = find_child("Katana", true, false) as Node3D

	if not equipar_katana:
		if is_instance_valid(_instancia_katana):
			_instancia_katana.visible = false
		return

	if is_instance_valid(_instancia_katana):
		_instancia_katana.visible = true
		return

	var skel: Skeleton3D = _obtener_skeleton()
	if not skel:
		return

	var bone_idx: int = skel.find_bone(HUESO_MANO_DERECHA)
	if bone_idx == -1:
		return

	var attachments := skel.find_children("*", "BoneAttachment3D", false, false)
	for att in attachments:
		var ba := att as BoneAttachment3D
		if ba and ba.bone_name == HUESO_MANO_DERECHA:
			_bone_attachment = ba
			break

	if not is_instance_valid(_bone_attachment):
		_bone_attachment = BoneAttachment3D.new()
		_bone_attachment.name = "BoneAttachment_ManoDerecha"
		_bone_attachment.bone_name = HUESO_MANO_DERECHA
		_bone_attachment.bone_idx = bone_idx
		skel.add_child(_bone_attachment)

	if ESCENA_KATANA:
		_instancia_katana = ESCENA_KATANA.instantiate() as Node3D
		_instancia_katana.name = "Katana"
		_instancia_katana.position = katana_pos_local
		_instancia_katana.rotation_degrees = katana_rot_local_grados
		_instancia_katana.scale = katana_escala_local
		_bone_attachment.add_child(_instancia_katana)


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
	var skel := _obtener_skeleton()
	if skel:
		for c in skel.get_children():
			if c is MeshInstance3D:
				var mi := c as MeshInstance3D
				mi.material_override = material_npc
				if mi.mesh != null and mi.mesh.get_surface_count() > 0:
					mi.set_surface_override_material(0, material_npc)
	else:
		var meshes := find_children("*", "MeshInstance3D", true, false)
		for m in meshes:
			var mi := m as MeshInstance3D
			if not mi.get_parent() is BoneAttachment3D and mi.name.to_lower() != "katana":
				mi.material_override = material_npc
				if mi.mesh != null and mi.mesh.get_surface_count() > 0:
					mi.set_surface_override_material(0, material_npc)


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
# 15. FUNCIONES PRIVADAS – Interacción y Diálogo
# ─────────────────────────────────────────────

func _es_dialogo_activo() -> bool:
	return dialogo_interactivo


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
		if not mi.get_parent() is BoneAttachment3D and mi.name.to_lower() != "katana":
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
	sb.offset_cabeza = OFFSET_CABEZA_DEFECTO
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
		var shape := BoxShape3D.new()
		shape.size = Vector3(radio_interaccion * 1.5, 2.5, radio_interaccion * 1.5)
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
	_jugador_ref = j
	return _jugador_ref


func _procesar_proximidad_jugador(_delta: float) -> void:
	var jugador := _obtener_jugador()
	if not is_instance_valid(jugador):
		return
	var dist: float = global_position.distance_to(jugador.global_position)
	var cerca_fisica: bool = (dist <= radio_interaccion) or _cerca_por_area
	# Solo el NPC en conversación permanece morado.
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


func _girar_hacia_angulo(angulo_objetivo: float, animado: bool = true) -> void:
	_configurar_pivot()
	if not is_instance_valid(_pivot_visual):
		return

	if _tween_giro_dialogo and _tween_giro_dialogo.is_valid():
		_tween_giro_dialogo.kill()

	# Calcular el camino angular más corto usando wrapf
	var angulo_act_rad: float = deg_to_rad(_pivot_visual.rotation_degrees.y)
	var angulo_obj_rad: float = deg_to_rad(angulo_objetivo)
	var diff_rad: float = wrapf(angulo_obj_rad - angulo_act_rad, -PI, PI)
	var angulo_final: float = _pivot_visual.rotation_degrees.y + rad_to_deg(diff_rad)

	if not animado or not is_inside_tree():
		_pivot_visual.rotation_degrees.y = angulo_final
		return

	_tween_giro_dialogo = create_tween()
	_tween_giro_dialogo.tween_property(_pivot_visual, "rotation_degrees:y", angulo_final, 0.2)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)


func _girar_hacia_direccion_x(dir_x: float, animado: bool = true) -> void:
	var angulo_objetivo: float = ANGULO_PIVOT_DERECHA if dir_x > 0.0 else ANGULO_PIVOT_IZQUIERDA
	_girar_hacia_angulo(angulo_objetivo, animado)


func _orientar_hacia_jugador(animado: bool = true) -> void:
	var jugador := _obtener_jugador()
	if not is_instance_valid(jugador):
		return
	_configurar_pivot()
	if not is_instance_valid(_pivot_visual):
		return

	# Convertir posición del jugador al espacio local de Gateno
	var dir_local: Vector3 = to_local(jugador.global_position)
	dir_local.y = 0.0
	if dir_local.length_squared() < 0.001:
		return

	# En espacio local de Godot, atan2(dir.x, dir.z) orienta el frente del personaje directamente al jugador
	var angulo_objetivo: float = rad_to_deg(atan2(dir_local.x, dir_local.z))
	_girar_hacia_angulo(angulo_objetivo, animado)


func _reproducir_animacion_idle() -> void:
	var ap := _obtener_animation_player()
	if not ap:
		return
	var anim_idle := _resolver_nombre_animacion_pose(POSE_IDLE)
	if not anim_idle.is_empty() and ap.has_animation(anim_idle):
		_restaurar_transform_modelo()
		var clip := ap.get_animation(anim_idle)
		if clip:
			clip.loop_mode = Animation.LOOP_LINEAR
		ap.speed_scale = 1.0
		ap.play(anim_idle, 0.2)
		animacion_cambiada.emit(anim_idle)


func _restaurar_orientacion_estatica(animado: bool = true) -> void:
	_configurar_pivot()
	if not is_instance_valid(_pivot_visual):
		return
	var angulo_destino: float = posar_angulo if posar_360 else _angulo_pivot_previo_dialogo
	_girar_hacia_angulo(angulo_destino, animado)


func _iniciar_dialogo() -> void:
	if lineas_dialogo.is_empty():
		return
	if _hay_otro_npc_hablando():
		return

	_dialogo_activo = true
	_apagar_resaltado_otros_npcs()
	_indice_dialogo = 0

	# Guardar estado previo para reanudar al terminar
	_direccion_previa_dialogo = _direccion_actual
	_pose_previa_dialogo = pose_estatica
	_configurar_pivot()
	if is_instance_valid(_pivot_visual):
		_angulo_pivot_previo_dialogo = _pivot_visual.rotation_degrees.y
	else:
		_angulo_pivot_previo_dialogo = ANGULO_PIVOT_DERECHA if _direccion_actual > 0.0 else ANGULO_PIVOT_IZQUIERDA

	if _estado_actual == Estado.CAMINANDO or _estado_actual == Estado.GIRANDO:
		_estaba_caminando_antes_de_dialogo = true
		_velocidad_actual = 0.0
	else:
		_estaba_caminando_antes_de_dialogo = false

	# Girarse de frente hacia el jugador
	_orientar_hacia_jugador(true)

	# Reproducir animación Idle
	_reproducir_animacion_idle()

	# Detener lentamente al DummyBoya mientras Gateno habla
	_detener_dummy_boya()

	var prompt := _obtener_prompt_hablar()
	if prompt and is_instance_valid(prompt):
		prompt.visible = false
		prompt.modulate.a = 0.0
		prompt.outline_modulate.a = 0.0

	_avanzar_dialogo()


func _avanzar_dialogo() -> void:
	var sb := _obtener_speech_bubble()
	if not sb:
		return

	# Mantenerse orientado de frente hacia el jugador
	_orientar_hacia_jugador(true)

	# Asegurar que continúa en animación Idle
	_reproducir_animacion_idle()

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

	# Restaurar orientación y animación previa al diálogo
	if _estaba_caminando_antes_de_dialogo and not estatico:
		_direccion_actual = _direccion_previa_dialogo
		_velocidad_actual = velocidad_caminar
		_cambiar_estado(Estado.CAMINANDO)
		var ap := _obtener_animation_player()
		if ap and ap.has_animation(anim_caminar):
			ap.play(anim_caminar, 0.2)
		_girar_hacia_direccion_x(_direccion_actual, true)
	elif estatico:
		_restaurar_orientacion_estatica()
		_actualizar_modo_estatico()

	# Reanudar la animación del DummyBoya al terminar de hablar
	_reanudar_dummy_boya()


func _obtener_dummy_boya() -> DummyBoya:
	if is_instance_valid(dummy_boya):
		return dummy_boya
	var d := get_node_or_null("DummyBoya") as DummyBoya
	if not d:
		d = get_node_or_null("%DummyBoya") as DummyBoya
	if not d and get_parent():
		d = get_parent().find_child("DummyBoya*", true, false) as DummyBoya
	if not d and is_inside_tree():
		var lista := get_tree().get_nodes_in_group("dummy_boya")
		var min_dist: float = INF
		for nodo in lista:
			if nodo is DummyBoya:
				var dist: float = global_position.distance_to((nodo as DummyBoya).global_position)
				if dist < min_dist and dist < 6.0:
					min_dist = dist
					d = nodo as DummyBoya
	dummy_boya = d
	return dummy_boya


func _detener_dummy_boya() -> void:
	var dummy := _obtener_dummy_boya()
	if is_instance_valid(dummy):
		dummy.detener_suavemente(1.2)


func _reanudar_dummy_boya() -> void:
	var dummy := _obtener_dummy_boya()
	if is_instance_valid(dummy):
		dummy.reanudar_suavemente(1.0)


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
