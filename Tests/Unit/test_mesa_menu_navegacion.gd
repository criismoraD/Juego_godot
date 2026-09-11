extends GutTest

## Navegación W/S del menú del mueble (MesaConfiguracion): foco único,
## vuelta en los extremos, E activa y el ratón roba el foco al teclado.

const ESCENA_MESA: PackedScene = preload("res://Levels/Nivel_Interior/MesaConfiguracion.tscn")


func _instanciar_mesa() -> MesaConfiguracion:
	var mesa := ESCENA_MESA.instantiate() as MesaConfiguracion
	add_child_autofree(mesa)
	await get_tree().process_frame
	return mesa


func test_mesa_registra_tres_opciones_en_orden() -> void:
	# Arrange
	var mesa := await _instanciar_mesa()

	# Act
	var botones: Array[Button] = mesa._botones_menu

	# Assert: defensoras, bestiario, salir.
	assert_eq(botones.size(), 3, "Tres opciones en el menú del mueble")
	assert_eq(mesa.btn_defensoras, botones[0], "La primera es Defensoras")
	assert_eq(mesa.btn_salir, botones[2], "La última es Salir")


func test_mesa_w_s_navega_con_vuelta() -> void:
	# Arrange
	var mesa := await _instanciar_mesa()
	mesa._jugador_cerca = true
	mesa._abrir_menu()
	assert_eq(mesa._opcion_foco, 0, "Arranca en la primera (Defensoras)")

	# Act & Assert: S baja, S baja, W sube.
	mesa._mover_foco(1)
	assert_eq(mesa._opcion_foco, 1, "S baja a Bestiario")
	mesa._mover_foco(1)
	assert_eq(mesa._opcion_foco, 2, "S baja a Salir")
	mesa._mover_foco(-1)
	assert_eq(mesa._opcion_foco, 1, "W sube a Bestiario")

	# Act: vuelta por los extremos.
	mesa._mover_foco(-1)
	assert_eq(mesa._opcion_foco, 0, "W en Bestiario sube a Defensoras")
	mesa._mover_foco(-1)
	assert_eq(mesa._opcion_foco, 2, "W en la primera da la vuelta a Salir")
	mesa._mover_foco(1)
	assert_eq(mesa._opcion_foco, 0, "S en Salir da la vuelta a la primera")


func test_mesa_mouse_roba_foco_al_teclado() -> void:
	# Arrange
	var mesa := await _instanciar_mesa()
	mesa._jugador_cerca = true
	mesa._abrir_menu()

	# Act: teclado a Bestiario, el ratón entra en Salir.
	mesa._mover_foco(1)
	assert_eq(get_tree().root.get_viewport().gui_get_focus_owner(), mesa._botones_menu[1], "Teclado marca Bestiario")
	mesa._on_mouse_entra_opcion_menu(mesa.btn_salir)

	# Assert: una sola marca, la del último input (el ratón).
	assert_eq(mesa._opcion_foco, 2, "El ratón roba la selección")
	assert_eq(get_tree().root.get_viewport().gui_get_focus_owner(), mesa.btn_salir, "Foco único en Salir")


func test_mesa_e_activa_opcion_con_foco() -> void:
	# Arrange
	var mesa := await _instanciar_mesa()
	mesa._jugador_cerca = true
	mesa._abrir_menu()
	mesa._cerrar_menu(false)

	# Act: seleccionar Salir con S y activar con E (re-abre y dispara).
	mesa._abrir_menu()
	mesa._mover_foco(1)
	mesa._mover_foco(1)
	mesa._activar_foco()
	await get_tree().process_frame

	# Assert: Salir cierra el menú del mueble.
	assert_false(mesa.menu_canvas.visible, "E en Salir cierra el menú")


func test_pulsar_opcion_suena_seleccion_menu() -> void:
	# Arrange
	var mesa := await _instanciar_mesa()
	var am = get_tree().root.get_node_or_null("AudioManager")
	assert_not_null(am, "Precondición: AudioManager disponible")
	mesa._jugador_cerca = true
	mesa._abrir_menu()

	# Act: pulsar Salir (cierra sin abrir submenús).
	mesa._on_btn_salir_pressed()

	# Assert: suena selección.
	var esperados: Array = am.sfx_streams["seleccion_menu"]
	var suena := false
	for p in am.sfx_pool:
		if p.playing and p.stream != null and p.stream in esperados:
			suena = true
			break
	assert_true(suena, "Pulsar opción del mueble suena seleccion_menu")
	await get_tree().create_timer(0.3).timeout
	assert_false(mesa.menu_canvas.visible, "El menú se cerró")


func test_abrir_menu_suena_seleccion_menu() -> void:
	# Arrange
	var mesa := await _instanciar_mesa()
	var am = get_tree().root.get_node_or_null("AudioManager")
	assert_not_null(am, "Precondición: AudioManager disponible")
	mesa._jugador_cerca = true

	# Act: abrir el menú del mueble.
	mesa._abrir_menu()

	# Assert: suena selección al entrar (sin el ruido viejo de interacción).
	var esperados: Array = am.sfx_streams["seleccion_menu"]
	var suena := false
	for p in am.sfx_pool:
		if p.playing and p.stream != null and p.stream in esperados:
			suena = true
			break
	assert_true(suena, "Abrir el mueble suena seleccion_menu")
