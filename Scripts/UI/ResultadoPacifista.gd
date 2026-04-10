class_name ResultadoPacifista
extends CanvasLayer

signal opcion_elegida(opcion: String)

@onready var boton_continuar: Button = $Contenedor/BotonContinuar
@onready var boton_reiniciar: Button = $Contenedor/BotonReiniciar

func _ready():
	if boton_continuar:
		boton_continuar.focus_mode = Control.FOCUS_NONE
		boton_continuar.pressed.connect(func():
			emit_signal("opcion_elegida", "continuar")
		)

	if boton_reiniciar:
		boton_reiniciar.focus_mode = Control.FOCUS_NONE
		boton_reiniciar.pressed.connect(func():
			emit_signal("opcion_elegida", "reiniciar")
		)
