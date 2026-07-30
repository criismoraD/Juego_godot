class_name UIInstruccionesMouse
extends CanvasLayer

## Si está activado, traduce automáticamente los textos al iniciar.
## Desactiva esta casilla en el Inspector si prefieres usar textos personalizados editados directamente en la escena.
@export var usar_traduccion_automatica: bool = true

@onready var contenedor: Control = %ContenedorInstrucciones
@onready var imagen_instrucciones: TextureRect = %ImagenInstrucciones
@onready var texto_moverse: Label = %TextoMoverse
@onready var texto_raton: Label = %TextoRaton

var ocultando: bool = false


func _ready() -> void:
	add_to_group("ui_instrucciones")
	if usar_traduccion_automatica:
		_actualizar_traducciones()


func _actualizar_traducciones() -> void:
	if texto_moverse:
		texto_moverse.text = "= " + tr("INSTR_MOVERSE")
	if texto_raton:
		texto_raton.text = tr("INSTR_RATON")


## Oculta de golpe las instrucciones al impactar un enemigo y revela la UI de vida del jugador
func ocultar() -> void:
	if ocultando:
		return
	ocultando = true

	# Revelar la UI de vida de la protagonista al desaparecer las instrucciones
	if get_tree():
		get_tree().call_group("ui_vida_protagonista", "mostrar")

	queue_free()


## Método estático para notificar el impacto a un enemigo y cerrar las instrucciones
static func notificar_impacto_enemigo(tree: SceneTree) -> void:
	if is_instance_valid(tree):
		tree.call_group("ui_instrucciones", "ocultar")
