class_name SalpicaduraAzulina
extends SalpicaduraTest

## Salpicadura de producción para la emergencia de Azulina desde el agua.
## Un solo impacto que se libera solo al terminar. Hereda tira de cuadros,
## offset de línea de agua, caché de SpriteFrames y previsualización.
## Igual que Fuego2D es la versión productiva de su escena de pruebas.

# === FUNCIONES BUILT-IN ===
func _ready() -> void:
	reproduccion_en_bucle = false
	animar_en_editor = false
	super._ready()
