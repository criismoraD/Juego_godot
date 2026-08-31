@tool
extends TextureRect

## Flecha roja indicadora con animación de flotación vertical continua
@export var velocidad_flotacion: float = 4.5
@export var amplitud_flotacion: float = 10.0

var _tiempo: float = 0.0
var _pos_base_y: float = 0.0
var _iniciado: bool = false

func _ready() -> void:
	_pos_base_y = position.y
	_iniciado = true

func _process(delta: float) -> void:
	if not is_inside_tree() or not visible:
		return
	if not _iniciado:
		_pos_base_y = position.y
		_iniciado = true
	_tiempo += delta * velocidad_flotacion
	position.y = _pos_base_y + sin(_tiempo) * amplitud_flotacion
