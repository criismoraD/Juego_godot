class_name ImpPiezaFisica
extends GoblinPiezaFisica

## Pieza física del Imp (cabeza desmembrada). Hereda el vuelo parabólico,
## rebote y disolución del Goblin, pero disuelve con el color de sangre del Imp.

func iniciar_disolucion(duracion: float = 1.2, color_disolucion: Color = Color(0.2, 0.85, 0.2)) -> void:
	var color_imp: Color = Color(0.4, 0.0, 0.5) if ImpEnemy.sangre_morada else Color(0.6, 0.0, 0.0)
	super.iniciar_disolucion(duracion, color_imp)
