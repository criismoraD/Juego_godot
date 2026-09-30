extends "res://addons/gut/test.gd"

## Regresión: la franja de tierra del fondo (Piso nueva version) debe
## mantenerse continua a medida que la canoa avanza, sin huecos ni
## desapariciones. Cubre el bug de wrap que mezclaba coordenadas locales
## con la cámara global y el paso fijo descalibrado.

const ESCENA_RIO: PackedScene = preload("res://Levels/Rio en canoa con paralax.tscn")
const MARGEN: float = 0.05


func _xs_globales_ordenadas(pisos: Array) -> Array[float]:
	var xs: Array[float] = []
	for p in pisos:
		if is_instance_valid(p):
			xs.append((p as Node3D).global_position.x)
	xs.sort()
	return xs


func _hueco_maximo(xs: Array[float]) -> float:
	if xs.size() < 2:
		return 0.0
	var peor: float = 0.0
	for i in range(1, xs.size()):
		peor = maxf(peor, xs[i] - xs[i - 1])
	return peor


func test_piso_fondo_franja_continua_tras_avance() -> void:
	# Arrange: nivel completo, franja inicial continua
	var nivel: Node3D = ESCENA_RIO.instantiate() as Node3D
	add_child_autofree(nivel)
	var parallax = nivel.find_child("ParallaxFondo", true, false)
	assert_not_null(parallax, "ParallaxFondo debe existir")
	var camara: Camera3D = nivel.find_child("CamaraPrincipal", true, false) as Camera3D
	assert_not_null(camara, "CamaraPrincipal debe existir")

	var pisos: Array = parallax.call("obtener_segmentos_piso_aliado")
	assert_gt(pisos.size(), 0, "Debe haber pisos de fondo")
	var total: int = pisos.size()
	var paso: float = float(parallax.get("ancho_segmento_piso"))
	var hueco_inicial: float = _hueco_maximo(_xs_globales_ordenadas(pisos))
	assert_lt(hueco_inicial, paso * 1.5, "La franja inicial debe ser continua (hueco=%.2f, paso=%.2f)" % [hueco_inicial, paso])

	# Act: simular avance largo de cámara + scroll parallax (200 frames)
	for i in range(200):
		camara.global_position.x += 0.65 * 0.016 * 6.0
		parallax.call("_actualizar_loop_piso_aliado", 0.016)

	# Assert: ningún segmento se pierde y la franja sigue continua
	var pisos2: Array = parallax.call("obtener_segmentos_piso_aliado")
	assert_eq(pisos2.size(), total, "No debe perderse ningún segmento de piso")
	var xs: Array[float] = _xs_globales_ordenadas(pisos2)
	var hueco: float = _hueco_maximo(xs)
	assert_lt(hueco, paso * 1.5, "Sin huecos tras el avance (hueco=%.2f, paso=%.2f)" % [hueco, paso])
	var x_cam: float = camara.global_position.x
	assert_lte(xs[0], x_cam - 20.0, "La franja debe cubrir por detrás de la cámara")
	assert_gte(xs[xs.size() - 1], x_cam + 30.0, "La franja debe cubrir por delante de la cámara")
	for p in pisos2:
		assert_true((p as Node3D).visible, "La baldosa %s debe permanecer visible" % (p as Node3D).name)


func test_piso_fondo_wrap_en_global_no_teletransporte_masivo() -> void:
	# Arrange
	var nivel: Node3D = ESCENA_RIO.instantiate() as Node3D
	add_child_autofree(nivel)
	var parallax = nivel.find_child("ParallaxFondo", true, false)
	var camara: Camera3D = nivel.find_child("CamaraPrincipal", true, false) as Camera3D
	var pisos: Array = parallax.call("obtener_segmentos_piso_aliado")
	var xs_antes: Array[float] = _xs_globales_ordenadas(pisos)

	# Act: un solo frame sin mover la cámara (nada debería reciclarse de golpe)
	parallax.call("_actualizar_loop_piso_aliado", 0.016)
	var xs_despues: Array[float] = _xs_globales_ordenadas(parallax.call("obtener_segmentos_piso_aliado"))

	# Assert: desplazamiento mínimo (solo el paso), sin teletransporte masivo
	var paso_esperado: float = float(parallax.get("velocidad_base")) * float(parallax.get("factor_piso_fondo")) * 0.016
	for i in range(xs_antes.size()):
		assert_almost_eq(xs_antes[i] - xs_despues[i], paso_esperado, MARGEN,
			"El piso solo debe desplazarse el paso parallax, sin saltos")
