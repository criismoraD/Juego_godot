extends "res://addons/gut/test.gd"

## Tests unitarios para el escenario 'Rio en canoa con paralax'.
## Validan la estructura del nivel, paridad de posiciones con NIVEL01,
## el funcionamiento del loop infinito de parallax y la navegación de la canoa.

const ESCENA_RIO_PATH: String = "res://Levels/Rio_En_Canoa_Con_Parallax/Rio_En_Canoa_Con_Parallax.tscn"
const SCRIPT_PARALLAX: Script = preload("res://Levels/Rio_En_Canoa_Con_Parallax/ParallaxFondoRio.gd")
const SCRIPT_CANOA_RIO: Script = preload("res://Levels/Rio_En_Canoa_Con_Parallax/CanoaProtagonistaRio.gd")
const MARGEN_FLOAT: float = 0.01


# === TESTS DE ESTRUCTURA E INSTANCIACIÓN ===
func test_instanciar_escena_rio_en_canoa_con_parallax() -> void:
	# Arrange & Act
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	assert_not_null(packed, "La escena debe cargar correctamente")

	var nivel: Node3D = packed.instantiate() as Node3D
	assert_not_null(nivel, "La escena debe instanciarse")
	add_child_autofree(nivel)

	# Assert
	assert_not_null(nivel.find_child("Lighting", true, false), "Debe contener el nodo Lighting")
	assert_not_null(nivel.find_child("WaterPlane", true, false), "Debe contener WaterPlane")
	assert_not_null(nivel.find_child("ParallaxFondo", true, false), "Debe contener ParallaxFondo")
	assert_not_null(nivel.find_child("CanoaProtagonistaRio", true, false), "Debe contener CanoaProtagonistaRio")


# === TESTS DE PARIDAD CON NIVEL01 (CÁMARA, AGUA, PECES) ===
func test_camara_agua_y_peces_en_posiciones_nivel01() -> void:
	# Arrange
	var packed := load(ESCENA_RIO_PATH) as PackedScene
	var nivel: Node3D = packed.instantiate() as Node3D
	add_child_autofree(nivel)

	# Act & Assert Cámara: (-3.0599, 3.2650, 40.9710)
	var camara: Camera3D = nivel.find_child("CamaraPrincipal", true, false) as Camera3D
	assert_not_null(camara, "Debe existir la cámara principal")
	assert_almost_eq(camara.position.x, -3.0599065, MARGEN_FLOAT, "Posición X de cámara debe coincidir con Nivel 1")
	assert_almost_eq(camara.position.y, 3.265016, MARGEN_FLOAT, "Posición Y de cámara debe coincidir con Nivel 1")
	assert_almost_eq(camara.position.z, 40.971046, MARGEN_FLOAT, "Posición Z de cámara debe coincidir con Nivel 1")

	# Act & Assert WaterPlane: (-5.9324, -0.1729, -12.3044)
	var water: Node3D = nivel.find_child("WaterPlane", true, false) as Node3D
	assert_not_null(water, "Debe existir WaterPlane")
	assert_almost_eq(water.position.x, -5.9324427, MARGEN_FLOAT, "Posición X de agua debe coincidir con Nivel 1")
	assert_almost_eq(water.position.y, -0.17290789, MARGEN_FLOAT, "Posición Y de agua debe coincidir con Nivel 1")
	assert_almost_eq(water.position.z, -12.304441, MARGEN_FLOAT, "Posición Z de agua debe coincidir con Nivel 1")

	# Act & Assert Pez 1 y Pez 2
	var pez1: Node3D = nivel.find_child("Pez", true, false) as Node3D
	var pez2: Node3D = nivel.find_child("Pez2", true, false) as Node3D
	assert_not_null(pez1, "Debe existir Pez 1")
	assert_not_null(pez2, "Debe existir Pez 2")
	assert_almost_eq(pez1.position.x, 2.5, MARGEN_FLOAT, "Pez 1 X")
	assert_almost_eq(pez2.position.x, -2.6435776, MARGEN_FLOAT, "Pez 2 X")


# === TESTS DE CAPAS DE PARALLAX ===
func test_parallax_capas_atardecer_y_terroso() -> void:
	# Arrange & Act
	var parallax: Node3D = SCRIPT_PARALLAX.new() as Node3D
	add_child_autofree(parallax)

	# Assert
	var capa_atardecer := parallax.get_node_or_null("CapaAtardecer") as Node3D
	var capa_terroso := parallax.get_node_or_null("CapaTerroso") as Node3D

	assert_not_null(capa_atardecer, "Debe existir CapaAtardecer")
	assert_not_null(capa_terroso, "Debe existir CapaTerroso")

	# Profundidad: Atardecer más alejado que Terroso (Z más negativa)
	assert_lt(capa_atardecer.position.z, capa_terroso.position.z, "El atardecer debe estar más al fondo que el terreno")

	# Segmentos
	var sprites_terroso: Array = parallax.call("obtener_sprites_terroso")
	assert_eq(sprites_terroso.size(), 3, "Deben existir 3 segmentos modulares de rocas terrosas")

	for s in sprites_terroso:
		var sprite := s as Sprite3D
		assert_eq(sprite.texture, SCRIPT_PARALLAX.TEX_TERROSO, "La textura del terreno debe ser Fondo terroso nivel 6")


# === TESTS DE LOOP INFINITO EN PARALLAX ===
func test_parallax_loop_continuo_terroso() -> void:
	# Arrange
	var parallax: Node3D = SCRIPT_PARALLAX.new() as Node3D
	add_child_autofree(parallax)
	parallax.set("velocidad_terroso", 2.0)

	var sprites: Array = parallax.call("obtener_sprites_terroso")
	var sprite_0 := sprites[0] as Sprite3D
	var x_inicial_0: float = sprite_0.position.x

	# Act: Simular desplazamiento de 1 segundo hacia la izquierda
	parallax._process(1.0)

	# Assert: Debe haberse desplazado hacia la izquierda (X menor)
	assert_almost_eq(sprite_0.position.x, x_inicial_0 - 2.0, MARGEN_FLOAT, "El terreno debe desplazarse a la izquierda")

	# Simular salida del encuadre para probar el wrap-around
	var ancho_seg: float = float(parallax.get("ancho_segmento_terroso"))
	sprite_0.position.x = -ancho_seg * 2.0
	parallax.call("_actualizar_loop_terroso", 0.016)

	# Assert: El sprite debe haberse reposicionado al extremo derecho
	assert_gt(sprite_0.position.x, 0.0, "El segmento debe recolocarse a la derecha al hacer loop")


# === TESTS DE CANOA Y PROTAGONISTA ===
func test_canoa_navegacion_hacia_la_derecha() -> void:
	# Arrange
	var canoa: Node3D = SCRIPT_CANOA_RIO.new() as Node3D
	add_child_autofree(canoa)
	canoa.call("fijar_posicion_base", Vector3(-5.0, -0.28, -7.5))
	canoa.set("velocidad_avance", 1.0)

	# Act: Iniciar viaje y avanzar 2 segundos
	canoa.call("iniciar_travesia", 1.0)
	canoa.call("_actualizar_navegacion", 2.0)

	# Assert: La posición X debe haber avanzado hacia la derecha (de -5.0 a -3.0)
	var pos_base: Vector3 = canoa.call("obtener_posicion_base")
	assert_almost_eq(pos_base.x, -3.0, MARGEN_FLOAT, "La canoa debe avanzar hacia la derecha (+X)")
	assert_true(bool(canoa.call("esta_flotando")), "La canoa debe mantener su estado de flotación")
