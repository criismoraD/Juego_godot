extends "res://addons/gut/test.gd"

## Tests unitarios de la contención de la canoa ante el jefe vivo.
## Mientras el jefe siga vivo, la canoa no rebasa su arena ni la meta final:
## así matar al jefe jamás dispara el final en otro punto y el nivel solo
## termina al cruzar la zona de árboles (x_fin_nivel).

const SCRIPT_RIO: Script = preload("res://Levels/Rio_En_Canoa_Con_Parallax/Rio_En_Canoa_Con_Parallax.gd")
const ESCENA_CANOA: PackedScene = preload("res://Levels/Rio_En_Canoa_Con_Parallax/CanoaProtagonistaRio.tscn")
const MARGEN_FLOAT: float = 0.05


class DummyJefeArena extends Node3D:
	var combate_activo: bool = true
	var a_flote: bool = true
	var _jefe_muerto: bool = false

	func esta_en_superficie() -> bool:
		return a_flote and not _jefe_muerto


func _crear_nivel_con_canoa(canoa_x: float) -> Array:
	var nivel: RioEnCanoaConParallax = SCRIPT_RIO.new()
	add_child_autofree(nivel)
	var canoa: CanoaProtagonistaRio = ESCENA_CANOA.instantiate() as CanoaProtagonistaRio
	add_child_autofree(canoa)
	canoa.fijar_posicion_base(Vector3(canoa_x, 0.0, 0.0))
	canoa.expulsar_maderos_en_impacto = false
	nivel.canoa_protagonista = canoa
	var jefe := DummyJefeArena.new()
	add_child_autofree(jefe)
	jefe.global_position = Vector3(141.0, 0.0, 0.0)
	nivel._jefe_submarino_ref = jefe
	return [nivel, canoa, jefe]


func test_contencion_retiene_canoa_en_arena_con_jefe_vivo() -> void:
	# Arrange: canoa aproximándose a la arena (125), jefe en combate en 141
	var pack: Array = _crear_nivel_con_canoa(125.0)
	var nivel: RioEnCanoaConParallax = pack[0]
	var canoa: CanoaProtagonistaRio = pack[1]

	# Act: varios frames con intento de avance (simula navegación)
	for i in range(20):
		canoa.fijar_posicion_base(canoa.obtener_posicion_base() + Vector3(0.5, 0.0, 0.0))
		nivel._contener_canoa_ante_jefe_vivo(0.05)

	# Assert: retenida en el tope (141 - 7.3, distancia de combate con plataforma y cañón visibles), sin rebasar la arena
	assert_lte(canoa.obtener_posicion_base().x, 141.0 - 7.3 + 0.6, "No debe rebasar la arena con el jefe vivo")
	assert_gte(canoa.obtener_posicion_base().x, 133.0, "Debe avanzar hasta la línea de contención de combate")


func test_contencion_no_arrastra_hacia_atras() -> void:
	# Arrange: canoa ya pasada de la línea (jefe emergió tarde detrás)
	var pack: Array = _crear_nivel_con_canoa(150.0)
	var nivel: RioEnCanoaConParallax = pack[0]
	var canoa: CanoaProtagonistaRio = pack[1]

	# Act
	for i in range(20):
		nivel._contener_canoa_ante_jefe_vivo(0.05)

	# Assert: congela el avance pero jamás la arrastra atrás
	assert_almost_eq(canoa.obtener_posicion_base().x, 150.0, 0.6, "No debe arrastrar hacia atrás")


func test_contencion_no_bloquea_antes_del_combate() -> void:
	# Arrange: jefe aún sumergido sin combatir, canoa aproximándose
	var pack: Array = _crear_nivel_con_canoa(120.0)
	var nivel: RioEnCanoaConParallax = pack[0]
	var canoa: CanoaProtagonistaRio = pack[1]
	var jefe: DummyJefeArena = pack[2]
	jefe.combate_activo = false
	jefe.a_flote = false

	# Act
	nivel._contener_canoa_ante_jefe_vivo(0.05)

	# Assert: vía libre para acercarse y despertar al jefe
	assert_almost_eq(canoa.obtener_posicion_base().x, 120.0, MARGEN_FLOAT, "Antes del combate no debe contener")


func test_contencion_libera_al_morir_el_jefe() -> void:
	# Arrange: canoa contenida en la arena
	var pack: Array = _crear_nivel_con_canoa(135.0)
	var nivel: RioEnCanoaConParallax = pack[0]
	var canoa: CanoaProtagonistaRio = pack[1]
	var jefe: DummyJefeArena = pack[2]
	nivel._contener_canoa_ante_jefe_vivo(0.05)

	# Act: muere el jefe y el nivel debe continuar
	jefe._jefe_muerto = true
	for i in range(10):
		canoa.fijar_posicion_base(canoa.obtener_posicion_base() + Vector3(0.5, 0.0, 0.0))
		nivel._contener_canoa_ante_jefe_vivo(0.05)

	# Assert: avanza libre hacia el tramo final
	assert_gt(canoa.obtener_posicion_base().x, 135.0, "Muerto el jefe, el nivel continúa")
