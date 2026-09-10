extends GutTest

## Tests del cadáver del goblin ballestero (decorado de la cinemática de
## oleada 5): modelo congelado en el último frame de su muerte, invisible
## fuera de la escena.

const ESCENA_CADAVER: PackedScene = preload("res://Entities/Enemigo_Goblin/GoblinBallesteroCadaver.tscn")
const CINE: GDScript = preload("res://Levels/NIVEL01/CinematicaOleada5.gd")
const ANIM_MUERTE := "Armature|Armature|ENEMIGO_GOBLING_MUERTE_1"


func test_cadaver_oculto_por_defecto_y_congelado_en_ultimo_frame() -> void:
	# Arrange
	var cadaver = ESCENA_CADAVER.instantiate()
	add_child_autofree(cadaver)
	await get_tree().process_frame

	# Act & Assert: oculto por defecto (solo la cinemática lo muestra).
	assert_false(cadaver.visible, "El cadáver nace invisible (decorado de la cinemática)")

	# Assert: el AnimationPlayer quedó pausado al final del clip de muerte.
	var ap := cadaver.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert_not_null(ap, "El GLB trae su AnimationPlayer")
	assert_true(ap.is_paused() or not ap.is_playing(), "El player quedó pausado en el frame final")
	assert_almost_eq(
		ap.current_animation_position,
		ap.get_animation(ANIM_MUERTE).length - 0.01,
		0.05, "La posición del player es el último frame de la muerte"
	)
	assert_eq(ap.current_animation, ANIM_MUERTE, "La animación activa es la muerte 1")

	# Assert: sin física (decoración, no enemigo).
	assert_false(cadaver is CharacterBody3D, "El cadáver no es un cuerpo físico de enemigo")
	assert_true(cadaver is Node3D, "Es un nodo decorativo Node3D")


func test_cadaver_lleva_su_ballesta_y_material() -> void:
	# Arrange
	var cadaver = ESCENA_CADAVER.instantiate()
	add_child_autofree(cadaver)
	await get_tree().process_frame

	# Act & Assert: la ballesta va anclada a la mano (fiel al ballestero).
	var ballesta := cadaver.find_child("BALLES_GOBLING", true, false) as Node3D
	assert_not_null(ballesta, "El cadáver conserva su ballesta")
	assert_true(ballesta.visible, "La ballesta es visible con el cadáver")

	# Assert: material del goblin vivo (contorno TOON incluido).
	var mats: Array[Material] = []
	for m in cadaver.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.material_override:
			mats.append(mi.material_override)
	assert_false(mats.is_empty(), "Aplica material_override (GOBLING_MATERIAL)")


func test_cinematica_muestra_los_cadaveres_solo_durante_la_escena() -> void:
	# Arrange: nivel falso con los dos cadáveres colocados (como NIVEL01.tscn:
	# GoblinBallesteroCadaver y GoblinBallesteroCadaver2).
	var eryn = load("res://Entities/Jugador_Arquera/Player.tscn").instantiate()
	add_child_autofree(eryn)
	await get_tree().process_frame

	var nivel := Node.new()
	add_child_autofree(nivel)
	var cadaver1 = ESCENA_CADAVER.instantiate()
	cadaver1.name = "GoblinBallesteroCadaver"
	nivel.add_child(cadaver1)
	var cadaver2 = ESCENA_CADAVER.instantiate()
	cadaver2.name = "GoblinBallesteroCadaver2"
	nivel.add_child(cadaver2)
	await get_tree().process_frame
	assert_false(cadaver1.visible, "Antes de la cinemática el cadáver 1 está oculto")
	assert_false(cadaver2.visible, "Antes de la cinemática el cadáver 2 está oculto")

	var cams: Array[Camera3D] = []
	for ruta in ["SubViewportFrente3D/CamaraFrente", "SubViewportMedio3D/CamaraMedio", "SubViewportFondo3D/CamaraFondoDOF"]:
		var partes: PackedStringArray = ruta.split("/")
		var padre := SubViewport.new()
		padre.name = partes[0]
		nivel.add_child(padre)
		var cam := Camera3D.new()
		cam.name = partes[1]
		cam.position = Vector3(-3.06, 3.26, 40.97)
		padre.add_child(cam)
		cams.append(cam)

	var cine = CINE.new()
	nivel.add_child(cine)

	# Act: iniciar la cinemática.
	cine.iniciar(nivel, Callable())
	cine.entrada_torre_habilitada = false
	await get_tree().process_frame

	# Assert: la cinemática muestra ambos cadáveres.
	assert_true(cadaver1.visible, "La cinemática muestra el cadáver 1 del goblin")
	assert_true(cadaver2.visible, "La cinemática muestra el cadáver 2 del goblin")

	# Act: abortar la secuencia (ruta de fallo).
	cine._abortar()
	await get_tree().process_frame

	# Assert: al abortar vuelven a ocultarse.
	assert_false(cadaver1.visible, "Al abortar, el cadáver 1 se oculta de nuevo")
	assert_false(cadaver2.visible, "Al abortar, el cadáver 2 se oculta de nuevo")
