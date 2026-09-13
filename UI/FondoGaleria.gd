class_name FondoGaleria
extends Control
## Dibuja el fondo minimalista limpio y elegante de la Galería de Arte,
## con base oscura y 2 franjas de color celeste perfectamente nítidas
## (sin pixelación ni bordes dentados).

@export var color_fondo: Color = Color(0.04, 0.04, 0.06, 1.0)
@export var color_franja_principal: Color = Color(0.0, 0.68, 0.96, 1.0)
@export var color_franja_secundaria: Color = Color(0.3, 0.85, 1.0, 0.85)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 0.0 or h <= 0.0:
		return

	# 1. Base negra/azul oscura minimalista (idéntica a los menús interiores de la torre)
	draw_rect(Rect2(Vector2.ZERO, size), color_fondo, true)

	# 2. Franja horizontal superior secundaria (celeste claro fino, 2px)
	draw_rect(Rect2(0.0, 116.0, w, 2.0), color_franja_secundaria, true)

	# 3. Franja horizontal superior principal (celeste vibrante, 3px)
	draw_rect(Rect2(0.0, 122.0, w, 3.0), color_franja_principal, true)
