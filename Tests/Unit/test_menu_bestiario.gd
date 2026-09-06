extends "res://addons/gut/test.gd"

const MENU_BESTIARIO_SCENE := preload("res://UI/MenuBestiario/MenuBestiario.tscn")
const MESA_CONFIG_SCENE := preload("res://Levels/Nivel_Interior/MesaConfiguracion.tscn")


func test_lista_10_enemigos_datos_completos() -> void:
	# Arrange
	var menu = MENU_BESTIARIO_SCENE.instantiate()
	add_child_autofree(menu)
	await get_tree().process_frame

	# Act & Assert
	assert_eq(menu.enemigos.size(), 10, "El bestiario debe contener exactamente 10 enemigos")

	var nombres_esperados: Array[String] = [
		"Imp Embajador",
		"Imp",
		"Arquera Goblin",
		"Imp Escudera",
		"Ballestero Goblin",
		"Guardiana Moradita",
		"Goblin Rosada",
		"Gargola",
		"Globo Aerostático",
		"Arquera Lonko"
	]

	for i in range(10):
		var e: Dictionary = menu.enemigos[i]
		assert_eq(e.get("numero"), i + 1, "El número de orden debe coincidir con su posición (1 a 10)")
		assert_eq(e.get("nombre"), nombres_esperados[i], "El nombre del enemigo debe coincidir con la lista oficial")
		assert_false(str(e.get("hp", "")).is_empty(), "HP no debe estar vacío")
		assert_false(str(e.get("att", "")).is_empty(), "ATT no debe estar vacío")
		assert_false(str(e.get("item", "")).is_empty(), "ITEM no debe estar vacío")
		assert_false(str(e.get("descripcion", "")).is_empty(), "La descripción no debe estar vacía")
		assert_false(str(e.get("imagen_path", "")).is_empty(), "La ruta de imagen asignada no debe estar vacía")

	# Verificación de datos específicos
	assert_eq(menu.enemigos[0].get("hp"), "6", "Imp Embajador debe tener HP 6")
	assert_eq(menu.enemigos[5].get("hp"), "10", "Guardiana Moradita debe tener HP 10")
	assert_eq(menu.enemigos[5].get("item"), "Poción curativa", "Guardiana Moradita debe tener poción curativa")
	assert_eq(menu.enemigos[8].get("hp"), "3", "Globo Aerostático debe tener HP 3")
	assert_eq(menu.enemigos[9].get("hp"), "5", "Arquera Lonko debe tener HP 5")


func test_menu_bestiario_instanciacion_y_botones() -> void:
	# Arrange
	var menu = MENU_BESTIARIO_SCENE.instantiate()
	add_child_autofree(menu)
	await get_tree().process_frame

	# Assert
	assert_false(menu.visible, "El menú debe iniciar oculto")
	assert_eq(menu.botones_enemigos.size(), 10, "Deben generarse 10 botones en la lista del pergamino")


func test_abrir_y_seleccionar_enemigos() -> void:
	# Arrange
	var menu = MENU_BESTIARIO_SCENE.instantiate()
	add_child_autofree(menu)
	await get_tree().process_frame

	# Act: Abrir menú
	menu.abrir()

	# Assert
	assert_true(menu.visible, "El menú debe ser visible tras abrir()")
	assert_eq(menu.lbl_nombre_enemigo.text, "IMP EMBAJADOR", "El primer enemigo seleccionado por defecto debe ser Imp Embajador")
	assert_eq(menu.lbl_val_numero.text, "N° 1")
	assert_eq(menu.lbl_val_hp.text, "6")
	assert_eq(menu.lbl_val_att.text, "1")
	assert_eq(menu.lbl_val_item.text, "Disparo múltiple")

	# Act: Seleccionar Guardiana Moradita (índice 5)
	menu.seleccionar_enemigo(5)

	# Assert
	assert_eq(menu.lbl_nombre_enemigo.text, "GUARDIANA MORADITA")
	assert_eq(menu.lbl_val_numero.text, "N° 6")
	assert_eq(menu.lbl_val_hp.text, "10")
	assert_eq(menu.lbl_val_item.text, "Poción curativa")
	assert_true(menu.lbl_descripcion.text.contains("bastión"), "La descripción de la Guardiana debe actualizarse")

	# Act: Seleccionar Arquera Lonko (índice 9)
	menu.seleccionar_enemigo(9)

	# Assert
	assert_eq(menu.lbl_nombre_enemigo.text, "ARQUERA LONKO")
	assert_eq(menu.lbl_val_numero.text, "N° 10")
	assert_eq(menu.lbl_val_hp.text, "5")
	assert_eq(menu.lbl_val_item.text, "Flecha explosiva")
	assert_true(menu.lbl_descripcion.text.contains("aturdimiento"), "Debe mencionar el estado aturdimiento")
	assert_true(menu.lbl_descripcion.text.contains("El ataque especial no provoca daño a las defensoras"), "Debe aclarar que no daña a las defensoras")


func test_placeholder_retrato_cuando_no_hay_imagen() -> void:
	# Arrange
	var menu = MENU_BESTIARIO_SCENE.instantiate()
	add_child_autofree(menu)
	await get_tree().process_frame

	# Act: Probar con un enemigo sin imagen
	var idx_sin_imagen: int = -1
	for i in range(menu.enemigos.size()):
		var p: String = menu.enemigos[i].get("imagen_path", "")
		if not ResourceLoader.exists(p):
			idx_sin_imagen = i
			break

	if idx_sin_imagen != -1:
		menu.abrir()
		menu.seleccionar_enemigo(idx_sin_imagen)
		assert_true(menu.placeholder_retrato.visible, "El placeholder debe ser visible si no hay imagen PNG cargada")
	else:
		menu.enemigos[0]["imagen_path"] = "res://UI/MenuBestiario/Portraits/inexistente.png"
		menu.abrir()
		menu.seleccionar_enemigo(0)
		assert_true(menu.placeholder_retrato.visible, "El placeholder debe ser visible si no hay imagen PNG cargada")


func test_retrato_cuando_imagen_existe() -> void:
	# Arrange
	var menu = MENU_BESTIARIO_SCENE.instantiate()
	add_child_autofree(menu)
	await get_tree().process_frame

	# Act: Seleccionar Imp Embajador (índice 0, cuya imagen ya existe en Portraits)
	menu.abrir()
	menu.seleccionar_enemigo(0)

	# Assert
	if ResourceLoader.exists("res://UI/MenuBestiario/Portraits/imp_embajador.png"):
		assert_true(menu.tex_retrato_enemigo.visible, "El TextureRect debe ser visible cuando la imagen existe")
		assert_false(menu.placeholder_retrato.visible, "El placeholder debe ocultarse cuando la imagen existe")


func test_cerrar_menu_emite_senal() -> void:
	# Arrange
	var menu = MENU_BESTIARIO_SCENE.instantiate()
	add_child_autofree(menu)
	await get_tree().process_frame

	watch_signals(menu)
	menu.abrir()

	# Act
	menu.cerrar()
	await wait_seconds(0.25)

	# Assert
	assert_signal_emitted(menu, "cerrado", "El menú debe emitir la señal 'cerrado' al salir")
	assert_false(menu.visible, "El menú debe quedar invisible al cerrarse")


func test_integracion_con_mesa_configuracion() -> void:
	# Arrange
	var mesa = MESA_CONFIG_SCENE.instantiate()
	add_child_autofree(mesa)
	await get_tree().process_frame

	# Assert: MenuBestiario existe en la mesa
	assert_not_null(mesa.menu_bestiario, "MesaConfiguracion debe tener referencia a MenuBestiario")
	assert_false(mesa.menu_bestiario.visible, "MenuBestiario debe iniciar oculto")

	# Act: Presionar botón Bestiario
	mesa._on_btn_bestiario_pressed()

	# Assert
	assert_true(mesa.menu_bestiario.visible, "Presionar botón Bestiario debe abrir el MenuBestiario")
