class_name MontanaBeta
extends Sprite3D

## Montaña Beta decorativa en el nivel del río.
## Ubicada en el fondo panorámico, avanza a la misma velocidad del bosque rojo
## y aparece una sola vez a lo largo del recorrido (sin repetición en el loop parallax).

# === EXPORTS ===
@export_category("Parallax y Desplazamiento")
@export var sincronizar_con_bosque_rojo: bool = true  ## Si true, avanza sincronizada a la velocidad del bosque rojo


# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	# Respetar la capa visual de fondo (2) si no fue asignada
	if layers == 1:
		layers = 2
