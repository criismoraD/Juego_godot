class_name SpeechBubbleComponent
extends Node3D

## Componente 3D para proyectar globos de diálogo (Speech Bubbles) sobre personajes.
## Convierte las coordenadas 3D del personaje a coordenadas de pantalla 2D,
## permitiendo que el globo siga el movimiento fluidamente y renderice texto nítido.

signal dialogo_iniciado(texto: String)
signal dialogo_terminado

const ESCENA_UI: PackedScene = preload("res://Components/Dialogue/SpeechBubbleUI.tscn")
const NOMBRE_LAYER_GLOBOS: String = "SpeechBubbleCanvasLayer"
const LAYER_PRIORIDAD: int = 100

@export_group("Offset 3D")
@export var offset_cabeza: Vector3 = Vector3(0.0, 2.2, 0.0)  ## Offset local respecto a los pies del personaje (se escala automáticamente)

@export_group("Personalidad y Voz")
@export_range(0.5, 2.0, 0.05) var pitch_voz: float = 1.0
@export var audio_habla: AudioStream = preload("res://Entities/Ambiente_Escudo/IMPACTO_ESCUDO_BALLESTA.mp3")
@export var volumen_audio_db: float = -28.0

@export_group("Estilo Visual")
@export var color_borde: Color = Color(0.95, 0.76, 0.35, 1.0)
@export var color_fondo: Color = Color(0.11, 0.08, 0.16, 0.95)
@export var color_texto: Color = Color(0.14, 0.09, 0.04, 1.0)
@export var tamano_fuente: int = 16
@export var ancho_maximo: float = 380.0
@export var ancho_minimo: float = 60.0

@export_group("Comportamiento")
@export var duracion_defecto: float = 3.5
@export var velocidad_escritura: float = 0.025
@export var auto_hablar_al_iniciar: bool = false
@export var clave_auto_hablar: String = ""
@export var retraso_auto_hablar: float = 0.5

var _bubble_ui: SpeechBubbleUI = null
var _canvas_layer: CanvasLayer = null
var _secuencia_activa: bool = false


func _ready() -> void:
	call_deferred("_asegurar_ui")
	if auto_hablar_al_iniciar and not clave_auto_hablar.is_empty():
		get_tree().create_timer(retraso_auto_hablar, false).timeout.connect(func() -> void:
			if is_instance_valid(self) and is_inside_tree():
				decir(clave_auto_hablar)
		)


func _process(_delta: float) -> void:
	if not _bubble_ui or not is_instance_valid(_bubble_ui) or not _bubble_ui.esta_abierto():
		return

	var camera := get_viewport().get_camera_3d()
	if not camera:
		return

	var pos_3d := to_global(offset_cabeza)
	var detras_camara: bool = camera.is_position_behind(pos_3d)
	var pos_2d := camera.unproject_position(pos_3d)

	_bubble_ui.actualizar_posicion_pantalla(pos_2d, not detras_camara)


func _exit_tree() -> void:
	if _bubble_ui and is_instance_valid(_bubble_ui):
		_bubble_ui.queue_free()
		_bubble_ui = null


## Asegura la existencia del CanvasLayer compartido y la instancia de SpeechBubbleUI
func _asegurar_ui() -> void:
	if _bubble_ui and is_instance_valid(_bubble_ui):
		return

	# Buscar o crear el CanvasLayer dedicado para globos de diálogo
	var tree := get_tree()
	if not tree or not tree.root:
		return

	_canvas_layer = tree.root.find_child(NOMBRE_LAYER_GLOBOS, true, false) as CanvasLayer
	if not _canvas_layer or not is_instance_valid(_canvas_layer):
		_canvas_layer = CanvasLayer.new()
		_canvas_layer.name = NOMBRE_LAYER_GLOBOS
		_canvas_layer.layer = LAYER_PRIORIDAD
		tree.root.add_child(_canvas_layer)

	# Instanciar el globo de diálogo dentro del CanvasLayer
	if ESCENA_UI:
		_bubble_ui = ESCENA_UI.instantiate() as SpeechBubbleUI
		_aplicar_estilos_a_ui()
		_canvas_layer.add_child(_bubble_ui)
		_bubble_ui.ocultado.connect(func() -> void:
			emit_signal("dialogo_terminado")
		)


func _aplicar_estilos_a_ui() -> void:
	if not _bubble_ui or not is_instance_valid(_bubble_ui):
		return
	if "color_borde" in _bubble_ui:
		_bubble_ui.color_borde = color_borde
	if "color_fondo" in _bubble_ui:
		_bubble_ui.color_fondo = color_fondo
	if "color_texto" in _bubble_ui:
		_bubble_ui.color_texto = color_texto
	if "tamano_fuente" in _bubble_ui:
		_bubble_ui.tamano_fuente = tamano_fuente
	if "ancho_maximo" in _bubble_ui:
		_bubble_ui.ancho_maximo = ancho_maximo
	if "ancho_minimo" in _bubble_ui:
		_bubble_ui.ancho_minimo = ancho_minimo


## Muestra un diálogo en el globo de este personaje
func decir(clave_o_texto: String, duracion: float = -1.0) -> void:
	var _parent := get_parent()
	if is_instance_valid(_parent):
		if _parent is CanvasItem and not _parent.visible:
			return
		if "health" in _parent and int(_parent.health) <= 0:
			return
		if "current_state" in _parent and "State" in _parent:
			var _st = _parent.current_state
			var _State = _parent.State
			if _st == _State.DYING or _st == _State.DEAD:
				return
		if "esta_paralizada" in _parent and _parent.has_method("esta_paralizada") and _parent.esta_paralizada():
			# Permitir diálogo si solo está paralizada, pero no si está muerta
			pass
	_asegurar_ui()
	if not _bubble_ui:
		return

	_aplicar_estilos_a_ui()
	var dur_final: float = duracion if duracion >= 0.0 else duracion_defecto

	# Actualizar posición inicial de inmediato
	var camera := get_viewport().get_camera_3d()
	if camera:
		var pos_3d := to_global(offset_cabeza)
		var detras: bool = camera.is_position_behind(pos_3d)
		var pos_2d := camera.unproject_position(pos_3d)
		_bubble_ui.actualizar_posicion_pantalla(pos_2d, not detras)

	_bubble_ui.mostrar_dialogo(
		clave_o_texto,
		dur_final,
		velocidad_escritura,
		pitch_voz,
		audio_habla,
		volumen_audio_db
	)

	emit_signal("dialogo_iniciado", clave_o_texto)


## Reproduce una secuencia de diálogos uno detrás de otro
func decir_secuencia(lineas: Array[String], duraciones: Array[float] = []) -> void:
	if lineas.is_empty() or _secuencia_activa:
		return

	_secuencia_activa = true
	for i in range(lineas.size()):
		if not is_instance_valid(self) or not is_inside_tree():
			break
		var linea: String = lineas[i]
		var dur: float = duraciones[i] if i < duraciones.size() else duracion_defecto
		decir(linea, dur)
		await dialogo_terminado
		await get_tree().create_timer(0.3, false).timeout

	_secuencia_activa = false


## Oculta el diálogo activo
func ocultar() -> void:
	if _bubble_ui and is_instance_valid(_bubble_ui):
		_bubble_ui.ocultar_dialogo(true)


## Retorna true si el globo de diálogo está actualmente abierto
func esta_hablando() -> bool:
	return _bubble_ui != null and is_instance_valid(_bubble_ui) and _bubble_ui.esta_abierto()
