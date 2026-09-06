extends GutTest
## Test unitario para la sombra circular del enemigo Gargola.
## Verifica que posea una sombra circular similar al Globo aerostatico,
## visible a las alturas de vuelo y con proporciones 1:1.

const GARGOLA_SCENE: PackedScene = preload("res://Entities/Enemigo_Gargola/Gargola.tscn")
const GARGOLA_SCRIPT = preload("res://Entities/Enemigo_Gargola/Gargola.gd")


func test_gargola_escena_configura_sombra_circular_y_altura_de_vuelo() -> void:
	# Arrange
	var gargola: Gargola = GARGOLA_SCENE.instantiate() as Gargola
	add_child_autofree(gargola)
	await get_tree().process_frame

	# Assert 1: Forma circular (ancho igual a profundidad)
	assert_almost_eq(
		gargola.sombra_tamano.x,
		gargola.sombra_tamano.y,
		0.001,
		"La sombra de la gargola debe ser perfectamente circular (aspect ratio 1:1)"
	)

	# Assert 2: Tamano proporcional y mayor al de personajes terrestres (0.6 x 0.6)
	assert_gt(
		gargola.sombra_tamano.x,
		0.9,
		"La sombra circular de la gargola debe tener un diametro visible (>= 1.0m)"
	)

	# Assert 3: Altura maxima de desvanecimiento superior a la altura de vuelo alta (5.2m)
	assert_gt(
		gargola.sombra_altura_max,
		gargola.altura_spawn_alta,
		"La sombra debe permanecer visible a la altura maxima de vuelo"
	)

	# Boundary: a la altura maxima de vuelo conserva mas de la mitad de su opacidad
	var factor_max: float = clampf(1.0 - (gargola.altura_spawn_alta / gargola.sombra_altura_max), 0.0, 1.0)
	assert_gt(factor_max, 0.6, "A la altura maxima de vuelo la sombra conserva mas del 60% de su opacidad")

	# Assert 4: Nodo de sombra instanciado correctamente
	assert_not_null(gargola.sombra_nodo, "La gargola debe tener sombra_nodo instanciado")
	assert_true(gargola.sombra_nodo is SombraPersonaje, "sombra_nodo debe ser de tipo SombraPersonaje")


func test_gargola_script_defaults_en_init() -> void:
	# Arrange & Act: Instanciacion directa por script
	var gargola := GARGOLA_SCRIPT.new() as Gargola
	add_child_autofree(gargola)
	await get_tree().process_frame

	# Assert
	assert_almost_eq(gargola.sombra_tamano.x, gargola.sombra_tamano.y, 0.001, "Script default debe ser circular")
	assert_gt(gargola.sombra_altura_max, 20.0, "Script default de altura_max debe ser amplio para vuelo")
	assert_not_null(gargola.sombra_nodo, "Debe instanciar sombra_nodo en _ready()")
