extends GutTest

## Regresión: flujo torre post-misión 5 → misión Río.
## - Perrena NPC solo visible tras la misión 5 (antes oculta e inactiva).
## - Sin botón WIP/regresar ni SALIR hasta escuchar el Plan de asalto.
## - Tras el diálogo, el botón dice "Iniciar misión" y lleva al Río.
## - Lógica de puerta en NivelInterior (estática, sin escena) + visibilidad
##   del NPC + existencia de la escena del Río y de la clave de traducción.

const RUTA_RIO_ESPERADA: String = "res://Levels/Rio en canoa con paralax.tscn"
const CLAVE_INICIAR_MISION: String = "MENU_INICIAR_MISION"

var scene_root: Node3D
var _flag_mision_guardada: bool = false
var _flag_plan_guardado: bool = false


func before_each() -> void:
	_flag_mision_guardada = GameUI.regreso_conversacion_nivel5
	_flag_plan_guardado = GameUI.plan_asalto_escuchado
	GameUI.regreso_conversacion_nivel5 = false
	GameUI.plan_asalto_escuchado = false
	scene_root = Node3D.new()
	add_child(scene_root)


func after_each() -> void:
	GameUI.regreso_conversacion_nivel5 = _flag_mision_guardada
	GameUI.plan_asalto_escuchado = _flag_plan_guardado
	if is_instance_valid(scene_root):
		scene_root.queue_free()
	await get_tree().process_frame


func test_sin_mision5_torre_normal() -> void:
	# Arrange: sin progresión (visita entre oleadas 1-4)
	GameUI.regreso_conversacion_nivel5 = false
	GameUI.plan_asalto_escuchado = false

	# Assert: ni modo post-misión ni desbloqueo
	assert_false(NivelInterior.es_modo_post_mision5(), "Sin misión 5 no hay modo post-misión")
	assert_false(NivelInterior.mision_rio_desbloqueada(), "Sin plan de asalto no hay desbloqueo")


func test_post_mision5_bloqueado_hasta_plan_asalto() -> void:
	# Arrange: cinemática vista, diálogo aún no escuchado
	GameUI.regreso_conversacion_nivel5 = true
	GameUI.plan_asalto_escuchado = false

	# Assert
	assert_true(NivelInterior.es_modo_post_mision5(), "Con misión 5 debe activarse el modo post-misión")
	assert_false(NivelInterior.mision_rio_desbloqueada(), "Sin plan de asalto el Río sigue bloqueado")


func test_post_mision5_con_plan_desbloquea_rio() -> void:
	# Arrange
	GameUI.regreso_conversacion_nivel5 = true
	GameUI.plan_asalto_escuchado = true

	# Assert
	assert_true(NivelInterior.mision_rio_desbloqueada(), "Con plan escuchado el Río debe desbloquearse")
	assert_eq(NivelInterior.TEXTO_INICIAR_MISION, CLAVE_INICIAR_MISION, "La clave del botón debe ser MENU_INICIAR_MISION")
	assert_eq(NivelInterior.RUTA_NIVEL_RIO, RUTA_RIO_ESPERADA, "La ruta del Río no debe cambiar")
	assert_true(ResourceLoader.exists(NivelInterior.RUTA_NIVEL_RIO), "La escena del Río debe existir")


func test_traduccion_iniciar_mision_bien_formada() -> void:
	# Arrange
	var acceso := FileAccess.open("res://Translations/translations.csv", FileAccess.READ)
	assert_not_null(acceso, "Debe poder leerse translations.csv")
	var texto: String = acceso.get_as_text()

	# Act: localizar la fila de la clave
	var fila: String = ""
	for linea in texto.split("\n"):
		if linea.begins_with(CLAVE_INICIAR_MISION + ","):
			fila = linea.strip_edges()
			break

	# Assert: fila propia con 15 campos (14 comas) y es/en traducidos
	assert_ne(fila, "", "translations.csv debe contener la fila MENU_INICIAR_MISION")
	var comas: int = fila.count(",")
	assert_eq(comas, 14, "La fila debe tener 14 comas (15 campos), tiene %d: %s" % [comas, fila])
	var campos := fila.split(",")
	assert_gte(campos.size(), 3, "La fila debe tener al menos 3 campos")
	if campos.size() < 3:
		return
	assert_eq(campos[1], "Iniciar misión", "El texto en español debe ser 'Iniciar misión'")
	assert_eq(campos[2], "Start mission", "El texto en inglés debe ser 'Start mission'")


func test_perrena_oculta_antes_de_mision5() -> void:
	# Arrange: sin progresión
	GameUI.regreso_conversacion_nivel5 = false
	var npc := PerrenaNPCInterior.new()
	scene_root.add_child(npc)
	await get_tree().process_frame

	# Assert: oculta e inactiva
	assert_false(npc.npc_disponible, "Perrena no debe estar disponible antes de la misión 5")
	assert_false(npc.visible, "Perrena no debe verse antes de la misión 5")


func test_perrena_visible_tras_mision5() -> void:
	# Arrange: misión 5 terminada
	GameUI.regreso_conversacion_nivel5 = true
	var npc := PerrenaNPCInterior.new()
	scene_root.add_child(npc)
	await get_tree().process_frame

	# Assert: visible y disponible
	assert_true(npc.npc_disponible, "Perrena debe estar disponible tras la misión 5")
	assert_true(npc.visible, "Perrena debe verse tras la misión 5")


func test_mesa_navegacion_ignora_salir_oculto() -> void:
	# Arrange: mesa sin escena (lógica pura, sin _ready) con 3 botones
	var mesa := MesaConfiguracion.new()
	var b1 := Button.new()
	var b2 := Button.new()
	var b3 := Button.new()
	mesa._botones_menu = [b1, b2, b3]
	mesa.btn_salir = b3

	# Act: ocultar SALIR como en modo post-misión 5
	mesa.set_salir_visible(false)
	var navegables: Array[Button] = mesa._botones_navegables()

	# Assert: SALIR oculto fuera de la navegación
	assert_false(b3.visible, "set_salir_visible(false) debe ocultar SALIR")
	assert_eq(navegables.size(), 2, "Con SALIR oculto solo debe haber 2 navegables")
	assert_false(navegables.has(b3), "El botón oculto no debe ser navegable")

	# Act: reaparecer
	mesa.set_salir_visible(true)
	navegables = mesa._botones_navegables()

	# Assert
	assert_true(b3.visible, "set_salir_visible(true) debe mostrar SALIR")
	assert_eq(navegables.size(), 3, "Con SALIR visible debe haber 3 navegables")
	mesa.free()
	b1.free()
	b2.free()
	b3.free()
