extends "res://addons/gut/test.gd"

## Tests unitarios para la transición de derecha a izquierda y pantalla de nivel completado (Nivel Río).
## Valida la integración del shader modular, parámetros, textos localizados, botón Continuar
## y la activación automática al alcanzar la cota meta en el mapa.

const SCRIPT_PANTALLA: Script = preload("res://UI/PantallaFinNivel.gd")
const SCRIPT_NIVEL_RIO: Script = preload("res://Levels/Rio_En_Canoa_Con_Parallax/Rio_En_Canoa_Con_Parallax.gd")
const RUTA_SHADER: String = "res://shader/transition.gdshader"
const RUTA_SHAPE_CIRCLE: String = "res://assets/BinbunVFX/shared/texture/gradient/circle/circle_02.tres"
const MARGEN_FLOAT: float = 0.001


# === TESTS DE INSTANCIACIÓN Y ESTRUCTURA DE PANTALLAFINNIVEL ===
func test_instanciar_pantalla_fin_nivel_propiedades_defecto() -> void:
	# Arrange & Act
	var pantalla: PantallaFinNivel = SCRIPT_PANTALLA.new() as PantallaFinNivel
	add_child_autofree(pantalla)

	# Assert
	assert_not_null(pantalla, "La pantalla de fin de nivel debe instanciarse")
	assert_eq(pantalla.layer, 210, "El layer CanvasLayer debe ser 210 para superar todo el HUD")
	assert_almost_eq(pantalla.duracion_transicion, 1.4, MARGEN_FLOAT, "Duración por defecto 1.4s")
	assert_almost_eq(pantalla.ancho_transicion_shader, 0.675, MARGEN_FLOAT, "Width del shader debe ser 0.675")
	assert_almost_eq(pantalla.tiling_shape_shader, 36.47, MARGEN_FLOAT, "Tiling shape debe ser 36.47")
	assert_eq(pantalla.color_base_transicion, Color.BLACK, "Color base debe ser negro")


func test_shader_material_y_gradiente_derecha_a_izquierda() -> void:
	# Arrange & Act
	var pantalla: PantallaFinNivel = SCRIPT_PANTALLA.new() as PantallaFinNivel
	add_child_autofree(pantalla)

	var rect := pantalla.get_node_or_null("RectTransicion") as ColorRect
	assert_not_null(rect, "Debe existir RectTransicion en la jerarquía")

	var mat := rect.material as ShaderMaterial
	assert_not_null(mat, "RectTransicion debe tener un ShaderMaterial asignado")

	# Assert - Shader shader/transition.gdshader
	var shader := mat.shader
	assert_not_null(shader, "El shader debe ser válido")
	assert_eq(shader.resource_path, RUTA_SHADER, "Debe ser res://shader/transition.gdshader")

	# Assert - Gradiente de derecha a izquierda
	var grad_tex = mat.get_shader_parameter("gradient_texture") as GradientTexture2D
	assert_not_null(grad_tex, "Debe tener asignada la textura de gradiente")
	assert_eq(grad_tex.fill, GradientTexture2D.FILL_LINEAR, "El gradiente debe ser lineal")
	assert_almost_eq(grad_tex.fill_from.x, 1.0, MARGEN_FLOAT, "fill_from debe comenzar en X=1.0 (derecha)")
	assert_almost_eq(grad_tex.fill_to.x, 0.0, MARGEN_FLOAT, "fill_to debe concluir en X=0.0 (izquierda)")

	# Assert - Shape semitono circle_02.tres
	var shape_tex = mat.get_shader_parameter("shape_texture") as Texture2D
	assert_not_null(shape_tex, "Debe tener asignada la textura shape")
	assert_true(
		shape_tex.resource_path.ends_with("circle_02.tres"),
		"La textura de forma debe ser circle_02.tres"
	)

	# Assert - Parámetros de inspector coinciden con captura
	assert_almost_eq(float(mat.get_shader_parameter("width")), 0.675, MARGEN_FLOAT)
	assert_almost_eq(float(mat.get_shader_parameter("shape_tiling")), 36.47, MARGEN_FLOAT)
	assert_true(bool(mat.get_shader_parameter("gradient_fixed")), "gradient_fixed debe ser true")


func test_factor_progresion_shader() -> void:
	# Arrange
	var pantalla: PantallaFinNivel = SCRIPT_PANTALLA.new() as PantallaFinNivel
	add_child_autofree(pantalla)

	# Act & Assert
	pantalla.establecer_factor(0.0)
	assert_almost_eq(pantalla.obtener_factor(), 0.0, MARGEN_FLOAT, "Factor inicial 0.0")

	pantalla.establecer_factor(0.5)
	assert_almost_eq(pantalla.obtener_factor(), 0.5, MARGEN_FLOAT, "Factor intermedio 0.5")

	pantalla.establecer_factor(1.0)
	assert_almost_eq(pantalla.obtener_factor(), 1.0, MARGEN_FLOAT, "Factor final 1.0")

	# Clamping a límites [0.0, 1.0]
	pantalla.establecer_factor(-0.2)
	assert_almost_eq(pantalla.obtener_factor(), 0.0, MARGEN_FLOAT, "Clamped a 0.0")

	pantalla.establecer_factor(1.5)
	assert_almost_eq(pantalla.obtener_factor(), 1.0, MARGEN_FLOAT, "Clamped a 1.0")


# === TESTS DE TEXTOS LOCALIZADOS Y BOTÓN CONTINUAR ===
func test_textos_titulo_y_boton_sujetos_a_traduccion() -> void:
	# Arrange
	var pantalla: PantallaFinNivel = SCRIPT_PANTALLA.new() as PantallaFinNivel
	add_child_autofree(pantalla)

	# Act
	var label: Label = pantalla.obtener_label_titulo()
	var boton: Button = pantalla.obtener_boton_continuar()

	# Assert
	assert_not_null(label, "Debe existir el Label del título")
	assert_not_null(boton, "Debe existir el Botón de continuar")

	# El título debe contener 'NIVEL' y 'COMPLETADO' o la clave traducida
	assert_true(
		label.text.contains("COMPLETADO") or label.text.contains("COMPLETE"),
		"El título debe contener texto de nivel completado: " + label.text
	)

	# El botón debe decir 'Continuar' / 'Continue' o el valor localizado
	assert_true(
		boton.text.to_lower().contains("continuar") or boton.text.to_lower().contains("continue"),
		"El botón debe decir Continuar o su traducción: " + boton.text
	)


func test_boton_continuar_emite_senal_y_ejecuta_callback() -> void:
	# Arrange
	var pantalla: PantallaFinNivel = SCRIPT_PANTALLA.new() as PantallaFinNivel
	pantalla.escena_siguiente = ""  # No cambiar escena durante test
	add_child_autofree(pantalla)

	var callback_llamado: Array[bool] = [false]
	pantalla.on_continuar_callback = func() -> void:
		callback_llamado[0] = true

	watch_signals(pantalla)

	# Act
	var boton: Button = pantalla.obtener_boton_continuar()
	boton.emit_signal("pressed")

	# Assert
	assert_signal_emitted(pantalla, "continuar_presionado", "Debe emitirse señal continuar_presionado")
	assert_true(callback_llamado[0], "El callback configurado debe ejecutarse al presionar Continuar")
	assert_true(boton.disabled, "El botón debe quedar deshabilitado para evitar múltiples pulsaciones")


# === TESTS DE INTEGRACIÓN CON RIO_EN_CANOA_CON_PARALLAX ===
func test_nivel_rio_terminar_nivel_despliega_pantalla() -> void:
	# Arrange
	var nivel: Node3D = SCRIPT_NIVEL_RIO.new() as Node3D
	add_child_autofree(nivel)

	watch_signals(nivel)

	# Act
	nivel.call("terminar_nivel")

	# Assert
	assert_signal_emitted(nivel, "nivel_completado", "Debe emitirse signal nivel_completado")
	assert_true(bool(nivel.call("esta_nivel_terminado")), "esta_nivel_terminado() debe retornar true")
	assert_false(bool(nivel.get("travesia_activa")), "travesia_activa debe pasar a false al terminar nivel")

	var pantalla = nivel.call("obtener_pantalla_fin_nivel")
	assert_not_null(pantalla, "obtener_pantalla_fin_nivel() debe retornar una instancia válida")
	assert_true(pantalla is PantallaFinNivel, "La pantalla debe ser de clase PantallaFinNivel")

	# Limpieza: matar la transición viva (si completa, pausaría el árbol y contaminaría otros tests)
	pantalla.queue_free()


func test_nivel_rio_deteccion_coordenada_fin_dispara_terminar_nivel() -> void:
	# Arrange
	var nivel: Node3D = SCRIPT_NIVEL_RIO.new() as Node3D
	nivel.set("x_fin_nivel", 100.0)
	add_child_autofree(nivel)

	var canoa_dummy := Node3D.new()
	canoa_dummy.name = "CanoaProtagonistaRio"
	canoa_dummy.position.x = 50.0
	nivel.add_child(canoa_dummy)
	nivel.set("canoa_protagonista", canoa_dummy)

	# Act 1: Antes de alcanzar la meta no debe terminar
	nivel.call("_procesar_fin_de_nivel")
	assert_false(bool(nivel.call("esta_nivel_terminado")), "No debe terminar si X < x_fin_nivel")

	# Act 2: Al cruzar la coordenada meta debe terminar
	canoa_dummy.position.x = 101.0
	nivel.call("_procesar_fin_de_nivel")
	assert_true(bool(nivel.call("esta_nivel_terminado")), "Debe terminar al cruzar X >= x_fin_nivel")

	# Limpieza: matar la transición viva (si completa, pausaría el árbol y contaminaría otros tests)
	var pantalla_fin = nivel.call("obtener_pantalla_fin_nivel")
	if is_instance_valid(pantalla_fin):
		pantalla_fin.queue_free()


func test_pantalla_negro_total_al_completar_transicion() -> void:
	# Arrange
	var pantalla: PantallaFinNivel = SCRIPT_PANTALLA.new() as PantallaFinNivel
	add_child_autofree(pantalla)

	# Act 1: Al inicio el fondo negro sólido está transparente
	var fondo_negro := pantalla.get_node_or_null("FondoNegroSolido") as ColorRect
	assert_not_null(fondo_negro, "Debe existir el nodo FondoNegroSolido para garantizar negro total")
	assert_eq(fondo_negro.color, Color.BLACK, "El fondo debe ser de color negro")
	assert_almost_eq(fondo_negro.modulate.a, 0.0, MARGEN_FLOAT, "Al inicio modulate.a debe ser 0.0")

	# Act 2: Al llegar al factor 1.0 (pantalla completamente cubierta), se consolida en negro total
	pantalla.establecer_factor(1.0)
	pantalla.call("_al_terminar_transicion")

	# Assert 2
	assert_almost_eq(fondo_negro.modulate.a, 1.0, MARGEN_FLOAT, "Fondo negro sólido debe ser 1.0 (opaco)")
	assert_true(fondo_negro.visible, "Fondo negro debe estar visible cubriendo toda la pantalla")

	# Limpieza: cubrir pausa el mundo (silencio final); restaurar para no contaminar otros tests
	get_tree().paused = false


# === TESTS DE TÍTULO DEL RÍO, CENTRADO Y SILENCIO FINAL ===
func test_fin_rio_muestra_asalto_al_rio_superado() -> void:
	# Arrange
	var nivel: Node3D = SCRIPT_NIVEL_RIO.new() as Node3D
	add_child_autofree(nivel)

	# Act
	nivel.call("terminar_nivel")
	var pantalla = nivel.call("obtener_pantalla_fin_nivel")
	assert_not_null(pantalla, "Debe existir la pantalla de fin de nivel")

	# Assert: título propio del Río (mayúsculas como el resto de títulos)
	var titulo: String = (pantalla.call("obtener_label_titulo") as Label).text
	assert_true(
		titulo.contains("ASALTO") or titulo.contains("ASSAULT"),
		"El título debe ser Asalto al rio Superado: " + titulo
	)
	assert_true(
		(titulo.contains("RIO") or titulo.contains("RIVER")) and (titulo.contains("SUPERADO") or titulo.contains("COMPLETED")),
		"El título debe mencionar el río superado: " + titulo
	)

	# Assert: botón Continuar debajo
	var boton: Button = pantalla.call("obtener_boton_continuar") as Button
	assert_not_null(boton, "Debe existir el botón Continuar")
	assert_true(
		boton.text.to_lower().contains("continuar") or boton.text.to_lower().contains("continue"),
		"El botón debe decir Continuar: " + boton.text
	)

	# Limpieza: la transición queda en curso con tweens vivos
	pantalla.queue_free()


func test_pantalla_final_centrada_titulo_y_boton() -> void:
	# Arrange
	var pantalla: PantallaFinNivel = SCRIPT_PANTALLA.new() as PantallaFinNivel
	add_child_autofree(pantalla)

	# Act
	var centro := pantalla.get_node_or_null("ContenedorVictoria/CentroVictoria") as CenterContainer
	var vbox := pantalla.get_node_or_null("ContenedorVictoria/CentroVictoria/VBoxCentro") as VBoxContainer
	var label: Label = pantalla.obtener_label_titulo()
	var boton: Button = pantalla.obtener_boton_continuar()

	# Assert: CenterContainer a pantalla completa centra de verdad el contenido
	assert_not_null(centro, "Debe existir CentroVictoria bajo ContenedorVictoria")
	assert_eq(centro.anchor_right, 1.0, "CentroVictoria debe anclar full-rect horizontal")
	assert_eq(centro.anchor_bottom, 1.0, "CentroVictoria debe anclar full-rect vertical")
	assert_not_null(vbox, "Debe existir VBoxCentro bajo CentroVictoria")
	assert_eq(vbox.alignment, BoxContainer.ALIGNMENT_CENTER, "El VBox debe alinear al centro")
	assert_eq(label.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER, "El título debe estar centrado")
	assert_eq(boton.size_flags_horizontal, Control.SIZE_SHRINK_CENTER, "El botón debe centrarse en el VBox")


func test_cubrir_silencia_mundo_y_continuar_reanuda() -> void:
	# Arrange
	var pantalla: PantallaFinNivel = SCRIPT_PANTALLA.new() as PantallaFinNivel
	pantalla.escena_siguiente = ""
	add_child_autofree(pantalla)
	var callback_llamado: Array[bool] = [false]
	pantalla.on_continuar_callback = func() -> void:
		callback_llamado[0] = true

	# Act: cubrir toda la pantalla
	pantalla.establecer_factor(1.0)
	pantalla.call("_al_terminar_transicion")

	# Assert: mundo en silencio (pausado para que ningún loop re-arranque)
	assert_true(get_tree().paused, "Al cubrir debe pausarse el mundo")
	assert_true(pantalla.mantener_musica_al_cubrir, "La música debe seguir sonando bajo la cortinilla por defecto")

	# Act: Continuar reanuda y sigue el flujo
	var boton: Button = pantalla.obtener_boton_continuar()
	boton.emit_signal("pressed")

	# Assert
	assert_false(get_tree().paused, "Continuar debe reanudar el mundo")
	assert_true(callback_llamado[0], "Debe ejecutarse el callback de continuar")


func test_terminar_nivel_garantiza_musica_viaje_bajo_cortinilla() -> void:
	# Arrange: sin música sonando (gap tras la fanfarria del jefe)
	var nivel: Node3D = SCRIPT_NIVEL_RIO.new() as Node3D
	add_child_autofree(nivel)
	var am = get_node_or_null("/root/AudioManager")
	assert_not_null(am, "AudioManager debe existir como autoload")
	am.stop_all()

	# Act: terminar el nivel (cubre la cortinilla)
	nivel.call("terminar_nivel")

	# Assert: la música de viaje suena bajo la cortinilla
	assert_eq(am.get_current_music_index(), 7, "Debe sonar Viaje por el rio (índice 7) bajo la cortinilla")

	# Limpieza: matar la transición viva y la música de prueba
	var pantalla = nivel.call("obtener_pantalla_fin_nivel")
	if is_instance_valid(pantalla):
		pantalla.queue_free()
	am.stop_all()


func test_stop_all_sin_musica_no_resetea_indice() -> void:
	# Arrange
	var antes: int = AudioManager.get_current_music_index()

	# Act: stop_all(false) como al cubrir la cortinilla (música sigue)
	AudioManager.stop_all(false)

	# Assert: no debe tocar el índice de música en curso
	assert_eq(AudioManager.get_current_music_index(), antes, "stop_all(false) no debe resetear la música")
