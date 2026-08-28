@tool
class_name PuntoNacimientoDialogo
extends Marker2D

## Punto de Nacimiento de Diálogo: Nodo visual para ubicar y disparar diálogos.
## Al duplicarlo en la escena (Ctrl+D), cada instancia tiene su propio texto,
## posición y configuración editable en el Inspector.

@export_group("Contenido del Diálogo")
@export_multiline var texto: String = "¡Distingo varias siluetas en el horizonte!":
	set(value):
		texto = value
		if Engine.is_editor_hint():
			queue_redraw()

@export var id_dialogo: String = "":
	set(value):
		id_dialogo = value

@export_group("Comportamiento")
@export var duracion: float = 4.0  ## Tiempo visible en segundos (0 para mantener hasta cerrar)
@export var velocidad_escritura: float = 0.025  ## Segundos por letra al revelarse
@export var auto_activar_al_inicio: bool = false  ## Si se activa solo al iniciar la escena
@export var retraso_inicio: float = 0.0  ## Retraso antes de auto-activarse

@export_group("Estilo Visual")
@export var color_borde: Color = Color(0.95, 0.76, 0.35, 1.0):
	set(value):
		color_borde = value
		if Engine.is_editor_hint():
			queue_redraw()

@export var color_fondo: Color = Color(0.11, 0.08, 0.16, 0.95):
	set(value):
		color_fondo = value
		if Engine.is_editor_hint():
			queue_redraw()

@export var tamano_fuente: int = 22
@export var ancho_maximo: float = 750.0
@export var ancho_minimo: float = 240.0
@export var mostrar_preview_editor: bool = true:
	set(value):
		mostrar_preview_editor = value
		if Engine.is_editor_hint():
			queue_redraw()


func _ready() -> void:
	add_to_group("puntos_dialogo")
	if Engine.is_editor_hint():
		return

	if auto_activar_al_inicio:
		if retraso_inicio > 0.0:
			get_tree().create_timer(retraso_inicio, false).timeout.connect(func() -> void:
				if is_instance_valid(self) and is_inside_tree():
					activar()
			)
		else:
			activar()


## Dispara y muestra este diálogo con su texto y posición específicos
func activar() -> void:
	var game_ui := get_tree().get_first_node_in_group("game_ui")
	if game_ui and game_ui.has_method("mostrar_dialogo_desde_punto"):
		game_ui.mostrar_dialogo_desde_punto(self)
	elif game_ui and game_ui.has_method("mostrar_texto_defensora"):
		game_ui.mostrar_texto_defensora(texto, duracion, true)


## Oculta el diálogo activo
func ocultar() -> void:
	var game_ui := get_tree().get_first_node_in_group("game_ui")
	if game_ui and game_ui.has_method("ocultar_texto_defensora"):
		game_ui.ocultar_texto_defensora(true)


func _draw() -> void:
	if not Engine.is_editor_hint() or not mostrar_preview_editor:
		return

	# Dibujar retícula y caja de previsualización en el editor 2D
	var radio_centro: float = 8.0
	draw_circle(Vector2.ZERO, radio_centro, color_borde)
	draw_line(Vector2(-16, 0), Vector2(16, 0), color_borde, 2.0)
	draw_line(Vector2(0, -16), Vector2(0, 16), color_borde, 2.0)

	var texto_corto: String = texto
	if texto_corto.length() > 32:
		texto_corto = texto_corto.substr(0, 29) + "..."

	var font: Font = ThemeDB.fallback_font
	if font:
		var preview_text := "[%s] %s" % [name, texto_corto]
		draw_string(font, Vector2(-90, -22), preview_text, HORIZONTAL_ALIGNMENT_CENTER, 300, 14, color_borde)
