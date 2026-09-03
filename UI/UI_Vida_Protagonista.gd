class_name UIVidaProtagonista
extends CanvasLayer

@onready var barra_vida: TextureRect = %BarraVida
@onready var corazon_01: TextureRect = %Corazon01
@onready var corazon_02: TextureRect = %Corazon02
@onready var corazon_03: TextureRect = %Corazon03
@onready var corazon_04: TextureRect = %Corazon04
@onready var contador_flechas_explosivas: Label = %ContadorFlechasExplosivas
@onready var icono_flechas_explosivas: TextureRect = %IconoFlechaExplosiva

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

	if is_instance_valid(contador_flechas_explosivas):
		contador_flechas_explosivas.pivot_offset = contador_flechas_explosivas.size * 0.5
		contador_flechas_explosivas.visible = false

	if is_instance_valid(icono_flechas_explosivas):
		icono_flechas_explosivas.pivot_offset = icono_flechas_explosivas.size * 0.5
		icono_flechas_explosivas.visible = false

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


## Reconecta el HUD al "player" activo actual (llamado al cambiar de personaje).
func reconectar_player() -> void:
	_buscar_y_conectar_player()


func _intentar_conectar_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		_conectar_player(player)


const TEXTURA_FLECHA_EXPLOSIVA = preload("res://UI/Icons/Icono_Flecha_Explosiva.png")
const TEXTURA_FLECHA_MULTIPLE = preload("res://UI/Icons/Icono_Flecha_Multiple.png")


func _conectar_player(player: Node) -> void:
	if player.has_signal("health_changed"):
		if not player.health_changed.is_connected(_on_health_changed):
			player.health_changed.connect(_on_health_changed)
	if player.has_signal("flechas_explosivas_changed"):
		if not player.flechas_explosivas_changed.is_connected(_on_flechas_explosivas_changed):
			player.flechas_explosivas_changed.connect(_on_flechas_explosivas_changed)
	if player.has_signal("flechas_multiples_changed"):
		if not player.flechas_multiples_changed.is_connected(_on_flechas_multiples_changed):
			player.flechas_multiples_changed.connect(_on_flechas_multiples_changed)
	if player.has_signal("tipo_municion_changed"):
		if not player.tipo_municion_changed.is_connected(_on_tipo_municion_changed):
			player.tipo_municion_changed.connect(_on_tipo_municion_changed)
	if "health" in player:
		actualizar_vida(int(player.health))
	_refrescar_display_municion(player)


func _on_health_changed(new_health: int) -> void:
	actualizar_vida(new_health)


func _on_tipo_municion_changed(_tipo: int) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		_refrescar_display_municion(player)


func _on_flechas_explosivas_changed(cantidad: int) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and int(player.get("municion_activa")) == 1:
		actualizar_flechas_explosivas(cantidad)
	elif player and int(player.get("municion_activa")) == 0 and cantidad > 0:
		_refrescar_display_municion(player)


func _on_flechas_multiples_changed(cantidad: int) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and int(player.get("municion_activa")) == 2:
		actualizar_flechas_multiples(cantidad)
	elif player and int(player.get("municion_activa")) == 0 and cantidad > 0:
		_refrescar_display_municion(player)


func _refrescar_display_municion(player: Node) -> void:
	if not player:
		return
	var tipo: int = int(player.get("municion_activa")) if "municion_activa" in player else 0
	match tipo:
		1:  # EXPLOSIVA
			var cnt: int = int(player.get("flechas_explosivas")) if "flechas_explosivas" in player else 0
			actualizar_flechas_explosivas(cnt)
		2:  # MULTIPLE
			var cnt: int = int(player.get("flechas_multiples")) if "flechas_multiples" in player else 0
			actualizar_flechas_multiples(cnt)
		_:  # NORMAL
			_actualizar_powerup_display(0, TEXTURA_FLECHA_EXPLOSIVA)


## Actualiza el contador e icono de flechas múltiples
func actualizar_flechas_multiples(cantidad: int) -> void:
	_actualizar_powerup_display(cantidad, TEXTURA_FLECHA_MULTIPLE)


## Actualiza el contador e icono de flechas explosivas
func actualizar_flechas_explosivas(cantidad: int) -> void:
	_actualizar_powerup_display(cantidad, TEXTURA_FLECHA_EXPLOSIVA)


func _actualizar_powerup_display(cantidad: int, textura_icono: Texture2D) -> void:
	if not is_instance_valid(contador_flechas_explosivas):
		return

	if cantidad <= 0:
		contador_flechas_explosivas.visible = false
		if is_instance_valid(icono_flechas_explosivas):
			icono_flechas_explosivas.visible = false
	else:
		contador_flechas_explosivas.visible = true
		contador_flechas_explosivas.text = str(cantidad)
		contador_flechas_explosivas.pivot_offset = contador_flechas_explosivas.size * 0.5

		if is_instance_valid(icono_flechas_explosivas):
			icono_flechas_explosivas.texture = textura_icono
			icono_flechas_explosivas.visible = true
			icono_flechas_explosivas.pivot_offset = icono_flechas_explosivas.size * 0.5

		# Animación punch scale al ganar o gastar flechas
		var tween := create_tween()
		contador_flechas_explosivas.scale = Vector2(1.3, 1.3)
		tween.tween_property(contador_flechas_explosivas, "scale", Vector2.ONE, 0.22) \
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

		if is_instance_valid(icono_flechas_explosivas):
			var tween_icono := create_tween()
			icono_flechas_explosivas.scale = Vector2(1.3, 1.3)
			tween_icono.tween_property(icono_flechas_explosivas, "scale", Vector2.ONE, 0.22) \
				.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


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
