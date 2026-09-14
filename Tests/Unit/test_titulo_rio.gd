extends "res://addons/gut/test.gd"

## Tests unitarios de la tarjeta de título del nivel del rio (TituloRio).
## Validan texto traducible, fundido simétrico de aparición/desaparición
## y que la presentación puede repetirse.

const ESCENA_TITULO: String = "res://Levels/Rio_En_Canoa_Con_Parallax/TituloRio.tscn"
const CLAVE_TITULO: String = "TITULO_RIO_TULEMAKI"


func _crear_titulo() -> TituloRio:
	var packed := load(ESCENA_TITULO) as PackedScene
	assert_not_null(packed, "La escena del título debe cargar correctamente")
	var titulo := packed.instantiate() as TituloRio
	assert_not_null(titulo, "La escena debe instanciar un TituloRio")
	add_child_autofree(titulo)
	await get_tree().process_frame
	return titulo


func _tiempos_cortos(titulo: TituloRio) -> void:
	titulo.tiempo_aparicion = 0.05
	titulo.tiempo_visible = 0.05
	titulo.tiempo_brillo = 0.05
	titulo.tiempo_desaparicion = 0.05


# === TEXTO Y TRADUCCIÓN ===
func test_texto_titulo_sujeto_a_traduccion() -> void:
	# Arrange & Act
	var titulo := await _crear_titulo()

	# Assert: traducido al idioma activo o clave como respaldo
	assert_not_null(titulo.etiqueta, "Debe existir la etiqueta del título")
	var texto: String = titulo.etiqueta.text
	assert_true(texto == "Rio Tulemaki" or texto == CLAVE_TITULO, "El título debe salir de las traducciones (o la clave como respaldo): " + texto)


func test_valores_por_defecto() -> void:
	# Arrange & Act
	var titulo := await _crear_titulo()

	# Assert
	assert_eq(titulo.clave_traduccion, CLAVE_TITULO, "Clave de traducción por defecto")
	assert_true(titulo.mostrar_al_iniciar, "Debe presentarse al iniciar por defecto")
	assert_eq(titulo.tamano_fuente, 120, "Misma tipografía de tamaño que el nivel 1")
	assert_eq(titulo.color_fuente, Color.BLACK, "Texto negro como el nivel 1")
	assert_almost_eq(titulo.tiempo_aparicion, 2.0, 0.001, "Misma duración de aparición que el nivel 1")
	assert_almost_eq(titulo.tiempo_visible, 16.0, 0.001, "Misma duración visible que el nivel 1")
	assert_almost_eq(titulo.tiempo_brillo, 1.0, 0.001, "Misma duración de brillo que el nivel 1")
	assert_almost_eq(titulo.tiempo_desaparicion, 3.0, 0.001, "Misma duración de desaparición que el nivel 1")


# === PRESENTACIÓN ===
func test_presentacion_aparece_y_desaparece_igual() -> void:
	# Arrange
	var titulo := await _crear_titulo()
	_tiempos_cortos(titulo)
	watch_signals(titulo)

	# Act
	titulo.mostrar()
	assert_true(titulo.etiqueta.visible, "Visible durante la presentación")
	await get_tree().create_timer(0.6).timeout

	# Assert: desaparece con el mismo fundido y avisa
	assert_false(titulo.etiqueta.visible, "Oculto al terminar la presentación")
	assert_signal_emitted(titulo, "presentacion_terminada", "Debe emitir al terminar")


func test_mostrar_repite_presentacion() -> void:
	# Arrange
	var titulo := await _crear_titulo()
	_tiempos_cortos(titulo)

	# Act: presentar dos veces seguidas (la segunda reinicia el fundido)
	titulo.mostrar()
	titulo.mostrar()
	await get_tree().create_timer(0.6).timeout

	# Assert
	assert_false(titulo.etiqueta.visible, "Tras repetir debe terminar oculta")
