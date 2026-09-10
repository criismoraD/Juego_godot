extends "res://addons/gut/test.gd"

## Sonido de impacto contra el suelo: registrado en AudioManager, suena en
## la caída alta de la protagonista (rama del humo) y una sola vez cuando
## el trapo de la gárgola toca el suelo. Sigue la estructura AAA.

const GARGOLA_SCENE: PackedScene = preload("res://Entities/Enemigo_Gargola/Gargola.tscn")

var audio_mgr: Node = null
var gargola: Node3D = null


func before_each():
	var audio_script = load("res://System/Core/AudioManager.gd")
	audio_mgr = audio_script.new()
	add_child(audio_mgr)


func after_each():
	if is_instance_valid(audio_mgr):
		audio_mgr.free()
	if is_instance_valid(gargola):
		gargola.free()


func test_impacto_suelo_registrado_y_reproducible():
	# Arrange & Act
	assert_true(audio_mgr.sfx_streams.has("impacto_suelo"), "Debe tener registrado impacto_suelo")
	var flujos: Array = audio_mgr.sfx_streams["impacto_suelo"]
	assert_eq(flujos.size(), 1, "Una variante del golpe contra el suelo")
	assert_not_null(flujos[0], "El recurso de audio no debe ser nulo")
	audio_mgr.play_sfx("impacto_suelo")

	# Assert: un reproductor del pool lo está sonando.
	var sonando: AudioStreamPlayer = null
	for p in audio_mgr.sfx_pool:
		if p.playing and p.stream != null:
			sonando = p
			break
	assert_not_null(sonando, "Un reproductor debe sonar impacto_suelo")


func _instanciar_gargola() -> Gargola:
	gargola = GARGOLA_SCENE.instantiate()
	add_child(gargola)
	await get_tree().process_frame
	return gargola as Gargola


func _crear_suelo_en(borde_superior_y: float) -> StaticBody3D:
	var suelo := StaticBody3D.new()
	suelo.collision_layer = 1
	suelo.collision_mask = 0
	var forma := CollisionShape3D.new()
	var caja := BoxShape3D.new()
	caja.size = Vector3(4.0, 0.2, 4.0)
	forma.shape = caja
	suelo.add_child(forma)
	add_child_autofree(suelo)
	suelo.global_position = Vector3(0.0, borde_superior_y - 0.1, 0.0)
	return suelo


func test_gargola_suena_una_vez_al_tocar_suelo():
	# Arrange
	var g := await _instanciar_gargola()
	assert_false(g._impacto_suelo_sonado, "Sin sonar al instanciar")
	var cadera := g._get_hips_global_position()
	assert_false(cadera.is_zero_approx(), "Precondición: cadera localizable")
	_crear_suelo_en(cadera.y - 0.2)
	await get_tree().physics_frame

	# Act
	g._detectar_impacto_suelo_ragdoll()

	# Assert: sonó una vez y el flag evita repetir.
	assert_true(g._impacto_suelo_sonado, "El trapo tocó suelo: suena impacto")
	g._detectar_impacto_suelo_ragdoll()
	assert_true(g._impacto_suelo_sonado, "Sigue marcado sin re-sonar")


func test_gargola_no_suena_en_el_aire():
	# Arrange
	var g := await _instanciar_gargola()
	var cadera := g._get_hips_global_position()
	_crear_suelo_en(cadera.y - 5.0)
	await get_tree().physics_frame

	# Act
	g._detectar_impacto_suelo_ragdoll()

	# Assert: en el aire no hay contacto que soner.
	assert_false(g._impacto_suelo_sonado, "Sin suelo debajo no suena")


func test_volumen_progresivo_con_la_altura():
	# Arrange
	var g := await _instanciar_gargola()

	# Act & Assert: suave junto al umbral, completo en caídas largas.
	assert_almost_eq(g._volumen_impacto_por_caida(0.9), -10.0, 0.01, "Junto al umbral suena suave")
	assert_almost_eq(g._volumen_impacto_por_caida(6.0), 0.0, 0.01, "En el punto alto suena a fuerza completa")
	assert_almost_eq(g._volumen_impacto_por_caida(20.0), 0.0, 0.01, "Por encima del máximo se queda al máximo")
	assert_almost_eq(g._volumen_impacto_por_caida(0.0), -10.0, 0.01, "Por debajo del mínimo se queda al mínimo")
	assert_true(
		g._volumen_impacto_por_caida(1.0) < g._volumen_impacto_por_caida(3.0)
			and g._volumen_impacto_por_caida(3.0) < g._volumen_impacto_por_caida(6.0),
		"A más altura, más fuerte"
	)
