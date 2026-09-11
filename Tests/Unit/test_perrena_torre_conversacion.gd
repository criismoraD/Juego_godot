extends GutTest

## Conversación "[E] Hablar" con Perrena en la torre (PerrenaNPCInterior).
## Menú con 4 opciones (asalto / civiles / consejos / salir) navegable
## con W/S, diálogos como el de la cinemática (DialogoComic dual) y
## consejos sin repetición con relleno mezclado al agotarse.

const ESCENA_NIVEL: PackedScene = preload("res://Levels/Player_Interior.tscn")
const RUTA_CSV_TRADUCCIONES := "res://Translations/translations.csv"


func _obtener_npc(nivel: Node) -> PerrenaNPCInterior:
	return nivel.find_child("PerrenaNPC", true, false) as PerrenaNPCInterior


func _instanciar_nivel() -> Node:
	var nivel: Node = ESCENA_NIVEL.instantiate()
	add_child_autofree(nivel)
	await get_tree().process_frame
	return nivel


func _leer_csv() -> String:
	var archivo := FileAccess.open(RUTA_CSV_TRADUCCIONES, FileAccess.READ)
	if archivo == null:
		return ""
	return archivo.get_as_text()


func _teletransportar_jugador(nivel: Node, destino: Vector3) -> PlayerInterior:
	var jugador := nivel.get_tree().get_first_node_in_group("player_interior") as PlayerInterior
	if jugador:
		jugador.global_position = destino
	return jugador


func test_interior_crea_prompt_y_menu_hablar() -> void:
	# Arrange
	var nivel := await _instanciar_nivel()
	var npc := _obtener_npc(nivel)
	assert_not_null(npc, "El interior tiene el NPC Perrena")

	# Act
	var prompt := nivel.find_child("PromptHablar", true, false) as Label3D
	var menu := nivel.find_child("MenuConversacionPerrena", true, false) as CanvasLayer
	var prompt_mesa := nivel.find_child("PromptE", true, false) as Label3D

	# Assert: existen, el prompt arranca oculto y el menú cerrado.
	assert_not_null(prompt, "Existe el prompt sobre Perrena")
	assert_not_null(menu, "Existe el menú de conversación")
	assert_true(prompt.is_inside_tree(), "El prompt está en el árbol")
	assert_true(menu.is_inside_tree(), "El menú entra al árbol (add diferido)")
	assert_false(menu.visible, "El menú arranca cerrado")
	assert_true(not prompt.visible or prompt.modulate.a == 0.0, "El prompt arranca oculto")
	assert_true(String(prompt.text).begins_with("[E] "), "El prompt es '[E] Hablar': %s" % prompt.text)

	# Assert: clon exacto del PromptE del mueble (blanco, misma fuente y contorno para visibilidad).
	assert_not_null(prompt_mesa, "Existe el prompt del mueble para comparar")
	assert_eq(prompt.font_size, prompt_mesa.font_size, "Misma fuente que el mueble (20)")
	assert_almost_eq(prompt.pixel_size, prompt_mesa.pixel_size, 0.00001, "Mismo pixel_size que el mueble (0.0011)")
	assert_eq(prompt.outline_size, prompt_mesa.outline_size, "Mismo contorno que el mueble (4)")
	assert_eq(prompt.billboard, prompt_mesa.billboard, "Mismo billboard que el mueble")
	assert_true(prompt.global_position.y > npc.global_position.y + 0.1, "El prompt está sobre su cabeza")
	var plano := Vector2(prompt.global_position.x, prompt.global_position.z) - Vector2(npc.global_position.x, npc.global_position.z)
	assert_true(plano.length() < 0.15, "El prompt está en su vertical")


func test_prompt_sigue_la_cabeza_donde_este_el_npc() -> void:
	# Arrange
	var nivel := await _instanciar_nivel()
	var npc := _obtener_npc(nivel)
	npc.global_position = Vector3(1.0, 0.2, -0.5)

	# Act
	npc._seguir_cabeza_prompt()

	# Assert: clavado sobre su cabeza aunque se mueva el nodo en el editor.
	assert_true(npc._prompt_hablar.global_position.y > npc.global_position.y + 0.1, "El prompt está sobre su cabeza")
	assert_almost_eq(npc._prompt_hablar.global_position.x, npc.global_position.x, 0.05, "El prompt sigue a Perrena en X")
	assert_almost_eq(npc._prompt_hablar.global_position.z, npc.global_position.z, 0.05, "El prompt sigue a Perrena en Z")


func test_radio_cubre_el_corral() -> void:
	# Arrange
	var nivel := await _instanciar_nivel()
	var npc := _obtener_npc(nivel)

	# Act & Assert: radio amplio para hablar desde fuera del corral.
	assert_true(
		npc.RADIO_INTERACCION >= 0.8 and npc.RADIO_INTERACCION <= 1.2,
		"Radio amplio para hablar desde fuera del corral: %s" % npc.RADIO_INTERACCION
	)


func test_cerca_activa_prompt() -> void:
	# Arrange
	var nivel := await _instanciar_nivel()
	var npc := _obtener_npc(nivel)
	var jugador := _teletransportar_jugador(nivel, npc.global_position + Vector3(0.3, 0.0, 0.0))
	assert_not_null(jugador, "El jugador interior existe")

	# Act: a 0.3 m (pegado a ella, como en juego) se evalúa proximidad.
	npc._actualizar_proximidad()

	# Assert
	assert_true(npc._jugador_cerca, "Pegado a Perrena hay proximidad")
	assert_true(npc._prompt_hablar.visible, "El prompt se muestra sobre ella")


func test_lejos_desactiva_y_cierra_menu() -> void:
	# Arrange
	var nivel := await _instanciar_nivel()
	var npc := _obtener_npc(nivel)
	npc._jugador_cerca = true
	npc._abrir_menu_conversacion()
	assert_true(npc._menu_abierto, "Precondición: menú abierto")
	_teletransportar_jugador(nivel, npc.global_position + Vector3(5.0, 0.0, 5.0))

	# Act: a ~7 m se evalúa proximidad.
	npc._actualizar_proximidad()

	# Assert: se pierde proximidad y el menú se cierra con movimiento libre.
	assert_false(npc._jugador_cerca, "Lejos no hay proximidad")
	assert_false(npc._menu_abierto, "Al alejarse se cierra el menú")

	# Act: esperar el fundido y comprobar que el prompt se oculta.
	await get_tree().create_timer(0.5).timeout
	assert_false(npc._prompt_hablar.visible, "Lejos se oculta el prompt")


func test_menu_tiene_cuatro_opciones_con_salir() -> void:
	# Arrange
	var nivel := await _instanciar_nivel()
	var npc := _obtener_npc(nivel)

	# Act
	var botones: Array[Button] = npc._botones_opciones

	# Assert: 3 temas + Salir al final, sin flechas.
	assert_eq(botones.size(), 4, "Tres opciones y Salir")
	assert_eq(npc.OPCIONES_CLAVES.size(), 4, "Cuatro claves de opción")
	assert_eq(npc.OPCIONES_CLAVES[3], "MENU_SALIR", "La última es Salir")
	for boton in botones:
		assert_false(String(boton.text).begins_with("▶ "), "Opción sin flecha: %s" % boton.text)


func test_opcion_salir_cierra_menu() -> void:
	# Arrange
	var nivel := await _instanciar_nivel()
	var npc := _obtener_npc(nivel)
	var jugador := get_tree().get_first_node_in_group("player_interior") as PlayerInterior
	if jugador == null:
		return
	npc._jugador_cerca = true
	npc._abrir_menu_conversacion()
	assert_true(npc._menu_abierto, "Precondición: menú abierto")

	# Act: elegir Salir (índice 3).
	npc._on_opcion_conversacion(3)

	# Assert: menú cerrado y movimiento devuelto.
	assert_false(npc._menu_abierto, "Salir cierra el menú")
	assert_true(jugador.puede_moverse, "Salir devuelve el movimiento")


func test_menu_navegable_con_w_s_y_vuelta() -> void:
	# Arrange
	var nivel := await _instanciar_nivel()
	var npc := _obtener_npc(nivel)
	npc._jugador_cerca = true
	npc._abrir_menu_conversacion()
	var botones: Array[Button] = npc._botones_opciones

	# Act & Assert: abrir deja el foco en la primera.
	assert_eq(npc._opcion_foco, 0, "Arranca en la primera opción")
	assert_eq(nivel.get_viewport().gui_get_focus_owner(), botones[0], "Foco en la primera")

	# Act: S baja, W sube.
	npc._mover_foco(1)
	assert_eq(npc._opcion_foco, 1, "S baja a la segunda")
	assert_eq(nivel.get_viewport().gui_get_focus_owner(), botones[1], "Foco en la segunda")
	npc._mover_foco(-1)
	assert_eq(npc._opcion_foco, 0, "W vuelve a la primera")

	# Act: vuelta por los extremos.
	npc._mover_foco(-1)
	assert_eq(npc._opcion_foco, 3, "W en la primera da la vuelta a Salir")
	assert_eq(nivel.get_viewport().gui_get_focus_owner(), botones[3], "Foco en Salir")
	npc._mover_foco(1)
	assert_eq(npc._opcion_foco, 0, "S en Salir da la vuelta a la primera")


func test_e_activa_la_opcion_seleccionada() -> void:
	# Arrange
	var nivel := await _instanciar_nivel()
	var npc := _obtener_npc(nivel)
	npc._jugador_cerca = true
	npc._abrir_menu_conversacion()

	# Act: bajar a Salir y activar con E.
	npc._mover_foco(-1)
	assert_eq(npc._opcion_foco, 3, "Selección en Salir")
	npc._activar_foco()

	# Assert: se cerró sin abrir diálogo.
	assert_false(npc._menu_abierto, "E en Salir cierra el menú")
	assert_false(npc._dialogo_activo, "Salir no abre diálogo")


func test_mouse_roba_foco_una_sola_marca() -> void:
	# Arrange
	var nivel := await _instanciar_nivel()
	var npc := _obtener_npc(nivel)
	npc._jugador_cerca = true
	npc._abrir_menu_conversacion()
	var botones: Array[Button] = npc._botones_opciones

	# Act: teclado a la 2ª, luego el ratón entra en la 4ª (Salir).
	npc._mover_foco(1)
	assert_eq(nivel.get_viewport().gui_get_focus_owner(), botones[1], "Teclado marca la 2ª")
	npc._on_mouse_entra_opcion(3)

	# Assert: el foco (única marca) pasó al ratón: prioridad último input.
	assert_eq(npc._opcion_foco, 3, "El ratón roba la selección")
	assert_eq(nivel.get_viewport().gui_get_focus_owner(), botones[3], "Una sola opción marcada: la última")

	# Act: el teclado vuelve a mandar (W/S re-roba el foco).
	npc._mover_foco(-1)
	assert_eq(nivel.get_viewport().gui_get_focus_owner(), botones[2], "El teclado recupera la marca")


func test_menu_muestra_icono_perrena_en_vez_del_nombre() -> void:
	# Arrange
	var nivel := await _instanciar_nivel()
	var npc := _obtener_npc(nivel)

	# Act
	var icono := nivel.find_child("IconoPerrena", true, false) as TextureRect

	# Assert: icono centrado con textura, sin título de texto.
	assert_not_null(icono, "El menú muestra el icono de Perrena")
	assert_not_null(icono.texture, "El icono trae textura")
	assert_eq(icono.size_flags_horizontal, Control.SIZE_SHRINK_CENTER, "Icono centrado")
	assert_null(nivel.find_child("TituloMenu", true, false), "Ya no hay título de texto")

	# Assert: el icono corona el menú y sobresale medio cuerpo del marco.
	var caja := icono.get_parent() as VBoxContainer
	assert_not_null(caja, "El icono vive en la caja del menú")
	assert_eq(caja.get_child(0), icono, "El icono va primero, sobre las opciones")
	var margen := caja.get_parent() as MarginContainer
	assert_not_null(margen, "Existe el margen del panel")
	assert_eq(margen.get_theme_constant("margin_top"), -int(npc.SUBIDA_ICONO), "El borde corta el tercio superior del icono")
	assert_true(npc.TAMANO_ICONO_MENU >= 270.0, "Icono grande como el mockup: %s" % npc.TAMANO_ICONO_MENU)
	assert_true(icono.custom_minimum_size.y < icono.custom_minimum_size.x, "Rectángulo al aspecto del png, sin bandas negras")


func test_salir_iluminado_rebota_el_icono() -> void:
	# Arrange
	var nivel := await _instanciar_nivel()
	var npc := _obtener_npc(nivel)
	npc._jugador_cerca = true
	npc._abrir_menu_conversacion()

	# Act: foco en una opción normal (sin rebote).
	npc._on_foco_opcion(0)

	# Assert: sin tween de rebote en marcha.
	var rebotando_antes := npc._tween_icono != null and npc._tween_icono.is_valid() and npc._tween_icono.is_running()
	assert_false(rebotando_antes, "Sin rebote fuera de Salir")

	# Act: iluminar SALIR (última opción, con W/S, ratón o foco).
	npc._on_foco_opcion(npc.OPCIONES_CLAVES.size() - 1)

	# Assert: el icono rebota con deformación elástica.
	assert_true(npc._tween_icono != null and npc._tween_icono.is_valid(), "Arranca el rebote del icono")
	assert_true(npc._tween_icono.is_running(), "El rebote está en marcha")


func test_dialogo_asalto_cuatro_paginas_con_orden() -> void:
	# Arrange
	var nivel := await _instanciar_nivel()
	var npc := _obtener_npc(nivel)

	# Act & Assert: Perrena x2, Eryn, Perrena (río / inmediato / pertrechos / carne).
	assert_eq(npc.DIALOGO_ASALTO_PAGINAS.size(), 4, "El plan de asalto tiene 4 páginas")
	assert_eq(
		Array(npc.DIALOGO_ASALTO_HABLANTES),
		["perrena", "perrena", "eryn", "perrena"],
		"Orden de hablantes del asalto"
	)


func test_dialogo_civiles_dos_paginas_de_perrena() -> void:
	# Arrange
	var nivel := await _instanciar_nivel()
	var npc := _obtener_npc(nivel)

	# Act & Assert: gremio atrapado (turbantes/mochilas) + favores, ambas de Perrena.
	assert_eq(npc.DIALOGO_CIVILES_PAGINAS.size(), 2, "Sobre los civiles tiene 2 páginas")
	assert_eq(
		Array(npc.DIALOGO_CIVILES_HABLANTES),
		["perrena", "perrena"],
		"Ambas páginas las dice Perrena"
	)


func test_consejos_ocho_claves_distintas() -> void:
	# Arrange
	var nivel := await _instanciar_nivel()
	var npc := _obtener_npc(nivel)
	assert_eq(npc.CONSEJOS_CLAVES.size(), 8, "La lista de consejos tiene 8 entradas")

	# Act: pedir los 8 seguidos (una vuelta completa de la cola).
	var vistos: Array = []
	for i in 8:
		vistos.append(npc.obtener_siguiente_consejo())

	# Assert: 8 claves distintas, todas de la lista (sin repetición).
	var unicos := {}
	for clave in vistos:
		unicos[clave] = true
		assert_true(npc.CONSEJOS_CLAVES.has(clave), "Consejo de la lista: %s" % clave)
	assert_eq(unicos.size(), 8, "Los 8 consejos salen sin repetirse: %s" % [vistos])


func test_consejos_se_rellenan_al_agotarse() -> void:
	# Arrange
	var nivel := await _instanciar_nivel()
	var npc := _obtener_npc(nivel)

	# Act: 16 peticiones (dos vueltas completas).
	var conteo := {}
	for i in 16:
		var clave := npc.obtener_siguiente_consejo()
		conteo[clave] = int(conteo.get(clave, 0)) + 1

	# Assert: cada consejo salió exactamente 2 veces (relleno tras agotar).
	assert_eq(conteo.size(), 8, "Tras 16 peticiones se vieron los 8 consejos")
	for clave in npc.CONSEJOS_CLAVES:
		assert_eq(int(conteo.get(clave, 0)), 2, "El consejo %s sale una vez por vuelta" % clave)


func test_claves_existen_en_csv_con_texto_es() -> void:
	# Arrange & Act
	var csv := _leer_csv()

	# Assert
	assert_false(csv.is_empty(), "El CSV de traducciones se puede leer")
	for clave in [
		"PERRENA_PROMPT_HABLAR",
		"PERRENA_OPCION_ASALTO", "PERRENA_OPCION_CIVILES", "PERRENA_OPCION_CONSEJOS",
		"PERRENA_ASALTO_1", "PERRENA_ASALTO_2", "PERRENA_ASALTO_3", "PERRENA_ASALTO_4",
		"PERRENA_CIVILES_1", "PERRENA_CIVILES_2",
		"PERRENA_CONSEJO_1", "PERRENA_CONSEJO_2", "PERRENA_CONSEJO_3", "PERRENA_CONSEJO_4",
		"PERRENA_CONSEJO_5", "PERRENA_CONSEJO_6", "PERRENA_CONSEJO_7", "PERRENA_CONSEJO_8",
	]:
		assert_true(csv.contains(clave), "La clave %s está registrada" % clave)
	for texto in [
		"Plan de asalto",
		"río para evitar ser emboscadas",
		"turbantes y grandes mochilas",
		"no te hagas el muerto",
		"apuéstale todo al rojo",
	]:
		assert_true(csv.contains(texto), "El texto español existe: %s" % texto)


func test_opcion_invalida_no_abre_dialogo() -> void:
	# Arrange
	var nivel := await _instanciar_nivel()
	var npc := _obtener_npc(nivel)

	# Act: índices fuera de rango (límite inferior y superior).
	npc._on_opcion_conversacion(-1)
	npc._on_opcion_conversacion(99)

	# Assert: no se abrió ningún diálogo ni se bloqueó nada.
	assert_false(npc._dialogo_activo, "Opción inválida no abre diálogo")


func test_mesa_cerrada_no_bloquea_conversacion() -> void:
	# Arrange
	var nivel := await _instanciar_nivel()
	var npc := _obtener_npc(nivel)

	# Act & Assert: con la mesa cerrada, Perrena puede abrir su menú.
	assert_false(npc._mesa_menu_abierto(), "Mesa cerrada: no bloquea a Perrena")


func test_menu_abre_y_cierra_bloqueando_movimiento() -> void:
	# Arrange
	var nivel := await _instanciar_nivel()
	var npc := _obtener_npc(nivel)
	var jugador := get_tree().get_first_node_in_group("player_interior") as PlayerInterior
	assert_not_null(jugador, "El jugador interior existe")
	if jugador == null:
		return
	npc._jugador_cerca = true

	# Act: abrir con E.
	npc._abrir_menu_conversacion()

	# Assert: menú visible, jugador quieto y prompt oculto.
	assert_true(npc._menu_abierto, "El menú quedó abierto")
	assert_true(npc._menu_conversacion.visible, "El menú es visible")
	assert_false(jugador.puede_moverse, "El jugador se queda quieto en el menú")

	# Act: cerrar.
	npc._cerrar_menu_conversacion()

	# Assert: todo restaurado.
	assert_false(npc._menu_abierto, "El menú quedó cerrado")
	assert_false(npc._menu_conversacion.visible, "El menú se oculta")
	assert_true(jugador.puede_moverse, "El jugador recupera el movimiento")


func test_jugadora_aparece_abajo_mirando_al_fondo() -> void:
	# Arrange
	var nivel := await _instanciar_nivel()
	var jugador := get_tree().get_first_node_in_group("player_interior") as PlayerInterior
	assert_not_null(jugador, "El jugador interior existe")
	if jugador == null:
		return

	# Act & Assert: aparece abajo-centro (entrada) a la altura del suelo.
	assert_almost_eq(jugador.global_position.x, 0.0, 0.02, "Centrada en X")
	assert_almost_eq(jugador.global_position.z, 0.3, 0.02, "Junto a la puerta sur")

	# Act & Assert: mira al fondo (norte, -z): el giro vive en el modelo,
	# el cuerpo queda sin rotar para no romper el giro por movimiento.
	var modelo := jugador.find_child("ArqueraModel", true, false) as Node3D
	assert_not_null(modelo, "Existe el modelo de la arquera")
	assert_almost_eq(absf(wrapf(modelo.rotation.y, -PI, PI)), PI, 0.05, "Modelo mirando al fondo")
	assert_almost_eq(absf(wrapf(jugador.rotation.y, -PI, PI)), 0.0, 0.05, "Cuerpo sin rotar")


func test_opcion_dialogo_suena_seleccion_menu() -> void:
	# Arrange
	var nivel := await _instanciar_nivel()
	var npc := _obtener_npc(nivel)
	var am = get_tree().root.get_node_or_null("AudioManager")
	assert_not_null(am, "Precondición: AudioManager disponible")
	var esperados: Array = am.sfx_streams["seleccion_menu"]
	assert_false(esperados.is_empty(), "seleccion_menu registrado con audio")
	npc._jugador_cerca = true
	npc._abrir_menu_conversacion()

	# Act: pulsar la primera opción (abre diálogo).
	npc._on_opcion_conversacion(0)

	# Assert: suena selección (no el de salida).
	var suena := false
	for p in am.sfx_pool:
		if p.playing and p.stream != null and p.stream in esperados:
			suena = true
			break
	assert_true(suena, "Pulsar opción suena seleccion_menu")

	# Cleanup: cerrar el diálogo para no dejar nodos colgados.
	var ancla: Node = get_tree().current_scene if get_tree().current_scene else nivel
	var dialogo := ancla.find_child("DialogoConversacionNivel5", true, false)
	if dialogo:
		dialogo.emit_signal("continuado")
		await get_tree().process_frame
		await get_tree().process_frame
	assert_true(dialogo == null or not is_instance_valid(dialogo), "Diálogo liberado")


func test_abrir_menu_suena_seleccion_menu() -> void:
	# Arrange
	var nivel := await _instanciar_nivel()
	var npc := _obtener_npc(nivel)
	var am = get_tree().root.get_node_or_null("AudioManager")
	assert_not_null(am, "Precondición: AudioManager disponible")
	npc._jugador_cerca = true

	# Act: abrir el menú de Perrena.
	npc._abrir_menu_conversacion()

	# Assert: suena selección al entrar.
	var esperados: Array = am.sfx_streams["seleccion_menu"]
	var suena := false
	for p in am.sfx_pool:
		if p.playing and p.stream != null and p.stream in esperados:
			suena = true
			break
	assert_true(suena, "Abrir el menú suena seleccion_menu")
