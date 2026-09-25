class_name NivelInterior
extends Node3D

const MAT_ESCUDO_ELFICO: Material = preload("res://Levels/Nivel_Interior/MAT_EscudoPesadoElfico.tres")
const MAT_CASCO_OXIDADO: Material = preload("res://Levels/Nivel_Interior/MAT_CascoOxidado.tres")
const ENV_ACTUAL: Environment = preload("res://Levels/Nivel_Interior/Interior_Environment.tres")
const ENV_ANTERIOR: Environment = preload("res://Levels/Nivel_Interior/Interior_Environment_Anterior.tres")
## Misión del Río (nivel 6): se desbloquea al escuchar el Plan de asalto de Perrena.
const RUTA_NIVEL_RIO: String = "res://Levels/Rio en canoa con paralax.tscn"
const TEXTO_INICIAR_MISION: String = "MENU_INICIAR_MISION"

@onready var btn_regresar: Button = %BtnRegresar
@onready var _iluminacion_actual: Node3D = get_node_or_null("IluminacionActual") as Node3D
@onready var _iluminacion_anterior: Node3D = get_node_or_null("IluminacionAnterior") as Node3D
@onready var _capa_mascara_sombra: CanvasLayer = get_node_or_null("CapaMascaraSombra") as CanvasLayer
@onready var _capa_mascara_bordes: CanvasLayer = get_node_or_null("CapaMascaraBordes") as CanvasLayer
@onready var _world_env: WorldEnvironment = get_node_or_null("WorldEnvironment") as WorldEnvironment

var _usando_iluminacion_actual: bool = false



func _ready() -> void:
	add_to_group("torre_interior")
	if btn_regresar:
		btn_regresar.pressed.connect(_on_btn_regresar_pressed)
	# Música del interior de la torre (al salir, NIVEL01 restaura la de batalla)
	AudioManager.play_music(6)
	# Estado inicial de iluminación: restaurar la iluminación completa de la torre
	# (antorchas, mesa de alquimia, cama y relleno; L/F7 alternan para comparar).
	_aplicar_modo_iluminacion(false)
	# Torre normal: el botón de salida usa texto traducible.
	if not es_modo_post_mision5() and btn_regresar:
		btn_regresar.text = tr("BTN_VOLVER")
	_aplicar_estado_mision()


## True tras terminar la misión 5 (cinemática de oleada 5 → torre).
## Antes de eso la torre funciona como siempre (Perrena oculta, WIP regresar).
static func es_modo_post_mision5() -> bool:
	return GameUI.regreso_conversacion_nivel5


## True cuando ya se escuchó el Plan de asalto: el botón pasa a "Iniciar misión".
static func mision_rio_desbloqueada() -> bool:
	return es_modo_post_mision5() and GameUI.plan_asalto_escuchado


## Post-misión 5: sin salidas a NIVEL01 (BtnRegresar oculto) hasta escuchar
## el Plan de asalto; entonces el botón se vuelve "Iniciar misión".
## SALIR del mueble siempre visible: solo cierra su menú, no sale de la torre.
func _aplicar_estado_mision() -> void:
	if not es_modo_post_mision5():
		return
	if btn_regresar:
		btn_regresar.visible = false
	_set_mesa_salir_visible(true)
	if mision_rio_desbloqueada():
		_mostrar_boton_iniciar_mision()


## La llama el NPC Perrena (call_group) al terminar el diálogo Plan de asalto.
func desbloquear_mision_rio() -> void:
	if not es_modo_post_mision5():
		return
	_set_mesa_salir_visible(true)
	_mostrar_boton_iniciar_mision()


func _mostrar_boton_iniciar_mision() -> void:
	if btn_regresar == null:
		return
	btn_regresar.text = tr(TEXTO_INICIAR_MISION)
	btn_regresar.disabled = false
	btn_regresar.visible = true


func _set_mesa_salir_visible(v: bool) -> void:
	var raiz := get_parent()
	if raiz == null:
		return
	var mesa := raiz.find_child("MesaConfiguracion", true, false)
	if mesa and mesa.has_method("set_salir_visible"):
		mesa.call("set_salir_visible", v)


func _on_btn_regresar_pressed() -> void:
	if es_modo_post_mision5():
		if mision_rio_desbloqueada():
			_iniciar_mision_rio()
		return
	if btn_regresar:
		btn_regresar.disabled = true
	_reproducir_sonido_puerta()
	SceneManager.cambiar_escena_cortinilla_circular("res://Levels/NIVEL01/NIVEL01.tscn")


## Transición con cortinilla al nivel del Río. Limpia los marcadores de
## retorno a NIVEL01 (ya no hay cortinilla de oleada que restaurar ni
## posición de puerta que reutilizar).
func _iniciar_mision_rio() -> void:
	if btn_regresar:
		btn_regresar.disabled = true
	_reproducir_sonido_puerta()
	GameUI.regreso_desde_interior_oleada = 0
	if has_node("/root/SceneManager"):
		get_node("/root/SceneManager").posicion_retorno_puerta = Vector3.ZERO
	SceneManager.cambiar_escena_cortinilla_circular(RUTA_NIVEL_RIO)


## SFX de puerta al salir de la torre.
func _reproducir_sonido_puerta() -> void:
	var stream: AudioStream = load("res://System/Audio/SFX/abrir_puerta.wav")
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

