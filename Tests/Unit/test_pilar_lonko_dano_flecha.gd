extends GutTest

## Regresión: el pilar de Lonko debe ser dañable por las flechas de la jugadora
## en el nivel del río (la flecha atravesaba el pilar sin registrar impacto).
## Cubre: capas/grupos/flags del PilarBody, compatibilidad con la máscara de
## la flecha (Arrow.tscn), ruta de daño recibir_golpe/take_damage, aviso de
## destrucción a Lonko y tamaño mínimo del hitbox (perdón de apuntado X/Z
## desde la canoa en movimiento).

const PILAR_SCENE: PackedScene = preload("res://Entities/Enemigo_Lonko/PilarLonko.tscn")
const ARROW_SCENE: PackedScene = preload("res://Entities/Proyectil_Flecha/Arrow.tscn")

const ESCALA_PILAR_LONKO: float = 3.0 ## Misma escala que usa Lonko al invocar el pilar
const ANCHO_ESPERADO_MUNDO_X: float = 0.54 ## 0.18 x3: el X debe ceñir el visual de la columna (~0.64 m) para que las flechas se claven en la superficie del pilar sin flotar en el aire
const TOLERANCIA_ANCHO_X: float = 0.10
const PROFUNDIDAD_MINIMA_MUNDO_Z: float = 2.0 ## El plano Z de la flecha va 0.75 m detrás del pilar: el hitbox debe cubrirlo con margen (NO bajar Z de 0.6 en el tscn o las flechas lo atraviesan; el Z extra es invisible de lado)
const ALTURA_ESPERADA_MUNDO_Y: float = 3.0 ## El pilar visual mide 1.0 m x3 de escala
const Z_PILAR_RIO: float = -6.75 ## Z de Lonko (-7.2) + offset_z_pilar (0.45)
const Z_JUGADORA_RIO: float = -7.5 ## Z de la canoa protagonista


class LonkoFalso extends Node:
	var destruido_llamadas: int = 0

	func _on_pilar_destruido() -> void:
		destruido_llamadas += 1


var scene_root: Node3D


func before_each() -> void:
	scene_root = Node3D.new()
	add_child(scene_root)


func after_each() -> void:
	if is_instance_valid(scene_root):
		scene_root.queue_free()
	await get_tree().process_frame


func _instanciar_pilar() -> Node3D:
	var pilar := PILAR_SCENE.instantiate() as Node3D
	scene_root.add_child(pilar)
	pilar.scale = Vector3(ESCALA_PILAR_LONKO, ESCALA_PILAR_LONKO, ESCALA_PILAR_LONKO)
	await get_tree().process_frame
	return pilar


func test_pilar_body_en_grupos_y_flags_enemigos() -> void:
	# Arrange & Act
	var pilar: Node3D = await _instanciar_pilar()
	var body := pilar.find_child("PilarBody", true, false) as PilarLonkoBody

	# Assert
	assert_not_null(body, "PilarLonko debe contener el nodo PilarBody")
	assert_true(body.is_in_group("enemies"), "El pilar debe estar en el grupo enemies")
	assert_true(body.is_in_group("escudos"), "El pilar debe estar en el grupo escudos")
	assert_true(body.es_escudo_enemigo, "es_escudo_enemigo debe ser true (flechas del jugador lo dañan)")
	assert_true(body.es_pilar_enemigo, "es_pilar_enemigo debe ser true")
	assert_true(body.has_method("recibir_golpe"), "El pilar debe exponer recibir_golpe")
	assert_true(body.has_method("take_damage"), "El pilar debe exponer take_damage")


func test_pilar_en_capa_detectable_por_flecha_jugadora() -> void:
	# Arrange
	var pilar: Node3D = await _instanciar_pilar()
	var body := pilar.find_child("PilarBody", true, false) as PilarLonkoBody
	var flecha := ARROW_SCENE.instantiate() as Area3D
	scene_root.add_child(flecha)
	await get_tree().process_frame

	# Act
	var capa_pilar: int = body.collision_layer
	var mascara_flecha: int = flecha.collision_mask

	# Assert: la máscara de la flecha debe incluir la capa del pilar
	assert_ne(capa_pilar, 0, "El pilar debe tener alguna capa de colisión activa")
	assert_ne(mascara_flecha & capa_pilar, 0, "La máscara de la flecha (%d) debe incluir la capa del pilar (%d)" % [mascara_flecha, capa_pilar])

	flecha.queue_free()


func test_pilar_hitbox_cubre_plano_z_jugadora_rio() -> void:
	# Arrange
	var pilar: Node3D = await _instanciar_pilar()
	var body := pilar.find_child("PilarBody", true, false) as PilarLonkoBody
	var col := body.find_child("CollisionShape3D", true, false) as CollisionShape3D

	# Act
	assert_not_null(col, "PilarBody debe tener CollisionShape3D")
	var caja := col.shape as BoxShape3D
	assert_not_null(caja, "La forma del pilar debe ser BoxShape3D")
	var mundo_x: float = caja.size.x * pilar.scale.x
	var mundo_y: float = caja.size.y * pilar.scale.y
	var mundo_z: float = caja.size.z * pilar.scale.z

	# Assert: X ceñido al visual (clavadas que parezcan impactar, no flotar) y Z con cobertura
	assert_almost_eq(mundo_x, ANCHO_ESPERADO_MUNDO_X, TOLERANCIA_ANCHO_X, "Ancho mundo X %.2f debe ceñir el visual (~%.2f)" % [mundo_x, ANCHO_ESPERADO_MUNDO_X])
	assert_almost_eq(mundo_y, ALTURA_ESPERADA_MUNDO_Y, 0.05, "Alto mundo Y debe ser ~%.2f, fue %.2f" % [ALTURA_ESPERADA_MUNDO_Y, mundo_y])
	assert_gte(mundo_z, PROFUNDIDAD_MINIMA_MUNDO_Z, "Profundidad mundo Z %.2f debe ser >= %.2f" % [mundo_z, PROFUNDIDAD_MINIMA_MUNDO_Z])

	# Assert: el hitbox centrado en el pilar del río debe alcanzar el plano Z de la jugadora
	var mitad_z: float = mundo_z * 0.5
	var cubre: bool = absf(Z_JUGADORA_RIO - Z_PILAR_RIO) <= mitad_z
	assert_true(cubre, "El hitbox (Z %.2f ± %.2f) debe cubrir el plano de la jugadora %.2f" % [Z_PILAR_RIO, mitad_z, Z_JUGADORA_RIO])


func test_pilar_recibe_dano_y_avisa_destruccion_una_vez() -> void:
	# Arrange
	var pilar: Node3D = await _instanciar_pilar()
	var body := pilar.find_child("PilarBody", true, false) as PilarLonkoBody
	var lonko_falso := LonkoFalso.new()
	scene_root.add_child(lonko_falso)
	body.inicializar(lonko_falso, 15.0)

	# Assert: vida inicial
	assert_eq(body.vida_pilar, 15.0, "El pilar debe iniciar con 15 de vida")

	# Act: 14 impactos de flecha normal (1.0 de daño)
	for _i in range(14):
		body.recibir_golpe(1.0)

	# Assert: aún en pie y sin aviso
	assert_eq(body.vida_pilar, 1.0, "Tras 14 impactos debe quedar 1 de vida")
	assert_eq(lonko_falso.destruido_llamadas, 0, "Sin aviso de destrucción antes del golpe letal")

	# Act: golpe letal 15
	body.recibir_golpe(1.0)

	# Assert: aviso único
	assert_true(body.vida_pilar <= 0.0, "La vida debe agotarse con 15 impactos")
	assert_eq(lonko_falso.destruido_llamadas, 1, "Debe avisar a Lonko exactamente una vez")

	# Act: impactos extra sobre el pilar caído
	body.recibir_golpe(1.0)
	body.take_damage(5.0)

	# Assert: sin avisos duplicados
	assert_eq(lonko_falso.destruido_llamadas, 1, "No debe re-avisar tras la destrucción")


func test_pilar_take_damage_es_alias_de_recibir_golpe() -> void:
	# Arrange
	var pilar: Node3D = await _instanciar_pilar()
	var body := pilar.find_child("PilarBody", true, false) as PilarLonkoBody
	var lonko_falso := LonkoFalso.new()
	scene_root.add_child(lonko_falso)
	body.inicializar(lonko_falso, 15.0)

	# Act
	body.take_damage(2.0)

	# Assert
	assert_eq(body.vida_pilar, 13.0, "take_damage(2.0) debe restar 2 de vida")
