class_name LanzaVoladora
extends GoblinPiezaFisica

## Lanza que Azulina suelta al morir: maneja el vuelo parabólico, rotación,
## rebote contra el suelo y disolución celeste con partículas.
## Hereda de GoblinPiezaFisica para comportarse de la misma manera que el arco de la arquera goblin.

const COLOR_DISOLUCION_LANZA := Color(0.45, 0.85, 1.0)


func _ready() -> void:
	super._ready()
	_tiempo_para_disolver = 2.5


func iniciar_disolucion(duracion: float = 1.2, _color_disolucion: Color = Color(0.2, 0.85, 0.2)) -> void:
	super.iniciar_disolucion(duracion, COLOR_DISOLUCION_LANZA)
