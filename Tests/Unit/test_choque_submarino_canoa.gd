extends "res://addons/gut/test.gd"

## Tests unitarios del choque canoa-submarino en el nivel del río.
## Valida que la canoa y el submarino nunca se atraviesen: al contactar, la
## canoa hace tamboleo (sacudida_oleaje) para simular el choque, queda
## detenida y retrocede hasta una distancia segura con el casco despejado.

const ESCENA_CANOA: PackedScene = preload("res://Levels/Rio_En_Canoa_Con_Parallax/CanoaProtagonistaRio.tscn")
const MARGEN_FLOAT: float = 0.05
const AMPLITUD_BALANCEO_BASE: float = 2.5


class DummySubmarino extends Node3D:
	pass


func _crear_canoa() -> CanoaProtagonistaRio:
	var canoa: CanoaProtagonistaRio = ESCENA_CANOA.instantiate() as CanoaProtagonistaRio
	add_child_autofree(canoa)
	canoa.global_position = Vector3(0.0, 0.0, 0.0)
	canoa.expulsar_maderos_en_impacto = false
	canoa.iniciar_travesia(1.0)
	return canoa


func _crear_submarino(x: float) -> Node3D:
	var sub := DummySubmarino.new()
	sub.add_to_group("submarino")
	add_child_autofree(sub)
	sub.global_position = Vector3(x, 0.0, 0.0)
	return sub


func _avanzar(canoa: CanoaProtagonistaRio, frames: int, delta: float = 0.05) -> void:
	for i in range(frames):
		canoa._process(delta)


func test_choque_dispara_tamboleo_y_detiene_canoa() -> void:
	# Arrange: submarino a 2m (dentro del umbral de contacto 2.4)
	var canoa: CanoaProtagonistaRio = _crear_canoa()
	_crear_submarino(2.0)

	# Act
	_avanzar(canoa, 10)

	# Assert
	assert_true(canoa.esta_en_choque_submarino(), "La canoa debe estar en choque con el submarino")
	assert_gt(canoa.amplitud_balanceo, AMPLITUD_BALANCEO_BASE, "El tamboleo debe elevar el balanceo")
	assert_almost_eq(canoa.obtener_factor_velocidad_actual(), 0.0, MARGEN_FLOAT, "La canoa debe detenerse en el choque")
	assert_true(canoa.esta_detenida_por_enemigo(), "La canoa debe quedar detenida por contacto")


func test_choque_separa_sin_atravesar_casco() -> void:
	# Arrange: canoa solapada con el casco (sub a 0.5m)
	var canoa: CanoaProtagonistaRio = _crear_canoa()
	var sub: Node3D = _crear_submarino(0.5)

	# Act: 3 segundos de simulación
	_avanzar(canoa, 60)

	# Assert: proa fuera del casco con margen extra (2.4 contacto + retroceso configurado)
	var x_segura: float = sub.global_position.x - canoa.distancia_contacto_enemigos - canoa.retroceso_choque_submarino
	assert_lte(canoa.obtener_posicion_base().x, x_segura + 0.5, "La canoa debe retroceder a distancia segura")
	assert_lt(canoa.global_position.x, sub.global_position.x, "La canoa nunca debe atravesar al submarino")


func test_sin_submarino_no_hay_choque() -> void:
	# Arrange
	var canoa: CanoaProtagonistaRio = _crear_canoa()

	# Act
	_avanzar(canoa, 10)

	# Assert
	assert_false(canoa.esta_en_choque_submarino(), "Sin submarino no debe haber choque")
	assert_almost_eq(canoa.obtener_factor_velocidad_actual(), 1.0, MARGEN_FLOAT, "Debe navegar libre")
	assert_almost_eq(canoa.amplitud_balanceo, AMPLITUD_BALANCEO_BASE, MARGEN_FLOAT, "Sin tamboleo")


func test_submarino_lejos_no_dispara_choque() -> void:
	# Arrange: submarino a 60m, fuera de todo alcance
	var canoa: CanoaProtagonistaRio = _crear_canoa()
	_crear_submarino(60.0)

	# Act
	_avanzar(canoa, 10)

	# Assert
	assert_false(canoa.esta_en_choque_submarino(), "Lejos no debe haber choque")
	assert_almost_eq(canoa.amplitud_balanceo, AMPLITUD_BALANCEO_BASE, MARGEN_FLOAT, "Sin tamboleo")


func test_submarino_atras_no_dispara_choque() -> void:
	# Arrange: submarino 10m detrás (ya superado)
	var canoa: CanoaProtagonistaRio = _crear_canoa()
	_crear_submarino(-10.0)

	# Act
	_avanzar(canoa, 10)

	# Assert
	assert_false(canoa.esta_en_choque_submarino(), "Con el submarino atrás no debe haber choque")
	assert_gt(canoa.obtener_posicion_base().x, -1.0, "La canoa no debe retroceder hacia el submarino superado")


func test_choque_desactivado_no_reacciona() -> void:
	# Arrange
	var canoa: CanoaProtagonistaRio = _crear_canoa()
	canoa.choque_submarino_activo = false
	_crear_submarino(2.0)

	# Act
	_avanzar(canoa, 10)

	# Assert
	assert_false(canoa.esta_en_choque_submarino(), "Desactivado no debe haber choque")
	assert_almost_eq(canoa.amplitud_balanceo, AMPLITUD_BALANCEO_BASE, MARGEN_FLOAT, "Sin tamboleo")


class DummySubBloqueador extends Node3D:
	var margen_bloqueo_proa: float = 5.0
	var a_flote: bool = true

	func esta_en_superficie() -> bool:
		return a_flote


func _crear_sub_bloqueador(x: float) -> DummySubBloqueador:
	var sub := DummySubBloqueador.new()
	sub.add_to_group("submarino")
	add_child_autofree(sub)
	sub.global_position = Vector3(x, 0.0, 0.0)
	return sub


func test_freno_bloquea_ante_submarino_en_superficie() -> void:
	# Arrange: solo el freno clásico (choque desactivado), sub con casco de 5m a 7m
	var canoa: CanoaProtagonistaRio = _crear_canoa()
	canoa.choque_submarino_activo = false
	var sub: DummySubBloqueador = _crear_sub_bloqueador(7.0)

	# Act
	_avanzar(canoa, 10)

	# Assert: contacto (7.0 <= 2.4 + 5.0), detenida contra la raíz con su margen
	assert_almost_eq(canoa.obtener_factor_velocidad_actual(), 0.0, MARGEN_FLOAT, "El freno debe detener ante el submarino")
	assert_true(canoa.esta_detenida_por_enemigo(), "Debe quedar detenida")
	assert_eq(canoa.obtener_enemigo_bloqueando(), sub, "El bloqueador debe ser el submarino")
	assert_lte(canoa.obtener_posicion_base().x, 0.1, "La proa no debe pasar la línea del casco")


func test_freno_libera_al_hundirse_el_submarino() -> void:
	# Arrange
	var canoa: CanoaProtagonistaRio = _crear_canoa()
	canoa.choque_submarino_activo = false
	var sub: DummySubBloqueador = _crear_sub_bloqueador(7.0)
	_avanzar(canoa, 10)
	assert_true(canoa.esta_detenida_por_enemigo(), "Precondición: detenida por el submarino")

	# Act: el submarino se sumerge
	sub.a_flote = false
	_avanzar(canoa, 10)

	# Assert: reanuda la marcha y el nivel puede continuar
	assert_almost_eq(canoa.obtener_factor_velocidad_actual(), 1.0, MARGEN_FLOAT, "Debe reanudar al hundirse el submarino")
	assert_false(canoa.esta_detenida_por_enemigo(), "Ya no debe estar detenida")


class DummyJefePelea extends Node3D:
	var margen_bloqueo_proa: float = 5.0
	var combate_activo: bool = true
	var a_flote: bool = true
	var _jefe_muerto: bool = false

	func esta_en_superficie() -> bool:
		return a_flote and not _jefe_muerto


func _crear_jefe_pelea(x: float) -> DummyJefePelea:
	var jefe := DummyJefePelea.new()
	jefe.add_to_group("submarino")
	add_child_autofree(jefe)
	jefe.global_position = Vector3(x, 0.0, 0.0)
	return jefe


func test_pelea_retiene_canoa_aunque_jefe_se_sumerja() -> void:
	# Arrange: contacto con el jefe en combate (a 7m, dentro del umbral 7.4)
	var canoa: CanoaProtagonistaRio = _crear_canoa()
	var jefe: DummyJefePelea = _crear_jefe_pelea(7.0)
	_avanzar(canoa, 10)
	assert_true(canoa.esta_retenida_por_jefe(), "Precondición: pelea retenida")
	var x_retenida: float = canoa.obtener_posicion_base().x

	# Act: el jefe se sumerge en crucero durante varios segundos
	jefe.a_flote = false
	_avanzar(canoa, 60)

	# Assert: la canoa no avanza de su tope y sigue detenida
	assert_true(canoa.esta_retenida_por_jefe(), "La pelea debe seguir retenida en inmersión")
	assert_almost_eq(canoa.obtener_factor_velocidad_actual(), 0.0, MARGEN_FLOAT, "Debe seguir detenida")
	assert_lte(canoa.obtener_posicion_base().x, x_retenida + 0.3, "No debe avanzar durante la pelea")


func test_pelea_libera_al_morir_el_jefe() -> void:
	# Arrange
	var canoa: CanoaProtagonistaRio = _crear_canoa()
	var jefe: DummyJefePelea = _crear_jefe_pelea(7.0)
	_avanzar(canoa, 10)
	assert_true(canoa.esta_retenida_por_jefe(), "Precondición: pelea retenida")

	# Act: muere el jefe y el nivel debe continuar
	jefe._jefe_muerto = true
	_avanzar(canoa, 10)

	# Assert
	assert_false(canoa.esta_retenida_por_jefe(), "Al morir el jefe se libera")
	assert_almost_eq(canoa.obtener_factor_velocidad_actual(), 1.0, MARGEN_FLOAT, "El nivel continúa tras el jefe")
	assert_false(canoa.esta_detenida_por_enemigo(), "Ya no debe estar detenida")


func test_pelea_libera_si_combate_termina_vivo() -> void:
	# Arrange
	var canoa: CanoaProtagonistaRio = _crear_canoa()
	var jefe: DummyJefePelea = _crear_jefe_pelea(7.0)
	_avanzar(canoa, 10)
	assert_true(canoa.esta_retenida_por_jefe(), "Precondición: pelea retenida")

	# Act: reinicio del enfrentamiento (sumergido e inactivo, jefe vivo)
	jefe.combate_activo = false
	jefe.a_flote = false
	_avanzar(canoa, 10)

	# Assert
	assert_false(canoa.esta_retenida_por_jefe(), "Sin combate se libera")
	assert_almost_eq(canoa.obtener_factor_velocidad_actual(), 1.0, MARGEN_FLOAT, "Reanuda la marcha")
