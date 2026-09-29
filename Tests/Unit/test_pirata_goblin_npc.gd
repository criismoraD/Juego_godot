extends "res://addons/gut/test.gd"

## Test unitario y de integración para PirataGoblinNPC:
## Verifica la instanciación con el modelo PirataGoblin.glb, aplicación de material,
## uso de la animación 'Strut Walking', ciclo de patrulla ida y vuelta con giro suave de 180°,
## presencia en la escena NivelPueblo y el sistema interactivo de diálogo de 3 viñetas.

const SCRIPT_PIRATA: GDScript = preload("res://Entities/NPC_PirataGoblin/PirataGoblinNPC.gd")
const SCENE_PIRATA: PackedScene = preload("res://Entities/NPC_PirataGoblin/PirataGoblinNPC.tscn")
const MATERIAL_PIRATA: Material = preload("res://Entities/Enemigo_Pirata_Goblin/MAT_PIRATA_GOBLIN.tres")


func before_all() -> void:
	if gut != null and gut.error_tracker != null:
		gut.error_tracker.treat_engine_errors_as = 0


func test_pirata_goblin_npc_instancia_correctamente():
	# Arrange & Act
	var npc: Node3D = SCENE_PIRATA.instantiate() as Node3D
	add_child_autofree(npc)

	# Assert
	assert_not_null(npc, "PirataGoblinNPC debe instanciarse")
	assert_not_null(npc.get("material_npc"), "Debe tener asignado material_npc")
	assert_eq(npc.get("capa_visual"), 1, "La capa visual por defecto debe ser 1")

	var skel: Skeleton3D = npc.call("_obtener_skeleton") as Skeleton3D
	assert_not_null(skel, "Debe contener un Skeleton3D")

	var meshes: Array[Node] = npc.find_children("*", "MeshInstance3D", true, false)
	assert_gt(meshes.size(), 0, "Debe contener al menos una MeshInstance3D")
	for m in meshes:
		var mi := m as MeshInstance3D
		assert_eq(mi.material_override, npc.get("material_npc"), "Las mallas deben tener aplicado el material del pirata goblin")


func test_pirata_goblin_solo_camina_con_strut_walking():
	# Arrange
	var npc: Node3D = SCENE_PIRATA.instantiate() as Node3D
	add_child_autofree(npc)

	var ap: AnimationPlayer = npc.call("_obtener_animation_player") as AnimationPlayer
	assert_not_null(ap, "Debe existir un AnimationPlayer en la jerarquía del modelo")
	assert_true(ap.has_animation("Strut Walking"), "El modelo debe contener la animación 'Strut Walking'")

	# Act
	npc.call("iniciar_caminata")

	# Assert
	assert_eq(npc.get("anim_caminar"), &"Strut Walking", "La animación de caminata configurada debe ser 'Strut Walking'")
	assert_eq(ap.current_animation, "Strut Walking", "El AnimationPlayer debe estar reproduciendo 'Strut Walking'")
	var clip: Animation = ap.get_animation("Strut Walking")
	assert_eq(clip.loop_mode, Animation.LOOP_LINEAR, "'Strut Walking' debe estar en modo LOOP_LINEAR")


func test_patrulla_caminata_y_giro_180_grados():
	# Arrange
	var npc: Node3D = SCENE_PIRATA.instantiate() as Node3D
	npc.set("direccion_inicial", SCRIPT_PIRATA.Direccion.DERECHA)
	npc.call("configurar_patrulla", 2.0, 1.0)
	npc.set("tiempo_giro", 0.5)
	npc.set("distancia_desaceleracion", 0.2)
	npc.set("tiempo_aceleracion", 0.2)
	add_child_autofree(npc)

	var x_inicial: float = npc.position.x
	assert_eq(npc.call("obtener_estado"), SCRIPT_PIRATA.Estado.CAMINANDO)
	assert_eq(npc.call("obtener_direccion"), 1.0)

	# Act - caminar 1 segundo (avance a la derecha)
	npc._process(1.0)
	assert_gt(npc.position.x, x_inicial, "Debe avanzar en dirección positiva X hacia la derecha")
	assert_gt(npc.call("obtener_distancia_acumulada"), 0.0)

	# Act - avanzar hasta alcanzar el límite del recorrido (2.0 metros)
	npc._process(1.5)
	assert_eq(npc.call("obtener_estado"), SCRIPT_PIRATA.Estado.GIRANDO, "Al alcanzar el límite debe entrar en estado GIRANDO")

	# Act - completar el tiempo de giro (0.5 segundos)
	npc._process(0.6)
	assert_eq(npc.call("obtener_estado"), SCRIPT_PIRATA.Estado.CAMINANDO, "Tras completar el tiempo de giro debe volver a CAMINANDO")
	assert_eq(npc.call("obtener_direccion"), -1.0, "La dirección debe haberse invertido a la izquierda (-1.0)")

	# Act - caminar hacia la izquierda
	var x_tras_giro: float = npc.position.x
	npc._process(1.0)
	assert_lt(npc.position.x, x_tras_giro, "Debe avanzar en dirección negativa X hacia la izquierda")


func test_pirata_goblin_es_estrictamente_neutral_y_aliado():
	# Arrange & Act
	var npc: Node3D = SCENE_PIRATA.instantiate() as Node3D
	add_child_autofree(npc)

	# Assert
	assert_true(npc.is_in_group("allies"), "Debe pertenecer al grupo 'allies' para que las flechas lo ignoren")
	assert_true(npc.is_in_group("npcs"), "Debe pertenecer al grupo 'npcs'")
	assert_true(npc.is_in_group("neutral_npcs"), "Debe pertenecer al grupo 'neutral_npcs'")
	assert_false(npc.is_in_group("enemies"), "NUNCA debe estar en el grupo 'enemies'")
	assert_false(npc.is_in_group("enemigos"), "NUNCA debe estar en el grupo 'enemigos'")
	assert_eq(npc.get("es_enemigo"), false, "es_enemigo debe ser false")
	assert_eq(npc.get("es_neutral"), true, "es_neutral debe ser true")


func test_pirata_goblin_presente_en_nivel_pueblo():
	# Arrange
	var scene: PackedScene = load("res://Levels/Nivel_Pueblo/NivelPueblo.tscn")
	assert_not_null(scene, "La escena NivelPueblo debe existir")

	# Act
	var nivel: Node = scene.instantiate()
	add_child_autofree(nivel)

	# Assert
	assert_true(nivel.call("es_nivel_pueblo"), "NivelPueblo debe identificarse con es_nivel_pueblo() == true")
	var pirata: Node = nivel.find_child("*PirataGoblin*", true, false)
	assert_not_null(pirata, "Debe existir un nodo 'PirataGoblin' en NivelPueblo")
	assert_gt(pirata.get("distancia_recorrido"), 0.0, "distancia_recorrido configurada debe ser mayor a 0")
	assert_eq(pirata.get("anim_caminar"), &"Strut Walking", "Debe usar 'Strut Walking'")
	assert_true(pirata.is_in_group("allies"), "Pirata Goblin en NivelPueblo debe ser del grupo allies")
	assert_false(pirata.is_in_group("enemies"), "Pirata Goblin en NivelPueblo NO debe estar en enemies")


func test_dialogo_lineas_configuradas():
	# Arrange & Act
	var npc: Node3D = SCENE_PIRATA.instantiate() as Node3D
	add_child_autofree(npc)

	# Assert
	var lineas: PackedStringArray = npc.get("lineas_dialogo")
	assert_eq(lineas.size(), 3, "Debe tener 3 líneas de diálogo por defecto")
	assert_eq(lineas[0], "PIRATA_GOBLIN_PUEBLO_1", "Línea 1 debe ser clave de traducción")
	assert_eq(lineas[1], "PIRATA_GOBLIN_PUEBLO_2", "Línea 2 debe ser clave de traducción")
	assert_eq(lineas[2], "PIRATA_GOBLIN_PUEBLO_3", "Línea 3 debe ser clave de traducción")
	assert_ne(tr("PIRATA_GOBLIN_PUEBLO_1"), "PIRATA_GOBLIN_PUEBLO_1", "PIRATA_GOBLIN_PUEBLO_1 debe resolverse en el locale activo")
	assert_ne(tr("PIRATA_GOBLIN_PUEBLO_2"), "PIRATA_GOBLIN_PUEBLO_2", "PIRATA_GOBLIN_PUEBLO_2 debe resolverse en el locale activo")
	assert_ne(tr("PIRATA_GOBLIN_PUEBLO_3"), "PIRATA_GOBLIN_PUEBLO_3", "PIRATA_GOBLIN_PUEBLO_3 debe resolverse en el locale activo")


func test_deteccion_proximidad_y_tinte_morado():
	# Arrange
	var npc: Node3D = SCENE_PIRATA.instantiate() as Node3D
	npc.set("dialogo_interactivo", true)
	add_child_autofree(npc)
	watch_signals(npc)

	# Act 1: Acercar jugador
	npc.call("fijar_jugador_cerca", true)

	# Assert 1
	assert_signal_emitted_with_parameters(npc, "proximidad_jugador_cambiada", [true])
	assert_true(npc.call("esta_jugador_cerca"), "Debe registrar que el jugador está cerca")

	var prompt: Label3D = npc.call("obtener_prompt_hablar") as Label3D
	assert_not_null(prompt, "Debe existir PromptHablar")
	assert_eq(prompt.text, "[E] " + tr("PERRENA_PROMPT_HABLAR"), "El prompt debe usar la clave traducida")

	var tinte: StandardMaterial3D = npc.call("obtener_material_tinte") as StandardMaterial3D
	assert_not_null(tinte, "Debe haberse configurado el material de tinte morado")
	assert_almost_eq(tinte.albedo_color.r, 0.78, 0.01, "El color debe ser morado (R ~0.78)")

	# Act 2: Alejar jugador
	npc.call("fijar_jugador_cerca", false)

	# Assert 2
	assert_signal_emitted_with_parameters(npc, "proximidad_jugador_cambiada", [false])
	assert_false(npc.call("esta_jugador_cerca"), "Debe registrar que el jugador se alejó")


func test_flujo_completo_dialogo_tres_vinetas():
	# Arrange
	var npc: Node3D = SCENE_PIRATA.instantiate() as Node3D
	npc.set("dialogo_interactivo", true)
	add_child_autofree(npc)
	watch_signals(npc)
	npc.call("fijar_jugador_cerca", true)

	# Act 1: Iniciar diálogo (viñeta 1)
	npc.call("interactuar")

	# Assert 1
	assert_true(npc.call("esta_hablando_dialogo"), "Debe estar en diálogo")
	assert_eq(npc.call("obtener_indice_dialogo"), 1, "Debe estar en viñeta 1")
	assert_signal_emitted_with_parameters(npc, "dialogo_iniciado", ["PIRATA_GOBLIN_PUEBLO_1"])

	# Act 2: Avanzar a viñeta 2
	npc.call("interactuar")

	# Assert 2
	assert_true(npc.call("esta_hablando_dialogo"), "Debe seguir en diálogo")
	assert_eq(npc.call("obtener_indice_dialogo"), 2, "Debe estar en viñeta 2")
	assert_signal_emitted_with_parameters(npc, "dialogo_avanzado", [2, "PIRATA_GOBLIN_PUEBLO_2"])

	# Act 3: Avanzar a viñeta 3
	npc.call("interactuar")

	# Assert 3
	assert_true(npc.call("esta_hablando_dialogo"), "Debe seguir en diálogo")
	assert_eq(npc.call("obtener_indice_dialogo"), 3, "Debe estar en viñeta 3")
	assert_signal_emitted_with_parameters(npc, "dialogo_avanzado", [3, "PIRATA_GOBLIN_PUEBLO_3"])

	# Act 4: Cerrar diálogo
	npc.call("interactuar")

	# Assert 4
	assert_false(npc.call("esta_hablando_dialogo"), "El diálogo debe haberse cerrado")
	assert_eq(npc.call("obtener_indice_dialogo"), 0, "El índice debe reiniciarse a 0")
	assert_signal_emitted(npc, "dialogo_terminado")


func test_dialogo_pausa_y_reanuda_patrulla():
	# Arrange
	var npc: Node3D = SCENE_PIRATA.instantiate() as Node3D
	npc.set("dialogo_interactivo", true)
	npc.set("velocidad_caminar", 1.5)
	add_child_autofree(npc)
	npc.call("iniciar_caminata")
	assert_eq(npc.call("obtener_velocidad_actual"), 1.5)

	npc.call("fijar_jugador_cerca", true)

	# Act 1: Abrir diálogo
	npc.call("interactuar")

	# Assert 1: Velocidad debe detenerse en 0.0 durante el diálogo
	assert_eq(npc.call("obtener_velocidad_actual"), 0.0, "La velocidad debe ser 0.0 durante el diálogo")
	var pos_x_pausa: float = npc.position.x
	npc._process(0.5)
	assert_eq(npc.position.x, pos_x_pausa, "El NPC no debe avanzar mientras habla")

	# Act 2: Recorrer viñetas hasta cerrar
	npc.call("interactuar")  # viñeta 2
	npc.call("interactuar")  # viñeta 3
	npc.call("interactuar")  # cerrar

	# Assert 2: Al terminar, debe reanudar la caminata
	assert_false(npc.call("esta_hablando_dialogo"))
	assert_eq(npc.call("obtener_velocidad_actual"), 1.5, "Debe restaurar la velocidad de caminata")


func test_pirata_gira_hacia_jugador_durante_dialogo():
	# Arrange: Pirata en el origen, jugador ubicado en +Z
	var npc: Node3D = SCENE_PIRATA.instantiate() as Node3D
	npc.set("dialogo_interactivo", true)
	add_child_autofree(npc)

	var dummy_jugador := Node3D.new()
	dummy_jugador.name = "Player"
	dummy_jugador.add_to_group("player")
	add_child_autofree(dummy_jugador)
	dummy_jugador.global_position = npc.global_position + Vector3(0.0, 0.0, 2.0)

	var ap: AnimationPlayer = npc.call("_obtener_animation_player") as AnimationPlayer
	npc.call("fijar_jugador_cerca", true)

	# Act: Iniciar diálogo
	npc.call("interactuar")

	# Assert: Debe orientarse hacia el jugador (0° en local para +Z) y reproducir Idle
	npc.call("orientar_hacia_jugador", false)
	assert_almost_eq(npc.call("obtener_angulo_pivot"), 0.0, 0.5, "Debe orientarse de frente al jugador")
	assert_eq(ap.current_animation, "Idle", "Debe cambiar a animación Idle durante el diálogo")


func test_alejarse_durante_dialogo_cierra_y_reinicia():
	# Arrange
	var npc: Node3D = SCENE_PIRATA.instantiate() as Node3D
	npc.set("dialogo_interactivo", true)
	add_child_autofree(npc)
	watch_signals(npc)
	npc.call("fijar_jugador_cerca", true)

	# Iniciar diálogo
	npc.call("interactuar")
	assert_true(npc.call("esta_hablando_dialogo"))
	assert_eq(npc.call("obtener_indice_dialogo"), 1)

	# Act: Jugador se aleja
	npc.call("fijar_jugador_cerca", false)

	# Assert: Diálogo se cierra automáticamente y se reinicia
	assert_false(npc.call("esta_hablando_dialogo"), "El diálogo debe cerrarse si el jugador se aleja")
	assert_eq(npc.call("obtener_indice_dialogo"), 0, "El índice debe reiniciarse")
	assert_signal_emitted(npc, "dialogo_terminado")


func test_pirata_goblin_npc_1_en_nivel_pueblo():
	# Arrange: Cargar NivelPueblo
	var scene: PackedScene = load("res://Levels/Nivel_Pueblo/NivelPueblo.tscn")
	assert_not_null(scene, "La escena NivelPueblo debe existir")
	var nivel: Node = scene.instantiate()
	add_child_autofree(nivel)

	# Act
	var npc1: PirataGoblinNPC = nivel.find_child("PirataGoblin npc 1", true, false) as PirataGoblinNPC

	# Assert
	assert_not_null(npc1, "Debe existir 'PirataGoblin npc 1' en NivelPueblo.tscn")
	assert_true(npc1.es_dialogo_activo(), "PirataGoblin npc 1 debe tener diálogo activo")
	assert_eq(npc1.lineas_dialogo.size(), 3, "Debe tener 3 líneas de diálogo configuradas")
	assert_eq(npc1.lineas_dialogo[0], "PIRATA_GOBLIN_PUEBLO_1")
	assert_eq(npc1.lineas_dialogo[1], "PIRATA_GOBLIN_PUEBLO_2")
	assert_eq(npc1.lineas_dialogo[2], "PIRATA_GOBLIN_PUEBLO_3")
