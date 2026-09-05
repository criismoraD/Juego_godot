class_name NivelInterior
extends Node3D

const MAT_ESCUDO_ELFICO: Material = preload("res://Levels/Nivel_Interior/MAT_EscudoPesadoElfico.tres")
const MAT_CASCO_OXIDADO: Material = preload("res://Levels/Nivel_Interior/MAT_CascoOxidado.tres")
const ENV_ACTUAL: Environment = preload("res://Levels/Nivel_Interior/Interior_Environment.tres")
const ENV_ANTERIOR: Environment = preload("res://Levels/Nivel_Interior/Interior_Environment_Anterior.tres")

@onready var btn_regresar: Button = %BtnRegresar
@onready var _iluminacion_actual: Node3D = get_node_or_null("IluminacionActual") as Node3D
@onready var _iluminacion_anterior: Node3D = get_node_or_null("IluminacionAnterior") as Node3D
@onready var _capa_mascara_sombra: CanvasLayer = get_node_or_null("CapaMascaraSombra") as CanvasLayer
@onready var _capa_mascara_bordes: CanvasLayer = get_node_or_null("CapaMascaraBordes") as CanvasLayer
@onready var _world_env: WorldEnvironment = get_node_or_null("WorldEnvironment") as WorldEnvironment

var _usando_iluminacion_actual: bool = true



func _ready() -> void:
	if btn_regresar:
		btn_regresar.pressed.connect(_on_btn_regresar_pressed)
	# Música del interior de la torre (al salir, NIVEL01 restaura la de batalla)
	AudioManager.play_music(6)


func _on_btn_regresar_pressed() -> void:
	if btn_regresar:
		btn_regresar.disabled = true
	_reproducir_sonido_puerta()
	SceneManager.cambiar_escena_cortinilla_circular("res://Levels/NIVEL01/NIVEL01.tscn")


## SFX de puerta al salir de la torre.
func _reproducir_sonido_puerta() -> void:
	var stream: AudioStream = load("res://TEST_/abrir_puerta.wav")
	if not stream:
		return
	var player := AudioStreamPlayer.new()
	player.add_to_group("pausable_audio")
	player.stream = stream
	player.volume_db = 2.0
	player.bus = "Master"
	var root := get_tree().current_scene
	if root:
		root.add_child(player)
		player.play()
		player.finished.connect(player.queue_free)
	else:
		player.queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var key_ev := event as InputEventKey
		if key_ev.keycode == KEY_L or key_ev.keycode == KEY_F7:
			_alternar_modo_iluminacion()
		elif key_ev.keycode == KEY_M or key_ev.keycode == KEY_F8:
			_alternar_mascara_bordes()


## Alterna la máscara de desaturación en los bordes
func _alternar_mascara_bordes() -> void:
	if _capa_mascara_bordes:
		_capa_mascara_bordes.visible = not _capa_mascara_bordes.visible
		print("[Máscara Bordes] Desaturación de bordes: %s (Presiona 'M' o 'F8' para alternar)" % ("ACTIVADA" if _capa_mascara_bordes.visible else "DESACTIVADA"))



## Alterna en tiempo de ejecución entre la iluminación actual (sombras 3D reales) y la anterior (máscara 2D + relleno)
func _alternar_modo_iluminacion() -> void:
	_usando_iluminacion_actual = not _usando_iluminacion_actual
	_aplicar_modo_iluminacion(_usando_iluminacion_actual)


func _aplicar_modo_iluminacion(usar_actual: bool) -> void:
	if _iluminacion_actual:
		_iluminacion_actual.visible = usar_actual
	if _iluminacion_anterior:
		_iluminacion_anterior.visible = not usar_actual
	if _capa_mascara_sombra:
		_capa_mascara_sombra.visible = not usar_actual
	if _world_env:
		_world_env.environment = ENV_ACTUAL if usar_actual else ENV_ANTERIOR
	print("[Comparador Iluminación] Modo: %s (Presiona 'L' o 'F7' para alternar)" % ("ACTUAL (Sombras Reales 3D)" if usar_actual else "ANTERIOR (Máscara 2D + Luces de Relleno)"))

