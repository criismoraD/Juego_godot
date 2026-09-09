extends GutTest

## Tests de la cinemática de fin de oleada 5 (sustituye a la cortinilla negra).
## Se usa un nivel falso con cámaras mínimas y protagonistas reales; la
## secuencia se avanza manualmente para no depender del tiempo real.

const CINE: GDScript = preload("res://Levels/NIVEL01/CinematicaOleada5.gd")


class NivelFalso extends Node:
	var bloqueos: Array = []
	var combate: Array = []
	var estados: Dictionary = {}
	var game_ui = null
	var wave_spawner = null
	var dialogo_mostrado := false
	var _aliadas_activas := true

	func _set_movimiento_jugador_bloqueado(bloqueado: bool) -> void:
		bloqueos.append(bloqueado)
		for p in get_tree().get_nodes_in_group("player"):
			var id_jugador: int = p.get_instance_id()
			if bloqueado:
				if not estados.has(id_jugador):
					estados[id_jugador] = [p.is_processing(), p.is_physics_processing()]
				p.set_process(false)
				p.set_physics_process(false)
			else:
				var e: Array = estados.get(id_jugador, [true, true])
				p.set_process(e[0])
				p.set_physics_process(e[1])
		if not bloqueado:
			estados.clear()

	func _set_aliadas_modo_pacifico() -> void:
		combate.append("pacifico")

	func _set_aliadas_activas(activas: bool) -> void:
		combate.append(activas)

	func _mostrar_dialogo_escena(_a, _b, _c, _d, _e, _f, _g) -> void:
		dialogo_mostrado = true


class SpawnerFalso extends Node:
	var detenido := false

	func detener_spawning() -> void:
		detenido = true


func _avanzar_hasta_fin(cine) -> bool:
	# La fase DIALOGO espera al jugador: cede frames reales para que el
	# await de la escena se resuelva; el resto avanza sin tiempo real.
	# Al entrar a la torre el nodo se libera: no tocarlo tras eso.
	var pasos := 0
	while is_instance_valid(cine) and pasos < 250:
		if cine.terminada:
			return true
		if cine._fase == CINE.Fase.DIALOGO:
			await get_tree().process_frame
		else:
			cine._process(0.25)
		pasos += 1
	return is_instance_valid(cine) and cine.terminada


## Primera Perrena de todo el árbol (como la busca la escena para
## reutilizarla; puede vivir fuera del nivel en tests).
func _primera_perrena() -> Perrena:
	var pila: Array[Node] = [get_tree().root]
	while not pila.is_empty():
		var actual: Node = pila.pop_back()
		if actual is Perrena:
			return actual as Perrena
		pila.append_array(actual.get_children())
	return null


func _ancho_contorno_perrena(per) -> float:
	for m in per.find_children("*", "MeshInstance3D", true, false):
		if (m as Node).name == "Perrena":
			var base := (m as MeshInstance3D).material_override as StandardMaterial3D
			if base:
				var sm := base.next_pass as ShaderMaterial
				if sm:
					return float(sm.get_shader_parameter("outline_width"))
	return -1.0


func _existe_jingle(nivel: Node) -> bool:
	for m in nivel.find_children("*", "AudioStreamPlayer", true, false):
		if (m as Node).name == "JinglePerrenaCine":
			return true
	return false


func _pies_min(personaje: Node) -> float:
	var skel := personaje.find_child("Skeleton3D", true, false) as Skeleton3D
	var il: int = skel.find_bone("mixamorig_LeftFoot")
	var ir: int = skel.find_bone("mixamorig_RightFoot")
	var pl: Vector3 = skel.global_transform * skel.get_bone_global_pose(il).origin
	var pr: Vector3 = skel.global_transform * skel.get_bone_global_pose(ir).origin
	return minf(pl.y, pr.y)


func _crear_camaras(nivel: Node) -> Array[Camera3D]:
	var cams: Array[Camera3D] = []
	for ruta in [
		"SubViewportFrente3D/CamaraFrente",
		"SubViewportMedio3D/CamaraMedio",
		"SubViewportFondo3D/CamaraFondoDOF"
	]:
		var partes: PackedStringArray = ruta.split("/")
		var padre := nivel.get_node_or_null(partes[0])
		if padre == null:
			# SubViewport real con FXAA como en juego (también sirve al
			# test de parpadeo de bordes PNG).
			padre = SubViewport.new()
			padre.name = partes[0]
			(padre as SubViewport).screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			nivel.add_child(padre)
		var cam := Camera3D.new()
		cam.name = partes[1]
		cam.projection = Camera3D.PROJECTION_FRUSTUM
		cam.fov = 5.0
		cam.size = 0.01
		cam.position = Vector3(-3.06, 3.26, 40.97)
		padre.add_child(cam)
		cams.append(cam)
	return cams


func _limpiar_regreso() -> void:
	GameUI.regreso_desde_interior_oleada = 0
	GameUI.regreso_conversacion_nivel5 = false
	GameUI.regreso_flechas_explosivas = 0
	GameUI.regreso_flechas_multiples = 0
	GameUI.regreso_municion_activa = 0
	var sm = get_tree().root.get_node_or_null("SceneManager")
	if sm:
		sm.set("posicion_retorno_puerta", Vector3.ZERO)


func _contar_perrenas(nivel: Node) -> int:
	var n := 0
	var pila: Array[Node] = [nivel]
	while not pila.is_empty():
		var actual: Node = pila.pop_back()
		if actual is Perrena:
			n += 1
		pila.append_array(actual.get_children())
	return n


func test_cinematica_oleada5_secuencia_completa() -> void:
	# NIVEL01.gd debe compilar (hook + continuación).
	var scr = load("res://Levels/NIVEL01/NIVEL01.gd")
	assert_not_null(scr, "NIVEL01.gd debe cargar")

	# Arrange: protagonista real en el grupo player.
	var eryn = load("res://Entities/Jugador_Arquera/Player.tscn").instantiate()
	add_child_autofree(eryn)
	await get_tree().process_frame

	var nivel := NivelFalso.new()
	add_child_autofree(nivel)
	# Suelo real bajo la isla (x -6..12, techo y=0): Eryn cae fuera de él
	# (x=-8.35) y usa su fallback; Perrena pisa suelo de verdad.
	var suelo := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(18, 1, 10)
	col.shape = caja
	suelo.add_child(col)
	suelo.position = Vector3(3, -0.5, 0.05)
	nivel.add_child(suelo)
	var cams := _crear_camaras(nivel)
	nivel.wave_spawner = SpawnerFalso.new()
	var marca := {"lista": false}
	var cine = CINE.new()
	nivel.add_child(cine)

	# Act: iniciar y avanzar la secuencia sin tiempo real.
	cine.iniciar(nivel, func(): marca["lista"] = true)
	# Sin cambio de escena en tests (la torre es real en juego).
	cine.entrada_torre_habilitada = false

	# Assert: suena el ambiente del bosque, sin música.
	var pista := AudioManager.get_music_player().stream as AudioStream
	assert_not_null(pista, "Debe sonar el ambiente durante la cinemática")
	assert_true(String(pista.resource_path).ends_with("SONIDO BOSQUE.mp3"), "Ambiente del bosque en la cinemática, fue %s" % pista.resource_path)

	var termino: bool = await _avanzar_hasta_fin(cine)

	# Assert: termina, bloquea el input y registra la entrada a la torre
	# (la oleada 6 espera al regreso del interior, no continúa aquí).
	assert_true(termino, "La cinemática debe terminar")
	assert_false(marca["lista"], "Sin torre no hay continuación directa")
	assert_eq(nivel.bloqueos, [true], "Bloquea al empezar (libera la oleada 6)")
	assert_true(nivel.dialogo_mostrado, "Se muestra el diálogo al llegar al límite")
	assert_eq(GameUI.regreso_desde_interior_oleada, 5, "Registra el regreso")
	assert_true(GameUI.regreso_conversacion_nivel5, "Marca el interludio conversado")
	var sm = get_tree().root.get_node_or_null("SceneManager")
	if sm:
		assert_almost_eq((sm.get("posicion_retorno_puerta") as Vector3).x, -8.35, 0.4, "Retorno en el segundo piso")
	_limpiar_regreso()

	# Assert: UNA sola Perrena, con el tamaño de la controlable, al límite.
	assert_eq(_contar_perrenas(nivel), 1, "Solo debe existir una Perrena")
	var per = _primera_perrena()
	assert_not_null(per, "Perrena debe haberse instanciado")
	assert_eq(per.scale, eryn.scale, "Mismo tamaño que la controlable")
	assert_almost_eq(per.global_position.x, -5.0, 0.35, "Perrena termina en x=-5.0")
	assert_almost_eq(per.global_position.y, 0.2, 0.5, "Perrena a altura de suelo")
	assert_almost_eq(_pies_min(per), 0.02, 0.12, "Pies de Perrena sobre el terreno")

	# Assert: sin enemigos (spawner detenido) y defensoras en pacífico
	# (siguen así: la escena muere al entrar a la torre, sin restaurar).
	assert_true(nivel.wave_spawner.detenido, "El spawner se detiene en la cinemática")
	assert_eq(nivel.combate, ["pacifico"], "Defensoras en pacífico")

	# Assert: Eryn queda en el segundo piso tras el escudo.
	assert_almost_eq(eryn.global_position.x, -8.35, 0.35, "Eryn queda en el segundo piso")
	assert_almost_eq(eryn.global_position.y, 3.3, 0.6, "Eryn a altura del segundo piso")
	assert_almost_eq(_pies_min(eryn), 3.32, 0.2, "Pies de Eryn sobre la plataforma")

	# Assert: la cámara queda en el seguimiento final (sin restaurar: hay
	# cambio de escena).
	for cam in cams:
		assert_almost_eq(cam.position.x, -6.2, 0.6, "Encuadre final sobre el límite")


func test_cinematica_reutiliza_perrena_existente() -> void:
	# Arrange: ya hay una Perrena en escena (p. ej. de un cambio anterior).
	var eryn = load("res://Entities/Jugador_Arquera/Player.tscn").instantiate()
	add_child_autofree(eryn)
	var previa = load("res://Entities/Jugador_Perrena/Perrena.tscn").instantiate()
	add_child_autofree(previa)
	await get_tree().process_frame

	var nivel := NivelFalso.new()
	add_child_autofree(nivel)
	# La previa vive fuera del nivel falso: se traslada bajo él para la escena.
	remove_child(previa)
	nivel.add_child(previa)
	var marca := {"lista": false}
	var cine = CINE.new()
	nivel.add_child(cine)

	# Act
	cine.iniciar(nivel, func(): marca["lista"] = true)
	# Sin cambio de escena en tests (la torre es real en juego).
	cine.entrada_torre_habilitada = false
	var termino: bool = await _avanzar_hasta_fin(cine)

	# Assert: no se instancia otra, se reutiliza la existente.
	assert_true(termino, "La cinemática debe terminar")
	assert_true(_primera_perrena() == previa, "Debe reutilizar la Perrena existente")
	assert_eq(_contar_perrenas(nivel), 1, "Sigue habiendo una sola Perrena")
	assert_almost_eq(previa.global_position.x, -5.0, 0.35, "La reutilizada termina en el límite")
	assert_false(marca["lista"], "La oleada 6 espera al regreso")
	assert_true(GameUI.regreso_conversacion_nivel5, "Marca el interludio")
	_limpiar_regreso()


func test_cinematica_bloquea_boton_swap() -> void:
	# Arrange
	var eryn = load("res://Entities/Jugador_Arquera/Player.tscn").instantiate()
	add_child_autofree(eryn)
	await get_tree().process_frame

	var nivel := NivelFalso.new()
	add_child_autofree(nivel)
	var cams := _crear_camaras(nivel)
	var gui := Node.new()
	gui.name = "GameUI"
	nivel.add_child(gui)
	nivel.game_ui = gui
	var btn := Button.new()
	btn.name = "BtnControlarPerrena"
	btn.disabled = false
	gui.add_child(btn)
	var capa := Sprite3D.new()
	capa.name = "CAPA001"
	capa.texture = ImageTexture.create_from_image(Image.create(200, 100, false, Image.FORMAT_RGBA8))
	capa.position = Vector3(1, 2, 30)
	nivel.add_child(capa)
	var marca := {"lista": false}
	var cine = CINE.new()
	nivel.add_child(cine)

	# Act: iniciar y avanzar unos pasos (en plena secuencia).
	cine.iniciar(nivel, func(): marca["lista"] = true)
	# Sin cambio de escena en tests (la torre es real en juego).
	cine.entrada_torre_habilitada = false
	for i in range(8):
		cine._process(0.25)

	# Assert: botón bloqueado durante la escena.
	assert_true(btn.disabled, "El cambio de personaje se bloquea en la cinemática")

	# Assert: la capa de tono sigue a la cámara (morado sin franja de cielo).
	assert_true(capa.visible, "CAPA001 visible en cinemática")
	assert_almost_eq(capa.position.x, cams[0].position.x, 0.3, "La capa sigue a la cámara")
	assert_almost_eq(capa.position.z, cams[0].position.z - 5.0, 0.3, "La capa va delante")
	assert_almost_eq(capa.scale.x, 1.066, 0.08, "La capa cubre el encuadre")

	# Assert: contorno delgado pero visible durante la escena.
	assert_almost_eq(_ancho_contorno_perrena(cine._perrena), 3.0, 0.01, "Contorno delgado en cinemática")

	# Assert: sin arco en la escena.
	var arco = cine._perrena.find_child("ARCO_ANIMADO", true, false)
	assert_not_null(arco, "Existe el nodo del arco")
	assert_false(arco.visible, "Perrena corre sin arco")

	# Assert: sombra falsa apagada (solo la real).
	for s in nivel.find_children("*", "SombraPersonaje", true, false):
		assert_false((s as Node3D).visible, "Sin sombra falsa en cinemática")

	# Assert: ni con clic dispara durante la escena.
	var runner = _primera_perrena()
	assert_not_null(runner, "Hay corredora")
	assert_true(runner.is_shot_locked, "Candado de disparo en la corredora")
	Input.action_press("click_izquierdo")
	runner.control_visual_state(0.5)
	assert_eq(runner.current_aim_state, Player.AimState.NONE, "El clic no inicia disparo")
	Input.action_release("click_izquierdo")

	# Assert: encuadre de la escena (travelling con seguimiento: personajes
	# grandes, agua fuera de campo).
	for cam in cams:
		assert_eq(cam.projection, Camera3D.PROJECTION_FRUSTUM, "Sin cambio de proyección")
		assert_almost_eq(cam.position.z, 23.05, 0.3, "Cámara acercada")
		assert_almost_eq(cam.position.y, 2.2, 0.25, "Agua fuera de campo")
		assert_almost_eq(cam.position.x, 3.0, 0.6, "Siguiendo a la corredora sin salirse del fondo")

	# Act: avanzar hasta que camine y comprobar el jingle.
	var it := 0
	while cine._fase != CINE.Fase.CAMINAR and it < 100:
		cine._process(0.25)
		it += 1
	assert_true(_existe_jingle(nivel), "Suena el jingle al caminar")

	# Act: terminar (la escena muere al entrar a la torre: sin restaurar).
	var termino2: bool = await _avanzar_hasta_fin(cine)

	# Assert: termina y registra la torre (sin continuación directa).
	assert_true(termino2, "La cinemática debe terminar")
	assert_false(marca["lista"], "La oleada 6 espera al regreso")
	assert_eq(GameUI.regreso_desde_interior_oleada, 5, "Registra el regreso")
	assert_true(GameUI.regreso_conversacion_nivel5, "Marca el interludio")
	_limpiar_regreso()
	assert_true(btn.disabled, "El botón sigue bloqueado (muere la escena)")
	assert_almost_eq(_ancho_contorno_perrena(_primera_perrena()), 20.0, 0.01, "Contorno restaurado (recurso compartido)")


func test_cinematica_devuelve_control_si_perrena_era_activa() -> void:
	# Arrange: el jugador controla a Perrena; Eryn aparcada (oculta, sin grupo).
	var activa = load("res://Entities/Jugador_Perrena/Perrena.tscn").instantiate()
	add_child_autofree(activa)
	var eryn = load("res://Entities/Jugador_Arquera/Player.tscn").instantiate()
	add_child_autofree(eryn)
	await get_tree().process_frame
	eryn.remove_from_group("player")
	eryn.visible = false
	eryn.set_physics_process(false)

	var nivel := NivelFalso.new()
	add_child_autofree(nivel)
	var marca := {"lista": false}
	var cine = CINE.new()
	nivel.add_child(cine)

	# Act
	cine.iniciar(nivel, func(): marca["lista"] = true)
	# Sin cambio de escena en tests (la torre es real en juego).
	cine.entrada_torre_habilitada = false
	var termino_era: bool = await _avanzar_hasta_fin(cine)

	# Assert: la misma instancia corre hasta el límite y registra la torre.
	assert_true(termino_era, "La cinemática debe terminar")
	assert_true(_primera_perrena() == activa, "Corre la Perrena que ya controlaba")
	assert_almost_eq(activa.global_position.x, -5.0, 0.35, "Termina en el límite")
	assert_false(marca["lista"], "La oleada 6 espera al regreso")
	assert_true(GameUI.regreso_conversacion_nivel5, "Marca el interludio")
	_limpiar_regreso()


func test_cinematica_mascaras_siguen_camara() -> void:
	# Arrange: protagonista + cámaras + máscaras del compositor visibles.
	var eryn = load("res://Entities/Jugador_Arquera/Player.tscn").instantiate()
	add_child_autofree(eryn)
	await get_tree().process_frame

	var nivel := NivelFalso.new()
	add_child_autofree(nivel)
	var _cams := _crear_camaras(nivel)
	var compositor := Node.new()
	compositor.name = "Compositor3D"
	nivel.add_child(compositor)
	var sombra := ColorRect.new()
	sombra.name = "SombraFalsaRect"
	compositor.add_child(sombra)
	var haces := ColorRect.new()
	haces.name = "LuzHacesFijaRect"
	compositor.add_child(haces)
	var icono := Node3D.new()
	icono.name = "IconoRefuerzo"
	icono.add_to_group("icono_mensajera")
	nivel.add_child(icono)
	var marca := {"lista": false}
	var cine = CINE.new()
	nivel.add_child(cine)

	# Act: iniciar y avanzar unos pasos (travelling en curso).
	cine.iniciar(nivel, func(): marca["lista"] = true)
	# Sin cambio de escena en tests (la torre es real en juego).
	cine.entrada_torre_habilitada = false
	for i in range(4):
		cine._process(0.25)

	# Assert: visibles pero siguiendo a la cámara (no se ocultan).
	assert_true(sombra.visible, "SombraFalsaRect visible en cinemática")
	assert_true(haces.visible, "LuzHacesFijaRect visible en cinemática")
	assert_gt(sombra.scale.x, 1.0, "SombraFalsaRect escala con el zoom")
	assert_ne(sombra.pivot_offset, Vector2.ZERO, "SombraFalsaRect pivota al centro")
	assert_false(icono.visible, "El icono de refuerzo no aparece en la escena")

	# Act: terminar (la escena muere al entrar a la torre: sin restaurar).
	var termino_masc: bool = await _avanzar_hasta_fin(cine)

	# Assert: registra la torre (sin continuación directa).
	assert_true(termino_masc, "La cinemática debe terminar")
	assert_false(marca["lista"], "La oleada 6 espera al regreso")
	assert_true(GameUI.regreso_conversacion_nivel5, "Marca el interludio")
	_limpiar_regreso()


func test_cinematica_aborta_a_continuacion_sin_protagonista() -> void:
	# Arrange: nivel sin nadie en el grupo player.
	var nivel := NivelFalso.new()
	add_child_autofree(nivel)
	var marca := {"lista": false}
	var cine = CINE.new()
	nivel.add_child(cine)

	# Act
	cine.iniciar(nivel, func(): marca["lista"] = true)
	# Sin cambio de escena en tests (la torre es real en juego).
	cine.entrada_torre_habilitada = false

	# Assert: no cuelga el juego, continúa igualmente y no bloquea.
	assert_true(cine.terminada, "Sin protagonista debe abortar marcada como terminada")
	assert_true(marca["lista"], "Abortar debe invocar la continuación igualmente")
	assert_eq(nivel.bloqueos, [], "Sin protagonista no debe bloquear nada")


func test_dialogo_conversacion_nivel5_contenido() -> void:
	# La escena del diálogo existe, usa el sistema del intro, muestra los png
	# de Eryn y Perrena y la conversación completa en 6 parlamentos.
	var escena: PackedScene = load("res://UI/DialogoConversacionNivel5.tscn")
	assert_not_null(escena, "Debe existir DialogoConversacionNivel5.tscn")
	var dlg = escena.instantiate()
	add_child_autofree(dlg)
	await get_tree().process_frame
	assert_true(dlg is DialogoComic, "Usa el sistema de diálogo del intro")
	assert_eq(dlg.paginas_texto.size(), 6, "Seis parlamentos")
	assert_eq(Array(dlg.paginas_hablante), ["eryn", "perrena", "perrena", "eryn", "perrena", "eryn"], "Orden de hablantes")
	assert_true(String(dlg.paginas_texto[0]).contains("identifícate"), "Eryn pide identificarse")
	assert_true(String(dlg.paginas_texto[1]).contains("Mi nombre es Perrena"), "Perrena se presenta")
	assert_true(String(dlg.paginas_texto[3]).contains("guardiana del bosque"), "Eryn se presenta")
	assert_true(String(dlg.paginas_texto[5]).contains("en la torre"), "Cierre hacia la torre")
	assert_not_null(dlg.find_child("RetratoEryn", true, false), "Retrato de Eryn")
	assert_not_null(dlg.find_child("RetratoPerrena", true, false), "Retrato de Perrena")


func _borde_inferior_retrato(retrato: Sprite2D) -> float:
	return retrato.position.y + float(retrato.texture.get_height()) * retrato.scale.y * 0.5


func test_dialogo_dual_resalta_hablante_y_apaga_otro() -> void:
	# Arrange
	var escena: PackedScene = load("res://UI/DialogoConversacionNivel5.tscn")
	var dlg = escena.instantiate()
	add_child_autofree(dlg)
	await get_tree().process_frame
	var eryn_nodo := dlg.find_child("RetratoEryn", true, false) as Node2D
	var perrena_nodo := dlg.find_child("RetratoPerrena", true, false) as Node2D
	assert_not_null(eryn_nodo, "Retrato de Eryn")
	assert_not_null(perrena_nodo, "Retrato de Perrena")

	# Assert página 0 (Eryn): ella plena, Perrena encogida y oscura.
	assert_eq(dlg.find_child("Nombre", true, false).text, "Eryn", "Habla Eryn")
	assert_eq(eryn_nodo.modulate, Color.WHITE, "Eryn plena")
	assert_eq(eryn_nodo.scale, Vector2(0.5853904, 0.5853905), "Eryn a tamaño base")
	assert_lt(perrena_nodo.modulate.r, 0.6, "Perrena oscura")
	assert_lt(perrena_nodo.scale.x, 0.535, "Perrena encogida")
	var borde_eryn: float = _borde_inferior_retrato(eryn_nodo)
	var borde_perrena: float = _borde_inferior_retrato(perrena_nodo)

	# Act: pasar a la página 1 (Perrena).
	dlg._indice_pagina = 1
	dlg._aplicar_pagina_actual()

	# Assert: se invierte el foco pero los bordes inferiores no se mueven.
	assert_eq(dlg.find_child("Nombre", true, false).text, "Perrena", "Habla Perrena")
	assert_eq(perrena_nodo.modulate, Color.WHITE, "Perrena plena")
	assert_lt(eryn_nodo.modulate.r, 0.6, "Eryn oscura")
	assert_lt(eryn_nodo.scale.x, 0.5853904, "Eryn encogida")
	assert_almost_eq(_borde_inferior_retrato(eryn_nodo), borde_eryn, 6.0, "Borde de Eryn anclado")
	assert_almost_eq(_borde_inferior_retrato(perrena_nodo), borde_perrena, 6.0, "Borde de Perrena anclado")


func test_dialogo_intro_sin_dual_igual_que_antes() -> void:
	# El intro no trae retratos duales: sin cambios de comportamiento.
	var escena: PackedScene = load("res://UI/Dialogo_Protagonista.tscn")
	var dlg = escena.instantiate()
	add_child_autofree(dlg)
	await get_tree().process_frame
	assert_null(dlg.find_child("RetratoEryn", true, false), "El intro no tiene duelo")
	assert_null(dlg.find_child("RetratoPerrena", true, false), "El intro no tiene duelo")
	assert_eq(dlg.paginas_texto.size(), 2, "El intro conserva sus 2 páginas")


func test_boton_debug_cinematica_limpia_y_arranca() -> void:
	# Arrange: nivel real con 2 enemigos en pie.
	var nivel = load("res://Levels/NIVEL01/NIVEL01.tscn").instantiate()
	add_child_autofree(nivel)
	await get_tree().process_frame
	await get_tree().process_frame
	var e1 := Node3D.new()
	e1.add_to_group("enemies")
	nivel.add_child(e1)
	var e2 := Node3D.new()
	e2.add_to_group("enemies")
	nivel.add_child(e2)

	# Act: botón "Test Cinemática" (sin matar: sin cadáveres ni efectos).
	nivel._probar_cinematica_oleada5_debug()
	await get_tree().process_frame

	# Assert: limpieza sin rastros y arranque en oleada 5.
	assert_false(is_instance_valid(e1), "Enemigo retirado sin matar")
	assert_false(is_instance_valid(e2), "Enemigo retirado sin matar")
	assert_eq(nivel.oleada_combate_actual, 5, "Oleada fijada en 5")
	var cine = nivel.get_node_or_null("CinematicaOleada5")
	assert_not_null(cine, "Cinemática arrancada")
	# Sin cambio de escena en tests (la torre es real en juego).
	cine.entrada_torre_habilitada = false

	# Act: avanzar cerrando el diálogo como el jugador (Siguiente/Saltar).
	# El nodo se libera al entrar a la torre: no tocarlo tras eso.
	var termino_btn: bool = false
	var pasos := 0
	while is_instance_valid(cine) and pasos < 300:
		if cine.terminada:
			termino_btn = true
			break
		if cine._fase == CINE.Fase.DIALOGO:
			var dlg = nivel.find_child("DialogoConversacionNivel5", true, false)
			assert_not_null(dlg, "Diálogo visible al llegar")
			dlg.emit_signal("continuado")
			await get_tree().process_frame
		else:
			cine._process(0.25)
		pasos += 1
	if not is_instance_valid(cine):
		termino_btn = true

	# Assert: termina y registra la entrada a la torre (la oleada 6 espera).
	assert_true(termino_btn, "La cinemática debe terminar")
	assert_eq(GameUI.regreso_desde_interior_oleada, 5, "Registra el regreso")
	assert_true(GameUI.regreso_conversacion_nivel5, "Marca el interludio")
	assert_eq(nivel.oleada_combate_actual, 5, "La oleada 6 espera al regreso")
	_limpiar_regreso()


func test_cinematica_aborto_mitad_restaura_todo() -> void:
	# Arrange: escena en marcha (Eryn + cámaras + botón). Eryn bajo el nivel
	# para que el barrido de contornos la incluya (como en juego).
	var eryn = load("res://Entities/Jugador_Arquera/Player.tscn").instantiate()
	add_child_autofree(eryn)
	await get_tree().process_frame

	var nivel := NivelFalso.new()
	add_child_autofree(nivel)
	remove_child(eryn)
	nivel.add_child(eryn)
	var cams := _crear_camaras(nivel)
	var gui := Node.new()
	gui.name = "GameUI"
	nivel.add_child(gui)
	nivel.game_ui = gui
	var btn := Button.new()
	btn.name = "BtnControlarPerrena"
	gui.add_child(btn)
	var compositor_ab := Node.new()
	compositor_ab.name = "Compositor3D"
	nivel.add_child(compositor_ab)
	var sombra_ab := ColorRect.new()
	sombra_ab.name = "SombraFalsaRect"
	compositor_ab.add_child(sombra_ab)
	var sol := DirectionalLight3D.new()
	sol.name = "SolPrueba"
	sol.shadow_enabled = true
	nivel.add_child(sol)
	# Los viewports los crea _crear_camaras (con FXAA como en juego).
	var vps: Array[SubViewport] = []
	for ruta_vp in ["SubViewportMedio3D", "SubViewportFrente3D"]:
		vps.append(nivel.get_node(ruta_vp) as SubViewport)
	var capa := Sprite3D.new()
	capa.name = "CAPA001"
	capa.texture = ImageTexture.create_from_image(Image.create(200, 100, false, Image.FORMAT_RGBA8))
	capa.position = Vector3(1, 2, 30)
	nivel.add_child(capa)
	var marca := {"lista": false}
	var cine = CINE.new()
	nivel.add_child(cine)
	cine.iniciar(nivel, func(): marca["lista"] = true)
	for i in range(8):
		cine._process(0.25)

	# Assert: sombras fijas durante el travelling.
	assert_eq(sol.directional_shadow_mode, DirectionalLight3D.SHADOW_ORTHOGONAL, "Sombras fijas en cinemática")

	# Assert: FXAA apagado durante el travelling (bordes PNG estables).
	for vp in vps:
		assert_eq(vp.screen_space_aa, Viewport.SCREEN_SPACE_AA_DISABLED, "FXAA apagado en cinemática")

	# Act: fallo a mitad (sigue la ruta de fallo, no la torre).
	cine._abortar()

	# Assert: todo restaurado y continúa a oleada 6.
	for cam in cams:
		assert_almost_eq(cam.position.x, -3.06, 0.05, "Encuadre X restaurado")
		assert_almost_eq(cam.position.y, 3.26, 0.05, "Encuadre Y restaurado")
		assert_almost_eq(cam.position.z, 40.97, 0.05, "Distancia restaurada")
	assert_false(btn.disabled, "Botón restaurado")
	assert_almost_eq(_ancho_contorno_perrena(_primera_perrena()), 20.0, 0.01, "Contorno restaurado")
	var arco_abort = _primera_perrena().find_child("ARCO_ANIMADO", true, false)
	assert_not_null(arco_abort, "Existe el nodo del arco")
	assert_true(arco_abort.visible, "Arco restaurado al abortar")
	assert_eq(capa.position, Vector3(1, 2, 30), "Capa de tono en su sitio")
	assert_eq(capa.scale, Vector3.ONE, "Tamaño de capa restaurado")
	assert_eq(sombra_ab.pivot_offset, Vector2.ZERO, "Máscara pivote restaurado")
	assert_eq(sombra_ab.scale, Vector2.ONE, "Máscara escala restaurada")
	assert_eq(sombra_ab.position, Vector2.ZERO, "Máscara posición restaurada")
	assert_eq(sol.directional_shadow_mode, DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS, "Sombras restauradas")
	for vp in vps:
		assert_eq(vp.screen_space_aa, Viewport.SCREEN_SPACE_AA_FXAA, "FXAA restaurado")
	for s in nivel.find_children("*", "SombraPersonaje", true, false):
		assert_true((s as Node3D).visible, "Sombra falsa restaurada")
	assert_eq(nivel.bloqueos, [true, false], "Desbloquea al abortar")
	assert_eq(nivel.combate, ["pacifico", true], "Defensoras reactivadas")
	assert_true(marca["lista"], "Abortar invoca la continuación")
	_limpiar_regreso()


func test_cinematica_aborto_era_devuelve_disparo() -> void:
	# Arrange: el jugador controla a Perrena; Eryn aparcada (oculta, sin grupo).
	var activa = load("res://Entities/Jugador_Perrena/Perrena.tscn").instantiate()
	add_child_autofree(activa)
	var eryn = load("res://Entities/Jugador_Arquera/Player.tscn").instantiate()
	add_child_autofree(eryn)
	await get_tree().process_frame
	eryn.remove_from_group("player")
	eryn.visible = false
	eryn.set_physics_process(false)

	var nivel := NivelFalso.new()
	add_child_autofree(nivel)
	var marca := {"lista": false}
	var cine = CINE.new()
	nivel.add_child(cine)
	cine.iniciar(nivel, func(): marca["lista"] = true)
	for i in range(8):
		cine._process(0.25)

	# Act: aborto a mitad (sigue la ruta de fallo, no la torre).
	cine._abortar()

	# Assert: control intacto incluido el disparo, y continúa a oleada 6.
	assert_true(activa.is_in_group("player"), "Recupera el grupo player")
	assert_true(activa.is_physics_processing(), "Recupera la física")
	assert_true(activa.is_processing_unhandled_input(), "Recupera el input")
	assert_false(activa.is_shot_locked, "Candado de disparo liberado al abortar")
	assert_true(marca["lista"], "Abortar invoca la continuación")
	_limpiar_regreso()

