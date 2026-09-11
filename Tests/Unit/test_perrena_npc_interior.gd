extends GutTest

## Tests del NPC Perrena en el interior de la torre (Player_Interior.tscn).
## Solo exhibición: sin física ni input; ciclo pose (10 s) -> idle (10 s)
## con crossfade suave del AnimationTree.

const ESCENA_NIVEL: PackedScene = preload("res://Levels/Player_Interior.tscn")
const ANIM_POSE := "Pose feemenina fija"


func _obtener_npc(nivel: Node) -> PerrenaNPCInterior:
	return nivel.find_child("PerrenaNPC", true, false) as PerrenaNPCInterior


func _obtener_arbol(npc: PerrenaNPCInterior) -> AnimationTree:
	return npc.find_child("AnimationTree", true, false) as AnimationTree


func test_interior_contiene_npc_perrena() -> void:
	# Arrange
	var nivel = ESCENA_NIVEL.instantiate()
	add_child_autofree(nivel)
	await get_tree().process_frame

	# Act
	var npc := _obtener_npc(nivel)

	# Assert: existe, arranca en la pose y sin física.
	assert_not_null(npc, "El interior debe tener el NPC Perrena")
	assert_true(npc is PerrenaNPCInterior, "Es el script del NPC (Node3D puro, sin física)")


func test_npc_cicla_pose_a_idle_con_transicion_suave() -> void:
	# Arrange
	var nivel = ESCENA_NIVEL.instantiate()
	add_child_autofree(nivel)
	await get_tree().process_frame
	var npc := _obtener_npc(nivel)
	var tree := _obtener_arbol(npc)
	assert_not_null(tree, "El NPC construye su AnimationTree")
	assert_true(tree.active, "El árbol del NPC está activo")

	# Act: avanzar 10 s (la pose dura DURACION_POSE) y un frame para que
	# el AnimationTree procese el transition_request encolado.
	npc._process(10.1)
	await get_tree().process_frame

	# Assert: pasó a idle con crossfade (transition_request, no salto).
	assert_false(npc._en_pose, "Tras 10 s de pose cambia a idle")
	var estado: String = String(tree.get("parameters/Alterna/current_state"))
	assert_eq(estado, "idle", "El estado activo del árbol es idle")

	# Act: otros 10 s y vuelve a la pose (ciclo continuo).
	npc._process(10.1)
	await get_tree().process_frame
	assert_true(npc._en_pose, "El ciclo vuelve a la pose")

	# Assert: xfade configurado (transición suave, no corte).
	assert_almost_eq(
		(tree.tree_root.get_node("Alterna") as AnimationNodeTransition).xfade_time,
		0.6, 0.01, "Crossfade de 0.6 s entre pose e idle"
	)


func test_npc_resuelve_clips_del_glb() -> void:
	# Arrange
	var nivel = ESCENA_NIVEL.instantiate()
	add_child_autofree(nivel)
	await get_tree().process_frame
	var npc := _obtener_npc(nivel)
	var anim_p := npc.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert_not_null(anim_p, "El GLB trae su AnimationPlayer")

	# Act: los clips existen tal cual los nombra el GLB (el de la pose
	# trae el typo "feemenina" del propio archivo).
	var pose := npc._resolver_anim_sufijo(anim_p, ANIM_POSE)
	var idle := npc._resolver_anim_idle(anim_p, "Idle")

	# Assert
	assert_false(pose.is_empty(), "Resuelve el clip 'Pose feemenina fija'")
	assert_false(idle.is_empty(), "Resuelve el clip 'Idle'")
	assert_true(String(pose).to_lower().ends_with("fija"), "Es el clip de la pose")
	assert_eq(String(idle), "Idle", "Es el clip idle (no 'Idle agachada')")


func test_npc_solo_conoce_pose_e_idle_interior_seguro() -> void:
	# El interior de la torre es seguro: el AnimationPlayer del NPC se
	# AISLA (librería privada con copias) y solo quedan las 2 animaciones
	# permitidas. "Disparo arco", "Muerte", "impacto" y compañía ya no
	# existen en el NPC: nadie puede disparlas.
	# Arrange
	var nivel = ESCENA_NIVEL.instantiate()
	add_child_autofree(nivel)
	await get_tree().process_frame
	var npc := _obtener_npc(nivel)
	var anim_p := npc.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert_not_null(anim_p, "El NPC tiene AnimationPlayer")

	# Act
	var lista: Array = []
	for lib in anim_p.get_animation_library_list():
		lista.append_array(anim_p.get_animation_library(lib).get_animation_list())

	# Assert: exactamente las 2 permitidas.
	assert_eq(lista.size(), 2, "El NPC solo conserva 2 animaciones (pose e idle), tiene %s" % [lista])
	for nombre in lista:
		var n := String(nombre).to_lower()
		assert_true(
			n.ends_with("fija") or n == "idle",
			"Solo 'Pose feemenina fija' e 'Idle' sobreviven al aislamiento: %s" % nombre
		)

	# Assert: las de combate/accessibles ya no existen.
	for prohibida in ["Disparo arco", "Muerte 1", "impacto", "Saltar", "Correr", "Celebracion"]:
		assert_false(anim_p.has_animation(prohibida), "'%s' eliminada del aislamiento" % prohibida)

	# Assert: el player quedó detenido por el aislamiento (solo el
	# AnimationTree manda; sin reproducción suelta).
	assert_false(anim_p.is_playing(), "El AnimationPlayer quedó detenido tras el aislamiento")


func test_npc_no_muta_la_libreria_compartida_del_glb() -> void:
	# REGRESIÓN (bug real): la librería "" del AnimationPlayer del GLB es
	# COMPARTIDA por todas sus instancias (idéntico objeto en memoria).
	# La poda original retiraba los clips de ese recurso compartido y la
	# Perrena de la cinemática de oleada 5 (mismo GLB) se quedaba sin
	# Caminar/Correr. El NPC debe AISLAR (copias privadas), jamás podar.
	# Arrange: una instancia del GLB AJENA al NPC, como la de la cinemática.
	var glb: PackedScene = load("res://Entities/Jugador_Perrena/Perrena.glb")
	var ajena: Node = glb.instantiate()
	add_child_autofree(ajena)
	var nivel = ESCENA_NIVEL.instantiate()
	add_child_autofree(nivel)
	await get_tree().process_frame
	var npc := _obtener_npc(nivel)
	var anim_ajeno: AnimationPlayer = ajena.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert_not_null(anim_ajeno, "La instancia ajena (cinemática) trae su AnimationPlayer")

	# Act: el NPC ya aisló su librería en su _ready (el nivel cargó).
	# Assert: la instancia ajena conserva TODOS sus clips de locomoción.
	for clip in ["Idle", "Caminar", "Correr", "Disparo arco", "Saltar", "Muerte 1", "Escaleras"]:
		assert_true(
			anim_ajeno.has_animation(clip),
			"'%s' sigue en la librería compartida tras aislar el NPC" % clip
		)
	# Assert: nada del GLB quedó en loop forzado (el NPC loopea sus COPIAS).
	var idle_orig: Animation = anim_ajeno.get_animation_library("").get_animation("Idle")
	assert_eq(
		idle_orig.loop_mode, Animation.LOOP_NONE,
		"El clip original del GLB queda sin loop (el NPC loopea copias privadas)"
	)


func test_npc_material_de_perrena_y_contorno_fino() -> void:
	# Arrange
	var nivel = ESCENA_NIVEL.instantiate()
	add_child_autofree(nivel)
	await get_tree().process_frame
	var npc := _obtener_npc(nivel)

	# Act & Assert: material de Perrena en las mallas y contorno 2.0.
	var mats: Array[Material] = []
	for m in npc.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.material_override:
			mats.append(mi.material_override)
	assert_false(mats.is_empty(), "El NPC aplica material_override en sus mallas")
	for mat in mats:
		assert_true(
			mat == npc.MAT_PERRENA or (mat is StandardMaterial3D and (mat as StandardMaterial3D).next_pass != null),
			"Material de Perrena o contorno fino duplicado"
		)


func test_npc_ignora_alias_de_ataque_registrados_por_la_jugable() -> void:
	# Escenario del bug: la cinemática instancia la Perrena JUGABLE en
	# NIVEL01 y su script registra alias en la librería del GLB, entre
	# ellos "Armature|Armature|APUNTAR_IDLE" (copia del ataque "Disparo
	# arco"), que TERMINA EN "idle". Si el NPC resolviera su idle por
	# sufijo adoptaría el ataque y se pondría a "disparar" en la torre.
	# Arrange: nivel + NPC, pero ANTES simulamos el remapeo de la jugable
	# registrando ese alias en el player del NPC (como llega compartido).
	var nivel = ESCENA_NIVEL.instantiate()
	add_child_autofree(nivel)
	await get_tree().process_frame
	var npc := _obtener_npc(nivel)
	var anim_p := npc.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert_not_null(anim_p, "El NPC tiene AnimationPlayer")
	# Simular la contaminación REAL: la Perrena jugable registra el alias
	# "Armature|Armature|APUNTAR_IDLE" (copia del ataque) en la librería
	# COMPARTIDA del GLB. Se inyecta ANTES de cargar el interior, tal como
	# llega en juego si la cinemática pasó antes por NIVEL01.
	var glb: PackedScene = load("res://Entities/Jugador_Perrena/Perrena.glb")
	var plantilla: Node = glb.instantiate()
	add_child(plantilla)
	var ap_plantilla: AnimationPlayer = plantilla.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var lib_glb: AnimationLibrary = ap_plantilla.get_animation_library("")
	assert_not_null(lib_glb, "Librería por defecto del GLB")
	var alias_nuevo: bool = not lib_glb.has_animation("Armature|Armature|APUNTAR_IDLE")
	if alias_nuevo and ap_plantilla.has_animation("Disparo arco"):
		lib_glb.add_animation(
			"Armature|Armature|APUNTAR_IDLE",
			lib_glb.get_animation("Disparo arco")
		)
	plantilla.free()

	# Act: cargar el interior CON el alias contaminando el GLB: el NPC
	# resuelve su idle por nombre EXACTO (no por sufijo) y su aislamiento
	# copia solo pose + idle (el alias no sobrevive).
	var nivel2 = ESCENA_NIVEL.instantiate()
	add_child_autofree(nivel2)
	await get_tree().process_frame
	var npc2 := _obtener_npc(nivel2)
	var anim_p2: AnimationPlayer = npc2.find_child("AnimationPlayer", true, false) as AnimationPlayer
	assert_not_null(anim_p2, "El segundo NPC tiene AnimationPlayer")

	# Assert: el alias de ataque NO existe en el player del NPC aislado.
	assert_false(
		anim_p2.has_animation("Armature|Armature|APUNTAR_IDLE"),
		"El alias de ataque (APUNTAR_IDLE) no sobrevive al aislamiento del NPC"
	)
	assert_false(anim_p2.has_animation("Disparo arco"), "El ataque 'Disparo arco' no existe en el NPC")
	assert_true(anim_p2.has_animation("Idle"), "El idle del NPC es el 'Idle' real")

	# Assert: el idle se resolvió por nombre exacto, no por sufijo.
	var idle_resuelto := npc2._resolver_anim_idle(anim_p2, "Idle")
	assert_eq(String(idle_resuelto), "Idle", "El idle se resuelve por nombre exacto, no por sufijo")

	# Cleanup: retirar el alias del GLB para no contaminar otros tests.
	if alias_nuevo and lib_glb.has_animation("Armature|Armature|APUNTAR_IDLE"):
		lib_glb.remove_animation("Armature|Armature|APUNTAR_IDLE")


func test_npc_con_colision_solidida_para_el_jugador() -> void:
	# Arrange
	var nivel = ESCENA_NIVEL.instantiate()
	add_child_autofree(nivel)
	await get_tree().process_frame
	var npc := _obtener_npc(nivel)

	# Assert: El NPC es un StaticBody3D (cuerpo de colisión sólido de choque)
	assert_not_null(npc, "El NPC existe en el nivel")
	assert_true(npc is StaticBody3D, "El NPC es StaticBody3D con colisión propia")
	assert_eq(npc.collision_layer, 1, "Colisión en layer 1 (bloquea al jugador)")

	# Assert: Forma de colisión de choque (CollisionShape3D cápsula)
	var forma := npc.find_child("CollisionShape3D", false, false) as CollisionShape3D
	if forma == null:
		forma = npc.find_child("ColisionShape", true, false) as CollisionShape3D
	assert_not_null(forma, "El NPC tiene forma de colisión de choque")
	var capsula := forma.shape as CapsuleShape3D
	assert_not_null(capsula, "La forma de choque es una cápsula")
	assert_gt(capsula.height, 0.1, "Cápsula con la altura del NPC en el interior")
	assert_gt(capsula.radius, 0.005, "Cápsula con radio utilizable")

	# Assert: Posee AreaInteraccion (Area3D) para activar el globo de texto
	var area := npc.find_child("AreaInteraccion", false, false) as Area3D
	assert_not_null(area, "El NPC tiene AreaInteraccion para el globo de texto")
	assert_true(area.collision_mask & 1 != 0, "El área detecta al jugador en layer 1")

	# Assert: el jugador interior colisiona en la layer del NPC (máscara
	# por defecto del CharacterBody3D: layer 1 incluida).
	var player_interior := nivel.find_child("Player", true, false) as CharacterBody3D
	assert_not_null(player_interior, "El jugador interior existe")
	assert_true(player_interior.collision_mask & npc.collision_layer != 0, "La máscara del jugador incluye la layer del NPC: no puede atravesarlo")
