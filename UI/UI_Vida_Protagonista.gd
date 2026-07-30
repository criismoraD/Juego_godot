class_name UIVidaProtagonista
extends CanvasLayer

@onready var barra_vida: TextureRect = %BarraVida
@onready var corazon_01: TextureRect = %Corazon01
@onready var corazon_02: TextureRect = %Corazon02
@onready var corazon_03: TextureRect = %Corazon03
@onready var corazon_04: TextureRect = %Corazon04

var _last_vida: int = -1
var _corazones_list: Array[TextureRect] = []


func _ready() -> void:
	add_to_group("ui_vida_protagonista")
	visible = false  # Permanece oculta hasta que desaparezcan las instrucciones
	_corazones_list = [corazon_01, corazon_02, corazon_03, corazon_04]

	# Configurar pivotes en el centro para escalados animados
	for corazon in _corazones_list:
		if is_instance_valid(corazon):
			corazon.pivot_offset = corazon.size * 0.5

	_buscar_y_conectar_player()


## Muestra la UI de vida
func mostrar() -> void:
	visible = true


func _buscar_y_conectar_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		_conectar_player(player)
	else:
		get_tree().process_frame.connect(_intentar_conectar_player, CONNECT_ONE_SHOT)


func _intentar_conectar_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		_conectar_player(player)


func _conectar_player(player: Node) -> void:
	if player.has_signal("health_changed"):
		if not player.health_changed.is_connected(_on_health_changed):
			player.health_changed.connect(_on_health_changed)
	if "health" in player:
		actualizar_vida(int(player.health))


func _on_health_changed(new_health: int) -> void:
	actualizar_vida(new_health)


## Actualiza la vida únicamente animando al ganar o perder corazones.
func actualizar_vida(vida_actual: int) -> void:
	var vida_anterior: int = _last_vida
	_last_vida = vida_actual

	for i in range(_corazones_list.size()):
		var corazon := _corazones_list[i]
		if not is_instance_valid(corazon):
			continue

		var debe_estar_visible: bool = (i < vida_actual)

		# Asegurar pivot offset
		corazon.pivot_offset = corazon.size * 0.5

		# Primera inicialización sin animar
		if vida_anterior == -1:
			corazon.visible = debe_estar_visible
			corazon.scale = Vector2(1.0, 1.0)
			corazon.modulate = Color(1.0, 1.0, 1.0, 1.0)
			continue

		# SI RECUPERÓ VIDA (Se enciende un corazón previamente apagado)
		if debe_estar_visible and not corazon.visible:
			corazon.visible = true
			corazon.scale = Vector2(1.6, 1.6)
			corazon.modulate = Color(1.5, 1.5, 1.5, 1.0)
			
			var tween := create_tween().set_parallel(true)
			tween.tween_property(corazon, "scale", Vector2(1.0, 1.0), 0.45) \
				.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
			tween.tween_property(corazon, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.3)

		# SI PERDIÓ VIDA (Se apaga un corazón previamente activo)
		elif not debe_estar_visible and corazon.visible:
			var tween := create_tween().set_parallel(true)
			tween.tween_property(corazon, "scale", Vector2(0.01, 0.01), 0.35) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
			tween.tween_property(corazon, "modulate", Color(2.0, 0.2, 0.2, 0.0), 0.35)
			
			tween.finished.connect(func():
				if is_instance_valid(corazon):
					corazon.visible = false
					corazon.scale = Vector2(1.0, 1.0)
					corazon.modulate = Color(1.0, 1.0, 1.0, 1.0)
			)
		else:
			corazon.visible = debe_estar_visible
