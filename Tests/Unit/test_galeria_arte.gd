extends GutTest

const RUTA_ESCENA_GALERIA := "res://UI/GaleriaArte.tscn"
const GaleriaArteScript := preload("res://UI/GaleriaArte.gd")
const FondoGaleriaScript := preload("res://UI/FondoGaleria.gd")

var _galeria: Node


func before_each() -> void:
	var escena := load(RUTA_ESCENA_GALERIA) as PackedScene
	assert_not_null(escena, "La escena GaleriaArte.tscn debe existir")
	_galeria = escena.instantiate()
	add_child_autofree(_galeria)


func test_escena_galeria_instancia_correctamente() -> void:
	# Arrange & Act: instanciado en before_each
	# Assert
	assert_not_null(_galeria, "GaleriaArte debe instanciarse")
	assert_true(_galeria.get_script() == GaleriaArteScript, "Debe tener asignado GaleriaArte.gd")


func test_titulo_galeria_es_amarillo_y_texto_correcto() -> void:
	# Arrange
	var titulo: Label = _galeria.get("title_label")
	assert_not_null(titulo, "Debe existir TitleLabel")

	# Act & Assert
	assert_true(titulo.text.to_lower().contains("galer"), "El título debe contener galería")
	var color_titulo: Color = titulo.get_theme_color("font_color")
	var color_esperado: Color = GaleriaArteScript.COLOR_AMARILLO_TITULO
	assert_almost_eq(color_titulo.r, color_esperado.r, 0.05, "Componente R amarillo")
	assert_almost_eq(color_titulo.g, color_esperado.g, 0.05, "Componente G amarillo")
	assert_lt(color_titulo.b, 0.4, "Componente B baja para tono amarillo")


func test_fondo_galeria_existe_con_franjas_celestes() -> void:
	# Arrange & Act
	var fondo: Control = _galeria.get("fondo_galeria")
	assert_not_null(fondo, "Debe existir el nodo FondoGaleria")

	# Assert
	assert_true(fondo.get_script() == FondoGaleriaScript, "El nodo debe usar FondoGaleria.gd")
	var franja_pri: Color = fondo.get("color_franja_principal")
	var franja_sec: Color = fondo.get("color_franja_secundaria")
	var fondo_base: Color = fondo.get("color_fondo")

	assert_gt(franja_pri.b, 0.8, "La franja principal debe tener tono celeste/azul prominente")
	assert_gt(franja_sec.b, 0.8, "La franja secundaria debe tener tono celeste prominente")
	assert_lt(fondo_base.r, 0.1, "El fondo base debe ser negro/oscuro minimalista")


func test_obra_eryn_dialogos_cargada_y_numerada() -> void:
	# Arrange & Act
	var lista_obras: Array = GaleriaArteScript.OBRAS_GALERIA
	assert_eq(lista_obras.size(), 1, "Actualmente hay 1 obra activa en la galería")

	var primera_obra: Dictionary = lista_obras[0]
	# Assert
	assert_eq(primera_obra.get("numero"), "01", "El número de la primera obra debe ser 01")
	assert_eq(primera_obra.get("titulo"), "Eryn diseño Dialogos", "El título debe ser Eryn diseño Dialogos")
	var ruta: String = primera_obra.get("ruta", "")
	assert_true(ResourceLoader.exists(ruta), "El archivo de textura debe existir: %s" % ruta)

	# Verificar que se generó la tarjeta en el collage
	var grid: Container = _galeria.get("grid_obras")
	assert_not_null(grid, "Debe existir GridObras")
	assert_true(grid.get_child_count() >= 1, "Debe haber al menos una tarjeta en el grid")


func test_textos_estan_traducidos() -> void:
	# Arrange & Act
	var btn_volver: Button = _galeria.get("btn_volver")
	var btn_cerrar: Button = _galeria.get("btn_cerrar_visor")
	var titulo: Label = _galeria.get("title_label")

	# Assert
	assert_not_null(btn_volver, "Existe botón volver")
	assert_true(btn_volver.text.contains(tr("BTN_VOLVER")), "Botón volver está traducido")
	assert_not_null(btn_cerrar, "Existe botón cerrar visor")
	assert_true(btn_cerrar.text.contains(tr("BTN_CERRAR")), "Botón cerrar visor está traducido")
	assert_true(titulo.text.contains(tr("MENU_GALLERY")), "Título de galería está traducido")


func test_visor_abrir_imagen_y_cerrar() -> void:
	# Arrange
	var visor: Control = _galeria.get("visor_modal")
	assert_not_null(visor, "Debe existir el visor modal")
	assert_false(visor.visible, "El visor modal debe iniciar oculto")

	# Act: abrir visor con la primera obra (imagen)
	var obra: Dictionary = GaleriaArteScript.OBRAS_GALERIA[0]
	_galeria._abrir_visor(obra)

	# Assert: visor visible, imagen visible y video oculto
	assert_true(visor.visible, "El visor modal debe ser visible tras abrir")
	var visor_num: Label = _galeria.get("visor_numero")
	var visor_tit: Label = _galeria.get("visor_titulo")
	var visor_img: TextureRect = _galeria.get("visor_imagen")
	var visor_vid: VideoStreamPlayer = _galeria.get("visor_video")

	assert_eq(visor_num.text, "01", "El visor debe mostrar el número 01")
	assert_eq(visor_tit.text, "Eryn diseño Dialogos", "El visor debe mostrar el título de la obra")
	assert_true(visor_img.visible, "La imagen debe ser visible")
	if visor_vid:
		assert_false(visor_vid.visible, "El video debe estar oculto para imágenes")

	# Act: cerrar visor
	_galeria._cerrar_visor()
	await get_tree().create_timer(0.25).timeout

	# Assert: visor cerrado
	assert_false(visor.visible, "El visor modal debe ocultarse al cerrar")


func test_visor_soporta_video_player() -> void:
	# Arrange
	var visor: Control = _galeria.get("visor_modal")
	var visor_img: TextureRect = _galeria.get("visor_imagen")
	var visor_vid: VideoStreamPlayer = _galeria.get("visor_video")
	assert_not_null(visor_vid, "Debe existir el nodo VisorVideo")

	# Act: abrir visor con una obra de tipo video
	var obra_video := {
		"id": 99,
		"numero": "99",
		"tipo": "video",
		"titulo": "Video Test",
		"ruta_video": "res://TEST_/0.1 Version.ogv"
	}
	_galeria._abrir_visor(obra_video)

	# Assert
	assert_true(visor.visible, "El visor modal debe ser visible")
	assert_false(visor_img.visible, "La imagen debe estar oculta al reproducir video")
	assert_true(visor_vid.visible, "El video player debe estar visible")

	# Act: cerrar visor
	_galeria._cerrar_visor()
	await get_tree().create_timer(0.25).timeout

	# Assert
	assert_false(visor.visible, "El visor debe cerrarse")
	assert_null(visor_vid.stream, "El stream debe liberarse al cerrar")


func test_tecla_escape_cierra_visor() -> void:
	# Arrange
	var visor: Control = _galeria.get("visor_modal")
	var obra: Dictionary = GaleriaArteScript.OBRAS_GALERIA[0]
	_galeria._abrir_visor(obra)
	assert_true(visor.visible, "Precondición: visor abierto")

	# Act: enviar evento de tecla ESC
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	_galeria._unhandled_input(ev)
	await get_tree().create_timer(0.25).timeout

	# Assert
	assert_false(visor.visible, "ESC debe cerrar el visor modal cuando está abierto")
