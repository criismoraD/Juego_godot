class_name BarraCircularFuegoRapido
extends Control

## Barra de carga circular sobre la protagonista que muestra la duración
## restante del buff de Fuego Rápido en color rosado.

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTES Y EXPORTS
# ═══════════════════════════════════════════════════════════════════════════════
const TAMANO_DEFAULT: Vector2 = Vector2(40.0, 40.0)

@export var radio: float = 14.0
@export var grosor: float = 3.5
@export var color_fondo_circulo: Color = Color(0.08, 0.05, 0.1, 0.5)
@export var color_track: Color = Color(0.18, 0.1, 0.22, 0.75)
@export var color_progreso: Color = Color(1.0, 0.35, 0.8, 0.95)
@export var color_brillo_cabeza: Color = Color(1.0, 0.9, 0.98, 1.0)
@export var color_nucleo: Color = Color(1.0, 0.45, 0.85, 0.9)

# ═══════════════════════════════════════════════════════════════════════════════
# VARIABLES
# ═══════════════════════════════════════════════════════════════════════════════
var progress: float = 1.0:
	set(val):
		var clamped: float = clampf(val, 0.0, 1.0)
		if not is_equal_approx(progress, clamped):
			progress = clamped
			queue_redraw()

var tiempo_restante: float = 15.0


func _init() -> void:
	custom_minimum_size = TAMANO_DEFAULT
	size = TAMANO_DEFAULT
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var center: Vector2 = size * 0.5

	# 1. Fondo circular translúcido
	draw_circle(center, radio + grosor * 0.5, color_fondo_circulo)

	# 2. Pista/anillo de fondo continuo
	draw_arc(center, radio, 0.0, TAU, 64, color_track, grosor, true)

	# 3. Anillo de progreso rosado (en sentido horario desde las 12 en punto)
	if progress > 0.005:
		var angulo_inicio: float = -PI * 0.5
		var angulo_fin: float = angulo_inicio + (TAU * progress)

		# Parpadeo suave si quedan menos de 2.5 segundos
		var color_actual: Color = color_progreso
		if tiempo_restante > 0.0 and tiempo_restante < 2.5:
			var flash: float = (sin(Time.get_ticks_msec() * 0.02) + 1.0) * 0.5
			color_actual = color_progreso.lerp(Color(1.0, 0.75, 0.95, 1.0), flash * 0.5)

		draw_arc(center, radio, angulo_inicio, angulo_fin, 64, color_actual, grosor, true)

		# Punto brillante en la punta del progreso
		var head_pos: Vector2 = center + Vector2(cos(angulo_fin), sin(angulo_fin)) * radio
		draw_circle(head_pos, grosor * 0.75, color_brillo_cabeza)

	# 4. Núcleo central decorativo rosado
	draw_circle(center, 2.5, color_nucleo)
