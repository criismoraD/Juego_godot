extends "res://addons/gut/test.gd"

## Tests unitarios para el efecto de bamboleo sutil de ErynTits en Dialogo_Protagonista.
## Verifica la existencia del nodo ErynTits, configuración de su ShaderMaterial,
## alineación con el retrato estático y la animación por Tween al pulsar continuar.

const SCENE_DIALOGO_PROTA: PackedScene = preload("res://UI/Dialogo_Protagonista.tscn")
const SCENE_DIALOGO_NIVEL5: PackedScene = preload("res://UI/DialogoConversacionNivel5.tscn")
const SHADER_JIGGLE: Shader = preload("res://System/Shaders/eryn_tits_jiggle.gdshader")


func test_instanciacion_dialogo_con_eryntits() -> void:
	# Arrange & Act
	var dialogo: DialogoComic = SCENE_DIALOGO_PROTA.instantiate() as DialogoComic
	assert_not_null(dialogo, "La escena Dialogo_Protagonista debe instanciarse")
	add_child_autofree(dialogo)

	# Assert
	var eryn_tits: Sprite2D = dialogo.find_child("Eryntits3", true, false) as Sprite2D
	assert_not_null(eryn_tits, "El nodo Eryntits3 debe existir en la escena")
	assert_not_null(eryn_tits.texture, "Eryntits3 debe tener una textura asignada")
	assert_true(eryn_tits.material is ShaderMaterial, "Eryntits3 debe tener un ShaderMaterial")

	var mat := eryn_tits.material as ShaderMaterial
	assert_eq(mat.shader, SHADER_JIGGLE, "El shader asignado debe ser eryn_tits_jiggle.gdshader")


func test_alineacion_eryntits_con_prota() -> void:
	# Arrange & Act
	var dialogo: DialogoComic = SCENE_DIALOGO_PROTA.instantiate() as DialogoComic
	add_child_autofree(dialogo)

	var prota: Sprite2D = dialogo.find_child("ProtaNormal", true, false) as Sprite2D
	var eryn_tits: Sprite2D = dialogo.find_child("Eryntits3", true, false) as Sprite2D

	# Assert
	assert_not_null(prota, "ProtaNormal debe existir")
	assert_not_null(eryn_tits, "Eryntits3 debe existir")

	# La escala debe ser idéntica a la del retrato base para que la silueta coincida al 100%
	assert_almost_eq(eryn_tits.scale.x, prota.scale.x, 0.01, "La escala X debe coincidir estrechamente con ProtaNormal")
	assert_almost_eq(eryn_tits.scale.y, prota.scale.y, 0.01, "La escala Y debe coincidir estrechamente con ProtaNormal")


func test_animacion_bamboleo_genera_tween() -> void:
	# Arrange
	var dialogo: DialogoComic = SCENE_DIALOGO_PROTA.instantiate() as DialogoComic
	add_child_autofree(dialogo)

	# Act
	dialogo.animar_bamboleo_eryntits()

	# Assert
	var tween: Tween = dialogo.get("_tween_eryn_tits") as Tween
	assert_not_null(tween, "animar_bamboleo_eryntits() debe crear un Tween")
	assert_true(tween.is_valid(), "El Tween de bamboleo debe estar activo y válido")


func test_resiliencia_sin_nodo_eryntits() -> void:
	# Arrange: Instancia pura de DialogoComic sin nodos hijos de retrato
	var dialogo := DialogoComic.new()
	add_child_autofree(dialogo)

	# Act & Assert: No debe producir error o crash
	dialogo.animar_bamboleo_eryntits()
	var tween: Tween = dialogo.get("_tween_eryn_tits") as Tween
	assert_null(tween, "Sin nodo ErynTits, no debe crear Tween ni crashear")


func test_direcciones_bamboleo_vertical_y_horizontal() -> void:
	# Arrange
	var dialogo: DialogoComic = SCENE_DIALOGO_PROTA.instantiate() as DialogoComic
	add_child_autofree(dialogo)

	# Test Vertical (Arriba_Abajo) por defecto
	assert_eq(dialogo.direccion_bamboleo, "Arriba_Abajo", "Por defecto la dirección debe ser Arriba_Abajo para testeo")
	dialogo.animar_bamboleo_eryntits()
	var tween_v: Tween = dialogo.get("_tween_eryn_tits") as Tween
	assert_not_null(tween_v, "Debe generar Tween en modo vertical")
	assert_true(tween_v.is_valid(), "El Tween vertical debe ser válido")

	# Test Horizontal (Derecha_Izquierda)
	dialogo.direccion_bamboleo = "Derecha_Izquierda"
	dialogo.animar_bamboleo_eryntits()
	var tween_h: Tween = dialogo.get("_tween_eryn_tits") as Tween
	assert_not_null(tween_h, "Debe generar Tween en modo horizontal")
	assert_true(tween_h.is_valid(), "El Tween horizontal debe ser válido")


func test_respiracion_inicial_eryn() -> void:
	# Arrange
	var dialogo: DialogoComic = SCENE_DIALOGO_PROTA.instantiate() as DialogoComic
	add_child_autofree(dialogo)

	# Act
	dialogo.reproducir_respiracion_eryn()

	# Assert
	var tween: Tween = dialogo.get("_tween_respiracion") as Tween
	assert_not_null(tween, "reproducir_respiracion_eryn() debe generar un Tween de respiración")
	assert_true(tween.is_valid(), "El Tween de respiración debe estar activo y válido")


func test_respiracion_mantiene_sincronia_tits() -> void:
	# Arrange
	var dialogo: DialogoComic = SCENE_DIALOGO_PROTA.instantiate() as DialogoComic
	add_child_autofree(dialogo)

	var prota: Sprite2D = dialogo.find_child("ProtaNormal", true, false) as Sprite2D
	var tits: Sprite2D = dialogo.find_child("Eryntits3", true, false) as Sprite2D
	assert_not_null(prota)
	assert_not_null(tits)

	dialogo.call("_preparar_nodos_respiracion")
	var escala_prota_inicial: Vector2 = prota.scale
	var escala_tits_inicial: Vector2 = tits.scale

	# Act: Simular pico de inhalación (factor = 1.0)
	dialogo.call("_aplicar_respiracion", 1.0)

	# Assert: Ambos nodos deben haberse estirado en Y y comprimido en X en la misma proporción
	var ratio_prota_y: float = prota.scale.y / escala_prota_inicial.y
	var ratio_tits_y: float = tits.scale.y / escala_tits_inicial.y
	assert_almost_eq(ratio_prota_y, ratio_tits_y, 0.001, "La respiración debe escalar ProtaNormal y Eryntits3 en sincronía idéntica")
	assert_gt(ratio_prota_y, 1.0, "En inhalación, la escala Y debe ser mayor a 1.0")

	# Act: Simular exhalación completa (factor = 0.0)
	dialogo.call("_aplicar_respiracion", 0.0)
	assert_almost_eq(prota.scale.y, escala_prota_inicial.y, 0.001, "Al exhalar debe volver a escala inicial")
	assert_almost_eq(tits.scale.y, escala_tits_inicial.y, 0.001, "Al exhalar Eryntits3 debe volver a escala inicial")


func test_bucle_respiracion_idle() -> void:
	# Arrange
	var dialogo: DialogoComic = SCENE_DIALOGO_PROTA.instantiate() as DialogoComic
	add_child_autofree(dialogo)

	var tits: Sprite2D = dialogo.find_child("Eryntits3", true, false) as Sprite2D
	assert_not_null(tits)

	# Act: Iniciar bucle
	dialogo.iniciar_bucle_respiracion()
	var tween_bucle: Tween = dialogo.get("_tween_bucle") as Tween
	assert_not_null(tween_bucle, "iniciar_bucle_respiracion() debe crear _tween_bucle")
	assert_true(tween_bucle.is_valid(), "_tween_bucle debe estar activo")

	var prota: Sprite2D = dialogo.find_child("ProtaNormal", true, false) as Sprite2D
	assert_not_null(prota)
	var pos_prota_inicial: Vector2 = prota.position
	var escala_prota_inicial: Vector2 = prota.scale
	var pos_tits_inicial: Vector2 = tits.position
	var escala_tits_inicial: Vector2 = tits.scale

	# Simular pico de inhalación en bucle
	dialogo.call("_aplicar_respiracion_bucle", 1.0)
	var mat := tits.material as ShaderMaterial
	assert_not_null(mat)
	var def_y: float = mat.get_shader_parameter("deformacion_y") as float
	assert_almost_eq(def_y, dialogo.bucle_amplitud_tits, 0.001, "Eryntits debe tener rebote elástico en inhalación")
	assert_true(dialogo.bucle_amplitud_tits >= 0.20 and dialogo.bucle_amplitud_tits <= 0.35, "La amplitud de respiracion de tits debe ser sutil y natural (0.20 - 0.35)")

	# El PNG entero (ProtaNormal) respira sutilmente con Squash & Stretch
	assert_gt(prota.scale.y, escala_prota_inicial.y, "El cuerpo entero de Eryn (incluyendo cabeza) se estira sutilmente en Y")
	assert_lt(prota.scale.x, escala_prota_inicial.x, "El cuerpo de Eryn se contrae sutilmente en X al inhalar")
	assert_lt(prota.position.y, pos_prota_inicial.y, "La posición Y asciende para mantener anclada la base")

	# Sincronización exacta: Eryntits3 coincide en escala y desplazamiento con ProtaNormal
	assert_almost_eq(tits.scale.y / escala_tits_inicial.y, prota.scale.y / escala_prota_inicial.y, 0.001, "La escala de Eryntits3 debe coincidir en proporción con ProtaNormal")
	var dy_prota: float = pos_prota_inicial.y - prota.position.y
	var dy_tits: float = pos_tits_inicial.y - tits.position.y
	assert_almost_eq(dy_tits, dy_prota, 0.001, "El desplazamiento de Eryntits3 coincide exactamente con ProtaNormal")

	# Simular rebote de exhalación (factor negativo por inercia elástica)
	dialogo.call("_aplicar_respiracion_bucle", -0.25)
	def_y = mat.get_shader_parameter("deformacion_y") as float
	assert_almost_eq(def_y, -0.25 * dialogo.bucle_amplitud_tits, 0.001, "Eryntits debe descender elásticamente en rebote de exhalación")
	assert_eq(prota.scale.y, escala_prota_inicial.y, "El cuerpo de Eryn descansa en la base neutra sin rebotes bruscos")

	# Detener bucle y comprobar que se resetea a 0.0 y a las posiciones/escalas iniciales
	dialogo.detener_bucle_respiracion()
	def_y = mat.get_shader_parameter("deformacion_y") as float
	assert_almost_eq(def_y, 0.0, 0.001, "Al detener el bucle debe resetear deformacion_y a 0.0")
	assert_eq(prota.position, pos_prota_inicial, "Posición de ProtaNormal vuelve exactamente a la base")
	assert_eq(prota.scale, escala_prota_inicial, "Escala de ProtaNormal vuelve exactamente a la base")
	assert_eq(tits.position, pos_tits_inicial, "Posición de Eryntits3 vuelve exactamente a la base")
	assert_eq(tits.scale, escala_tits_inicial, "Escala de Eryntits3 vuelve exactamente a la base")

	# Comprobar toggle de desactivación completa
	dialogo.bucle_respiracion_activo = false
	dialogo.iniciar_bucle_respiracion()
	assert_null(dialogo.get("_tween_bucle"), "Con bucle_respiracion_activo = false, no debe crear tween")


func test_conversacion_dual_con_eryntits() -> void:
	# Arrange
	var dialogo: DialogoComic = SCENE_DIALOGO_NIVEL5.instantiate() as DialogoComic
	assert_not_null(dialogo, "DialogoConversacionNivel5 debe instanciarse")
	add_child_autofree(dialogo)
	await get_tree().process_frame

	var eryn: Sprite2D = dialogo.find_child("RetratoEryn", true, false) as Sprite2D
	var tits: Sprite2D = dialogo.find_child("Eryntits3", true, false) as Sprite2D
	var perrena: Sprite2D = dialogo.find_child("RetratoPerrena", true, false) as Sprite2D

	assert_not_null(eryn, "RetratoEryn debe existir")
	assert_not_null(tits, "Eryntits3 debe existir en diálogo dual")
	assert_not_null(perrena, "RetratoPerrena debe existir")
	assert_true(tits.material is ShaderMaterial, "Eryntits3 en modo dual debe tener ShaderMaterial")

	# En página 0 (Eryn activa): Eryntits3 está visible/activo al 100%
	assert_eq(tits.modulate, Color.WHITE, "Eryntits3 activo debe tener modulate blanco")
	var escala_tits_base: Vector2 = dialogo.get("_escala_tits_base") as Vector2
	assert_almost_eq(tits.scale.x, escala_tits_base.x, 0.02, "Eryntits3 escala X coincide con su base activa")
	assert_almost_eq(tits.scale.y, escala_tits_base.y, 0.02, "Eryntits3 escala Y coincide con su base activa")

	# Act: Cambiar a página 1 (Perrena activa, Eryn inactiva)
	dialogo._indice_pagina = 1
	dialogo._aplicar_pagina_actual()

	# Assert: Eryntits3 se atenúa y se encoge en sincronía con RetratoEryn
	assert_lt(tits.modulate.r, 0.6, "Eryntits3 apagado al hablar Perrena")
	assert_almost_eq(tits.scale.x, escala_tits_base.x * DialogoComic.ESCALA_RETRATO_APAGADO, 0.01, "Eryntits3 se reduce a escala inactiva")
	assert_almost_eq(tits.scale.y, escala_tits_base.y * DialogoComic.ESCALA_RETRATO_APAGADO, 0.01, "Eryntits3 se reduce a escala inactiva")

	# Act: Regresar a página 3 (Eryn habla de nuevo en la conversación)
	dialogo._indice_pagina = 3
	dialogo._aplicar_pagina_actual()

	# Assert: Eryntits3 recupera foco, color pleno y escala base
	assert_eq(tits.modulate, Color.WHITE, "Eryntits3 recupera color al hablar Eryn")
	assert_almost_eq(tits.scale.x, escala_tits_base.x, 0.02, "Eryntits3 vuelve a escala activa")
	assert_almost_eq(tits.scale.y, escala_tits_base.y, 0.02, "Eryntits3 vuelve a escala activa")




