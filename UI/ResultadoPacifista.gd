class_name ResultadoPacifista
extends CanvasLayer
signal opcion_elegida(opcion: String)
@onready var boton_continuar: Button = _obtener_boton("BotonContinuar")
@onready var boton_reiniciar: Button = _obtener_boton("BotonReiniciar")


func _obtener_boton(nombre_boton: String) -> Button:
	var nodo := find_child(nombre_boton, true, false)
	if nodo is Button:
		return nodo
	return null


func _ready():
	_aplicar_traducciones()
	if boton_continuar:
		boton_continuar.focus_mode = Control.FOCUS_NONE
		boton_continuar.pressed.connect(func(): emit_signal("opcion_elegida", "continuar"))

	if boton_reiniciar:
		boton_reiniciar.focus_mode = Control.FOCUS_NONE
		boton_reiniciar.pressed.connect(func(): emit_signal("opcion_elegida", "reiniciar"))


## Textos por traducción (la escena trae literales en español de respaldo).
func _aplicar_traducciones() -> void:
	var texto := find_child("ResultadoTexto", true, false)
	if texto and "text" in texto:
		texto.set("text", tr("RESULTADO_PACIFISTA"))
	if boton_continuar:
		boton_continuar.text = tr("BOTON_CONTINUAR")
	if boton_reiniciar:
		boton_reiniciar.text = tr("BTN_REINICIAR_PARTIDA")
